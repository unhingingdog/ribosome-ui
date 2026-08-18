let assert_equal label expected actual =
  if expected <> actual then failwith label

let test_direction_strings () =
  assert_equal
    "vertical direction serialises"
    "vertical"
    (Container.string_of_direction Container.Vertical);
  assert_equal
    "horizontal direction serialises"
    "horizontal"
    (Container.string_of_direction Container.Horizontal)

let test_direction_parser () =
  assert_equal
    "vertical direction parses"
    Container.Vertical
    (Container.direction_of_string "vertical");
  assert_equal
    "horizontal direction parses"
    Container.Horizontal
    (Container.direction_of_string "horizontal")

let test_definition_requires_direction () =
  let direction = List.find (fun field -> field.TemplateDefinitionTypes.name = "direction") Container.definition.fields in
  assert_equal "direction is required" true direction.required

let () =
  test_direction_strings ();
  test_direction_parser ();
  test_definition_requires_direction ()
