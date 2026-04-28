import { resolve } from "path";
import { readdirSync, existsSync } from "fs";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Dynamically discover all .js files in output directories
const getEntryPoints = () => {
  const points = {};
  const dirs = ["src", "telomere"];
  
  dirs.forEach(dir => {
    const dirPath = resolve(__dirname, "output", dir);
    
    if (existsSync(dirPath)) {
      try {
        readdirSync(dirPath)
          .filter(f => f.endsWith(".js"))
          .forEach(f => {
            const name = f.replace(".js", "");
            points[name] = resolve(dirPath, f);
          });
      } catch (e) {
        console.warn(`Warning: Could not read directory ${dirPath}:`, e.message);
      }
    }
  });
  
  return points;
};

export default {
  input: getEntryPoints(),
  output: {
    dir: "dist",
    format: "esm"
  }
};
