import { defineConfig } from "vite";
import solid from "vite-plugin-solid";

export default defineConfig({
  plugins: [solid()],
  build: {
    target: "esnext",
  },
  server: {
    proxy: {
      "/v1": "http://127.0.0.1:8787",
      "/health": "http://127.0.0.1:8787",
    },
  },
});
