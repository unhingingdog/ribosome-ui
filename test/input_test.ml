let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_input_value_variants () =
  let input = {
    Input.kind = "input";
    id = "name";
    value = Some (Input.String "Ada");
  } in
  match input.value with
  | Some (Input.String value) -> assert_equal "string input value" "Ada" value
  | Some (Input.Int _) | None -> failwith "expected string input value"

let test_definition_requires_value () =
  let value = List.find (fun field -> field.TemplateDefinitionTypes.name = "value") Input.definition.fields in
  assert_equal "input value is required by the template contract" true value.required

let () =
  test_input_value_variants ();
  test_definition_requires_value ()
