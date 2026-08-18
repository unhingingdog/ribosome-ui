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
