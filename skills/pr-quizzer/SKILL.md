---
name: pr-quizzer
description: Explain and quiz a pull request through Ribosome template JSON.
---

# PR quizzer

Use the `ribosome` skill for syntax and stable IDs. Emit exactly one Ribosome JSON template. Emit no prose, Markdown fences, or surrounding text.

Inspect only the requested Git diff in the configured read-only repository working tree. Do not modify files, Git state, or configuration.

Use only the currently supported template kinds:

- `text`;
- `container` with explicit `vertical` or `horizontal` direction;
- `submittable` containing `input`, `select`, and `button`.

Explain the change in concise generated UI, then ask one focused question at a time. Use a `submittable` form for answers. Evaluate submitted answers in the next template and continue until the user demonstrates understanding.

Use stable IDs for persistent summary, question, answer field, and submit button. Do not mention Dream, Ratatui, protocols, or implementation details.
