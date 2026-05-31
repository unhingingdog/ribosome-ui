import { createEngineAdapter } from "./internal/engineAdapter.js";

export function createEngine(config) {
  return createEngineAdapter(config);
}

export default createEngine;
