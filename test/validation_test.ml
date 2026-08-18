open Ribosome_core

let assert_equal label expected actual =
  if expected <> actual then failwith label

let text id =
  Types.Text {
    Templates.Text.kind = "text";
    id;
    text_type = Templates.Text.Paragraph;
    content = "Text";
  }

let container children =
  Types.Container {
    Templates.Container.kind = "container";
    id = "root";
    direction = Templates.Container.Vertical;
    children;
  }

let test_accepts_unique_ids () =
  assert_equal "unique ids are valid" (Ok ())
    (Validation.validate (container [text "first"; text "second"]))

let test_rejects_empty_ids () =
  assert_equal "empty ids are invalid" (Error [Validation.Empty_id])
    (Validation.validate (container [text ""]))

let test_rejects_duplicates_in_form_controls () =
  let form = Types.Submittable {
    Templates.Submittable.kind = "submittable";
    id = "profile";
    value = [
      Templates.Submittable.FieldInput {
        Templates.Input.kind = "input";
        id = "name";
        value = None;
      };
    ];
    button = Some {
      Templates.Button.kind = "button";
      id = "name";
      label = "Save";
      action = Templates.Button.Submit;
      disabled = None;
    };
  } in
  assert_equal "duplicate form control ids are invalid"
    (Error [Validation.Duplicate_id "name"])
    (Validation.validate (container [form]))

let () =
  test_accepts_unique_ids ();
  test_rejects_empty_ids ();
  test_rejects_duplicates_in_form_controls ()
