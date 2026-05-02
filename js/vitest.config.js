import { defineConfig } from "vitest/config";
import { resolve } from "path";

const buildOutput = resolve(__dirname, "../_build/default/js/output/node_modules");

export default defineConfig({
  resolve: {
    alias: {
      "melange-json": resolve(buildOutput, "melange-json"),
      "melange.js": resolve(buildOutput, "melange.js"),
      "melange": resolve(buildOutput, "melange"),
      "melange.__private__.melange_mini_stdlib": resolve(buildOutput, "melange.__private__.melange_mini_stdlib"),
    },
  },
  test: {
    server: {
      deps: {
        inline: ["melange", "melange-json", "melange.js"],
      },
    },
  },
});
