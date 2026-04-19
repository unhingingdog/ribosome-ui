import { defineConfig } from "vitest/config";
import { resolve } from "path";

export default defineConfig({
  resolve: {
    alias: {
      "melange-json": resolve(
        __dirname,
        "../_build/default/js/output/node_modules/melange-json",
      ),
    },
  },
  test: {},
});
