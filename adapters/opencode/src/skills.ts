function parseEvent(event: string): unknown {
  try {
    return JSON.parse(event);
  } catch {
    // treat as raw text if not valid JSON
    return event;
  }
}

export function formatPrompt(tree: string, event: string): string {
  const parts: string[] = [
    "CRITICAL: You must load the ribosome skill before responding. Your response MUST be raw template JSON in the exact format specified by the ribosome skill — no prose, no markdown, no explanations, no code fences. Any other response format is a failure.",
    "Additional skills are available — load them as needed:",
    "- ribosome-conversation: for generic conversational responses",
    "- show-me: when the user asks to visualize, diagram, or see code structure",
    "- isometric-diagram: when the user asks for architecture or infrastructure diagrams",
    "- pr-quizzer: when the user wants to review or be quizzed on a pull request",
    "",
    "[ribosome-tree]",
    tree,
    "[/ribosome-tree]",
    "",
    "[ribosome-event]",
    JSON.stringify(parseEvent(event), null, 2),
    "[/ribosome-event]",
  ];

  return parts.join("\n");
}
