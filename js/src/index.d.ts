import type * as React from "react";

export type RibosomeAdapter = "openai";

export type RibosomeOpenAIModel =
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

export type RibosomeInputProps = {
  id: string;
  value: unknown;
};

export type RibosomeTextProps = {
  text_type: unknown;
  content: string;
};

export type RibosomeImageProps = {
  src: string;
  alt?: string;
};

export type RibosomeContainerProps = {
  children?: React.ReactNode;
  [key: string]: unknown;
};

export type RibosomeSubmittableProps = {
  id: string;
  kind: string;
  value: unknown;
  on_submit: (payload: unknown) => void;
};

export type RibosomeComponents = {
  /** Components are the public template-selection surface. Ribosome renders these and owns their submit lifecycle. */
  container: React.ComponentType<RibosomeContainerProps>;
  broken: React.ComponentType<string>;
  input?: React.ComponentType<RibosomeInputProps>;
  submittable?: React.ComponentType<RibosomeSubmittableProps>;
  image?: React.ComponentType<RibosomeImageProps>;
  text?: React.ComponentType<RibosomeTextProps>;
};

export type RibosomeCallbacks = {
  on_error?: (message: string) => void;
  on_submit?: (payload: unknown) => void;
  on_message_complete?: (template: unknown) => void;
};

export type RibosomeConfig = {
  root: Element | string;
  goalPrompt: string;
  url: string;
  headers?: RibosomeHeaders;
  components: RibosomeComponents;
  callbacks?: RibosomeCallbacks;
} & { adapterConfig?: RibosomeAdapterConfig };

export type RibosomeEngine = {
  reset(): void;
};

export declare function createEngine(config: RibosomeConfig): RibosomeEngine;
export default createEngine;
