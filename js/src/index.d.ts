import type * as React from "react";

export type RibosomeAdapter = "openai";

export type RibosomeOpenAIModel =
  | "gpt-5.5"
  | "gpt-5.5-pro"
  | "gpt-5.4-mini"
  | "gpt-5.4-nano"
  | "gpt-5"
  | "gpt-5-mini"
  | "gpt-5-nano"
  | "gpt-4o"
  | "gpt-4o-mini"
  | "gpt-4.1"
  | "gpt-4.1-mini"
  | "o3"
  | "o4-mini";

export type RibosomeAdapterConfig = {
  adapter: "openai";
  model?: RibosomeOpenAIModel;
};

export type RibosomeHeaders =
  | Record<string, string>
  | Array<[string, string]>
  | Headers;

export type RibosomeInputValue = string | number;

export type RibosomeTextType = "Paragraph" | "H1" | "H2" | "H3" | "H4" | "H5" | "H6";
export type RibosomeButtonAction = "Submit" | `Navigate:${string}` | string;
export type RibosomeBadgeVariant = "Neutral" | "Success" | "Warning" | "Error" | "Info";

export type RibosomeInputProps = {
  kind: "input";
  id: string;
  value: RibosomeInputValue;
};

export type RibosomeTextProps = {
  kind: "text";
  id: string;
  text_type: RibosomeTextType;
  value: string;
};

export type RibosomeImageProps = {
  kind: "image";
  id: string;
  src: string;
  alt?: string;
};

export type RibosomeContainerProps = {
  kind: "container";
  id: string;
  children?: React.ReactNode;
  [key: string]: unknown;
};

export type RibosomeButtonProps = {
  kind: "button";
  id: string;
  label: string;
  action: RibosomeButtonAction;
  disabled?: boolean;
};

export type RibosomeSelectOption = {
  value: string;
  label: string;
};

export type RibosomeSelectProps = {
  kind: "select";
  id: string;
  label: string;
  options: RibosomeSelectOption[];
  selected?: string;
};

export type RibosomeBadgeProps = {
  kind: "badge";
  id: string;
  label: string;
  variant: RibosomeBadgeVariant;
};

export type RibosomeListProps = {
  kind: "list";
  id: string;
  ordered?: boolean;
  children?: React.ReactNode;
  [key: string]: unknown;
};

export type RibosomeStatProps = {
  kind: "stat";
  id: string;
  label: string;
  value: string;
  secondary?: string;
};

export type RibosomeDividerProps = {
  kind: "divider";
  id: string;
  label?: string;
};

export type RibosomeSubmittableProps = {
  id: string;
  kind: "submittable";
  value: RibosomeInputProps[];
  on_submit: (payload: RibosomeSubmissionPayload) => void;
};

export type RibosomeSubmissionPayload = {
  templateId: string;
  values: Array<{
    id: string;
    value: RibosomeInputValue;
  }>;
};

export type RibosomeComponents = {
  /** Components are the public template-selection surface; template instructions are built in. */
  container: React.ComponentType<RibosomeContainerProps>;
  broken: React.ComponentType<string>;
  input?: React.ComponentType<RibosomeInputProps>;
  submittable?: React.ComponentType<RibosomeSubmittableProps>;
  image?: React.ComponentType<RibosomeImageProps>;
  text?: React.ComponentType<RibosomeTextProps>;
  button?: React.ComponentType<RibosomeButtonProps>;
  select?: React.ComponentType<RibosomeSelectProps>;
  badge?: React.ComponentType<RibosomeBadgeProps>;
  list?: React.ComponentType<RibosomeListProps>;
  stat?: React.ComponentType<RibosomeStatProps>;
  divider?: React.ComponentType<RibosomeDividerProps>;
};

export type RibosomeCallbacks = {
  on_error?: (message: string) => void;
  on_submit?: (payload: unknown) => void;
  on_message_complete?: (template: unknown) => void;
};

export type RibosomeAsset = {
  id: string;
  url: string;
  description?: string;
};

export type RibosomeConfig = {
  root: Element | string;
  goalPrompt: string;
  url: string;
  headers?: RibosomeHeaders;
  components: RibosomeComponents;
  assets?: RibosomeAsset[];
  callbacks?: RibosomeCallbacks;
} & { adapterConfig?: RibosomeAdapterConfig };

export type RibosomeEngine = {
  reset(): void;
};

export declare function createEngine(config: RibosomeConfig): RibosomeEngine;
export default createEngine;
