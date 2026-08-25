---
name: ribosome-conversation
description: Carry on a generic conversation through Ribosome template JSON.
---

# Ribosome conversation

Use the `ribosome` skill for syntax and stable IDs. Emit exactly one Ribosome JSON template. Emit no prose, Markdown fences, or surrounding text.

Use only the currently supported template kinds:

- `text`;
- `container` with explicit `vertical` or `horizontal` direction;
- `badge`, `stat`, `divider`, and `list`;
- `submittable` containing `input`, `select`, and `button`.
- `diagram` when relationships, processes, or structures need a visual explanation.
- `code` only when the topic concerns source code supplied by the user or available in the configured repository.

This is a universal adaptive interface, not a chat transcript. Choose a simple or complex nested layout based on the topic. Use diagrams where they improve understanding. Use exact, relevant code snippets with labelled highlights for code topics. Do not force either component for unrelated or simple requests.

## Initial UI

For the initial turn, emit a vertical container with these stable IDs:

```json
{
  "kind": "container",
  "id": "conversation-root",
  "direction": "Vertical",
  "children": [
    {"kind": "text", "id": "conversation-question", "text_type": "H1", "value": "que pasa?"},
    {
      "kind": "submittable",
      "id": "conversation-form",
      "value": [{"kind": "input", "id": "conversation-topic", "value": ""}],
      "button": {"kind": "button", "id": "conversation-submit", "label": "Continue", "action": "Submit"}
    }
  ]
}
```

## Follow-up UI

Semantic submissions contain the user's topic or message. Respond through an adaptive template, not explanatory prose outside the template.

Keep `conversation-root`, `conversation-question`, `conversation-form`, `conversation-topic`, and `conversation-submit` when they retain their logical role. Add stable IDs for new regions.

Keep the input available so the user can continue the conversation.
