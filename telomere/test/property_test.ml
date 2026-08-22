(* Property-based Telomere coverage using QCheck.

   Properties:
   1. Complete valid JSON finishes with Completion "".
   2. Every emitted completion produces JSON accepted by Yojson.Safe.from_string.
   3. Final output is invariant under arbitrary chunk partitioning.
   4. A corrupted processor remains corrupted for all subsequent input.

   The Yojson dependency lives in the test stanza only; it is not a dependency
   of the telomere library itself. *)

open QCheck2

(* --- Bounded recursive Yojson.Safe.t generator --- *)

(* A bounded recursive JSON value generator. Depth is limited to prevent
   exponential blow-up; at depth 0 only leaf values are generated. Floats
   are filtered to exclude NaN and Infinity, which are not valid standard
   JSON. Strings are restricted to ASCII printable characters (32-126)
   to avoid \u escape sequences, which Telomere does not fully support
   (known limitation from the original Rust port). *)
let finite_float_gen =
  Gen.map (fun f -> if Float.is_finite f then f else 0.0) Gen.float

(* String generator using only ASCII printable characters (no control
   characters, no quotes, no backslashes). Uses a custom primitive generator
   to ensure the shrinker also stays within the valid range. *)
let ascii_printable_gen : string Gen.t =
  Gen.make_primitive
    ~gen:(fun st ->
      let n = 1 + Random.State.int st 8 in
      let buf = Buffer.create n in
      for _ = 1 to n do
        let code = 32 + Random.State.int st 93 in
        let c = Char.chr code in
        if c <> '"' && c <> '\\' then Buffer.add_char buf c
        else Buffer.add_char buf 'a'
      done;
      Buffer.contents buf)
    ~shrink:(fun s ->
      let len = String.length s in
      if len <= 1 then Seq.empty
      else
        List.to_seq
          [ String.sub s 0 (len / 2); String.sub s (len / 2) (len - (len / 2)) ])

let rec json_gen depth =
  if depth <= 0 then
    Gen.oneof
      [
        Gen.return `Null;
        Gen.map (fun b -> `Bool b) Gen.bool;
        Gen.map (fun i -> `Int i) Gen.int;
        Gen.map (fun f -> `Float f) finite_float_gen;
        Gen.map (fun s -> `String s) ascii_printable_gen;
      ]
  else
    Gen.oneof
      [
        Gen.return `Null;
        Gen.map (fun b -> `Bool b) Gen.bool;
        Gen.map (fun i -> `Int i) Gen.int;
        Gen.map (fun f -> `Float f) finite_float_gen;
        Gen.map (fun s -> `String s) ascii_printable_gen;
        Gen.map
          (fun items -> `List items)
          (Gen.list_small (json_gen (depth - 1)));
        Gen.map
          (fun kvs -> `Assoc kvs)
          (Gen.list_small
             (Gen.map2
                (fun k v -> (k, v))
                ascii_printable_gen
                (json_gen (depth - 1))));
      ]

(* Top-level generator: only objects and arrays, since Telomere expects
   top-level JSON to start with { or [. *)
let toplevel_json_gen =
  Gen.oneof
    [
      Gen.map (fun items -> `List items) (Gen.list_small (json_gen 3));
      Gen.map
        (fun kvs -> `Assoc kvs)
        (Gen.list_small
           (Gen.map2 (fun k v -> (k, v)) ascii_printable_gen (json_gen 3)));
    ]

let json_print = Yojson.Safe.show

(* --- Chunk partitioning generator --- *)

(* Partition a string into a list of non-empty substrings at arbitrary
   boundaries. Always produces at least one chunk. *)
let partition_gen (s : string) : string list Gen.t =
  let len = String.length s in
  if len <= 1 then Gen.return [ s ]
  else
    Gen.map
      (fun cut_points ->
        let cuts = List.sort compare cut_points in
        let rec chunks pos acc = function
          | [] -> if pos < len then String.sub s pos (len - pos) :: acc else acc
          | cut :: rest ->
              if cut > pos then
                chunks cut (String.sub s pos (cut - pos) :: acc) rest
              else chunks pos acc rest
        in
        List.rev (chunks 0 [] cuts))
      (Gen.list_small (Gen.int_range 1 (len - 1)))

(* --- Property 1: complete valid JSON finishes with Completion "" --- *)

let prop_complete_json_empty_completion =
  Test.make ~name:"complete valid JSON -> Completion \"\"" ~count:1000
    ~print:json_print toplevel_json_gen (fun json ->
      let s = Yojson.Safe.to_string json in
      let state = Telomere.Processor.create_processor () in
      let output, _ = Telomere.Processor.feed state s in
      match output with Telomere.Processor.Completion "" -> true | _ -> false)

(* --- Property 2: every completion produces valid JSON --- *)

let prop_completion_produces_valid_json =
  Test.make ~name:"buffer ^ suffix is valid JSON" ~count:1000 ~print:json_print
    toplevel_json_gen (fun json ->
      let full = Yojson.Safe.to_string json in
      let state = Telomere.Processor.create_processor () in
      let output, _ = Telomere.Processor.feed state full in
      match output with
      | Telomere.Processor.Completion suffix -> (
          try
            let _ = Yojson.Safe.from_string (full ^ suffix) in
            true
          with _ -> false)
      | _ -> false)

(* --- Property 3: final output invariant under chunk partitioning --- *)

let prop_chunk_invariance =
  let partitioned_gen =
    Gen.bind toplevel_json_gen (fun json ->
        let s = Yojson.Safe.to_string json in
        Gen.map (fun chunks -> (s, chunks)) (partition_gen s))
  in
  let partitioned_print (s, _) = s in
  Test.make ~name:"final completion is empty regardless of chunking" ~count:1000
    ~print:partitioned_print partitioned_gen (fun (_full, chunks) ->
      let state = Telomere.Processor.create_processor () in
      let _, final_state =
        List.fold_left
          (fun (_, state) chunk -> Telomere.Processor.feed state chunk)
          (Telomere.Processor.Pending, state)
          chunks
      in
      let output, _ = Telomere.Processor.feed final_state "" in
      match output with Telomere.Processor.Completion "" -> true | _ -> false)

(* --- Property 4: corrupted processor stays corrupted --- *)

let prop_corrupted_stays_corrupted =
  Test.make
    ~name:"corrupted processor remains corrupted for all subsequent input"
    ~count:1000 ~print:Print.string Gen.string_small (fun input ->
      let state = Telomere.Processor.create_processor () in
      let _, poisoned = Telomere.Processor.feed state "]" in
      let output, _ = Telomere.Processor.feed poisoned input in
      match output with Telomere.Processor.Corrupted -> true | _ -> false)

let () =
  Alcotest.run "telomere-properties"
    [
      ( "properties",
        [
          QCheck_alcotest.to_alcotest ~speed_level:`Quick
            prop_complete_json_empty_completion;
          QCheck_alcotest.to_alcotest ~speed_level:`Quick
            prop_completion_produces_valid_json;
          QCheck_alcotest.to_alcotest ~speed_level:`Quick prop_chunk_invariance;
          QCheck_alcotest.to_alcotest ~speed_level:`Quick
            prop_corrupted_stays_corrupted;
        ] );
    ]
