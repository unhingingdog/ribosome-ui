open Ribosome.Template

let test_decode_string () =
  Alcotest.(check string)
    "string ok" "hello"
    (Result.get_ok (Decode.string (`String "hello")));
  Alcotest.(check bool)
    "string wrong type" true
    (match Decode.string (`Int 42) with Error _ -> true | _ -> false)

let test_decode_int () =
  Alcotest.(check int) "int ok" 42 (Result.get_ok (Decode.int (`Int 42)));
  Alcotest.(check bool)
    "int wrong type" true
    (match Decode.int (`String "x") with Error _ -> true | _ -> false)

let test_decode_bool () =
  Alcotest.(check bool)
    "bool ok" true
    (Result.get_ok (Decode.bool (`Bool true)));
  Alcotest.(check bool)
    "bool wrong type" true
    (match Decode.bool (`String "x") with Error _ -> true | _ -> false)

let test_required_field_present () =
  let json = `Assoc [ ("id", `String "root") ] in
  Alcotest.(check string)
    "field present" "root"
    (Result.get_ok (Decode.field "id" Decode.string json))

let test_required_field_missing () =
  let json = `Assoc [ ("other", `String "x") ] in
  match Decode.field "id" Decode.string json with
  | Error e ->
      Alcotest.(check string)
        "missing path" "id"
        (Codec_error.format_path e.path);
      Alcotest.(check string)
        "missing category" "missing field"
        (Codec_error.category_to_string e.category)
  | Ok _ -> Alcotest.fail "expected missing field error"

let test_required_field_wrong_type () =
  let json = `Assoc [ ("id", `Int 42) ] in
  match Decode.field "id" Decode.string json with
  | Error e ->
      Alcotest.(check string)
        "wrong type path" "id"
        (Codec_error.format_path e.path);
      Alcotest.(check string)
        "wrong type category" "wrong type"
        (Codec_error.category_to_string e.category)
  | Ok _ -> Alcotest.fail "expected wrong type error"

let test_optional_field_present () =
  let json = `Assoc [ ("label", `String "hi") ] in
  Alcotest.(check (option string))
    "optional present" (Some "hi")
    (Result.get_ok (Decode.optional_field "label" Decode.string json))

let test_optional_field_missing () =
  let json = `Assoc [ ("other", `String "x") ] in
  Alcotest.(check (option string))
    "optional missing" None
    (Result.get_ok (Decode.optional_field "label" Decode.string json))

let test_optional_field_null () =
  let json = `Assoc [ ("label", `Null) ] in
  Alcotest.(check (option string))
    "optional null" None
    (Result.get_ok (Decode.optional_field "label" Decode.string json))

let test_list_decode () =
  let json = `List [ `String "a"; `String "b"; `String "c" ] in
  Alcotest.(check (list string))
    "list ok" [ "a"; "b"; "c" ]
    (Result.get_ok (Decode.list Decode.string json))

let test_list_wrong_type () =
  let json = `String "not a list" in
  Alcotest.(check bool)
    "list wrong type" true
    (match Decode.list Decode.string json with Error _ -> true | _ -> false)

let test_list_nested_error_path () =
  let json = `List [ `String "ok"; `Int 42; `String "ok" ] in
  match Decode.list Decode.string json with
  | Error e ->
      Alcotest.(check string)
        "nested path" "[1]"
        (Codec_error.format_path e.path)
  | Ok _ -> Alcotest.fail "expected error at index 1"

let test_field_in_list_nested_error_path () =
  let json =
    `Assoc
      [
        ( "value",
          `List
            [ `Assoc [ ("label", `String "a") ]; `Assoc [ ("label", `Int 99) ] ]
        );
      ]
  in
  match
    Decode.field "value" (Decode.list (Decode.field "label" Decode.string)) json
  with
  | Error e ->
      Alcotest.(check string)
        "deep nested path" "value[1].label"
        (Codec_error.format_path e.path)
  | Ok _ -> Alcotest.fail "expected error at value[1].label"

let test_enum_ok () =
  let table = [ ("Red", 0); ("Green", 1); ("Blue", 2) ] in
  Alcotest.(check int)
    "enum ok" 1
    (Result.get_ok (Decode.enum table (`String "Green")))

let test_enum_unknown () =
  let table = [ ("Red", 0); ("Green", 1) ] in
  match Decode.enum table (`String "Purple") with
  | Error e ->
      Alcotest.(check string)
        "unknown enum category" "unknown enum value"
        (Codec_error.category_to_string e.category)
  | Ok _ -> Alcotest.fail "expected unknown enum error"

let test_enum_wrong_type () =
  let table = [ ("Red", 0) ] in
  Alcotest.(check bool)
    "enum wrong type" true
    (match Decode.enum table (`Int 0) with Error _ -> true | _ -> false)

let test_object_ok () =
  Alcotest.(check bool)
    "object ok" true
    (match Decode.object_ (`Assoc [ ("x", `Int 1) ]) with
    | Ok () -> true
    | _ -> false)

let test_object_wrong_type () =
  Alcotest.(check bool)
    "object wrong type" true
    (match Decode.object_ (`String "x") with Error _ -> true | _ -> false)

let test_encode_optional_present () =
  let fields = Encode.optional "label" (Some "hi") (fun s -> `String s) [] in
  Alcotest.(check int)
    "optional present adds field" 1
    (Stdlib.List.length fields)

let test_encode_optional_missing () =
  let fields = Encode.optional "label" None (fun s -> `String s) [] in
  Alcotest.(check int)
    "optional missing adds nothing" 0
    (Stdlib.List.length fields)

let test_encode_obj () =
  let json = Encode.obj [ ("kind", `String "text") ] in
  match json with
  | `Assoc [ ("kind", `String "text") ] -> ()
  | _ -> Alcotest.fail "obj produces correct assoc"

let test_error_to_string () =
  let e =
    Codec_error.make
      [ Field "value"; Index 2; Field "label" ]
      WrongType "expected string"
  in
  let s = Codec_error.to_string e in
  Alcotest.(check bool) "error string contains path" true (String.length s > 0)

let () =
  Alcotest.run "ribosome-codec"
    [
      ( "decode",
        [
          Alcotest.test_case "string" `Quick test_decode_string;
          Alcotest.test_case "int" `Quick test_decode_int;
          Alcotest.test_case "bool" `Quick test_decode_bool;
          Alcotest.test_case "required field present" `Quick
            test_required_field_present;
          Alcotest.test_case "required field missing" `Quick
            test_required_field_missing;
          Alcotest.test_case "required field wrong type" `Quick
            test_required_field_wrong_type;
          Alcotest.test_case "optional present" `Quick
            test_optional_field_present;
          Alcotest.test_case "optional missing" `Quick
            test_optional_field_missing;
          Alcotest.test_case "optional null" `Quick test_optional_field_null;
          Alcotest.test_case "list" `Quick test_list_decode;
          Alcotest.test_case "list wrong type" `Quick test_list_wrong_type;
          Alcotest.test_case "list nested error path" `Quick
            test_list_nested_error_path;
          Alcotest.test_case "field in list nested error path" `Quick
            test_field_in_list_nested_error_path;
          Alcotest.test_case "enum ok" `Quick test_enum_ok;
          Alcotest.test_case "enum unknown" `Quick test_enum_unknown;
          Alcotest.test_case "enum wrong type" `Quick test_enum_wrong_type;
          Alcotest.test_case "object ok" `Quick test_object_ok;
          Alcotest.test_case "object wrong type" `Quick test_object_wrong_type;
        ] );
      ( "encode",
        [
          Alcotest.test_case "optional present" `Quick
            test_encode_optional_present;
          Alcotest.test_case "optional missing" `Quick
            test_encode_optional_missing;
          Alcotest.test_case "obj" `Quick test_encode_obj;
        ] );
      ("error", [ Alcotest.test_case "to_string" `Quick test_error_to_string ]);
    ]
