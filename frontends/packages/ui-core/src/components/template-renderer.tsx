import { For, Show } from "solid-js";
import type { ComponentMap, EventCallback } from "../types/components";
import type { Template } from "../types/template";

export type Renderer = (node: Template) => any;

export function createRenderer(components: ComponentMap): Renderer {
  const render: Renderer = (node) => {
    switch (node.kind) {
      case "text":
        return components.text({ node, render, onEvent: noopEvent });

      case "image":
        return components.image({ node, render, onEvent: noopEvent });

      case "badge":
        return components.badge({ node, render, onEvent: noopEvent });

      case "stat":
        return components.stat({ node, render, onEvent: noopEvent });

      case "divider":
        return components.divider({ node, render, onEvent: noopEvent });

      case "diagram":
        return components.diagram({ node, render, onEvent: noopEvent });

      case "code":
        return components.code({ node, render, onEvent: noopEvent });

      case "container":
        return components.container({ node, render, onEvent: noopEvent });

      case "list":
        return components.list({ node, render, onEvent: noopEvent });

      case "submittable":
        return components.submittable({ node, render, onEvent: noopEvent });

      default:
        return null;
    }
  };

  return render;
}

export function createBoundRenderer(
  components: ComponentMap,
  onEvent: EventCallback,
): Renderer {
  const render: Renderer = (node) => {
    switch (node.kind) {
      case "text":
        return components.text({ node, render, onEvent });

      case "image":
        return components.image({ node, render, onEvent });

      case "badge":
        return components.badge({ node, render, onEvent });

      case "stat":
        return components.stat({ node, render, onEvent });

      case "divider":
        return components.divider({ node, render, onEvent });

      case "diagram":
        return components.diagram({ node, render, onEvent });

      case "code":
        return components.code({ node, render, onEvent });

      case "container":
        return components.container({ node, render, onEvent });

      case "list":
        return components.list({ node, render, onEvent });

      case "submittable":
        return components.submittable({ node, render, onEvent });

      default:
        return null;
    }
  };

  return render;
}

export { For, Show };

const noopEvent: EventCallback = () => {};
