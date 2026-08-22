export interface AdapterConfig {
  serverUrl: string;
  mcpToolName: string;
}

export function createConfig(
  serverUrl: string,
  mcpToolName: string = "start",
): AdapterConfig {
  return { serverUrl, mcpToolName };
}
