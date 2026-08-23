import {
  ALL_KINDS,
  BADGE_VARIANT_VALUES,
  CONTAINER_DIRECTION_VALUES,
  NESTED_ONLY_KINDS,
  TEXT_TYPE_VALUES,
  TONE_VALUES,
  type BadgeVariant,
  type CodeHighlight,
  type ContainerDirection,
  type DiagramPrimitive,
  type InputValue,
  type Position,
  type SelectOption,
  type Size,
  type Template,
  type TemplateBadge,
  type TemplateButton,
  type TemplateCode,
  type TemplateContainer,
  type TemplateDiagram,
  type TemplateDivider,
  type TemplateImage,
  type TemplateInput,
  type TemplateList,
  type TemplateSelect,
  type TemplateStat,
  type TemplateSubmittable,
  type TemplateText,
  type TextType,
  type Tone,
} from "../types/template";
import { type DecodeResult, err, ok } from "../types/protocol";

function isString(v: unknown): v is string {
  return typeof v === "string";
}

function isNumber(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

function isBool(v: unknown): v is boolean {
  return typeof v === "boolean";
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function isArray(v: unknown): v is unknown[] {
  return Array.isArray(v);
}

function enumValue<T extends string>(values: readonly T[], v: unknown): T | undefined {
  return isString(v) ? values.find((x) => x === v) : undefined;
}

function field<T>(
  obj: Record<string, unknown>,
  name: string,
  decode: (v: unknown) => DecodeResult<T>,
): DecodeResult<T> {
  return name in obj ? decode(obj[name]) : err<T>(name, "missing field");
}

function optional<T>(
  obj: Record<string, unknown>,
  name: string,
  decode: (v: unknown) => DecodeResult<T>,
): DecodeResult<T | undefined> {
  return name in obj ? (obj[name] === undefined || obj[name] === null ? ok(undefined) : decode(obj[name])) : ok(undefined);
}

function decodeString(v: unknown): DecodeResult<string> {
  return isString(v) ? ok(v) : err("value", "expected string");
}

function decodeNumber(v: unknown): DecodeResult<number> {
  return isNumber(v) ? ok(v) : err("value", "expected number");
}

function decodeBool(v: unknown): DecodeResult<boolean> {
  return isBool(v) ? ok(v) : err("value", "expected boolean");
}

function decodePosition(v: unknown): DecodeResult<Position> {
  if (!isObject(v)) return err("position", "expected object");
  const x = field(v, "x", decodeNumber);
  if (!x.ok) return x;
  const y = field(v, "y", decodeNumber);
  if (!y.ok) return y;
  return ok({ x: x.value, y: y.value });
}

function decodeSize(v: unknown): DecodeResult<Size> {
  if (!isObject(v)) return err("size", "expected object");
  const w = field(v, "width", decodeNumber);
  if (!w.ok) return w;
  const h = field(v, "height", decodeNumber);
  if (!h.ok) return h;
  return ok({ width: w.value, height: h.value });
}

function decodeTone(v: unknown): DecodeResult<Tone> {
  const t = enumValue(TONE_VALUES, v);
  return t ? ok(t) : err("tone", `expected one of ${TONE_VALUES.join(", ")}`);
}

function decodeDiagramPrimitive(v: unknown): DecodeResult<DiagramPrimitive> {
  if (!isObject(v)) return err("primitive", "expected object");
  const kind = field(v, "kind", decodeString);
  if (!kind.ok) return kind;

  switch (kind.value) {
    case "text": {
      const text = field(v, "text", decodeString);
      if (!text.ok) return text;
      const position = field(v, "position", decodePosition);
      if (!position.ok) return position;
      const tone = optional(v, "tone", decodeTone);
      if (!tone.ok) return tone;
      return ok({ kind: "text", text: text.value, position: position.value, tone: tone.value ?? "Default" });
    }
    case "line":
    case "arrow": {
      const start = field(v, "start", decodePosition);
      if (!start.ok) return start;
      const stop = field(v, "stop", decodePosition);
      if (!stop.ok) return stop;
      const tone = optional(v, "tone", decodeTone);
      if (!tone.ok) return tone;
      return ok({ kind: kind.value, start: start.value, stop: stop.value, tone: tone.value ?? "Default" });
    }
    case "rectangle": {
      const origin = field(v, "origin", decodePosition);
      if (!origin.ok) return origin;
      const size = field(v, "size", decodeSize);
      if (!size.ok) return size;
      const tone = optional(v, "tone", decodeTone);
      if (!tone.ok) return tone;
      return ok({ kind: "rectangle", origin: origin.value, size: size.value, tone: tone.value ?? "Default" });
    }
    case "circle": {
      const center = field(v, "center", decodePosition);
      if (!center.ok) return center;
      const radius = field(v, "radius", decodeNumber);
      if (!radius.ok) return radius;
      const tone = optional(v, "tone", decodeTone);
      if (!tone.ok) return tone;
      return ok({ kind: "circle", center: center.value, radius: radius.value, tone: tone.value ?? "Default" });
    }
    case "polyline": {
      const pointsRaw = v["points"];
      if (!isArray(pointsRaw)) return err<DiagramPrimitive>("points", "expected array");
      const points: Position[] = [];
      for (const p of pointsRaw) {
        const r = decodePosition(p);
        if (!r.ok) return err<DiagramPrimitive>("points", "invalid position");
        points.push(r.value);
      }
      const tone = optional(v, "tone", decodeTone);
      if (!tone.ok) return tone;
      return ok({ kind: "polyline", points, tone: tone.value ?? "Default" });
    }
    default:
      return err("kind", `unknown diagram primitive: ${kind.value}`);
  }
}

function decodeCodeHighlight(v: unknown): DecodeResult<CodeHighlight> {
  if (!isObject(v)) return err("highlight", "expected object");
  const sl = field(v, "start_line", decodeNumber);
  if (!sl.ok) return sl;
  const el = field(v, "end_line", decodeNumber);
  if (!el.ok) return el;
  const tone = field(v, "tone", decodeTone);
  if (!tone.ok) return tone;
  return ok({ start_line: sl.value, end_line: el.value, tone: tone.value });
}

function decodeSelectOption(v: unknown): DecodeResult<SelectOption> {
  if (!isObject(v)) return err("option", "expected object");
  const value = field(v, "value", decodeString);
  if (!value.ok) return value;
  const label = field(v, "label", decodeString);
  if (!label.ok) return label;
  return ok({ value: value.value, label: label.value });
}

function decodeInputValue(v: unknown): DecodeResult<InputValue> {
  if (isString(v) || isNumber(v)) return ok(v);
  return err("value", "expected string or number");
}

function decodeArray<T>(v: unknown, decodeItem: (item: unknown, i: number) => DecodeResult<T>): DecodeResult<T[]> {
  if (!isArray(v)) return err("array", "expected array");
  const out: T[] = [];
  for (let i = 0; i < v.length; i++) {
    const r = decodeItem(v[i], i);
    if (!r.ok) return r;
    out.push(r.value);
  }
  return ok(out);
}

function decodeInput(v: unknown): DecodeResult<TemplateInput> {
  if (!isObject(v)) return err("input", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const value = optional(v, "value", decodeInputValue);
  if (!value.ok) return value;
  return ok({ kind: "input", id: id.value, value: value.value });
}

function decodeSelect(v: unknown): DecodeResult<TemplateSelect> {
  if (!isObject(v)) return err("select", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const label = field(v, "label", decodeString);
  if (!label.ok) return label;
  const options = field(v, "options", (o) => decodeArray(o, decodeSelectOption));
  if (!options.ok) return options;
  const selected = optional(v, "selected", decodeString);
  if (!selected.ok) return selected;
  return ok({ kind: "select", id: id.value, label: label.value, options: options.value, selected: selected.value });
}

function decodeButton(v: unknown): DecodeResult<TemplateButton> {
  if (!isObject(v)) return err("button", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const label = field(v, "label", decodeString);
  if (!label.ok) return label;
  const action = field(v, "action", decodeString);
  if (!action.ok) return action;
  const disabled = optional(v, "disabled", decodeBool);
  if (!disabled.ok) return disabled;
  return ok({ kind: "button", id: id.value, label: label.value, action: action.value, disabled: disabled.value });
}

function decodeText(v: unknown): DecodeResult<TemplateText> {
  if (!isObject(v)) return err("text", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const text_type = field(v, "text_type", (t) => {
    const tt = enumValue(TEXT_TYPE_VALUES, t);
    return tt ? ok(tt) : err<TextType>("text_type", `expected one of ${TEXT_TYPE_VALUES.join(", ")}`);
  });
  if (!text_type.ok) return text_type;
  const value = field(v, "value", decodeString);
  if (!value.ok) return value;
  return ok({ kind: "text", id: id.value, text_type: text_type.value, value: value.value });
}

function decodeImage(v: unknown): DecodeResult<TemplateImage> {
  if (!isObject(v)) return err("image", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const src = field(v, "src", decodeString);
  if (!src.ok) return src;
  const alt = field(v, "alt", decodeString);
  if (!alt.ok) return alt;
  return ok({ kind: "image", id: id.value, src: src.value, alt: alt.value });
}

function decodeBadge(v: unknown): DecodeResult<TemplateBadge> {
  if (!isObject(v)) return err("badge", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const label = field(v, "label", decodeString);
  if (!label.ok) return label;
  const variant = field(v, "variant", (t) => {
    const bv = enumValue(BADGE_VARIANT_VALUES, t);
    return bv ? ok(bv) : err<BadgeVariant>("variant", `expected one of ${BADGE_VARIANT_VALUES.join(", ")}`);
  });
  if (!variant.ok) return variant;
  return ok({ kind: "badge", id: id.value, label: label.value, variant: variant.value });
}

function decodeStat(v: unknown): DecodeResult<TemplateStat> {
  if (!isObject(v)) return err("stat", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const label = field(v, "label", decodeString);
  if (!label.ok) return label;
  const value = field(v, "value", decodeString);
  if (!value.ok) return value;
  const secondary = optional(v, "secondary", decodeString);
  if (!secondary.ok) return secondary;
  return ok({ kind: "stat", id: id.value, label: label.value, value: value.value, secondary: secondary.value });
}

function decodeDivider(v: unknown): DecodeResult<TemplateDivider> {
  if (!isObject(v)) return err("divider", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const label = optional(v, "label", decodeString);
  if (!label.ok) return label;
  return ok({ kind: "divider", id: id.value, label: label.value });
}

function decodeDiagram(v: unknown): DecodeResult<TemplateDiagram> {
  if (!isObject(v)) return err("diagram", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const title = field(v, "title", decodeString);
  if (!title.ok) return title;
  const size = field(v, "size", decodeSize);
  if (!size.ok) return size;
  const primitives = field(v, "primitives", (p) => decodeArray(p, decodeDiagramPrimitive));
  if (!primitives.ok) return primitives;
  return ok({ kind: "diagram", id: id.value, title: title.value, size: size.value, primitives: primitives.value });
}

function decodeCode(v: unknown): DecodeResult<TemplateCode> {
  if (!isObject(v)) return err("code", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const path = field(v, "path", decodeString);
  if (!path.ok) return path;
  const language = field(v, "language", decodeString);
  if (!language.ok) return language;
  const line_start = field(v, "line_start", decodeNumber);
  if (!line_start.ok) return line_start;
  const source = field(v, "source", decodeString);
  if (!source.ok) return source;
  const highlights = field(v, "highlights", (h) => decodeArray(h, decodeCodeHighlight));
  if (!highlights.ok) return highlights;
  return ok({ kind: "code", id: id.value, path: path.value, language: language.value, line_start: line_start.value, source: source.value, highlights: highlights.value });
}

function decodeContainer(v: unknown, allowNested: boolean): DecodeResult<TemplateContainer> {
  if (!isObject(v)) return err("container", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const direction = field(v, "direction", (d) => {
    const cd = enumValue(CONTAINER_DIRECTION_VALUES, d);
    return cd ? ok(cd) : err<ContainerDirection>("direction", `expected one of ${CONTAINER_DIRECTION_VALUES.join(", ")}`);
  });
  if (!direction.ok) return direction;
  const children = field(v, "children", (c) => decodeArray(c, (item) => decodeTemplateNode(item, allowNested)));
  if (!children.ok) return children;
  return ok({ kind: "container", id: id.value, direction: direction.value, children: children.value });
}

function decodeList(v: unknown, allowNested: boolean): DecodeResult<TemplateList> {
  if (!isObject(v)) return err("list", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const children = field(v, "children", (c) => decodeArray(c, (item) => decodeTemplateNode(item, allowNested)));
  if (!children.ok) return children;
  const ordered = optional(v, "ordered", decodeBool);
  if (!ordered.ok) return ordered;
  return ok({ kind: "list", id: id.value, children: children.value, ordered: ordered.value });
}

function decodeSubmittable(v: unknown): DecodeResult<TemplateSubmittable> {
  if (!isObject(v)) return err("submittable", "expected object");
  const id = field(v, "id", decodeString);
  if (!id.ok) return id;
  const value = field(v, "value", (val): DecodeResult<(TemplateInput | TemplateSelect)[]> =>
    decodeArray(val, (item): DecodeResult<TemplateInput | TemplateSelect> => {
      if (!isObject(item)) return err("value", "expected object");
      const k = field(item, "kind", decodeString);
      if (!k.ok) return k;
      if (k.value === "input") return decodeInput(item);
      if (k.value === "select") return decodeSelect(item);
      return err("kind", `expected input or select, got ${k.value}`);
    }),
  );
  if (!value.ok) return value;
  const button = optional(v, "button", decodeButton);
  if (!button.ok) return button;
  return ok({ kind: "submittable", id: id.value, value: value.value, button: button.value });
}

export function decodeTemplateNode(v: unknown, allowNested: boolean): DecodeResult<Template> {
  if (!isObject(v)) return err("node", "expected object");
  const kind = field(v, "kind", decodeString);
  if (!kind.ok) return kind;

  if (!allowNested && (NESTED_ONLY_KINDS as readonly string[]).includes(kind.value)) {
    return err("kind", `${kind.value} is not allowed at top level`);
  }

  switch (kind.value) {
    case "text": return decodeText(v);
    case "image": return decodeImage(v);
    case "badge": return decodeBadge(v);
    case "stat": return decodeStat(v);
    case "divider": return decodeDivider(v);
    case "diagram": return decodeDiagram(v);
    case "code": return decodeCode(v);
    case "container": return decodeContainer(v, true);
    case "list": return decodeList(v, true);
    case "submittable": return decodeSubmittable(v);
    default:
      if ((ALL_KINDS as readonly string[]).includes(kind.value)) {
        return err("kind", `${kind.value} is not a top-level template kind`);
      }
      return err("kind", `unknown template kind: ${kind.value}`);
  }
}

export function decodeTemplate(jsonString: string): DecodeResult<Template> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonString);
  } catch {
    return err("tree", "invalid JSON");
  }
  return decodeTemplateNode(parsed, false);
}
