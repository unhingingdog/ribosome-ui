import React, { useEffect, useMemo, useRef, useState } from "react";

import createEngine, {
  type RibosomeConfig,
  type RibosomeAdapterConfig,
  type RibosomeAsset,
  type RibosomeContainerProps,
  type RibosomeImageProps,
  type RibosomeInputProps,
  type RibosomeSubmittableProps,
  type RibosomeTextProps,
} from "../../dist/index.js";

const storageKey = "ribosome-ui:demo";

type DemoSettings = {
  goalPrompt: string;
  url: string;
  headers: Record<string, string>;
  assets: RibosomeAsset[];
  adapterConfig?: {
    adapter: "openai";
    model?: RibosomeAdapterConfig["model"];
  };
};

type DemoDraft = DemoSettings & {
  persist: boolean;
};

const defaultSettings: DemoSettings = {
  goalPrompt: "Create a small UI that asks the user for a name and greets them.",
  url: "https://api.openai.com/v1/chat/completions",
  headers: {
    Authorization: "Bearer YOUR_OPENAI_API_KEY",
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
    adapter: "openai",
    model: "gpt-4o-mini",
  },
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

const Container = ({ id, children }: RibosomeContainerProps) => (
  <div id={id} data-kind="container">
    {children}
  </div>
);

const Broken = (props: unknown) => {
  const message =
    typeof props === "string"
      ? props
      : Object.values((props as Record<string, unknown>) ?? {}).join("");

  return <pre data-kind="broken">{message}</pre>;
};

const Input = ({ id, value }: RibosomeInputProps) => (
  <input id={id} name={id} defaultValue={String(value ?? "")} />
);

const Submittable = ({ id, value, on_submit }: RibosomeSubmittableProps) => (
  <form
    id={id}
    onSubmit={(event) => {
      event.preventDefault();
      const formData = new FormData(event.currentTarget);
      on_submit({
        templateId: id,
        values: value.map((input) => ({
          id: input.id,
          value: formData.get(input.id) ?? input.value,
        })),
      });
    }}
  >
    {value.map((input) => (
      <div key={input.id}>
        <label htmlFor={input.id}>{input.id}</label>
        <Input {...input} />
      </div>
    ))}
    <button type="submit">Submit</button>
  </form>
);

const Image = ({ src, alt }: RibosomeImageProps) => <img src={src} alt={alt} />;

const Text = ({ text_type, value }: RibosomeTextProps) => {
  if (text_type === "H1") return <h1>{value}</h1>;
  if (text_type === "H2") return <h2>{value}</h2>;
  if (text_type === "H3") return <h3>{value}</h3>;
  if (text_type === "H4") return <h4>{value}</h4>;
  if (text_type === "H5") return <h5>{value}</h5>;
  if (text_type === "H6") return <h6>{value}</h6>;

  return <p>{value}</p>;
};

const components = {
  container: Container,
  broken: Broken,
  input: Input,
  submittable: Submittable,
  image: Image,
  text: Text,
} satisfies Required<RibosomeConfig["components"]>;

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

    engineRef.current = createEngine({
      root: rootRef.current,
      goalPrompt: activeConfig.goalPrompt,
      url: activeConfig.url,
      headers: activeConfig.headers,
      assets: activeConfig.assets,
      components,
      adapterConfig: activeConfig.adapterConfig,
    });

    return () => {
      engineRef.current?.reset();
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
    };

    if (draft.persist) {
      saveSettings(nextConfig);
    } else {
      clearSettings();
    }

    setActiveConfig(nextConfig);
  };

  const resetConfig = () => {
    clearSettings();
    window.location.reload();
  };

  const configSummary = useMemo(() => {
    if (!activeConfig) return null;

    return [
      activeConfig.goalPrompt,
      activeConfig.url,
      activeConfig.headers.Authorization,
      activeConfig.assets.map((asset) => asset.id).join(", "),
      activeConfig.adapterConfig?.model ?? "",
    ].filter(Boolean);
  }, [activeConfig]);

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
            <label htmlFor="url">OpenAI URL</label>
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
            <label htmlFor="model">Model</label>
            <input
              id="model"
              value={draft.adapterConfig?.model ?? ""}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  adapterConfig: {
                    adapter: "openai",
                    model: event.target.value || undefined,
                  },
                }))
              }
              style={inputStyle}
            />
          </div>
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
        <p>Loaded config: {configSummary?.join(" | ")}</p>
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
