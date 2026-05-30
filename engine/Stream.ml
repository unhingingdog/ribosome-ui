external read : 'reader -> < done_ : bool [@mel.as "done"]; value : 'value > Js.t Js.Promise.t = "read" [@@mel.send]
external make_decoder : unit -> 'decoder = "TextDecoder" [@@mel.new]
external decode : 'decoder -> 'value -> string = "decode" [@@mel.send]

let sse_prefix = "data: "
let sse_prefix_len = String.length sse_prefix

type sse_state = {
  pending_line : string;
  done_ : bool;
}

type sse_event =
  | Data of string
  | Done

let create_sse_state () = {
  pending_line = "";
  done_ = false;
}

let has_data line =
  String.length line >= sse_prefix_len && String.sub line 0 sse_prefix_len = sse_prefix

let extract_data line =
  if has_data line then
    Some (String.sub line sse_prefix_len (String.length line - sse_prefix_len))
  else None

let trim_trailing_cr line =
  let len = String.length line in
  if len > 0 && line.[len - 1] = '\r' then
    String.sub line 0 (len - 1)
  else
    line

let parse_line line =
  match extract_data (trim_trailing_cr line) with
  | Some "[DONE]" -> Some Done
  | Some payload -> Some (Data payload)
  | None -> None

let parse_complete_lines lines =
  let rec loop events = function
    | [] -> (List.rev events, false)
    | line :: rest ->
      (match parse_line line with
      | Some Done -> (List.rev (Done :: events), true)
      | Some (Data _ as event) -> loop (event :: events) rest
      | None -> loop events rest)
  in
  loop [] lines

let parse_sse_chunk state raw =
  if state.done_ then
    ([], state)
  else
    let combined = state.pending_line ^ raw in
    let lines = String.split_on_char '\n' combined in
    let complete_lines, pending_line =
      match List.rev lines with
      | [] -> ([], "")
      | last :: complete_reversed -> (List.rev complete_reversed, last)
    in
    let events, done_ = parse_complete_lines complete_lines in
    let next_state = {
      pending_line = if done_ then "" else pending_line;
      done_;
    } in
    (events, next_state)

let pump ~on_chunk ~on_done reader =
  let decoder = make_decoder () in
  let done_called = ref false in
  let finish () =
    if not !done_called then begin
      done_called := true;
      on_done ()
    end
  in
  let rec drain state =
    read reader
    |> Js.Promise.then_ (fun result ->
      if result##done_ || state.done_ then begin
        finish ();
        Js.Promise.resolve ()
      end
      else begin
        let events, next_state = result##value |> decode decoder |> parse_sse_chunk state in
        List.iter (function Data payload -> on_chunk payload | Done -> ()) events;
        if next_state.done_ then begin
          finish ();
          Js.Promise.resolve ()
        end else
          drain next_state
      end)
  in
  drain (create_sse_state ())
