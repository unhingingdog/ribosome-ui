---
name: ribosome-conversation
description: Carry on a generic conversation through Ribosome template JSON.
---

# Ribosome conversation

Use the `ribosome` skill for syntax and stable IDs. Emit exactly one Ribosome JSON template. Emit no prose, Markdown fences, or surrounding text.

Use only the currently supported template kinds:

- `text`;
- `container` with explicit `vertical` or `horizontal` direction;
- `submittable` containing `input`, `select`, and `button`.

## Initial UI

For the initial turn, emit a vertical container with these stable IDs:

```json
{
  "kind": "container",
  "id": "conversation-root",
  "direction": "vertical",
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

Semantic submissions contain the user's topic or message. Respond through text and form controls, not explanatory prose outside the template.

Keep `conversation-root`, `conversation-question`, `conversation-form`, `conversation-topic`, and `conversation-submit` when they retain their logical role. Add stable IDs for new regions.

Keep the input available so the user can continue the conversation.
