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

let text_template = {
  Prompt.kind = "text";
  intent = "Render readable textual content.";
  instructions = "Use text for copy, labels, and explanatory content.";
  fields = [
    {
      name = "kind";
      type_ = "string literal \"text\"";
      required = true;
      instructions = "Must be exactly \"text\".";
    };
    {
      name = "content";
      type_ = "string";
      required = true;
      instructions = "The visible text to render.";
    };
  ];
}

let container_template = {
  Prompt.kind = "container";
  intent = "Group child templates into one layout section.";
  instructions = "Use containers when the response needs nested structure.";
  fields = [
    {
      name = "kind";
      type_ = "string literal \"container\"";
      required = true;
      instructions = "Must be exactly \"container\".";
    };
    {
      name = "children";
      type_ = "template[]";
      required = true;
      instructions = "Child templates to render inside the container.";
    };
  ];
}

let registry = [ text_template; container_template ]

let test_parse_registry_to_prompt () =
  let prompt = Prompt.parse_registry_to_prompt registry in
  assert_contains "registry includes available templates heading" prompt "# Available Templates";
  assert_contains "registry includes text heading" prompt "## text";
  assert_contains "registry includes container heading" prompt "## container";
  assert_contains "registry includes field requirement" prompt "content (string, required)";
  assert_contains "registry includes instructions" prompt "Use containers when the response needs nested structure."

let test_create_llm_prompt () =
  let prompt =
    Prompt.create_llm_prompt
      registry
      "Build a lesson UI for biology."
      "The user wants to compare ribosomes and mitochondria."
  in
  assert_contains "prompt includes task heading" prompt "# Ribosome UI Generation Task";
  assert_contains "prompt includes domain heading" prompt "## Domain Context";
  assert_contains "prompt includes base prompt" prompt "Build a lesson UI for biology.";
  assert_contains "prompt includes interaction heading" prompt "## Current Interaction";
  assert_contains "prompt includes interaction goal" prompt "compare ribosomes and mitochondria";
  assert_contains "prompt includes output contract" prompt "Return exactly one JSON object";
  assert_contains "prompt references chat history" prompt "Previous chat history and structured user submissions";
  assert_contains "prompt references submittables" prompt "include a submittable template";
  assert_contains "prompt includes streaming rule" prompt "When streaming, continue the same JSON object.";
  assert_contains "prompt includes available templates" prompt "# Available Templates"

let () =
  test_parse_registry_to_prompt ();
  test_create_llm_prompt ()
