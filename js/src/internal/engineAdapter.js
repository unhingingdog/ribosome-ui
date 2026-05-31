import { create } from "../../output/engine/Engine.js";
import { stream_adapter as openaiAdapter } from "../../output/engine/OpenaiAdapter.js";

const normaliseHeaders = (headers) => {
  if (!headers) return [];
  if (Array.isArray(headers)) return headers;
  if (headers instanceof Headers) return [...headers.entries()];
  return Object.entries(headers);
};

const ocamlListToArray = (list) => {
  const items = [];
  let current = list;

  while (current !== 0) {
    items.push(current.hd);
    current = current.tl;
  }

  return items;
};

const arrayToOcamlList = (items) =>
  items.reduceRight((tl, hd) => ({ hd, tl }), 0);

const field = (name, type, required, instructions) => ({
  name,
  type_: type,
  required,
  instructions,
});

const template = (kind, intent, instructions, fields) => ({
  kind,
  intent,
  instructions,
  fields: arrayToOcamlList(fields),
});

const templateDefinitions = {
  container: template(
    "container",
    "Group one or more templates into a nested rendered section.",
    "Use container for layout, grouping, and nesting other available templates.",
    [
      field("kind", "string", true, "Always container."),
      field("id", "string", true, "Stable id for this container."),
      field("children", "template[]", true, "Child templates to render inside this container."),
    ],
  ),
  input: template(
    "input",
    "Collect a user-editable value inside a submittable template.",
    "Only render input as part of a submittable template's value array.",
    [
      field("kind", "string", true, "Always input."),
      field("id", "string", true, "Stable id for this input."),
      field("value", "{ String: string } | { Int: number }", true, "Initial input value."),
    ],
  ),
  submittable: template(
    "submittable",
    "Present a submit-capable interaction that can start the next model turn.",
    "Use submittable when the user needs to provide data or make a choice before continuing.",
    [
      field("kind", "string", true, "Always submittable."),
      field("id", "string", true, "Stable id for this submittable template."),
      field("value", "input[]", true, "Inputs included in this submit-capable interaction."),
    ],
  ),
  image: template(
    "image",
    "Display an image by URL.",
    "Use image only when visual content directly helps satisfy the user's goal.",
    [
      field("kind", "string", true, "Always image."),
      field("id", "string", true, "Stable id for this image."),
      field("src", "string", true, "Image URL."),
      field("alt", "string", true, "Accessible description of the image."),
    ],
  ),
  text: template(
    "text",
    "Display textual content to the user.",
    "Use text for headings, paragraphs, labels, explanations, and short feedback.",
    [
      field("kind", "string", true, "Always text."),
      field("id", "string", true, "Stable id for this text node."),
      field("text_type", "Paragraph | H1 | H2 | H3 | H4 | H5 | H6", true, "Text presentation style."),
      field("content", "string", true, "Text content to render."),
    ],
  ),
};

const buildTemplateRegistry = (components) => {
  const registry = [templateDefinitions.container];

  for (const kind of ["input", "submittable", "image", "text"]) {
    if (components[kind]) registry.push(templateDefinitions[kind]);
  }

  return arrayToOcamlList(registry);
};

const openAIRole = (role) => (role === 0 ? "user" : "assistant");

const openAIMessages = (context) => [
  { role: "system", content: context.system_prompt },
  ...ocamlListToArray(context.messages).map((message) => ({
    role: openAIRole(message.role),
    content: message.content,
  })),
];

const buildRequest =
  (url, headers, model = "gpt-4o") =>
    (context) => ({
      url,
      headers: normaliseHeaders(headers),
      body: JSON.stringify({
        model,
        stream: true,
        messages: openAIMessages(context),
      }),
    });

const resolveAdapter = (adapterConfig) => {
  const adapter = adapterConfig?.adapter ?? "openai";
  if (adapter === "openai") {
    return (payload) => openaiAdapter(payload);
  }
  throw new Error(`Unknown adapter: ${adapter}`);
};

const resolveRoot = (root) => {
  if (typeof root === "string") return { TAG: 1, _0: root };
  return { TAG: 0, _0: root };
};

export function createEngineAdapter(config) {
  const model = config.adapterConfig?.model ?? "gpt-4o";
  const engine = create({
    root: resolveRoot(config.root),
    goal_prompt: config.goalPrompt,
    // Component registration is intentionally public: supplying components selects the renderable template surface.
    components: config.components,
    templates: buildTemplateRegistry(config.components),
    request: buildRequest(config.url, config.headers, model),
    stream_adapter: resolveAdapter(config.adapterConfig),
    callbacks: {
      on_error: config.callbacks?.on_error ?? (() => {}),
      on_submit: config.callbacks?.on_submit ?? (() => {}),
      on_message_complete: config.callbacks?.on_message_complete ?? (() => {}),
    },
  });

  return {
    reset: () => engine.reset(),
  };
}
