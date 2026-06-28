import React, { useEffect, useMemo, useRef, useState } from "react";

import createEngine, {
  type RibosomeAdapterConfig,
  type RibosomeAsset,
} from "../../dist/index.js";

import { components } from "./components";

const storageKey = "ribosome-ui:demo";

type Provider = "openai" | "groq" | "fireworks";

const providerOptions: Provider[] = ["openai", "groq", "fireworks"];

type ModelOption = { id: string; label: string };

const modelOptionsByProvider: Record<Provider, ModelOption[]> = {
  openai: [
    { id: "gpt-4o", label: "gpt-4o (capable)" },
    { id: "gpt-4o-mini", label: "gpt-4o-mini (cheap)" },
    { id: "gpt-4.1", label: "gpt-4.1 (latest)" },
    { id: "gpt-4.1-mini", label: "gpt-4.1-mini (fast)" },
    { id: "o3", label: "o3 (reasoning)" },
    { id: "o4-mini", label: "o4-mini (fast)" },
  ],
  groq: [
    { id: "llama-3.1-8b-instant", label: "llama-3.1-8b-instant (fastest)" },
    { id: "llama-3.3-70b-versatile", label: "llama-3.3-70b-versatile (capable)" },
    { id: "meta-llama/llama-4-scout-17b-16e-instruct", label: "llama-4-scout (newest)" },
    { id: "openai/gpt-oss-120b", label: "gpt-oss-120b (reasoning)" },
    { id: "qwen/qwen3-32b", label: "qwen3-32b (balanced)" },
    { id: "moonshotai/kimi-k2-instruct-0905", label: "kimi-k2 (premium)" },
  ],
  fireworks: [
    { id: "accounts/fireworks/routers/kimi-k2p6-fast", label: "kimi-k2p6-fast (fastest)" },
    { id: "accounts/fireworks/models/deepseek-v4-flash", label: "deepseek-v4-flash (cheap)" },
    { id: "accounts/fireworks/models/glm-5p2", label: "glm-5p2 (flagship)" },
    { id: "accounts/fireworks/models/glm-5p1", label: "glm-5p1 (proven)" },
    { id: "accounts/fireworks/models/qwen3p7-plus", label: "qwen3.7-plus (balanced)" },
    { id: "accounts/fireworks/models/llama4-maverick-instruct-basic", label: "llama-4-maverick (new)" },
    { id: "accounts/fireworks/models/gemma-4-31b-it-nvfp4", label: "gemma-4-31b (new)" },
  ],
};

const defaultUrls: Record<Provider, string> = {
  openai: "https://api.openai.com/v1/chat/completions",
  groq: "https://api.groq.com/openai/v1/chat/completions",
  fireworks: "https://api.fireworks.ai/inference/v1/chat/completions",
};

type ReasoningOption = { value: string; label: string };

const reasoningOptionsByModel: Record<string, ReasoningOption[]> = {
  // OpenAI
  "o3": [
    { value: "low", label: "low (faster)" },
    { value: "medium", label: "medium (default)" },
    { value: "high", label: "high (deeper)" },
  ],
  "o4-mini": [
    { value: "low", label: "low (faster)" },
    { value: "medium", label: "medium (default)" },
    { value: "high", label: "high (deeper)" },
  ],
  // Groq
  "openai/gpt-oss-120b": [
    { value: "low", label: "low (faster)" },
    { value: "medium", label: "medium (default)" },
    { value: "high", label: "high (deeper)" },
  ],
  // Fireworks
  "accounts/fireworks/models/glm-5p1": [
    { value: "none", label: "none (fastest)" },
    { value: "medium", label: "medium (reasoning on)" },
  ],
  "accounts/fireworks/models/glm-5p2": [
    { value: "high", label: "high (minimum)" },
    { value: "max", label: "max (default)" },
  ],
  "accounts/fireworks/models/qwen3p7-plus": [
    { value: "none", label: "none (fastest)" },
    { value: "low", label: "low" },
    { value: "medium", label: "medium (default)" },
    { value: "high", label: "high" },
  ],
  "accounts/fireworks/models/deepseek-v4-flash": [
    { value: "none", label: "none (fastest)" },
    { value: "low", label: "low" },
    { value: "medium", label: "medium" },
    { value: "high", label: "high (default)" },
    { value: "xhigh", label: "xhigh" },
    { value: "max", label: "max" },
  ],
};

function getReasoningOptions(modelId: string): ReasoningOption[] | null {
  return reasoningOptionsByModel[modelId] ?? null;
}

function getDefaultReasoningEffort(modelId: string): string | undefined {
  const options = getReasoningOptions(modelId);
  if (!options) return undefined;
  // Pick the option whose label contains "default" if any, else first non-none option, else first
  const defaultOption = options.find((o) => o.label.includes("default"));
  if (defaultOption) return defaultOption.value;
  const firstNonNone = options.find((o) => o.value !== "none");
  return firstNonNone?.value ?? options[0]?.value;
}

type DemoSettings = {
  goalPrompt: string;
  url: string;
  headers: Record<string, string>;
  assets: RibosomeAsset[];
  adapterConfig: RibosomeAdapterConfig;
  reasoningEffort?: string;
};

type DemoDraft = DemoSettings & {
  persist: boolean;
};

const defaultSettings: DemoSettings = {
  goalPrompt: "Create a small UI that asks the user for a name and greets them.",
  url: defaultUrls.fireworks,
  headers: {
    Authorization: "Bearer YOUR_API_KEY",
    "Content-Type": "application/json",
  },
  assets: [
    {
      id: "rice-field",
      url: "/assets/rice-field.jpg",
      description: "A green rice field landscape for agricultural or nature-themed UIs.",
    },
  ],
  adapterConfig: {
    adapter: "fireworks",
    model: "accounts/fireworks/models/glm-5p1",
  },
  reasoningEffort: "none",
};

const readSavedSettings = (): DemoSettings | null => {
  if (typeof window === "undefined") return null;

  const raw = window.localStorage.getItem(storageKey);
  if (!raw) return null;

  try {
    return { ...defaultSettings, ...JSON.parse(raw) };
  } catch {
    return null;
  }
};

const readDraft = (): DemoDraft => {
  const savedSettings = readSavedSettings();

  return {
    ...(savedSettings ?? defaultSettings),
    persist: Boolean(savedSettings),
  };
};

const saveSettings = (settings: DemoSettings) => {
  window.localStorage.setItem(storageKey, JSON.stringify(settings, null, 2));
};

const clearSettings = () => {
  window.localStorage.removeItem(storageKey);
};

const Panel = ({ children }: { children: React.ReactNode }) => (
  <section style={{ padding: 12, border: "1px solid #ddd" }}>{children}</section>
);

const formFieldStyle = {
  display: "grid",
  gap: 6,
  marginBottom: 12,
} as const;

const inputStyle = {
  width: "100%",
  padding: 8,
  border: "1px solid #ccc",
  borderRadius: 4,
} as const;

const buttonStyle = {
  padding: "8px 12px",
  border: "1px solid #111",
  background: "#fff",
  cursor: "pointer",
} as const;

export function App() {
  const [draft, setDraft] = useState<DemoDraft>(() =>
    typeof window === "undefined"
      ? { ...defaultSettings, persist: false }
      : readDraft(),
  );
  const [activeConfig, setActiveConfig] = useState<DemoSettings | null>(() =>
    typeof window === "undefined" ? null : readSavedSettings(),
  );
  const engineRef = useRef<ReturnType<typeof createEngine> | null>(null);
  const rootRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!rootRef.current || !activeConfig) return;

    const engine = createEngine({
      root: rootRef.current,
      goalPrompt: activeConfig.goalPrompt,
      url: activeConfig.url,
      headers: activeConfig.headers,
      assets: activeConfig.assets,
      components,
      adapterConfig: activeConfig.adapterConfig,
      reasoningEffort: activeConfig.reasoningEffort,
    });
    engineRef.current = engine;
    engine.start();

    return () => {
      engine.reset();
      engineRef.current = null;
    };
  }, [activeConfig]);

  const submitConfig = () => {
    const nextConfig: DemoSettings = {
      goalPrompt: draft.goalPrompt,
      url: draft.url,
      headers: draft.headers,
      assets: draft.assets,
      adapterConfig: draft.adapterConfig,
      reasoningEffort: draft.reasoningEffort,
    };

    if (draft.persist) {
      saveSettings(nextConfig);
    } else {
      clearSettings();
    }

    setActiveConfig(nextConfig);
  };

  const resetConfig = () => {
    const restored = readSavedSettings() ?? activeConfig;
    if (restored) {
      setDraft({ ...restored, persist: false });
    }
    clearSettings();
    setActiveConfig(null);
  };

  const activeProvider = useMemo<Provider>(() => {
    return (activeConfig?.adapterConfig?.adapter ?? "openai") as Provider;
  }, [activeConfig]);

  const activeModel = useMemo(() => {
    return activeConfig?.adapterConfig?.model ?? "gpt-4o-mini";
  }, [activeConfig]);

  const currentProvider = (draft.adapterConfig?.adapter ?? "openai") as Provider;
  const currentModels = modelOptionsByProvider[currentProvider];

  if (!activeConfig) {
    return (
      <main style={{ padding: 16, fontFamily: "sans-serif", maxWidth: 760 }}>
        <h1>Ribosome Demo</h1>
        <Panel>
          <div style={formFieldStyle}>
            <label htmlFor="goalPrompt">Goal prompt</label>
            <textarea
              id="goalPrompt"
              value={draft.goalPrompt}
              onChange={(event) => setDraft((current) => ({ ...current, goalPrompt: event.target.value }))}
              rows={4}
              style={inputStyle}
            />
          </div>
          <div style={formFieldStyle}>
            <label htmlFor="url">API URL</label>
            <input
              id="url"
              value={draft.url}
              onChange={(event) => setDraft((current) => ({ ...current, url: event.target.value }))}
              style={inputStyle}
            />
          </div>
          <div style={formFieldStyle}>
            <label htmlFor="authorization">Authorization header</label>
            <input
              id="authorization"
              value={draft.headers.Authorization ?? ""}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  headers: { ...current.headers, Authorization: event.target.value },
                }))
              }
              style={inputStyle}
            />
          </div>
          <div style={formFieldStyle}>
            <label htmlFor="provider">Provider</label>
            <select
              id="provider"
              value={currentProvider}
              onChange={(event) => {
                const provider = event.target.value as Provider;
                const newModelId = modelOptionsByProvider[provider][0].id;
                setDraft((current) => ({
                  ...current,
                  url: defaultUrls[provider],
                  adapterConfig: {
                    adapter: provider,
                    model: newModelId,
                  } as RibosomeAdapterConfig,
                  reasoningEffort: getDefaultReasoningEffort(newModelId),
                }));
              }}
              style={inputStyle}
            >
              {providerOptions.map((provider) => (
                <option key={provider} value={provider}>
                  {provider}
                </option>
              ))}
            </select>
          </div>
          <div style={formFieldStyle}>
            <label htmlFor="model">Model</label>
            <select
              id="model"
              value={draft.adapterConfig?.model ?? currentModels[0].id}
              onChange={(event) => {
                const newModelId = event.target.value;
                setDraft((current) => ({
                  ...current,
                  adapterConfig: {
                    ...(current.adapterConfig ?? { adapter: currentProvider }),
                    model: newModelId,
                  } as RibosomeAdapterConfig,
                  reasoningEffort: getDefaultReasoningEffort(newModelId),
                }));
              }}
              style={inputStyle}
            >
              {currentModels.map((model) => (
                <option key={model.id} value={model.id}>
                  {model.label}
                </option>
              ))}
            </select>
          </div>
          {(() => {
            const reasoningOptions = getReasoningOptions(
              draft.adapterConfig?.model ?? currentModels[0].id,
            );
            if (!reasoningOptions) return null;
            return (
              <div style={formFieldStyle}>
                <label htmlFor="reasoningEffort">Reasoning effort</label>
                <select
                  id="reasoningEffort"
                  value={draft.reasoningEffort ?? getDefaultReasoningEffort(draft.adapterConfig?.model ?? currentModels[0].id) ?? ""}
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      reasoningEffort: event.target.value || undefined,
                    }))
                  }
                  style={inputStyle}
                >
                  {reasoningOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
            );
          })()}
          <label style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 16 }}>
            <input
              type="checkbox"
              checked={draft.persist}
              onChange={(event) => setDraft((current) => ({ ...current, persist: event.target.checked }))}
            />
            Store config in localStorage
          </label>
          <button type="button" onClick={submitConfig} style={buttonStyle}>
            Start Ribosome
          </button>
        </Panel>
      </main>
    );
  }

  return (
    <main style={{ padding: 16, fontFamily: "sans-serif", maxWidth: 980 }}>
      <h1>Ribosome Demo</h1>
      <Panel>
        <p>Provider: {activeProvider}</p>
        <p>Model: {activeModel}</p>
        <button type="button" onClick={resetConfig} style={buttonStyle}>
          Clear saved config and restart
        </button>
      </Panel>
      <Panel>
        <div ref={rootRef} id="ribosome-engine-root" />
      </Panel>
    </main>
  );
}
