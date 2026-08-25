---
name: show-me
description: Answer the current topic with the smallest visual: pseudocode, call tree, component tree, file tree, diagram, diff, or code block. Use when the user says "show me", "diagram this", "visualize", "make it visual", or "this is too much text".
---

# Show Me

Use the `ribosome` skill for syntax and stable IDs. Emit exactly one Ribosome JSON template. Emit no prose, Markdown fences, or surrounding text.

Answer with the smallest view that carries the point. Strip every call, file, prop, state, and boundary the current question does not turn on. One view is the common case; a compound topic takes two at most.

## Pick the view

| The point is | Template | How |
|---|---|---|
| logic or an algorithm | `code` | Pseudocode in tree form, `language: "plaintext"` |
| what calls what at runtime | `code` | Indented call stack, `language: "plaintext"` |
| UI structure with state and module boundaries | `code` | JSX-like component tree with file annotations, `language: "plaintext"` |
| file responsibility or broad refactor | `code` | Shallow file tree with one-line per-directory comments, `language: "plaintext"` |
| interaction, control flow, or data flow | `diagram` | Primitives: `rectangle` for participants, `arrow` for messages, `text` for labels. Tone: `"Info"` for key paths, `"Default"` for context. Use sequence-diagram layout. |
| a change against an existing shape | `code` | Diff syntax with highlights: `"Positive"` tone for additions, `"Negative"` tone for removals. `language: "diff"`. |
| new code or a shape worth copying | `code` | Whole block with the real source. `path`, `language`, `line_start` must be exact. |
| types, signatures, interfaces | `code` | Concise type definitions, `language` matching the target. |

## Code views

### Pseudocode

For algorithmic or logical flow. Keep to the key branches.

```json
{"kind":"code","id":"flow-algorithm","path":"","language":"plaintext","line_start":1,"source":"on(save)\n  if content is unchanged\n    return cached result\n  write new content\n  return fresh result","highlights":[]}
```

Omit `path` when the source is not from a file. Omit `highlights` array when empty.

### Call tree

Indented text showing the call stack. One function per line. The indentation shows depth — standard is two spaces per level.

```json
{"kind":"code","id":"call-stack","path":"","language":"plaintext","line_start":1,"source":"submitForm\n  createSession\n    persistPrompt\n    launchAgent\n  navigateToSession","highlights":[]}
```

### Component tree

JSX-like tree with the owning file in parentheses. Include state hooks and module boundaries that matter. Omit everything else.

```json
{"kind":"code","id":"component-tree","path":"","language":"plaintext","line_start":1,"source":"<OrderPage> (src/routes/order.tsx)\n  useOrderEvents()\n  <OrderToolbar>\n    <RetryButton> (packages/ui)","highlights":[]}
```

### File tree

Shallow tree with one comment per directory. Only show directories relevant to the current question.

```json
{"kind":"code","id":"file-layout","path":"","language":"plaintext","line_start":1,"source":"src/\n├── commands/       # parses user actions\n├── sessions/       # owns session state\n└── transport/      # sends API requests","highlights":[]}
```

### Diff

Use when the point is what changes and the shape around it already exists. Match the diff format to the view it changes. Use `language: "diff"`. Highlight added lines with `"Positive"` tone and removed lines with `"Negative"` tone.

**Component change:**

```json
{"kind":"code","id":"component-diff","path":"src/routes/order.tsx","language":"diff","line_start":10,"source":"  <OrderPage>\n    useOrderEvents()\n    <OrderToolbar>\n+      <RetryButton />\n    <OrderTimeline>\n+      <RetryResultCard />","highlights":[{"start_line":13,"end_line":13,"tone":"Positive"},{"start_line":15,"end_line":15,"tone":"Positive"}]}
```

**File-layout change:**

```json
{"kind":"code","id":"file-diff","path":"","language":"diff","line_start":1,"source":"  src/\n  ├── commands/\n+ │   └── show-me.ts\n  ├── sessions/\n- └── transport.ts\n+ └── transport/\n+     ├── client.ts\n+     └── stream.ts","highlights":[{"start_line":3,"end_line":3,"tone":"Positive"},{"start_line":5,"end_line":5,"tone":"Negative"},{"start_line":6,"end_line":8,"tone":"Positive"}]}
```

**Call-tree change:**

```json
{"kind":"code","id":"call-diff","path":"","language":"diff","line_start":1,"source":"  submitForm\n    createSession\n      persistPrompt\n+       expandSkillMention\n      launchAgent\n-   navigateToSession\n+   navigateToSession\n+     subscribeToEvents","highlights":[{"start_line":4,"end_line":4,"tone":"Positive"},{"start_line":6,"end_line":6,"tone":"Negative"},{"start_line":7,"end_line":8,"tone":"Positive"}]}
```

**Control-flow change:**

```json
{"kind":"code","id":"flow-diff","path":"","language":"diff","line_start":1,"source":"  on(save)\n-   write content\n+   if content is unchanged\n+     return cached result\n+   write new content\n+   invalidate cache","highlights":[{"start_line":2,"end_line":2,"tone":"Negative"},{"start_line":3,"end_line":6,"tone":"Positive"}]}
```

### Whole block

When most of the code is new, or omitted context would hide ownership or order. Source must be exact and from a real file. `path`, `language`, and `line_start` must be accurate.

```json
{"kind":"code","id":"new-block","path":"src/commands/show-me.ts","language":"typescript","line_start":42,"source":"function expandSkill(command: string): string {\n  const skillName = command.slice(1)\n  return `use the ${skillName} skill`\n}","highlights":[]}
```

## Diagram views

Use `diagram` when the point is interaction, control flow, data flow, or architecture. The diagram is a declarative 100x100 canvas. Use `"Info"` tone for the key path, `"Default"` for supporting elements, `"Warning"` for error paths.

**Sequence layout** (services/talking to each other):

Place participant rectangles evenly across the top, labels below. Arrows between them for messages. Text labels above arrows.

```json
{"kind":"diagram","id":"sequence-diagram","title":"Session creation","size":{"width":100,"height":100},"primitives":[{"kind":"rectangle","id":"user-box","origin":{"x":5,"y":5},"size":{"width":20,"height":12},"tone":"Default"},{"kind":"text","id":"user-label","text":"User","position":{"x":15,"y":12},"tone":"Default"},{"kind":"rectangle","id":"api-box","origin":{"x":40,"y":5},"size":{"width":20,"height":12},"tone":"Default"},{"kind":"text","id":"api-label","text":"API","position":{"x":50,"y":12},"tone":"Default"},{"kind":"rectangle","id":"db-box","origin":{"x":75,"y":5},"size":{"width":20,"height":12},"tone":"Default"},{"kind":"text","id":"db-label","text":"DB","position":{"x":85,"y":12},"tone":"Default"},{"kind":"arrow","id":"msg-1","start":{"x":25,"y":28},"stop":{"x":40,"y":28},"tone":"Info"},{"kind":"text","id":"msg-1-label","text":"submit form","position":{"x":26,"y":24},"tone":"Info"},{"kind":"arrow","id":"msg-2","start":{"x":50,"y":42},"stop":{"x":75,"y":42},"tone":"Info"},{"kind":"text","id":"msg-2-label","text":"persist session","position":{"x":52,"y":38},"tone":"Info"},{"kind":"arrow","id":"msg-3","start":{"x":75,"y":56},"stop":{"x":50,"y":56},"tone":"Info"},{"kind":"text","id":"msg-3-label","text":"session created","position":{"x":53,"y":52},"tone":"Info"}]}
```

**Component flow** (UI state or data flow):

Place components as rectangles. Arrows for props, events, or data flow. Keep to the components relevant to the current question.

## Layout

Emit a root `container` with `id: "show-me-root"` holding the visual and a minimal label. Place the visual next to the short text it supports. Use a `divider` between multiple views only when the topic genuinely needs two views.

### Single view

```json
{"kind":"container","id":"show-me-root","direction":"Vertical","children":[{"kind":"text","id":"show-me-label","text_type":"H3","value":"Session lifecycle"},{"kind":"code","id":"show-me-view","path":"","language":"plaintext","line_start":1,"source":"submitForm\n  createSession\n    persistPrompt\n    launchAgent\n  navigateToSession","highlights":[]}]}
```

### Two views with divider

```json
{"kind":"container","id":"show-me-root","direction":"Vertical","children":[{"kind":"text","id":"show-me-label-1","text_type":"H3","value":"Before"},{"kind":"code","id":"show-me-view-1","path":"","language":"plaintext","line_start":1,"source":"submitForm\n  createSession\n    persistPrompt\n    launchAgent\n  navigateToSession","highlights":[]},{"kind":"divider","id":"show-me-divider","label":"Refactor to"},{"kind":"code","id":"show-me-view-2","path":"","language":"diff","line_start":1,"source":"  submitForm\n    createSession\n      persistPrompt\n+       expandSkillMention\n      launchAgent\n-   navigateToSession\n+   navigateToSession\n+     subscribeToEvents","highlights":[{"start_line":4,"end_line":4,"tone":"Positive"},{"start_line":6,"end_line":6,"tone":"Negative"},{"start_line":7,"end_line":8,"tone":"Positive"}]}]}
```

### With a submittable follow-up

When the user needs to confirm or decide, add a `submittable` after the visual with a single focused question. Use stable IDs so the visual persists across updates.

```json
{"kind":"container","id":"show-me-root","direction":"Vertical","children":[{"kind":"text","id":"show-me-label","text_type":"H3","value":"Proposed refactor"},{"kind":"code","id":"show-me-view","path":"","language":"diff","line_start":1,"source":"  src/\n  ├── commands/\n+ │   └── show-me.ts\n  ├── sessions/\n- └── transport.ts\n+ └── transport/\n+     ├── client.ts\n+     └── stream.ts","highlights":[{"start_line":3,"end_line":3,"tone":"Positive"},{"start_line":5,"end_line":5,"tone":"Negative"},{"start_line":6,"end_line":8,"tone":"Positive"}]},{"kind":"submittable","id":"show-me-confirm","value":[{"kind":"input","id":"show-me-response","value":""}],"button":{"kind":"button","id":"show-me-submit","label":"Looks good?","action":"Submit"}}]}
```

## Boundaries

- A diagram that must persist in a document belongs to a dedicated design or architecture skill, not here.
- A clickable UI prototype is a different skill — this is for understanding, not interaction.
- A full review walkthrough with multiple findings goes to a review skill.
- If the user says "this is too much content. show me.", restate the same information as the smallest visual that keeps the point. Do not add new content.
