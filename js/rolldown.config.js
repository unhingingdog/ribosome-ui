import { dirname, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const melangeModules = resolve(__dirname, "output/node_modules");

export default {
  input: resolve(__dirname, "src/index.js"),
  output: {
    dir: "dist",
    entryFileNames: "[name].js",
    format: "esm",
    preserveModules: true,
    preserveModulesRoot: "src",
  },
  resolve: {
    alias: {
      "melange.js": resolve(melangeModules, "melange.js"),
      melange: resolve(melangeModules, "melange"),
      "melange-json": resolve(melangeModules, "melange-json"),
      "melange-fetch": resolve(melangeModules, "melange-fetch"),
      "melange.__private__.melange_mini_stdlib": resolve(
        melangeModules,
        "melange.__private__.melange_mini_stdlib",
      ),
    },
  },
  external: ["react", "react-dom", "react-dom/client"],
};
