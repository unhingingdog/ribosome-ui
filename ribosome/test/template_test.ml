open Ribosome.Template

let test_construct_input () =
  let _ = Input.{ id = "name"; value = Some (String "hello") } in
  let _ = Input.{ id = "age"; value = Some (Int 42) } in
  let _ = Input.{ id = "empty"; value = None } in
  Alcotest.(check pass) "input constructed" () ()

let test_construct_select () =
  let _ =
    Select.
      {
        id = "color";
        label = "Color";
        options = [ { value = "red"; label = "Red" } ];
        selected = Some "red";
      }
  in
  Alcotest.(check pass) "select constructed" () ()

let test_construct_button () =
  let _ =
    Button.{ id = "go"; label = "Go"; action = Submit; disabled = false }
  in
  let _ =
    Button.
      {
        id = "nav";
        label = "Next";
        action = Navigate "/page2";
        disabled = true;
      }
  in
  let _ =
    Button.
      {
        id = "custom";
        label = "Run";
        action = Custom "run-script";
        disabled = false;
      }
  in
  Alcotest.(check pass) "button constructed" () ()

let test_construct_text () =
  let _ = Text.{ id = "title"; text_type = H1; value = "Hello" } in
  let _ = Text.{ id = "body"; text_type = Paragraph; value = "World" } in
  Alcotest.(check pass) "text constructed" () ()

let test_construct_image () =
  let _ =
    Image.{ id = "logo"; src = "https://example.com/x.png"; alt = "Logo" }
  in
  Alcotest.(check pass) "image constructed" () ()

let test_construct_badge () =
  let _ = Badge.{ id = "status"; label = "Active"; variant = Success } in
  Alcotest.(check pass) "badge constructed" () ()

let test_construct_stat () =
  let _ =
    Stat.{ id = "count"; label = "Items"; value = "42"; secondary = None }
  in
  let _ =
    Stat.
      {
        id = "price";
        label = "Price";
        value = "$10";
        secondary = Some "was $20";
      }
  in
  Alcotest.(check pass) "stat constructed" () ()

let test_construct_divider () =
  let _ = Divider.{ id = "sep"; label = None } in
  let _ = Divider.{ id = "sep2"; label = Some "Section" } in
  Alcotest.(check pass) "divider constructed" () ()

let test_enum_roundtrip () =
  Stdlib.List.iter
    (fun tt ->
      Alcotest.(check string)
        "text_type roundtrip"
        (Text.string_of_text_type tt)
        (Text.string_of_text_type
           (Text.text_type_of_string (Text.string_of_text_type tt))))
    [ Text.Paragraph; H1; H2; H3; H4; H5; H6 ];
  Stdlib.List.iter
    (fun v ->
      Alcotest.(check string)
        "badge_variant roundtrip"
        (Badge.string_of_badge_variant v)
        (Badge.string_of_badge_variant
           (Badge.badge_variant_of_string (Badge.string_of_badge_variant v))))
    [ Badge.Neutral; Success; Warning; Error; Info ];
  Stdlib.List.iter
    (fun a ->
      Alcotest.(check string)
        "action roundtrip"
        (Button.string_of_action a)
        (Button.string_of_action
           (Button.action_of_string (Button.string_of_action a))))
    [ Button.Submit; Navigate "/home"; Custom "do-thing" ]

let test_construct_container () =
  let _ = Container.{ id = "root"; direction = Vertical; children = [] } in
  let _ =
    Container.
      {
        id = "row";
        direction = Horizontal;
        children =
          [ Text.{ id = "label"; text_type = Paragraph; value = "hi" } ];
      }
  in
  Alcotest.(check pass) "container constructed" () ()

let test_construct_list () =
  let _ = List.{ id = "items"; ordered = None; children = [] } in
  let _ =
    List.
      {
        id = "steps";
        ordered = Some true;
        children =
          [ Text.{ id = "step1"; text_type = Paragraph; value = "first" } ];
      }
  in
  Alcotest.(check pass) "list constructed" () ()

let test_construct_submittable () =
  let _ =
    Submittable.
      {
        id = "form";
        value = [ FieldInput Input.{ id = "name"; value = None } ];
        button = None;
      }
  in
  let _ =
    Submittable.
      {
        id = "form2";
        value =
          [
            FieldInput Input.{ id = "age"; value = Some (Int 30) };
            FieldSelect
              Select.
                {
                  id = "color";
                  label = "Color";
                  options = [ { value = "red"; label = "Red" } ];
                  selected = None;
                };
          ];
        button =
          Some
            Button.
              { id = "go"; label = "Go"; action = Submit; disabled = false };
      }
  in
  Alcotest.(check pass) "submittable constructed" () ()

let test_construct_diagram () =
  let _ =
    Diagram.
      {
        id = "flow";
        title = "Flow";
        size = { width = 100; height = 50 };
        primitives =
          [
            Text
              {
                text = "start";
                position = { x = 0; y = 0 };
                tone = Tone.Default;
              };
            Line
              {
                start = { x = 0; y = 0 };
                stop = { x = 50; y = 25 };
                tone = Tone.Positive;
              };
            Arrow
              {
                start = { x = 50; y = 25 };
                stop = { x = 100; y = 50 };
                tone = Tone.Negative;
              };
            Rectangle
              {
                origin = { x = 10; y = 10 };
                size = { width = 20; height = 10 };
                tone = Tone.Warning;
              };
            Circle { center = { x = 50; y = 25 }; radius = 5; tone = Tone.Info };
            Polyline
              {
                points =
                  [ { x = 0; y = 0 }; { x = 10; y = 10 }; { x = 20; y = 0 } ];
                tone = Tone.Default;
              };
          ];
      }
  in
  Alcotest.(check pass) "diagram constructed" () ()

let test_construct_code () =
  let _ =
    Code.
      {
        id = "snippet";
        path = "src/main.ml";
        language = "ocaml";
        line_start = 1;
        source = "let () = print_endline \"hello\"";
        highlights = [];
      }
  in
  let _ =
    Code.
      {
        id = "snippet2";
        path = "src/utils.rs";
        language = "rust";
        line_start = 10;
        source = "fn main() { }";
        highlights =
          [
            { start_line = 10; end_line = 10; tone = Tone.Positive };
            { start_line = 12; end_line = 15; tone = Tone.Negative };
          ];
      }
  in
  Alcotest.(check pass) "code constructed" () ()

let test_id_helper () =
  let cases =
    [
      (Text Text.{ id = "t1"; text_type = Paragraph; value = "x" }, "t1");
      (Image Image.{ id = "i1"; src = "s"; alt = "a" }, "i1");
      (Badge Badge.{ id = "b1"; label = "l"; variant = Neutral }, "b1");
      (Stat Stat.{ id = "s1"; label = "l"; value = "v"; secondary = None }, "s1");
      (Divider Divider.{ id = "d1"; label = None }, "d1");
      (Submittable Submittable.{ id = "sub"; value = []; button = None }, "sub");
      ( Container Container.{ id = "c1"; direction = Vertical; children = [] },
        "c1" );
      (List List.{ id = "l1"; ordered = None; children = [] }, "l1");
      ( Diagram
          Diagram.
            {
              id = "dg1";
              title = "t";
              size = { width = 1; height = 1 };
              primitives = [];
            },
        "dg1" );
      ( Code
          Code.
            {
              id = "cd1";
              path = "p";
              language = "l";
              line_start = 1;
              source = "s";
              highlights = [];
            },
        "cd1" );
    ]
  in
  Stdlib.List.iter
    (fun (tmpl, expected) -> Alcotest.(check string) "id" expected (id tmpl))
    cases

let test_children_helper () =
  let text_child = Text Text.{ id = "c"; text_type = Paragraph; value = "x" } in
  Alcotest.(check string)
    "container children" "c"
    (match
       children
         (Container
            Container.
              { id = "root"; direction = Vertical; children = [ text_child ] })
     with
    | Some [ c ] -> id c
    | _ -> "FAIL");
  Alcotest.(check string)
    "list children" "c"
    (match
       children
         (List List.{ id = "lst"; ordered = None; children = [ text_child ] })
     with
    | Some [ c ] -> id c
    | _ -> "FAIL");
  Alcotest.(check (option bool))
    "leaf has no children" None
    (match children text_child with Some _ -> Some true | None -> None)

let test_tone_roundtrip () =
  Stdlib.List.iter
    (fun t ->
      Alcotest.(check string)
        "tone roundtrip" (Tone.to_string t)
        (Tone.to_string (Tone.of_string (Tone.to_string t))))
    [ Tone.Default; Positive; Negative; Warning; Info ]

let () =
  Alcotest.run "ribosome-template"
    [
      ( "construction",
        [
          Alcotest.test_case "input" `Quick test_construct_input;
          Alcotest.test_case "select" `Quick test_construct_select;
          Alcotest.test_case "button" `Quick test_construct_button;
          Alcotest.test_case "text" `Quick test_construct_text;
          Alcotest.test_case "image" `Quick test_construct_image;
          Alcotest.test_case "badge" `Quick test_construct_badge;
          Alcotest.test_case "stat" `Quick test_construct_stat;
          Alcotest.test_case "divider" `Quick test_construct_divider;
          Alcotest.test_case "container" `Quick test_construct_container;
          Alcotest.test_case "list" `Quick test_construct_list;
          Alcotest.test_case "submittable" `Quick test_construct_submittable;
          Alcotest.test_case "diagram" `Quick test_construct_diagram;
          Alcotest.test_case "code" `Quick test_construct_code;
          Alcotest.test_case "enum roundtrip" `Quick test_enum_roundtrip;
          Alcotest.test_case "tone roundtrip" `Quick test_tone_roundtrip;
          Alcotest.test_case "id helper" `Quick test_id_helper;
          Alcotest.test_case "children helper" `Quick test_children_helper;
        ] );
    ]
