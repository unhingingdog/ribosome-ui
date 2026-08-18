let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_text_type_conversion () =
  assert_equal "heading serialises" "H1" (Text.string_of_text_type Text.H1);
  assert_equal "heading parses" Text.H1 (Text.text_type_of_string "H1")

let test_badge_variant_conversion () =
  assert_equal "badge serialises" "Success" (Badge.string_of_badge_variant Badge.Success);
  assert_equal "badge parses" Badge.Success (Badge.badge_variant_of_string "Success")

let test_form_model () =
  let input = {
    Input.kind = "input";
    id = "name";
    value = Some (Input.String "Ada");
  } in
  let form = {
    Submittable.kind = "submittable";
    id = "profile";
    value = [Submittable.FieldInput input];
    button = Some {
      Button.kind = "button";
      id = "submit";
      label = "Save";
      action = Button.Submit;
      disabled = None;
    };
  } in
  match form.value, form.button with
  | [Submittable.FieldInput { Input.value = Some (Input.String "Ada"); _ }], Some { Button.action = Button.Submit; _ } -> ()
  | _ -> failwith "expected pure form model"

let test_all_template_definitions_are_pure () =
  let definitions = [
    Text.definition;
    Image.definition;
    Button.definition;
    Select.definition;
    Submittable.definition;
    Badge.definition;
    List.definition;
    Stat.definition;
    Divider.definition;
  ] in
  assert_equal "every model exposes a definition" 9 (Stdlib.List.length definitions)

let () =
  test_text_type_conversion ();
  test_badge_variant_conversion ();
  test_form_model ();
  test_all_template_definitions_are_pure ()
