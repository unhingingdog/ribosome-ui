open Ribosome.Template

let check_roundtrip decode encode v =
  let json = encode v in
  match decode json with
  | Ok actual -> Alcotest.(check bool) "roundtrip" true (actual = v)
  | Error e -> Alcotest.fail ("roundtrip failed: " ^ Codec_error.to_string e)

let check_ok name decoder json expected =
  match decoder json with
  | Ok actual -> Alcotest.(check bool) name true (actual = expected)
  | Error e -> Alcotest.fail (name ^ ": " ^ Codec_error.to_string e)

let check_error name decoder json =
  match decoder json with
  | Ok _ -> Alcotest.fail (name ^ ": expected error")
  | Error _ -> Alcotest.(check bool) (name ^ ": reports error") true true

(* --- container --- *)

let test_container_roundtrip () =
  let text_child =
    Text Text.{ id = "t1"; text_type = Paragraph; value = "hi" }
  in
  check_roundtrip
    (Container.decode_child decode)
    (Container.encode_child encode)
    Container.{ id = "c1"; direction = Vertical; children = [] };
  check_roundtrip
    (Container.decode_child decode)
    (Container.encode_child encode)
    Container.{ id = "c2"; direction = Horizontal; children = [ text_child ] };
  check_roundtrip
    (Container.decode_child decode)
    (Container.encode_child encode)
    Container.
      {
        id = "c3";
        direction = Vertical;
        children =
          [
            text_child;
            Container
              Container.{ id = "nested"; direction = Horizontal; children = [] };
          ];
      }

let test_container_malformed () =
  check_error "container missing direction"
    (Container.decode_child decode)
    (`Assoc [ ("id", `String "c") ]);
  check_error "container missing children"
    (Container.decode_child decode)
    (`Assoc [ ("id", `String "c"); ("direction", `String "Vertical") ])

(* --- list --- *)

let test_list_roundtrip () =
  let text_child =
    Text Text.{ id = "t1"; text_type = Paragraph; value = "hi" }
  in
  check_roundtrip (List.decode decode) (List.encode encode)
    List.{ id = "l1"; ordered = None; children = [] };
  check_roundtrip (List.decode decode) (List.encode encode)
    List.{ id = "l2"; ordered = Some true; children = [ text_child ] };
  check_roundtrip (List.decode decode) (List.encode encode)
    List.{ id = "l3"; ordered = Some false; children = [ text_child ] }

let test_list_malformed () =
  check_error "list missing children" (List.decode decode)
    (`Assoc [ ("id", `String "l") ])

(* --- submittable --- *)

let test_submittable_roundtrip () =
  let input_field =
    Submittable.FieldInput Input.{ id = "name"; value = Some (String "x") }
  in
  let select_field =
    Submittable.FieldSelect
      Select.
        {
          id = "color";
          label = "Color";
          options = [ { value = "r"; label = "Red" } ];
          selected = None;
        }
  in
  let button =
    Some Button.{ id = "go"; label = "Go"; action = Submit; disabled = false }
  in
  check_roundtrip Submittable.decode Submittable.encode
    Submittable.{ id = "s1"; value = []; button = None };
  check_roundtrip Submittable.decode Submittable.encode
    Submittable.{ id = "s2"; value = [ input_field ]; button = None };
  check_roundtrip Submittable.decode Submittable.encode
    Submittable.{ id = "s3"; value = [ input_field; select_field ]; button }

let test_submittable_malformed () =
  check_error "submittable missing value" Submittable.decode
    (`Assoc [ ("id", `String "s") ]);
  check_error "submittable unknown field kind" Submittable.decode
    (`Assoc
       [
         ("id", `String "s");
         ("value", `List [ `Assoc [ ("kind", `String "button") ] ]);
       ]);
  check_error "submittable field missing kind" Submittable.decode
    (`Assoc
       [
         ("id", `String "s"); ("value", `List [ `Assoc [ ("id", `String "f") ] ]);
       ])

(* --- diagram --- *)

let test_diagram_roundtrip () =
  let prim_text =
    Diagram.Text
      { text = "a"; position = { x = 1; y = 2 }; tone = Tone.Default }
  in
  let prim_line =
    Diagram.Line
      {
        start = { x = 0; y = 0 };
        stop = { x = 10; y = 10 };
        tone = Tone.Positive;
      }
  in
  let prim_arrow =
    Diagram.Arrow
      {
        start = { x = 0; y = 0 };
        stop = { x = 5; y = 5 };
        tone = Tone.Negative;
      }
  in
  let prim_rect =
    Diagram.Rectangle
      {
        origin = { x = 0; y = 0 };
        size = { width = 10; height = 5 };
        tone = Tone.Warning;
      }
  in
  let prim_circle =
    Diagram.Circle { center = { x = 5; y = 5 }; radius = 3; tone = Tone.Info }
  in
  let prim_poly =
    Diagram.Polyline
      { points = [ { x = 0; y = 0 }; { x = 1; y = 1 } ]; tone = Tone.Default }
  in
  check_roundtrip Diagram.decode Diagram.encode
    Diagram.
      {
        id = "d1";
        title = "t";
        size = { width = 100; height = 50 };
        primitives = [];
      };
  check_roundtrip Diagram.decode Diagram.encode
    Diagram.
      {
        id = "d2";
        title = "t";
        size = { width = 100; height = 50 };
        primitives =
          [
            prim_text; prim_line; prim_arrow; prim_rect; prim_circle; prim_poly;
          ];
      }

let test_diagram_primitive_malformed () =
  check_error "diagram unknown primitive kind" Diagram.decode_primitive
    (`Assoc [ ("kind", `String "triangle") ])

let test_diagram_malformed () =
  check_error "diagram missing size" Diagram.decode
    (`Assoc [ ("id", `String "d"); ("title", `String "t") ])

(* --- code --- *)

let test_code_roundtrip () =
  check_roundtrip Code.decode Code.encode
    Code.
      {
        id = "c1";
        path = "p";
        language = "ocaml";
        line_start = 1;
        source = "s";
        highlights = [];
      };
  check_roundtrip Code.decode Code.encode
    Code.
      {
        id = "c2";
        path = "p";
        language = "rust";
        line_start = 10;
        source = "fn main() {}";
        highlights = [ { start_line = 1; end_line = 2; tone = Tone.Positive } ];
      }

let test_code_malformed () =
  check_error "code missing source" Code.decode
    (`Assoc
       [
         ("id", `String "c");
         ("path", `String "p");
         ("language", `String "l");
         ("line_start", `Int 1);
       ]);
  check_error "code highlight missing tone" Code.decode_highlight
    (`Assoc [ ("start_line", `Int 1); ("end_line", `Int 2) ])

(* --- central dispatch --- *)

let test_dispatch_unknown_kind () =
  check_error "unknown kind" decode
    (`Assoc [ ("kind", `String "unknown"); ("id", `String "x") ])

let test_dispatch_nested_only_at_root () =
  check_error "input at root" decode
    (`Assoc [ ("kind", `String "input"); ("id", `String "x") ]);
  check_error "select at root" decode
    (`Assoc [ ("kind", `String "select"); ("id", `String "x") ]);
  check_error "button at root" decode
    (`Assoc [ ("kind", `String "button"); ("id", `String "x") ])

let test_dispatch_valid_top_level () =
  let json =
    Text.encode Text.{ id = "t1"; text_type = Paragraph; value = "hi" }
  in
  check_ok "text ok" decode json
    (Text Text.{ id = "t1"; text_type = Paragraph; value = "hi" });
  let json =
    Container.encode_child encode
      Container.{ id = "c1"; direction = Vertical; children = [] }
  in
  check_ok "container ok" decode json
    (Container Container.{ id = "c1"; direction = Vertical; children = [] })

(* --- string encode/decode --- *)

let test_string_roundtrip () =
  let tree = Text Text.{ id = "t1"; text_type = Paragraph; value = "hello" } in
  let s = encode_string tree in
  match decode_string s with
  | Ok actual -> Alcotest.(check bool) "string roundtrip" true (actual = tree)
  | Error e -> Alcotest.fail ("string roundtrip: " ^ Codec_error.to_string e)

let test_decode_string_invalid_json () =
  match decode_string "not json" with
  | Ok _ -> Alcotest.fail "expected error for invalid JSON"
  | Error e ->
      Alcotest.(check string)
        "invalid JSON category" "wrong type"
        (Codec_error.category_to_string e.category)

(* --- full tree with every variant --- *)

let test_full_tree_roundtrip () =
  let text = Text Text.{ id = "text"; text_type = H1; value = "Title" } in
  let image = Image Image.{ id = "image"; src = "http://x"; alt = "x" } in
  let badge = Badge Badge.{ id = "badge"; label = "ok"; variant = Success } in
  let stat =
    Stat Stat.{ id = "stat"; label = "n"; value = "42"; secondary = None }
  in
  let divider = Divider Divider.{ id = "divider"; label = Some "sep" } in
  let diagram =
    Diagram
      Diagram.
        {
          id = "diagram";
          title = "d";
          size = { width = 10; height = 10 };
          primitives =
            [
              Text
                { text = "a"; position = { x = 0; y = 0 }; tone = Tone.Default };
            ];
        }
  in
  let code =
    Code
      Code.
        {
          id = "code";
          path = "p";
          language = "ocaml";
          line_start = 1;
          source = "let () = ()";
          highlights = [ { start_line = 1; end_line = 1; tone = Tone.Info } ];
        }
  in
  let list_ =
    List
      List.
        {
          id = "list";
          ordered = Some true;
          children =
            [ Text Text.{ id = "li"; text_type = Paragraph; value = "item" } ];
        }
  in
  let submittable =
    Submittable
      Submittable.
        {
          id = "submittable";
          value =
            [
              FieldInput Input.{ id = "in"; value = Some (Int 1) };
              FieldSelect
                Select.
                  {
                    id = "sel";
                    label = "L";
                    options = [ { value = "a"; label = "A" } ];
                    selected = Some "a";
                  };
            ];
          button =
            Some
              Button.
                { id = "btn"; label = "Go"; action = Submit; disabled = false };
        }
  in
  let tree =
    Container
      Container.
        {
          id = "root";
          direction = Vertical;
          children =
            [
              text;
              image;
              badge;
              stat;
              divider;
              diagram;
              code;
              list_;
              submittable;
            ];
        }
  in
  let s = encode_string tree in
  match decode_string s with
  | Ok actual -> Alcotest.(check bool) "full tree roundtrip" true (actual = tree)
  | Error e -> Alcotest.fail ("full tree roundtrip: " ^ Codec_error.to_string e)

let () =
  Alcotest.run "ribosome-composite-codec"
    [
      ( "container",
        [
          Alcotest.test_case "roundtrip" `Quick test_container_roundtrip;
          Alcotest.test_case "malformed" `Quick test_container_malformed;
        ] );
      ( "list",
        [
          Alcotest.test_case "roundtrip" `Quick test_list_roundtrip;
          Alcotest.test_case "malformed" `Quick test_list_malformed;
        ] );
      ( "submittable",
        [
          Alcotest.test_case "roundtrip" `Quick test_submittable_roundtrip;
          Alcotest.test_case "malformed" `Quick test_submittable_malformed;
        ] );
      ( "diagram",
        [
          Alcotest.test_case "roundtrip" `Quick test_diagram_roundtrip;
          Alcotest.test_case "primitive malformed" `Quick
            test_diagram_primitive_malformed;
          Alcotest.test_case "malformed" `Quick test_diagram_malformed;
        ] );
      ( "code",
        [
          Alcotest.test_case "roundtrip" `Quick test_code_roundtrip;
          Alcotest.test_case "malformed" `Quick test_code_malformed;
        ] );
      ( "dispatch",
        [
          Alcotest.test_case "unknown kind" `Quick test_dispatch_unknown_kind;
          Alcotest.test_case "nested-only at root" `Quick
            test_dispatch_nested_only_at_root;
          Alcotest.test_case "valid top-level" `Quick
            test_dispatch_valid_top_level;
        ] );
      ( "string",
        [
          Alcotest.test_case "roundtrip" `Quick test_string_roundtrip;
          Alcotest.test_case "invalid JSON" `Quick
            test_decode_string_invalid_json;
        ] );
      ( "full-tree",
        [
          Alcotest.test_case "every variant roundtrip" `Quick
            test_full_tree_roundtrip;
        ] );
    ]
