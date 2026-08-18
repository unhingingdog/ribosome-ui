module Markdown = struct
  let divider () = "---------------------------"
  let heading content = "# " ^ content
  let subheading content = "## " ^ content
end

type template_registry = TemplateDefinitionTypes.template_definition list

type asset_definition = {
  id: string;
  url: string;
  description: string;
}

type asset_registry = asset_definition list

let required_label required =
  if required then "required" else "optional"

let field_type_label = function
  | TemplateDefinitionTypes.StringField -> "string"
  | TemplateDefinitionTypes.NumberField -> "number"
  | TemplateDefinitionTypes.BoolField -> "boolean"
  | TemplateDefinitionTypes.ArrayField -> "array"
  | TemplateDefinitionTypes.TemplateList -> "template[]"
  | TemplateDefinitionTypes.InputList -> "input[]"

let field_to_prompt (field: TemplateDefinitionTypes.field_def) =
  "- " ^ field.name
  ^ " (" ^ field_type_label field.field_type ^ ", " ^ required_label field.required ^ "): "
  ^ field.instructions

let template_to_prompt (template: TemplateDefinitionTypes.template_definition) =
  String.concat "\n" [
    Markdown.subheading template.kind;
    "Intent: " ^ template.intent;
    "Instructions: " ^ template.instructions;
    "Fields:";
    String.concat "\n" (List.map field_to_prompt template.fields);
  ]

let parse_registry_to_prompt registry =
  String.concat "\n\n" (List.map template_to_prompt registry)

let asset_to_prompt asset =
  "- " ^ asset.id ^ ": " ^ asset.url ^ " — " ^ asset.description

let assets_section assets =
  match assets with
  | [] -> ""
  | _ ->
      String.concat "\n\n" [
        Markdown.heading "Assets";
        "Use an image template only when the content is inherently \
         visual — a product photo, a map, a diagram, a chart. Never \
         use an image as decoration, mood-setting, or a hero banner. \
         If no asset directly represents content on this screen, do \
         not use any image. Copy the asset URL exactly into `src`.";
        String.concat "\n" (List.map asset_to_prompt assets);
      ]

let create_system_prompt active_kinds assets base_goal_prompt =
  let schema = TemplateRegistry.definitions_for_kinds active_kinds in
  String.concat "\n\n" [
    Markdown.heading "Role";
    "You are a UI renderer. You emit JSON trees. No prose, no markdown, no backticks.";
    Markdown.heading "Domain";
    base_goal_prompt;
    Markdown.heading "Available templates";
    "Use ONLY these types. The right specialized template is always better than a generic container.";
    parse_registry_to_prompt schema;
    assets_section assets;
  ]

let anti_patterns_section =
  String.concat "\n" [
    "ANTI-PATTERNS — NEVER do these:";
    "";
    "1. NEVER emit a single flat form as the entire UI. A lone submittable with inputs is a chatbot in drag.";
    "   Rich UIs have multiple independent zones: header, content, sidebar, status, actions.";
    "";
    "2. NEVER wrap everything in one giant container. If the tree is just {container -> [container -> [...]]},";
    "   you have failed. Containers should group 2-4 related items, not swallow the entire page.";
    "";
    "3. NEVER re-emit the entire UI on later turns. The user sees a patch, not a page reload.";
    "   If you emit id=\"root\" after turn 1, you are doing it wrong.";
    "";
    "4. NEVER use chat-style text blobs. No 'Here is your result:' paragraphs. Use stat, badge, list for data.";
    "";
    "5. NEVER put all user inputs in one massive form at the bottom. Distribute inputs near the data they affect.";
  ]

let first_turn_user_instructions =
  String.concat "\n" [
    "You are building a new UI from scratch.";
    "";
    "INSTRUCTIONS:";
    "- Emit ONE JSON object with id=\"root\"";
    "- It must be a container with 4-6 independent child regions as siblings";
    "- Every container must include direction: vertical or horizontal";
    "- Each region gets its own id and becomes a patch anchor for later turns";
    "- Do NOT nest all regions inside a single wrapper container";
    "- Make regions independent: header, list, detail, form, summary, status";
    "- Use specialized templates (stat, badge, list, text) instead of bare containers";
    "";
    anti_patterns_section;
    "";
    "Example of a rich first-turn output (list-detail view):";
    "{ \"kind\": \"container\", \"id\": \"root\", \"direction\": \"vertical\", \"children\": [";
    "  { \"kind\": \"text\", \"id\": \"project-header\", \"text_type\": \"H1\", \"value\": \"Task Manager\" },";
    "  { \"kind\": \"list\", \"id\": \"task-list\", \"children\": [";
    "    { \"kind\": \"container\", \"id\": \"task-1\", \"direction\": \"horizontal\", \"children\": [";
    "      { \"kind\": \"text\", \"id\": \"task-1-name\", \"text_type\": \"Paragraph\", \"value\": \"Review proposal\" },";
    "      { \"kind\": \"badge\", \"id\": \"task-1-status\", \"label\": \"In Progress\", \"variant\": \"Info\" }";
    "    ] },";
    "    { \"kind\": \"container\", \"id\": \"task-2\", \"direction\": \"horizontal\", \"children\": [";
    "      { \"kind\": \"text\", \"id\": \"task-2-name\", \"text_type\": \"Paragraph\", \"value\": \"Write tests\" },";
    "      { \"kind\": \"badge\", \"id\": \"task-2-status\", \"label\": \"Done\", \"variant\": \"Success\" }";
    "    ] }";
    "  ] },";
    "  { \"kind\": \"container\", \"id\": \"task-detail\", \"direction\": \"vertical\", \"children\": [";
    "    { \"kind\": \"text\", \"id\": \"detail-placeholder\", \"text_type\": \"Paragraph\", \"value\": \"Select a task to edit\" }";
    "  ] },";
    "  { \"kind\": \"submittable\", \"id\": \"new-task-form\", \"value\": [{ \"kind\": \"input\", \"id\": \"new-task-name\", \"value\": \"\" }] }";
    "] }";
    "";
    "MANDATE: If the tree is empty, your output MUST start with id=\"root\". No other id is acceptable on the first turn.";
  ]

let progressive_enhancement_section =
  String.concat "\n" [
    "PROGRESSIVE ENHANCEMENT RULES:";
    "";
    "- The UI grows in complexity over turns, not all at once";
    "- Turn 1: skeleton layout with placeholder content";
    "- Turn 2+: fill in specific regions as the user interacts";
    "- Add new regions when the user provides new data";
    "- Remove or hide regions that are no longer relevant";
    "- NEVER redraw the entire tree — the user will see a flash";
    "";
    "EXAMPLE: User asks to plan a trip";
    "  Turn 1: Header 'Trip Planner' + empty destination list + submittable 'Enter destination'";
    "  Turn 2: User submits 'Paris' → patch destination-list to show 'Paris', add weather-stat region";
    "  Turn 3: User submits dates → patch trip-summary region with itinerary, add budget-stat region";
    "  Turn 4: User asks to add hotel → patch hotel-list region (new region created this turn)";
    "";
    "The UI becomes richer as the conversation proceeds. Each turn adds or modifies ONE region.";
  ]

let later_turn_user_instructions =
  String.concat "\n" [
    "The user has interacted with the UI.";
    "";
    "INSTRUCTIONS:";
    "- Patch ONE existing child region by matching its id";
    "- Emit ONLY that region's replacement subtree";
    "- Include direction on every emitted container";
    "- Do NOT re-emit unchanged regions";
    "- Preserve user input values when re-emitting the same submittable";
    "";
    progressive_enhancement_section;
    "";
    "Example 1: user selected a task, patch the detail region:";
    "{ \"kind\": \"container\", \"id\": \"task-detail\", \"direction\": \"vertical\", \"children\": [";
    "  { \"kind\": \"text\", \"id\": \"detail-title\", \"text_type\": \"H2\", \"value\": \"Review proposal\" },";
    "  { \"kind\": \"badge\", \"id\": \"detail-priority\", \"label\": \"High\", \"variant\": \"Warning\" },";
    "  { \"kind\": \"stat\", \"id\": \"detail-assignee\", \"label\": \"Assignee\", \"value\": \"Ada\" },";
    "  { \"kind\": \"submittable\", \"id\": \"detail-form\", \"value\": [";
    "    { \"kind\": \"select\", \"id\": \"status\", \"label\": \"Status\", \"options\": [{\"value\":\"todo\",\"label\":\"To do\"},{\"value\":\"in-progress\",\"label\":\"In progress\"},{\"value\":\"done\",\"label\":\"Done\"}], \"selected\": \"in-progress\" }";
    "  ] }";
    "] }";
    "";
    "Example 2: user submitted the status change, patch the detail region with updated data:";
    "{ \"kind\": \"container\", \"id\": \"task-detail\", \"direction\": \"vertical\", \"children\": [";
    "  { \"kind\": \"text\", \"id\": \"detail-title\", \"text_type\": \"H2\", \"value\": \"Review proposal\" },";
    "  { \"kind\": \"badge\", \"id\": \"detail-status\", \"label\": \"Done\", \"variant\": \"Success\" },";
    "  { \"kind\": \"stat\", \"id\": \"detail-assignee\", \"label\": \"Assignee\", \"value\": \"Ada\" },";
    "  { \"kind\": \"submittable\", \"id\": \"detail-form\", \"value\": [";
    "    { \"kind\": \"select\", \"id\": \"status\", \"label\": \"Status\", \"options\": [{\"value\":\"todo\",\"label\":\"To do\"},{\"value\":\"in-progress\",\"label\":\"In progress\"},{\"value\":\"done\",\"label\":\"Done\"}], \"selected\": \"done\" }";
    "  ] }";
    "] }";
    "";
    "MANDATE: Use the id of an existing child region. Do NOT use id=\"root\" on later turns.";
  ]

let create_llm_prompt active_kinds assets base_goal_prompt _interaction_goal =
  create_system_prompt active_kinds assets base_goal_prompt
