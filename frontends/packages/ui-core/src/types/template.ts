export type Tone = "Default" | "Positive" | "Negative" | "Warning" | "Info";

export type Position = { x: number; y: number };
export type Size = { width: number; height: number };

export type DiagramPrimitive =
  | { kind: "text"; text: string; position: Position; tone: Tone }
  | { kind: "line"; start: Position; stop: Position; tone: Tone }
  | { kind: "arrow"; start: Position; stop: Position; tone: Tone }
  | { kind: "rectangle"; origin: Position; size: Size; tone: Tone }
  | { kind: "circle"; center: Position; radius: number; tone: Tone }
  | { kind: "polyline"; points: Position[]; tone: Tone };

export type CodeHighlight = {
  start_line: number;
  end_line: number;
  tone: Tone;
};

export type SelectOption = {
  value: string;
  label: string;
};

export type InputValue = string | number;

export type TextType = "Paragraph" | "H1" | "H2" | "H3" | "H4" | "H5" | "H6";

export type BadgeVariant = "Neutral" | "Success" | "Warning" | "Error" | "Info";

export type ContainerDirection = "Vertical" | "Horizontal";

export type ButtonAction = string;

export type TemplateInput = {
  kind: "input";
  id: string;
  value?: InputValue;
};

export type TemplateSelect = {
  kind: "select";
  id: string;
  label: string;
  options: SelectOption[];
  selected?: string;
};

export type TemplateButton = {
  kind: "button";
  id: string;
  label: string;
  action: ButtonAction;
  disabled?: boolean;
};

export type TemplateText = {
  kind: "text";
  id: string;
  text_type: TextType;
  value: string;
};

export type TemplateImage = {
  kind: "image";
  id: string;
  src: string;
  alt: string;
};

export type TemplateBadge = {
  kind: "badge";
  id: string;
  label: string;
  variant: BadgeVariant;
};

export type TemplateStat = {
  kind: "stat";
  id: string;
  label: string;
  value: string;
  secondary?: string;
};

export type TemplateDivider = {
  kind: "divider";
  id: string;
  label?: string;
};

export type TemplateDiagram = {
  kind: "diagram";
  id: string;
  title: string;
  size: Size;
  primitives: DiagramPrimitive[];
};

export type TemplateCode = {
  kind: "code";
  id: string;
  path: string;
  language: string;
  line_start: number;
  source: string;
  highlights: CodeHighlight[];
};

export type TemplateContainer = {
  kind: "container";
  id: string;
  direction: ContainerDirection;
  children: Template[];
};

export type TemplateList = {
  kind: "list";
  id: string;
  children: Template[];
  ordered?: boolean;
};

export type TemplateSubmittable = {
  kind: "submittable";
  id: string;
  value: (TemplateInput | TemplateSelect)[];
  button?: TemplateButton;
};

export type Template =
  | TemplateText
  | TemplateImage
  | TemplateBadge
  | TemplateStat
  | TemplateDivider
  | TemplateDiagram
  | TemplateCode
  | TemplateContainer
  | TemplateList
  | TemplateSubmittable;

export type NestedTemplate = TemplateInput | TemplateSelect | TemplateButton;

export const TOP_LEVEL_KINDS = [
  "text",
  "image",
  "badge",
  "stat",
  "divider",
  "diagram",
  "code",
  "container",
  "list",
  "submittable",
] as const;

export const NESTED_ONLY_KINDS = ["input", "select", "button"] as const;

export const ALL_KINDS = [...TOP_LEVEL_KINDS, ...NESTED_ONLY_KINDS] as const;

export const TONE_VALUES = ["Default", "Positive", "Negative", "Warning", "Info"] as const;

export const TEXT_TYPE_VALUES = ["Paragraph", "H1", "H2", "H3", "H4", "H5", "H6"] as const;

export const BADGE_VARIANT_VALUES = ["Neutral", "Success", "Warning", "Error", "Info"] as const;

export const CONTAINER_DIRECTION_VALUES = ["Vertical", "Horizontal"] as const;

export type TemplateKind = (typeof ALL_KINDS)[number];
