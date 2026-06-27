let assert_true label condition =
  if not condition then failwith label

let contains haystack needle =
  let haystack_len = String.length haystack in
  let needle_len = String.length needle in
  let rec loop i =
    if needle_len = 0 then true
    else if i + needle_len > haystack_len then false
    else if String.sub haystack i needle_len = needle then true
    else loop (i + 1)
  in
  loop 0

let assert_contains label haystack needle =
  assert_true label (contains haystack needle)

let registry = TemplateRegistry.all_definitions

let assets = [
  {
    Prompt.id = "rice-field";
    url = "/assets/rice-field.jpg";
    description = "A green rice field landscape.";
  }
]

let test_parse_registry_to_prompt () =
  let prompt = Prompt.parse_registry_to_prompt registry in
  assert_contains "registry includes text heading" prompt "## text";
  assert_contains "registry includes container heading" prompt "## container";
  assert_contains "registry includes field requirement" prompt "value (string, required)";
  assert_contains "registry includes instructions" prompt "Use container for layout, grouping"

let test_create_system_prompt () =
  let prompt =
    Prompt.create_system_prompt
      [ "text"; "container" ]
      assets
      "Build a lesson UI for biology."
  in
  assert_contains "system prompt includes role heading" prompt "# Role";
  assert_contains "system prompt includes domain heading" prompt "# Domain";
  assert_contains "system prompt includes base prompt" prompt "Build a lesson UI for biology.";
  assert_contains "system prompt includes available templates" prompt "# Available templates";
  assert_contains "system prompt includes assets heading" prompt "# Assets";
  assert_contains "system prompt includes asset url" prompt "/assets/rice-field.jpg";
  assert_contains "system prompt is minimal" prompt "You are a UI renderer. You emit JSON trees."

let test_first_turn_instructions () =
  let instructions = Prompt.first_turn_user_instructions in
  assert_contains "first turn instructions mention root" instructions "id=\"root\"";
  assert_contains "first turn instructions mention 4-6 regions" instructions "4-6";
  assert_contains "first turn instructions mention child regions" instructions "child regions";
  assert_contains "first turn instructions have example" instructions "Example of a rich first-turn output";
  assert_contains "first turn instructions have mandate" instructions "MANDATE"

let test_later_turn_instructions () =
  let instructions = Prompt.later_turn_user_instructions in
  assert_contains "later turn instructions mention patch one" instructions "Patch ONE";
  assert_contains "later turn instructions mention existing id" instructions "existing child region";
  assert_contains "later turn instructions have example" instructions "Example 1:";
  assert_contains "later turn instructions have mandate" instructions "MANDATE"

let () =
  test_parse_registry_to_prompt ();
  test_create_system_prompt ();
  test_first_turn_instructions ();
  test_later_turn_instructions ()
