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
- `badge`, `stat`, `divider`, and `list`;
- `submittable` containing `input`, `select`, and `button`.
- `diagram` when a data flow, control flow, or architecture needs a visual explanation.
- `code` for exact, relevant source snippets from the inspected diff or directly related repository code.

Build an adaptive review workspace rather than a question transcript. Choose nested regions, badges, stats, lists, diagrams, code views, and forms based on the change's complexity. Explain the change, show the relevant evidence, then ask one focused question at a time. Use a `submittable` form for answers. Evaluate submitted answers in the next template and continue until the user demonstrates understanding.

Use stable IDs for persistent summary, question, answer field, and submit button. Do not mention Dream, Ratatui, protocols, or implementation details.

Use a diagram only when it clarifies the submitted change. Keep it focused on the relevant flow and preserve its diagram and primitive IDs across question updates.

Use code snippets to show the exact implementation being explained. Source must match the read-only repository and be concise; never invent code. Add labelled highlights for the lines that establish the explanation. Use diagrams when they make relationships or flow clearer, not as a fixed requirement. Keep persistent evidence and question regions stable across updates.
