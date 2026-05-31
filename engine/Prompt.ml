
module Markdown = struct
  let divider () = "---------------------------"
  let heading content = ("#" ^ " " ^ content)
  let subheading content = "## " ^ content
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

let required_label required =
  if required then "required" else "optional"

let field_to_prompt field =
  "- " ^ field.name ^ " (" ^ field.type_ ^ ", " ^ required_label field.required ^ "): " ^ field.instructions

let template_to_prompt template =
  String.concat "\n" [
    Markdown.subheading template.kind;
    "Intent: " ^ template.intent;
    "Instructions: " ^ template.instructions;
    "Fields:";
    String.concat "\n" (List.map field_to_prompt template.fields);
  ]

let parse_registry_to_prompt registry =
  String.concat "\n\n" [
    Markdown.heading "Available Templates";
    String.concat "\n\n" (List.map template_to_prompt registry);
  ]

let create_llm_prompt registry base_goal_prompt interaction_goal =
  let base = String.concat "\n\n" [
    Markdown.heading "Ribosome UI Generation Task";
    Markdown.subheading "Domain Context";
    base_goal_prompt;
  ] in

  let interaction = match interaction_goal with 
    | Some prompt -> String.concat "\n\n" [
        Markdown.subheading "Current Interaction";
        prompt;
      ]
    | None -> "Initial render. Present a starting template to the user, and await interaction" in

  let general =
    String.concat "\n\n" [
      Markdown.divider ();
      Markdown.heading "Output Contract";
      "Return exactly one JSON object representing a UI template. Do not wrap the JSON in Markdown or prose.";
      "Only use the templates provided below, and conform exactly to their structure.";
      "Every object must include a stable id string. Use ids that describe the role of the node.";
      "Respond to the current interaction goal while staying inside the domain context.";
      "Previous chat history and structured user submissions are supplied outside this prompt as conversation messages.";
      "Structured user submissions should be treated as the user's latest turn, not as UI templates to render back verbatim.";
      "If the next turn needs user input, include a submittable template with input children so the frontend can call onSubmit.";
      "You should creatively generate arbitrary, nested template trees to respond to user intent.";
      "When streaming, continue the same JSON object. Do not restart the response midway through the stream.";
      Markdown.divider ();
      parse_registry_to_prompt registry;
      Markdown.divider ();
    ] in

    base ^ interaction ^ general

