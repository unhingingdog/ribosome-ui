open Ribosome_core

let assert_equal label expected actual =
  if expected <> actual then failwith label

let root =
  Types.Container {
    Templates.Container.kind = "container";
    id = "root";
    direction = Templates.Container.Vertical;
    children = [
      Types.Text {
        Templates.Text.kind = "text";
        id = "title";
        text_type = Templates.Text.H1;
        content = "Before";
      };
    ];
  }

let patch =
  Types.Text {
    Templates.Text.kind = "text";
    id = "title";
    text_type = Templates.Text.H1;
    content = "After";
  }

let test_reconciles_nested_template () =
  match Reconciler.reconcile root patch with
  | Reconciler.Found (Types.Container { children = [Types.Text text]; _ }) ->
    assert_equal "reconciler replaces matching child" "After" text.content
  | Reconciler.Found _ | Reconciler.NotFound _ ->
    failwith "expected reconciled container"

let test_preserves_missing_patch_tree () =
  let missing = Types.Text {
    Templates.Text.kind = "text";
    id = "missing";
    text_type = Templates.Text.Paragraph;
    content = "Missing";
  } in
  match Reconciler.reconcile root missing with
  | Reconciler.NotFound original ->
    assert_equal "missing patch preserves root" "root" (Types.id_of_template original)
  | Reconciler.Found _ -> failwith "expected missing patch"

let () =
  test_reconciles_nested_template ();
  test_preserves_missing_patch_tree ()
