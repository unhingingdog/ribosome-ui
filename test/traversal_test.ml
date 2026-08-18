open Ribosome_core

let assert_equal label expected actual =
  if expected <> actual then failwith label

let tree =
  Types.Container {
    Templates.Container.kind = "container";
    id = "root";
    direction = Templates.Container.Vertical;
    children = [
      Types.List {
        Templates.List.kind = "list";
        id = "results";
        ordered = None;
        children = [
          Types.Text {
            Templates.Text.kind = "text";
            id = "result";
            text_type = Templates.Text.Paragraph;
            content = "Result";
          };
        ];
      };
      Types.Submittable {
        Templates.Submittable.kind = "submittable";
        id = "profile";
        value = [
          Templates.Submittable.FieldInput {
            Templates.Input.kind = "input";
            id = "name";
            value = None;
          };
          Templates.Submittable.FieldSelect {
            Templates.Select.kind = "select";
            id = "role";
            label = "Role";
            options = [];
            selected = None;
          };
        ];
        button = Some {
          Templates.Button.kind = "button";
          id = "save";
          label = "Save";
          action = Templates.Button.Submit;
          disabled = None;
        };
      };
    ];
  }

let test_template_children () =
  assert_equal "container has two template children" 2 (Stdlib.List.length (Traversal.template_children tree));
  match tree with
  | Types.Container { children = list :: _; _ } ->
    assert_equal "list has one template child" 1 (Stdlib.List.length (Traversal.template_children list))
  | _ -> failwith "expected root container"

let test_fold_templates () =
  let count = Traversal.fold_templates (fun count _ -> count + 1) 0 tree in
  assert_equal "fold visits template nodes" 4 count

let test_ids_include_form_controls () =
  assert_equal
    "ids include nested form controls"
    ["root"; "results"; "result"; "profile"; "name"; "role"; "save"]
    (Traversal.ids tree)

let () =
  test_template_children ();
  test_fold_templates ();
  test_ids_include_form_controls ()
