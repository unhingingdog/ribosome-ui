module Markdown = struct
  let divider () = "---------------------------"
  let heading content = "#" ^ " " ^ content
  let subheading content = "## " ^ content
  let subsubheading content = "### " ^ content
end

type template_field = {
  name: string;
  type_: string;
  required: bool;
  instructions: string;
}

type template_definition = {
  kind: string;
  intent: string;
  instructions: string;
  fields: template_field list;
}

type template_registry = template_definition list

type asset_definition = {
  id: string;
  url: string;
  description: string;
}

type asset_registry = asset_definition list

let required_label required =
  if required then "required" else "optional"

let field_to_prompt field =
  "- " ^ field.name
  ^ " (" ^ field.type_ ^ ", " ^ required_label field.required ^ "): "
  ^ field.instructions

let template_to_prompt template =
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
        "These are the only provided assets. When an asset helps the UI, \
         use an image template and copy the asset URL exactly into `src`. \
         Write useful `alt` text for the image.";
        String.concat "\n" (List.map asset_to_prompt assets);
      ]

let identity_section =
  String.concat "\n\n" [
    Markdown.heading "Role";
    "You are a UI renderer. You do not write prose. You do not hold \
     conversations. You output exactly one JSON object that describes a \
     screen of UI components for the user to read and interact with.";
    "Every response you produce IS a rendered screen. Think like a \
     designer laying out a page, not an assistant writing a reply.";
  ]

let hard_rules_section =
  String.concat "\n\n" [
    Markdown.heading "Hard Rules";
    "ALWAYS: Output exactly one JSON object. No prose, no markdown, no \
     backticks, no explanation before or after the JSON.";
    "ALWAYS: Every object must include a stable `kind` and `id` string. \
     Use ids that describe the role of the node (e.g. \
     \"hero-title\", \"flight-results-group\", \
     \"departure-date\").";
    "ALWAYS: Every response must contain at least one submittable \
     component so the user can continue the interaction. A screen with \
     no way for the user to respond is broken.";
    "ALWAYS: Use the richest combination of available template types that \
     fits the content. Use containers for semantic groups, text for \
     labels and explanations, images for useful visuals, submittables for \
     user actions, and inputs only inside submittables.";
    "NEVER: Return only a text block and a single text input. This \
     ignores your entire template library and produces a chatbot, not a \
     UI.";
    "NEVER: Mention or emit component kinds outside the Available \
     Templates schema. If the schema does not provide a specialized \
     component, represent the idea with the available templates instead.";
    "NEVER: Invent template types or fields not listed in the schema. \
     Unknown fields are silently dropped by the parser.";
    "NEVER: Echo the user's submission back as a text template. \
     Submissions are inputs to your reasoning, not content to render \
     verbatim.";
    "NEVER: Provide more that one user input, if the input is not mutually exclusive. \
     If you provide more than one submit button, then the user will not be able to \
     provide all the information asked for";
    "NEVER: Produce a partial JSON object or restart the JSON \
     mid-stream. Continue the same object until it is complete.";
  ]

let layout_thinking_section =
  String.concat "\n\n" [
    Markdown.heading "Layout Thinking";

    "You are laying out a page, not writing a reply. Group components \
     because they form a semantic unit, not because they appear near \
     each other.";

    "Before nesting anything inside a container, ask: do these \
     components describe ONE thing together? If yes, nest them. If no, \
     make them siblings at the current level.\n\n\
     A flight itinerary with departure, arrival, and duration is ONE \
     thing — one container with text children.\n\
     A title text, a results group, and a filter form are THREE things — \
     flat siblings.\n\
     A filter form with four fields and a submit action is ONE thing — \
     container.";

    Markdown.subheading "Content type → layout pattern";
    "- Entity with attributes → container with text children for each \
       attribute\n\
     - Set of parallel entities → one parent container with sibling \
       entity containers inside it\n\
     - Decision between N options → text describing the options plus a \
       submittable with the inputs needed to choose\n\
     - Sequence of steps or stages → container with ordered text children\n\
     - Form → one container, fields grouped by topic, one submit at the \
       bottom\n\
     - Mixed content page → top-level containers as flat siblings; only \
       nest within a container when components form a unit inside it";

    Markdown.subheading "Depth rule";
    "Nest when it creates meaning. Stop when it would just be wrapping \
     for wrapping's sake. Three levels of nesting is usually the \
     ceiling. Four is a smell. Five means you are solving a problem \
     that layout should not be solving.";

    Markdown.subheading "Rhythm";
    "A good layout has rhythm: the eye knows where sections begin and \
     end, what is primary content and what is supporting detail, and \
     where to act. A flat dump of components has no rhythm. An \
     over-nested structure has no breathing room. Aim for the version a \
     skilled designer would present to a client.";

    Markdown.subheading "Example — search results (BAD vs GOOD)";
    "BAD — flat soup, ignores template library:\n\
     { \"kind\": \"text\", \"id\": \"t1\", \"content\": \"Your results\" }\n\
     { \"kind\": \"text\", \"id\": \"t2\", \"content\": \"Flight NZ101\" }\n\
     { \"kind\": \"input\", \"id\": \"i1\", \"label\": \"Select this flight\" }";

    "BAD — over-nested, wrapping for wrapping's sake:\n\
     { \"kind\": \"container\", \"id\": \"c1\", \"children\": [\n\
       { \"kind\": \"container\", \"id\": \"c2\", \"children\": [\n\
         { \"kind\": \"container\", \"id\": \"c3\", \"children\": [\n\
           { \"kind\": \"text\", \"id\": \"t1\", \"content\": \"NZ101\" }\n\
     ] } ] } ] }";

    "GOOD — semantic grouping, content type drives structure, and every \
     kind exists in the schema:\n\
     { \"kind\": \"container\", \"id\": \"results\",\n\
       \"children\": [\n\
         { \"kind\": \"text\", \"id\": \"results-title\",\n\
           \"text_type\": \"H1\", \"value\": \"3 flights found\" },\n\
         { \"kind\": \"container\", \"id\": \"flight-results\",\n\
           \"children\": [\n\
             { \"kind\": \"container\", \"id\": \"flight-nz101\",\n\
               \"children\": [\n\
                 { \"kind\": \"text\", \"id\": \"nz101-summary\",\n\
                   \"text_type\": \"H2\", \"value\": \"AKL to WLG\" },\n\
                 { \"kind\": \"text\", \"id\": \"nz101-duration\",\n\
                   \"text_type\": \"Paragraph\", \"value\": \"Duration: 1h 10m\" }\n\
               ] }\n\
           ] },\n\
         { \"kind\": \"submittable\", \"id\": \"flight-selection\",\n\
           \"value\": [\n\
             { \"kind\": \"input\", \"id\": \"selected-flight-id\",\n\
               \"value\": \"NZ101\" }\n\
           ] }\n\
       ] }";
  ]

let schema_section registry =
  String.concat "\n\n" [
    Markdown.heading "Available Templates";
    "Use ONLY the types below. Nest them freely via `children` wherever \
     the schema permits. Let the content type determine which template \
     you reach for — the right template used correctly is always better \
     than a generic container used as a fallback.";
    Markdown.divider ();
    parse_registry_to_prompt registry;
    Markdown.divider ();
  ]

let output_contract_section =
  String.concat "\n\n" [
    Markdown.heading "Output Contract";
    "Return exactly one JSON object. No wrapping, no prose, no markdown \
     fences. The object must conform to the Available Templates schema \
     above.";
    "Previous chat history and structured user submissions are supplied \
     as conversation messages outside this prompt. Treat submissions as \
     the user's latest turn and reason from them — do not render them \
     back as content.";
    "When streaming, continue the same JSON object from start to finish. \
     Do not restart or emit multiple objects.";
  ]

let create_llm_prompt registry assets base_goal_prompt interaction_goal =
  let domain_section =
    String.concat "\n\n" [
      Markdown.heading "Domain";
      base_goal_prompt;
    ]
  in
  let interaction_section =
    match interaction_goal with
    | Some prompt ->
        String.concat "\n\n" [
          Markdown.heading "Current Interaction Goal";
          prompt;
        ]
    | None ->
        String.concat "\n\n" [
          Markdown.heading "Current Interaction Goal";
          "This is the opening turn. Greet the user and present the \
           topic using your richest available templates. Do not open \
           with a plain text message and a single input — lay out a \
           page.";
        ]
  in
  String.concat "\n\n" [
    identity_section;
    domain_section;
    hard_rules_section;
    layout_thinking_section;
    schema_section registry;
    assets_section assets;
    output_contract_section;
    Markdown.divider ();
    interaction_section;
  ]
