import * as React from "react";

import { create } from "../../output/engine/Engine.js";
import { stream_adapter as openaiAdapter } from "../../output/engine/OpenaiAdapter.js";

const debug = (label, detail) => {
  if (typeof window !== "undefined" && window.__DEBUG__) {
    if (detail === undefined || window.__DEBUG__ < 2) console.log(label);
    else console.log(label, detail);
  }
};

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
      field(
        "children",
        "template[]",
        true,
        "Child templates to render inside this container.",
      ),
    ],
  ),
  input: template(
    "input",
    "Collect a user-editable value inside a submittable template.",
    "Only render input as part of a submittable template's value array.",
    [
      field("kind", "string", true, "Always input."),
      field("id", "string", true, "Stable id for this input."),
      field(
        "value",
        "string | number",
        true,
        "Initial input value as a raw JSON string or number.",
      ),
    ],
  ),
  submittable: template(
    "submittable",
    "Present a submit-capable interaction that can start the next model turn.",
    "Use submittable when the user needs to provide data or make a choice before continuing.",
    [
      field("kind", "string", true, "Always submittable."),
      field("id", "string", true, "Stable id for this submittable template."),
      field(
        "value",
        "input[]",
        true,
        "Inputs included in this submit-capable interaction.",
      ),
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
      field(
        "text_type",
        "Paragraph | H1 | H2 | H3 | H4 | H5 | H6",
        true,
        'Text presentation style as a raw JSON string, for example "H1".',
      ),
      field("value", "string", true, "Text content to render."),
    ],
  ),
};

const buildTemplateRegistry = (components) => {
  const registry = [templateDefinitions.container];

  for (const kind of ["input", "submittable", "image", "text"]) {
    if (components[kind]) registry.push(templateDefinitions[kind]);
  }

  debug(
    "[ribosome adapter] template registry",
    registry.map((template) => template.kind),
  );
  return arrayToOcamlList(registry);
};

const buildAssetRegistry = (assets) =>
  arrayToOcamlList(
    (assets ?? []).map((asset) => ({
      id: asset.id,
      url: asset.url,
      description: asset.description ?? "",
    })),
  );

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
    (context) => {
      const request = {
        url,
        headers: normaliseHeaders(headers),
        body: JSON.stringify({
          model,
          stream: true,
          messages: openAIMessages(context),
        }),
      };

      debug("[ribosome adapter] request", request);
      return request;
    };

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

const textTypes = ["Paragraph", "H1", "H2", "H3", "H4", "H5", "H6"];

const inputValueToPublic = (value) => {
  if (value && typeof value === "object" && "TAG" in value) return value._0;
  return value;
};

const inputValueToInternal = (value) => {
  if (typeof value === "number") return { TAG: 0, _0: value };
  return { TAG: 1, _0: String(value ?? "") };
};

const inputToPublic = (input) => ({
  ...input,
  value: inputValueToPublic(input.value),
});

const submissionToInternal = (payload) => ({
  template_id: payload.templateId ?? payload.template_id,
  values: arrayToOcamlList(
    (payload.values ?? []).map((value) => ({
      id: value.id,
      value: inputValueToInternal(value.value),
    })),
  ),
});

const brokenMessage = (props) => {
  if (typeof props === "string") return props;
  return Object.values(props ?? {}).join("");
};

const adaptComponents = (components) => ({
  container: (props) => {
    const publicProps = {
      ...props,
      children: props.children === 0 ? null : props.children,
    };
    debug("[ribosome adapter] render container props", publicProps);
    return React.createElement(components.container, publicProps);
  },
  broken: (props) => {
    const message = brokenMessage(props);
    debug("[ribosome adapter] render broken", message);
    return components.broken(message);
  },
  input: components.input
    ? (props) => {
      const publicProps = inputToPublic(props);
      debug("[ribosome adapter] render input props", publicProps);
      return React.createElement(components.input, publicProps);
    }
    : undefined,
  submittable: components.submittable
    ? (props) => {
      const publicProps = {
        ...props,
        value: ocamlListToArray(props.value).map(inputToPublic),
        on_submit: (payload) =>
          props.on_submit(submissionToInternal(payload)),
      };
      debug("[ribosome adapter] render submittable props", publicProps);
      return React.createElement(components.submittable, publicProps);
    }
    : undefined,
  image: components.image
    ? (props) => {
      debug("[ribosome adapter] render image props", props);
      return React.createElement(components.image, props);
    }
    : undefined,
  text: components.text
    ? (props) => {
      const publicProps = {
        ...props,
        text_type: textTypes[props.text_type] ?? props.text_type,
        value: props.content,
      };
      debug("[ribosome adapter] render text props", publicProps);
      return React.createElement(components.text, publicProps);
    }
    : undefined,
});

export function createEngineAdapter(config) {
  debug("[ribosome adapter] createEngineAdapter config", config);
  const model = config.adapterConfig?.model ?? "gpt-4o";
  const engine = create({
    root: resolveRoot(config.root),
    goal_prompt: config.goalPrompt,
    components: adaptComponents(config.components),
    templates: buildTemplateRegistry(config.components),
    assets: buildAssetRegistry(config.assets),
    request: buildRequest(config.url, config.headers, model),
    stream_adapter: resolveAdapter(config.adapterConfig),
    callbacks: {
      on_error: config.callbacks?.on_error ?? (() => { }),
      on_submit: config.callbacks?.on_submit ?? (() => { }),
      on_message_complete: config.callbacks?.on_message_complete ?? (() => { }),
    },
  });

  return {
    reset: () => engine.reset(),
  };
}
