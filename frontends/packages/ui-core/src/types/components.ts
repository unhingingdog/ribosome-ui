import type { Template } from "./template";
import type { ComponentKind } from "./protocol";

export type EventCallback = (
  targetId: string,
  kind: ComponentKind,
  value?: string | number,
) => void;

export type ComponentProps<T extends Template = Template> = {
  node: T;
  render: (node: Template) => any;
  onEvent: EventCallback;
};

export type ComponentMap = {
  text: (props: ComponentProps<import("./template").TemplateText>) => any;
  image: (props: ComponentProps<import("./template").TemplateImage>) => any;
  badge: (props: ComponentProps<import("./template").TemplateBadge>) => any;
  stat: (props: ComponentProps<import("./template").TemplateStat>) => any;
  divider: (props: ComponentProps<import("./template").TemplateDivider>) => any;
  diagram: (props: ComponentProps<import("./template").TemplateDiagram>) => any;
  code: (props: ComponentProps<import("./template").TemplateCode>) => any;
  container: (props: ComponentProps<import("./template").TemplateContainer>) => any;
  list: (props: ComponentProps<import("./template").TemplateList>) => any;
  submittable: (props: ComponentProps<import("./template").TemplateSubmittable>) => any;
};
