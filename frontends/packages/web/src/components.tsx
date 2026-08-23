import { For, Show } from "solid-js";
import { Dynamic } from "solid-js/web";
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

const TONE_COLOR: Record<string, string> = {
  Default: "var(--tone-default)",
  Positive: "var(--tone-positive)",
  Negative: "var(--tone-negative)",
  Warning: "var(--tone-warning)",
  Info: "var(--tone-info)",
};

const BADGE_CLASS: Record<string, string> = {
  Neutral: "badge-neutral",
  Success: "badge-success",
  Warning: "badge-warning",
  Error: "badge-error",
  Info: "badge-info",
};

export function TextComponent(props: ComponentProps<TemplateText>) {
  const tag = () => {
    switch (props.node.text_type) {
      case "H1": return "h1";
      case "H2": return "h2";
      case "H3": return "h3";
      case "H4": return "h4";
      case "H5": return "h5";
      case "H6": return "h6";
      default: return "p";
    }
  };
  return <Dynamic component={tag()}>{props.node.value}</Dynamic>;
}

export function ImageComponent(props: ComponentProps<TemplateImage>) {
  return <img src={props.node.src} alt={props.node.alt} />;
}

export function BadgeComponent(props: ComponentProps<TemplateBadge>) {
  return (
    <span class={`badge ${BADGE_CLASS[props.node.variant] ?? "badge-neutral"}`}>
      {props.node.label}
    </span>
  );
}

export function StatComponent(props: ComponentProps<TemplateStat>) {
  return (
    <div class="stat">
      <span class="stat-label">{props.node.label}</span>
      <span class="stat-value">{props.node.value}</span>
      <Show when={props.node.secondary}>
        <span class="stat-secondary">{props.node.secondary}</span>
      </Show>
    </div>
  );
}

export function DividerComponent(props: ComponentProps<TemplateDivider>) {
  return (
    <Show when={props.node.label} fallback={<hr />}>
      <div class="divider-labeled">
        <hr /><span class="divider-label">{props.node.label}</span><hr />
      </div>
    </Show>
  );
}

export function DiagramComponent(props: ComponentProps<TemplateDiagram>) {
  const node = props.node;
  return (
    <svg
      width={node.size.width}
      height={node.size.height}
      viewBox={`0 0 ${node.size.width} ${node.size.height}`}
    >
      <title>{node.title}</title>
      <For each={node.primitives}>{(p) => {
        const color = TONE_COLOR[p.tone] ?? TONE_COLOR.Default;
        switch (p.kind) {
          case "text":
            return <text x={p.position.x} y={p.position.y} fill={color} font-size="12">{p.text}</text>;
          case "line":
            return <line x1={p.start.x} y1={p.start.y} x2={p.stop.x} y2={p.stop.y} stroke={color} />;
          case "arrow":
            return (
              <g>
                <line x1={p.start.x} y1={p.start.y} x2={p.stop.x} y2={p.stop.y} stroke={color} marker-end="url(#arrow)" />
              </g>
            );
          case "rectangle":
            return <rect x={p.origin.x} y={p.origin.y} width={p.size.width} height={p.size.height} fill="none" stroke={color} />;
          case "circle":
            return <circle cx={p.center.x} cy={p.center.y} r={p.radius} fill="none" stroke={color} />;
          case "polyline":
            return (
              <polyline
                points={p.points.map((pt) => `${pt.x},${pt.y}`).join(" ")}
                fill="none"
                stroke={color}
              />
            );
          default:
            return null;
        }
      }}</For>
      <defs>
        <marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">
          <path d="M0,0 L8,3 L0,6 Z" fill="currentColor" />
        </marker>
      </defs>
    </svg>
  );
}

export function CodeComponent(props: ComponentProps<TemplateCode>) {
  const node = props.node;
  const lines = () => node.source.split("\n");
  const highlightFor = (lineIndex: number): string | null => {
    const lineNum = lineIndex + node.line_start;
    for (const h of node.highlights) {
      if (lineNum >= h.start_line && lineNum <= h.end_line) {
        return TONE_COLOR[h.tone] ?? null;
      }
    }
    return null;
  };
  return (
    <pre class="code-block" data-language={node.language}>
      <div class="code-path">{node.path}</div>
      <code>
        <For each={lines()}>{(line, i) => {
          const bg = highlightFor(i());
          return (
            <div class="code-line" style={bg ? { "background-color": `${bg}22` } : undefined}>
              {line}
            </div>
          );
        }}</For>
      </code>
    </pre>
  );
}

export function ContainerComponent(props: ComponentProps<TemplateContainer>) {
  return (
    <div
      class="container"
      style={{
        "flex-direction": props.node.direction === "Horizontal" ? "row" : "column",
      }}
    >
      <For each={props.node.children}>{(child) => props.render(child)}</For>
    </div>
  );
}

export function ListComponent(props: ComponentProps<TemplateList>) {
  return (
    <Dynamic component={props.node.ordered ? "ol" : "ul"} class="template-list">
      <For each={props.node.children}>{(child) => (
        <li>{props.render(child)}</li>
      )}</For>
    </Dynamic>
  );
}

function InputField(props: { node: TemplateInput; onEvent: ComponentProps["onEvent"] }) {
  const handleChange = (e: Event) => {
    const target = e.target as HTMLInputElement;
    const value = target.type === "number" ? Number(target.value) : target.value;
    props.onEvent(props.node.id, "change", value);
  };
  const inputType = () => typeof props.node.value === "number" ? "number" : "text";
  return (
    <input
      type={inputType()}
      value={props.node.value ?? ""}
      onInput={handleChange}
    />
  );
}

function SelectField(props: { node: TemplateSelect; onEvent: ComponentProps["onEvent"] }) {
  const handleChange = (e: Event) => {
    const target = e.target as HTMLSelectElement;
    props.onEvent(props.node.id, "change", target.value);
  };
  return (
    <label class="select-field">
      <span class="select-label">{props.node.label}</span>
      <select value={props.node.selected ?? ""} onChange={handleChange}>
        <For each={props.node.options}>{(opt) => (
          <option value={opt.value} selected={opt.value === props.node.selected}>
            {opt.label}
          </option>
        )}</For>
      </select>
    </label>
  );
}

function ButtonField(props: { node: TemplateButton; onEvent: ComponentProps["onEvent"] }) {
  const isSubmit = props.node.action === "Submit" || props.node.action.startsWith("start:");
  return (
    <button
      type={isSubmit ? "submit" : "button"}
      disabled={props.node.disabled ?? false}
      onClick={isSubmit ? undefined : () => props.onEvent(props.node.id, "click")}
    >
      {props.node.label}
    </button>
  );
}

export function SubmittableComponent(props: ComponentProps<TemplateSubmittable>) {
  const handleSubmit = (e: Event) => {
    e.preventDefault();
    props.onEvent(props.node.id, "submit");
  };
  return (
    <form class="submittable" onSubmit={handleSubmit}>
      <For each={props.node.value}>{(field) => {
        if (field.kind === "input") return <InputField node={field} onEvent={props.onEvent} />;
        if (field.kind === "select") return <SelectField node={field} onEvent={props.onEvent} />;
        return null;
      }}</For>
      <Show when={props.node.button}>
        <ButtonField node={props.node.button!} onEvent={props.onEvent} />
      </Show>
    </form>
  );
}

export const webComponents: ComponentMap = {
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
