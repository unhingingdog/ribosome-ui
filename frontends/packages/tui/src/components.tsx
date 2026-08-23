import { For, Show } from "solid-js";
import type { ComponentMap, ComponentProps } from "@ribosome/ui-core";
import type {
  TemplateBadge,
  TemplateButton,
  TemplateCode,
  TemplateContainer,
  TemplateDiagram,
  TemplateDivider,
  TemplateImage,
  TemplateInput,
  TemplateList,
  TemplateSelect,
  TemplateStat,
  TemplateSubmittable,
  TemplateText,
} from "@ribosome/ui-core";

const BADGE_COLOR: Record<string, string> = {
  Neutral: "gray",
  Success: "green",
  Warning: "yellow",
  Error: "red",
  Info: "blue",
};

const TONE_COLOR: Record<string, string> = {
  Default: "gray",
  Positive: "green",
  Negative: "red",
  Warning: "yellow",
  Info: "blue",
};

const HEADING_WEIGHT: Record<string, string> = {
  H1: "bright",
  H2: "bright",
  H3: "bright",
  H4: "bold",
  H5: "bold",
  H6: "bold",
};

export function TextComponent(props: ComponentProps<TemplateText>) {
  const weight = () => HEADING_WEIGHT[props.node.text_type] ?? "normal";
  const isHeading = () => props.node.text_type !== "Paragraph";
  return (
    <text
      fg={isHeading() ? "bright-white" : undefined}
      style={{
        attributes: isHeading() ? 1 : 0,
      }}
    >
      {weight() === "bright" ? `▶ ${props.node.value}` : props.node.value}
    </text>
  );
}

export function ImageComponent(props: ComponentProps<TemplateImage>) {
  return (
    <text fg="cyan">[image: {props.node.alt}]</text>
  );
}

export function BadgeComponent(props: ComponentProps<TemplateBadge>) {
  const color = () => BADGE_COLOR[props.node.variant] ?? "gray";
  return (
    <text fg={color()}>[{props.node.label}]</text>
  );
}

export function StatComponent(props: ComponentProps<TemplateStat>) {
  return (
    <box flexDirection="column">
      <text fg="gray">{props.node.label}</text>
      <text fg="bright-white">{props.node.value}</text>
      <Show when={props.node.secondary}>
        <text fg="gray">{props.node.secondary}</text>
      </Show>
    </box>
  );
}

export function DividerComponent(props: ComponentProps<TemplateDivider>) {
  return (
    <Show
      when={props.node.label}
      fallback={<text fg="gray">{"─".repeat(40)}</text>}
    >
      <text fg="gray">── {props.node.label} ─{"─".repeat(30)}</text>
    </Show>
  );
}

function renderDiagramPrimitive(p: import("@ribosome/ui-core").DiagramPrimitive): string {
  switch (p.kind) {
    case "text":
      return p.text;
    case "line":
    case "arrow":
      return `──${p.kind === "arrow" ? "▶" : "──"}`;
    case "rectangle":
      return `┌${"─".repeat(10)}┐\n│          │\n└${"─".repeat(10)}┘`;
    case "circle":
      return `( ○ )`;
    case "polyline":
      return p.points.map((pt) => `(${pt.x},${pt.y})`).join(" → ");
    default:
      return "?";
  }
}

export function DiagramComponent(props: ComponentProps<TemplateDiagram>) {
  return (
    <box border={true} title={props.node.title} flexDirection="column">
      <For each={props.node.primitives}>{(p) => (
        <text fg={TONE_COLOR[p.tone] ?? "gray"}>{renderDiagramPrimitive(p)}</text>
      )}</For>
    </box>
  );
}

export function CodeComponent(props: ComponentProps<TemplateCode>) {
  return (
    <box border={true} title={props.node.path} flexDirection="column">
      <text>{props.node.source}</text>
    </box>
  );
}

export function ContainerComponent(props: ComponentProps<TemplateContainer>) {
  return (
    <box
      flexDirection={props.node.direction === "Horizontal" ? "row" : "column"}
      gap={1}
    >
      <For each={props.node.children}>{(child) => props.render(child)}</For>
    </box>
  );
}

export function ListComponent(props: ComponentProps<TemplateList>) {
  return (
    <box flexDirection="column" gap={0}>
      <For each={props.node.children}>{(child, i) => (
        <box flexDirection="row">
          <text fg="gray">{props.node.ordered ? `${i() + 1}. ` : "• "}</text>
          {props.render(child)}
        </box>
      )}</For>
    </box>
  );
}

function InputField(props: { node: TemplateInput; onEvent: ComponentProps["onEvent"] }) {
  return (
    <input
      value={typeof props.node.value === "string" ? props.node.value : String(props.node.value ?? "")}
      onChange={(value: string) => {
        const v = typeof props.node.value === "number" ? Number(value) : value;
        props.onEvent(props.node.id, "change", v);
      }}
      onSubmit={() => props.onEvent(props.node.id, "change", props.node.value ?? "")}
    />
  );
}

function SelectField(props: { node: TemplateSelect; onEvent: ComponentProps["onEvent"] }) {
  const options = () =>
    props.node.options.map((opt) => ({
      name: opt.label,
      description: "",
      value: opt.value,
    }));

  const selectedIndex = () => {
    const i = props.node.options.findIndex((o) => o.value === props.node.selected);
    return i >= 0 ? i : 0;
  };

  return (
    <box flexDirection="column">
      <text fg="gray">{props.node.label}</text>
      <select
        options={options()}
        selectedIndex={selectedIndex()}
        onChange={(_index: number, option: { value?: string; name: string; description: string } | null) => {
          if (option?.value) props.onEvent(props.node.id, "change", option.value);
        }}
      />
    </box>
  );
}

function ButtonField(props: { node: TemplateButton; onEvent: ComponentProps["onEvent"] }) {
  const isSubmit = props.node.action === "Submit";
  return (
    <box
      border={true}
      borderStyle="single"
      borderColor={props.node.disabled ? "gray" : "blue"}
      focusable={!props.node.disabled}
      on:Select={() =>
        props.onEvent(
          props.node.id,
          isSubmit ? "submit" : "click",
        )
      }
    >
      <text fg={props.node.disabled ? "gray" : "bright-white"}>
        {props.node.label}
      </text>
    </box>
  );
}

export function SubmittableComponent(props: ComponentProps<TemplateSubmittable>) {
  return (
    <box border={true} title="Form" flexDirection="column" gap={1}>
      <For each={props.node.value}>{(field) => {
        if (field.kind === "input") return <InputField node={field} onEvent={props.onEvent} />;
        if (field.kind === "select") return <SelectField node={field} onEvent={props.onEvent} />;
        return null;
      }}</For>
      <Show when={props.node.button}>
        <ButtonField node={props.node.button!} onEvent={props.onEvent} />
      </Show>
    </box>
  );
}

export const tuiComponents: ComponentMap = {
  text: TextComponent,
  image: ImageComponent,
  badge: BadgeComponent,
  stat: StatComponent,
  divider: DividerComponent,
  diagram: DiagramComponent,
  code: CodeComponent,
  container: ContainerComponent,
  list: ListComponent,
  submittable: SubmittableComponent,
};
