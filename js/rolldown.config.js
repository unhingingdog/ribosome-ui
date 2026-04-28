import { existsSync, readdirSync } from "fs";
import { dirname, join, relative, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputDir = resolve(__dirname, "output");
const moduleDirs = ["engine", "telomere"];

const collectJsFiles = (dir) => {
  if (!existsSync(dir)) return [];

  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);

    if (entry.isDirectory()) {
      return collectJsFiles(path);
    }

    return entry.isFile() && entry.name.endsWith(".js") ? [path] : [];
  });
};

const input = moduleDirs.flatMap((dir) => collectJsFiles(resolve(outputDir, dir)));

if (input.length === 0) {
  throw new Error(
    `No Melange output found under ${moduleDirs
      .map((dir) => relative(__dirname, resolve(outputDir, dir)))
      .join(" or ")}. Run npm run build:ocaml first.`,
  );
}

export default {
  input,
  output: {
    dir: "dist",
    entryFileNames: "[name].js",
    format: "esm",
    preserveModules: true,
    preserveModulesRoot: "output",
  },
};
