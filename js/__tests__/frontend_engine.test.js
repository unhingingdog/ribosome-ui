import React from "react";
import { describe, expect, it } from "vitest";
import { render_template } from "./output/engine/EngineFrontendReact.js";

const list = (items) =>
  items.reduceRight((tl, hd) => ({ hd, tl }), 0);

const textTemplate = (content, id = "text") => ({
  TAG: 3,
  _0: {
    kind: "text",
    id,
    text_type: 0,
    content,
  },
});

const imageTemplate = (id = "image") => ({
  TAG: 2,
  _0: {
    kind: "image",
    id,
    src: "/image.png",
    alt: "Test image",
  },
});

const containerTemplate = (children, id = "container") => ({
  TAG: 4,
  _0: {
    kind: "container",
    id,
    children: list(children),
  },
});

const Text = ({ content }) => React.createElement("p", null, content);
const Image = ({ src, alt }) => React.createElement("img", { src, alt });
const Container = ({ children }) => React.createElement("section", null, children);
const Broken = (props) =>
  React.createElement("span", null, Object.values(props).join(""));

const registry = (components = {}) => ({
  input: undefined,
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
});
