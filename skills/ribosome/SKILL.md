---
name: ribosome
description: Generate Ribosome template JSON for generative user interfaces.
---

# Ribosome

Emit exactly one JSON object. Emit no prose, Markdown fences, or surrounding text. Your response must be **raw template JSON only**.

Ribosome describes UI semantics. Do not mention rendering libraries, terminals, widgets, clients, protocols, or implementation details.

## General rules

- Every template has `kind` and a stable string `id`.
- Reuse an ID only when updating the same logical region.
- New regions require new IDs.
- Omit optional fields when they have no value. Do not emit `null`.
- Use only the types below.
- Every `container` has an explicit `direction`: `Vertical` or `Horizontal`.
- `input`, `select`, and `button` only occur inside a `submittable`.
- Do not emit internal error templates.
- Build an interface for the subject, not a transcript of a conversation. Choose meaningful regions, nesting, and components based on the subject's complexity.

## Renderable templates

### Text

```json
{"kind":"text","id":"page-title","text_type":"H1","value":"Trip planner"}
```

Required: `id`, `text_type`, `value`.

`text_type`: `Paragraph`, `H1`, `H2`, `H3`, `H4`, `H5`, `H6`.

### Image

```json
{"kind":"image","id":"route-map","src":"https://example.com/map.png","alt":"Route map"}
```

Required: `id`, `src`, `alt`.

### Badge

```json
{"kind":"badge","id":"booking-status","label":"Confirmed","variant":"Success"}
```

Required: `id`, `label`, `variant`.

`variant`: `Neutral`, `Success`, `Warning`, `Error`, `Info`.

### Stat

```json
{"kind":"stat","id":"total-price","label":"Total","value":"NZ$1,240","secondary":"For two travellers"}
```

Required: `id`, `label`, `value`. `secondary` is optional.

### Divider

```json
{"kind":"divider","id":"fare-boundary","label":"Fare details"}
```

Required: `id`. `label` is optional.

### Diagram

Use `diagram` when a visual explanation makes a flow, relationship, architecture, or data shape clearer. It is a declarative drawing canvas, not an image or an implementation instruction.

```json
{"kind":"diagram","id":"request-lifecycle","title":"Request lifecycle","size":{"width":400,"height":200},"primitives":[{"kind":"rectangle","id":"client","origin":{"x":10,"y":10},"size":{"width":80,"height":40},"tone":"Default"},{"kind":"text","text":"Client","position":{"x":30,"y":30},"tone":"Default"},{"kind":"arrow","start":{"x":90,"y":30},"stop":{"x":200,"y":30},"tone":"Info"},{"kind":"text","text":"request","position":{"x":120,"y":22},"tone":"Info"}]}
```

Required: `id`, `title`, `size`, `primitives`.

- `size` is an object with integer `width` and `height`. Choose values that fit the content (e.g. `{"width":400,"height":200}`).
- Coordinates are integers within the canvas bounds: `x` from 0 to `width`, `y` from 0 to `height`. `x` increases left to right, `y` increases top to bottom.
- Primitives are painted in source order. Each has a `tone`: `Default`, `Positive`, `Negative`, `Warning`, or `Info`.
- `text` has `text`, `position` (`{x, y}`), and `tone`.
- `line` and `arrow` have `start` (`{x, y}`), `stop` (`{x, y}`), and `tone`.
- `rectangle` has `origin` (`{x, y}`), `size` (`{width, height}`), and `tone`.
- `circle` has `center` (`{x, y}`), `radius` (integer), and `tone`.
- `polyline` has `points` (array of `{x, y}`), and `tone`. At least two points.
- Do not use RGB values, images, executable content, or implementation-specific properties.

### Code

Use `code` only when the subject concerns source code. The source must be a concise, exact, self-contained snippet from the relevant file; never invent source to make an explanation easier.

```json
{"kind":"code","id":"event-dispatch","path":"src/session.rs","language":"rust","line_start":42,"source":"fn dispatch(event: Event) {\n  validate(event)?;\n  start_turn(event)\n}","highlights":[{"start_line":43,"end_line":43,"tone":"Warning"},{"start_line":44,"end_line":44,"tone":"Info"}]}
```

Required: `id`, `path`, `language`, `line_start`, `source`, `highlights`.

- `path` is repository-relative. `line_start` is the absolute line number of the first source line.
- Preserve source indentation exactly. Keep snippets focused; do not emit an entire file when a relevant region is sufficient.
- Each highlight has inclusive `start_line` and `end_line` and a named `tone`: `Default`, `Positive`, `Negative`, `Warning`, or `Info`.
- Highlights are ordered and non-overlapping. Preserve code and highlight IDs when updating the same logical snippet.

### Container

```json
{"kind":"container","id":"booking-summary","direction":"Vertical","children":[...]}
```

Required: `id`, `direction`, `children`.

Use `Vertical` for stacked regions and `Horizontal` for adjacent regions. Children are renderable templates only.

### List

```json
{"kind":"list","id":"flight-options","ordered":false,"children":[...]}
```

Required: `id`, `children`. `ordered` is optional. Children are renderable templates only.

### Submittable

```json
{"kind":"submittable","id":"passenger-form","value":[{"kind":"input","id":"passenger-name","value":"Alice"}],"button":{"kind":"button","id":"save-passenger","label":"Save","action":"Submit"}}
```

Required: `id`, `value`. `button` is optional.

`value` contains only `input` and `select` fields.

#### Input

```json
{"kind":"input","id":"passenger-name","value":"Alice"}
```

Required: `id`. `value` is optional and is a string or integer.

#### Select

```json
{"kind":"select","id":"cabin","label":"Cabin","options":[{"value":"economy","label":"Economy"},{"value":"business","label":"Business"}],"selected":"economy"}
```

Required: `id`, `label`, `options`. `selected` is optional.

#### Button

```json
{"kind":"button","id":"save-passenger","label":"Save","action":"Submit","disabled":false}
```

Required: `id`, `label`, `action`. `disabled` is optional.

`action` is `Submit`, `Navigate:<url>`, or a non-empty custom action string.

## New UI

For a new UI, emit a root `container` with a stable `id` and meaningful child regions.

Use nested containers, stats, lists, diagrams, code views, and forms when they clarify the subject. Do not force a fixed layout or component set: simple requests may need only a small UI, while technical or multi-step requests should use several semantic regions.

```json
{"kind":"container","id":"root","direction":"Vertical","children":[{"kind":"text","id":"page-title","text_type":"H1","value":"Trip planner"},{"kind":"submittable","id":"destination-form","value":[{"kind":"input","id":"destination","value":""}],"button":{"kind":"button","id":"find-flights","label":"Find flights","action":"Submit"}}]}
```

## Update

For an existing UI, emit one replacement subtree whose `id` matches an existing template in the current tree. The reconciler replaces the subtree with that matching `id`. Preserve unaffected IDs and values. Do not re-emit the root unless the root is the changed region.

## Semantic interaction

Interaction arrives as semantic events, never key presses:

- `Click` identifies a component ID.
- `Submit` identifies a form ID and field values.
- `Change` identifies a field ID and value.

Emit the subtree that reflects the resulting application state.
