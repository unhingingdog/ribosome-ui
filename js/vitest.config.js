import { defineConfig } from "vitest/config";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const melangeModules = resolve(__dirname, "output/node_modules");

export default defineConfig({
  resolve: {
    alias: {
      "melange.js": resolve(melangeModules, "melange.js"),
      melange: resolve(melangeModules, "melange"),
      "melange-json": resolve(melangeModules, "melange-json"),
      "melange.__private__.melange_mini_stdlib": resolve(
        melangeModules,
        "melange.__private__.melange_mini_stdlib",
      ),
      "melange-fetch": resolve(melangeModules, "melange-fetch"),
    },
  },
  test: {
    server: {
      deps: {
        inline: ["melange", "melange-json", "melange.js", "melange-fetch"],
      },
    },
  },
});
