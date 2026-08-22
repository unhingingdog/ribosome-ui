open Ribosome.Template

let check_errors name tree expected_msgs =
  let errors = Ribosome.Validate.validate tree in
  let msgs =
    Stdlib.List.map (fun (e : Ribosome.Validate.error) -> e.message) errors
  in
  Alcotest.(check (list string)) name expected_msgs msgs

let check_no_errors name tree = check_errors name tree []

(* --- empty id --- *)

let test_empty_id () =
  let tree = Text Text.{ id = ""; text_type = Paragraph; value = "x" } in
  check_errors "empty id" tree [ "id must not be empty" ]

(* --- duplicate ids --- *)

let test_duplicate_ids () =
  let tree =
    Container
      Container.
        {
          id = "root";
          direction = Vertical;
          children =
            [
              Text Text.{ id = "dup"; text_type = Paragraph; value = "a" };
              Text Text.{ id = "dup"; text_type = Paragraph; value = "b" };
            ];
        }
  in
  check_errors "duplicate ids" tree [ "duplicate id across tree: dup" ]

(* --- diagram validation --- *)

let test_diagram_positive_size () =
  let tree =
    Diagram
      Diagram.
        {
          id = "d";
          title = "t";
          size = { width = 0; height = 10 };
          primitives = [];
        }
  in
  check_errors "diagram zero width" tree [ "width must be positive" ]

let test_diagram_circle_radius () =
  let tree =
    Diagram
      Diagram.
        {
          id = "d";
          title = "t";
          size = { width = 10; height = 10 };
          primitives =
            [
              Circle
                { center = { x = 0; y = 0 }; radius = 0; tone = Tone.Default };
            ];
        }
  in
  check_errors "diagram zero radius" tree [ "radius must be positive" ]

let test_diagram_polyline_points () =
  let tree =
    Diagram
      Diagram.
        {
          id = "d";
          title = "t";
          size = { width = 10; height = 10 };
          primitives =
            [ Polyline { points = [ { x = 0; y = 0 } ]; tone = Tone.Default } ];
        }
  in
  check_errors "diagram polyline short" tree
    [ "polyline must have at least 2 points" ]

(* --- code validation --- *)

let test_code_line_start () =
  let tree =
    Code
      Code.
        {
          id = "c";
          path = "p";
          language = "l";
          line_start = 0;
          source = "s";
          highlights = [];
        }
  in
  check_errors "code line_start zero" tree [ "line_start must be >= 1" ]

let test_code_highlight_order () =
  let tree =
    Code
      Code.
        {
          id = "c";
          path = "p";
          language = "l";
          line_start = 1;
          source = "s";
          highlights = [ { start_line = 5; end_line = 3; tone = Tone.Default } ];
        }
  in
  check_errors "code highlight inverted" tree
    [ "start_line (5) must not exceed end_line (3)" ]

let test_code_highlight_before_start () =
  let tree =
    Code
      Code.
        {
          id = "c";
          path = "p";
          language = "l";
          line_start = 10;
          source = "s";
          highlights = [ { start_line = 5; end_line = 5; tone = Tone.Default } ];
        }
  in
  check_errors "code highlight before line_start" tree
    [ "start_line must be >= line_start (10)" ]

(* --- select validation --- *)

let test_select_invalid_selected () =
  let tree =
    Submittable
      Submittable.
        {
          id = "s";
          value =
            [
              FieldSelect
                Select.
                  {
                    id = "color";
                    label = "Color";
                    options = [ { value = "r"; label = "Red" } ];
                    selected = Some "g";
                  };
            ];
          button = None;
        }
  in
  check_errors "select invalid selected" tree
    [ "selected value 'g' is not in options" ]

(* --- button validation --- *)

let test_button_empty_navigate () =
  let tree =
    Submittable
      Submittable.
        {
          id = "s";
          value = [];
          button =
            Some
              Button.
                {
                  id = "b";
                  label = "Go";
                  action = Navigate "";
                  disabled = false;
                };
        }
  in
  check_errors "button empty navigate" tree
    [ "Navigate action must have a non-empty URL" ]

let test_button_empty_custom () =
  let tree =
    Submittable
      Submittable.
        {
          id = "s";
          value = [];
          button =
            Some
              Button.
                { id = "b"; label = "Go"; action = Custom ""; disabled = false };
        }
  in
  check_errors "button empty custom" tree [ "Custom action must be non-empty" ]

(* --- valid tree has no errors --- *)

let test_valid_tree () =
  let tree =
    Container
      Container.
        {
          id = "root";
          direction = Vertical;
          children =
            [
              Text Text.{ id = "t1"; text_type = Paragraph; value = "hello" };
              Image Image.{ id = "img"; src = "http://x"; alt = "x" };
              Badge Badge.{ id = "b"; label = "ok"; variant = Success };
              Stat
                Stat.{ id = "s"; label = "n"; value = "42"; secondary = None };
              Divider Divider.{ id = "d"; label = Some "sep" };
              Diagram
                Diagram.
                  {
                    id = "dg";
                    title = "t";
                    size = { width = 10; height = 10 };
                    primitives =
                      [
                        Circle
                          {
                            center = { x = 5; y = 5 };
                            radius = 3;
                            tone = Tone.Default;
                          };
                        Polyline
                          {
                            points = [ { x = 0; y = 0 }; { x = 1; y = 1 } ];
                            tone = Tone.Default;
                          };
                      ];
                  };
              Code
                Code.
                  {
                    id = "c";
                    path = "p";
                    language = "l";
                    line_start = 1;
                    source = "s";
                    highlights =
                      [ { start_line = 1; end_line = 2; tone = Tone.Default } ];
                  };
              List List.{ id = "l"; ordered = None; children = [] };
              Submittable
                Submittable.
                  {
                    id = "sub";
                    value =
                      [
                        FieldInput Input.{ id = "in"; value = None };
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
                          {
                            id = "btn";
                            label = "Go";
                            action = Submit;
                            disabled = false;
                          };
                  };
            ];
        }
  in
  check_no_errors "valid full tree" tree

(* --- multiple errors collected --- *)

let test_multiple_errors () =
  let tree =
    Container
      Container.
        {
          id = "";
          direction = Vertical;
          children =
            [
              Text Text.{ id = ""; text_type = Paragraph; value = "x" };
              Diagram
                Diagram.
                  {
                    id = "d";
                    title = "t";
                    size = { width = 0; height = 0 };
                    primitives = [];
                  };
            ];
        }
  in
  let errors = Ribosome.Validate.validate tree in
  let msgs =
    Stdlib.List.map (fun (e : Ribosome.Validate.error) -> e.message) errors
  in
  Alcotest.(check int) "multiple error count" 4 (Stdlib.List.length msgs);
  Alcotest.(check bool)
    "has empty id" true
    (Stdlib.List.mem "id must not be empty" msgs);
  Alcotest.(check bool)
    "has zero width" true
    (Stdlib.List.mem "width must be positive" msgs);
  Alcotest.(check bool)
    "has zero height" true
    (Stdlib.List.mem "height must be positive" msgs)

(* --- error paths --- *)

let test_error_paths () =
  let tree =
    Container
      Container.
        {
          id = "root";
          direction = Vertical;
          children =
            [
              Code
                Code.
                  {
                    id = "c";
                    path = "p";
                    language = "l";
                    line_start = 1;
                    source = "s";
                    highlights =
                      [ { start_line = 5; end_line = 3; tone = Tone.Default } ];
                  };
            ];
        }
  in
  let errors = Ribosome.Validate.validate tree in
  match errors with
  | [ e ] ->
      Alcotest.(check string)
        "error path" "root.children[0].highlights[0]" e.path
  | _ -> Alcotest.fail "expected exactly one error"

let () =
  Alcotest.run "ribosome-validate"
    [
      ( "invariants",
        [
          Alcotest.test_case "empty id" `Quick test_empty_id;
          Alcotest.test_case "duplicate ids" `Quick test_duplicate_ids;
          Alcotest.test_case "diagram positive size" `Quick
            test_diagram_positive_size;
          Alcotest.test_case "diagram circle radius" `Quick
            test_diagram_circle_radius;
          Alcotest.test_case "diagram polyline points" `Quick
            test_diagram_polyline_points;
          Alcotest.test_case "code line_start" `Quick test_code_line_start;
          Alcotest.test_case "code highlight order" `Quick
            test_code_highlight_order;
          Alcotest.test_case "code highlight before start" `Quick
            test_code_highlight_before_start;
          Alcotest.test_case "select invalid selected" `Quick
            test_select_invalid_selected;
          Alcotest.test_case "button empty navigate" `Quick
            test_button_empty_navigate;
          Alcotest.test_case "button empty custom" `Quick
            test_button_empty_custom;
          Alcotest.test_case "valid tree" `Quick test_valid_tree;
          Alcotest.test_case "multiple errors" `Quick test_multiple_errors;
          Alcotest.test_case "error paths" `Quick test_error_paths;
        ] );
    ]
