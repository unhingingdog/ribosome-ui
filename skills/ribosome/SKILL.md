---
name: ribosome
description: Generate Ribosome template JSON for generative user interfaces.
---

# Ribosome

Emit exactly one JSON object. Emit no prose, Markdown fences, or surrounding text.

Ribosome describes UI semantics. Do not mention rendering libraries, terminals, widgets, clients, protocols, or implementation details.

## General rules

- Every template has `kind` and a stable string `id`.
- Reuse an ID only when updating the same logical region.
- New regions require new IDs.
- Omit optional fields when they have no value. Do not emit `null`.
- Use only the types below.
- Every `container` has an explicit `direction`: `vertical` or `horizontal`.
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

Use `diagram` when a visual explanation makes a flow, relationship, architecture, or data shape clearer. It is a declarative 100 by 100 drawing canvas, not an image or an implementation instruction.

```json
{"kind":"diagram","id":"request-lifecycle","title":"Request lifecycle","size":"regular","primitives":[{"shape":"rectangle","id":"client","at":{"x":8,"y":38},"width":20,"height":24,"tone":"primary"},{"shape":"text","id":"client-label","at":{"x":13,"y":51},"value":"TUI","tone":"primary"},{"shape":"arrow","id":"request","from":{"x":28,"y":50},"to":{"x":72,"y":50},"tone":"secondary"},{"shape":"text","id":"request-label","at":{"x":41,"y":43},"value":"semantic event","tone":"muted"}]}
```

Required: `id`, `title`, `size`, `primitives`.

- `size` is `compact`, `regular`, or `tall`.
- Coordinates are integer percentages: `x` increases left to right and `y` increases top to bottom, from 0 to 100.
- Primitives are painted in source order. Each has a stable `id` and a `tone`: `primary`, `secondary`, `success`, `warning`, `danger`, or `muted`.
- `text` has `at` and `value`.
- `line` and `arrow` have `from` and `to`.
- `rectangle` has top-left `at`, `width`, and `height`.
- `circle` has centre `at` and `radius`.
- `polyline` has `points`, with at least two points.
- Preserve diagram and primitive IDs when updating an existing diagram. Do not use RGB values, images, executable content, or implementation-specific properties.

### Code

Use `code` only when the subject concerns source code. The source must be a concise, exact, self-contained snippet from the relevant file; never invent source to make an explanation easier.

```json
{"kind":"code","id":"event-dispatch","path":"src/session.rs","language":"rust","line_start":42,"source":"fn dispatch(event: Event) {\n  validate(event)?;\n  start_turn(event)\n}","highlights":[{"id":"validate-event","start_line":43,"end_line":43,"label":"Reject invalid semantic events","tone":"warning"},{"id":"start-turn","start_line":44,"end_line":44,"label":"Starts the next generation","tone":"primary"}]}
```

Required: `id`, `path`, `language`, `line_start`, `source`, `highlights`.

- `path` is repository-relative. `line_start` is the absolute line number of the first source line.
- Preserve source indentation exactly. Keep snippets focused; do not emit an entire file when a relevant region is sufficient.
- Each highlight has a stable `id`, inclusive `start_line` and `end_line`, short `label`, and a named tone: `primary`, `secondary`, `success`, `warning`, `danger`, or `muted`.
- Highlights are ordered and non-overlapping. Preserve code and highlight IDs when updating the same logical snippet.

### Container

```json
{"kind":"container","id":"booking-summary","direction":"vertical","children":[...]}
```

Required: `id`, `direction`, `children`.

Use `vertical` for stacked regions and `horizontal` for adjacent regions. Children are renderable templates only.

### List

```json
{"kind":"list","id":"flight-options","ordered":false,"children":[...]}
```

Required: `id`, `children`. `ordered` is optional. Children are renderable templates only.

### Form

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

For a new UI, emit a root `container` with `id` equal to `root` and meaningful child regions.

Use nested containers, stats, lists, diagrams, code views, and forms when they clarify the subject. Do not force a fixed layout or component set: simple requests may need only a small UI, while technical or multi-step requests should use several semantic regions.

```json
{"kind":"container","id":"root","direction":"vertical","children":[{"kind":"text","id":"page-title","text_type":"H1","value":"Trip planner"},{"kind":"submittable","id":"destination-form","value":[{"kind":"input","id":"destination","value":""}],"button":{"kind":"button","id":"find-flights","label":"Find flights","action":"Submit"}}]}
```

## Update

For an existing UI, emit one replacement subtree anchored by the stable ID of the region that changed. Preserve unaffected IDs and values. Do not re-emit the root unless the root is the changed region.

## Semantic interaction

Interaction arrives as semantic events, never key presses:

- `Click` identifies a component ID.
- `Submit` identifies a form ID and field values.
- `Change` identifies a field ID and value.

Emit the subtree that reflects the resulting application state.
