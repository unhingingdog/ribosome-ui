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

const buildTemplateRegistry = (components) => {
  const registry = Object.keys(components)
    .filter((kind) => kind !== "broken" && components[kind]);

  debug(
    "[ribosome adapter] template registry",
    registry,
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
const badgeVariants = ["Neutral", "Success", "Warning", "Error", "Info"];

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

// submittable.value is an OCaml list of a field variant:
//   FieldInput  -> { TAG: 0, _0: input }
//   FieldSelect -> { TAG: 1, _0: select }
const submittableFieldToPublic = (field) =>
  field.TAG === 1
    ? { ...field._0, options: ocamlListToArray(field._0.options) }
    : inputToPublic(field._0);

const buttonActionToPublic = (action) => {
  if (action === 0) return "Submit";
  if (action && typeof action === "object" && action.TAG === 0) {
    return `Navigate:${action._0}`;
  }
  if (action && typeof action === "object" && action.TAG === 1) {
    return action._0;
  }
  return action;
};

const withPublicChildren = (props) => ({
  ...props,
  children: props.children === 0 ? null : props.children,
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
    const publicProps = withPublicChildren(props);
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
        value: ocamlListToArray(props.value).map(submittableFieldToPublic),
        on_submit: (payload) => {
          debug("[ribosome adapter] on_submit public payload", payload);
          const internal = submissionToInternal(payload);
          debug("[ribosome adapter] on_submit internal payload", internal);
          return props.on_submit(internal);
        },
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
  button: components.button
    ? (props) => {
      const publicProps = {
        ...props,
        action: buttonActionToPublic(props.action),
      };
      debug("[ribosome adapter] render button props", publicProps);
      return React.createElement(components.button, publicProps);
    }
    : undefined,
  select: components.select
    ? (props) => {
      const publicProps = {
        ...props,
        options: ocamlListToArray(props.options),
      };
      debug("[ribosome adapter] render select props", publicProps);
      return React.createElement(components.select, publicProps);
    }
    : undefined,
  badge: components.badge
    ? (props) => {
      const publicProps = {
        ...props,
        variant: badgeVariants[props.variant] ?? props.variant,
      };
      debug("[ribosome adapter] render badge props", publicProps);
      return React.createElement(components.badge, publicProps);
    }
    : undefined,
  list: components.list
    ? (props) => {
      const publicProps = withPublicChildren(props);
      debug("[ribosome adapter] render list props", publicProps);
      return React.createElement(components.list, publicProps);
    }
    : undefined,
  stat: components.stat
    ? (props) => {
      debug("[ribosome adapter] render stat props", props);
      return React.createElement(components.stat, props);
    }
    : undefined,
  divider: components.divider
    ? (props) => {
      debug("[ribosome adapter] render divider props", props);
      return React.createElement(components.divider, props);
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
    start: () => engine.start(),
    reset: () => engine.reset(),
  };
}
