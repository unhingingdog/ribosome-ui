import { createSignal, Show } from "solid-js";
import { decodeTemplate, createRenderer, type Template } from "@ribosome/ui-core";
import { webComponents } from "./components";

export function Templates() {
  const [tree, setTree] = createSignal<Template | null>(null);
  const [error, setError] = createSignal<string | null>(null);
  const renderer = createRenderer(webComponents);

  const fetchTemplates = async () => {
    try {
      const res = await fetch(`http://${window.location.hostname}:8787/templates`);
      if (!res.ok) {
        setError(`Server returned ${res.status}`);
        return;
      }
      const json = await res.text();
      const decoded = decodeTemplate(json);
      if (decoded.ok) {
        setTree(decoded.value);
      } else {
        setError(`Decode error: ${decoded.error.field}: ${decoded.error.message}`);
      }
    } catch (e) {
      setError(`Fetch failed: ${String(e)}`);
    }
  };

  fetchTemplates();

  return (
    <div>
      <div class="status-bar">
        <span class="status-dot connected" />
        <span>Template Storybook</span>
        <a href="/" class="status-revision" style={{ "text-decoration": "none" }}>← Back to app</a>
      </div>

      <Show when={error()}>
        <div class="error-toast">{error()}</div>
      </Show>

      <Show when={tree()} fallback={<div>Loading templates…</div>}>
        <div class="tree-container">
          {renderer(tree()!)}
        </div>
      </Show>
    </div>
  );
}
