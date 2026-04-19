open Types

let example_image = {|{"kind":"image","id":"1","src":"/img.png","alt":"test"}|}

let test_valid_image () =
  let result = Parser.attempt_template_parse example_image in
  Alcotest.(check (option (of_pp (fun fmt _ -> Format.pp_print_string fmt "template"))))
    "parses valid image" (Some (Image { kind = "image"; id = "1"; src = "/img.png"; alt = "test" })) result

let test_missing_field () =
  let result = Parser.attempt_template_parse {|{"kind":"image","id":"1","alt":"test"}|} in
  Alcotest.(check bool) "missing field returns none" true (result = None)

let test_invalid_json () =
  let result = Parser.attempt_template_parse "{\"kind\":\"image\"" in
  Alcotest.(check bool) "invalid json returns none" true (result = None)

let test_unknown_kind () =
  let result = Parser.attempt_template_parse {|{"kind":"huh","id":"1"}|} in
  Alcotest.(check bool) "unknown kind returns none" true (result = None)

let () =
  Alcotest.run "Parser" [
    "parsing", [
      Alcotest.test_case "parses a valid image" `Quick test_valid_image;
      Alcotest.test_case "missing field returns none" `Quick test_missing_field;
      Alcotest.test_case "invalid json returns none" `Quick test_invalid_json;
      Alcotest.test_case "unknown kind returns none" `Quick test_unknown_kind;
    ]
  ]
