import React from "react";
import { describe, expect, it, vi } from "vitest";
import {
  render_template,
  render_template_with_submit,
} from "./output/engine/EngineFrontendReact.js";

const list = (items) =>
  items.reduceRight((tl, hd) => ({ hd, tl }), 0);

const textTemplate = (content, id = "text") => ({
  TAG: 2,
  _0: {
    kind: "text",
    id,
    text_type: 0,
    content,
  },
});

const imageTemplate = (id = "image") => ({
  TAG: 1,
  _0: {
    kind: "image",
    id,
    src: "/image.png",
    alt: "Test image",
  },
});

const containerTemplate = (children, id = "container") => ({
  TAG: 3,
  _0: {
    kind: "container",
    id,
    children: list(children),
  },
});

const input = (id, value = "") => ({
  kind: "input",
  id,
  value: { TAG: 1, _0: value },
});

const submittableTemplate = (id = "form") => ({
  TAG: 0,
  _0: {
    kind: "submittable",
    id,
    value: list([input("name")]),
  },
});

const Text = ({ content }) => React.createElement("p", null, content);
const Image = ({ src, alt }) => React.createElement("img", { src, alt });
const Submittable = ({ id }) => React.createElement("form", { id });
const Container = ({ children }) => React.createElement("section", null, children);
const Broken = ({ message }) => {
  return React.createElement("span", null, message);
};

const registry = (components = {}) => ({
  submittable: undefined,
  image: Image,
  text: Text,
  container: Container,
  broken: Broken,
  ...components,
});

const render = (template, components) => render_template(template, registry(components));

describe("FrontendEngine", () => {
  it("renders a React component from a template", () => {
    const element = render(textTemplate("Hello"));

    expect(element.type).toBe(Text);
    expect(element.props.content).toBe("Hello");
  });

  it("renders the broken component for a missing registry component", () => {
    const element = render(imageTemplate(), { image: undefined });

    expect(element.type).toBe(Broken);
    expect(Object.values(element.props).join("")).toBe(
      "Used missing component: image",
    );
  });

  it("renders a list of child templates", () => {
    const element = render(containerTemplate([textTemplate("One"), textTemplate("Two")]));
    const children = React.Children.toArray(element.props.children);

    expect(element.type).toBe(Container);
    expect(children).toHaveLength(2);
    expect(children[0].type).toBe(Text);
    expect(children[0].props.content).toBe("One");
    expect(children[1].type).toBe(Text);
    expect(children[1].props.content).toBe("Two");
  });

  it("passes flat submittable props with a noop submit callback", () => {
    const element = render(submittableTemplate(), { submittable: Submittable });

    expect(element.type).toBe(Submittable);
    expect(element.props.kind).toBe("submittable");
    expect(element.props.id).toBe("form");
    expect(element.props.value).toBeDefined();
    expect(element.props.template).toBeUndefined();
    expect(element.props.on_submit).toEqual(expect.any(Function));
  });

  it("threads submittable on_submit to the provided callback", () => {
    const onSubmit = vi.fn();
    const element = render_template_with_submit(
      submittableTemplate(),
      registry({ submittable: Submittable }),
      onSubmit,
    );
    const payload = {
      template_id: "form",
      values: list([
        {
          id: "name",
          value: { TAG: 1, _0: "Ada" },
        },
      ]),
    };

    element.props.on_submit(payload);

    expect(onSubmit).toHaveBeenCalledTimes(1);
    expect(onSubmit).toHaveBeenCalledWith(payload);
  });
});
