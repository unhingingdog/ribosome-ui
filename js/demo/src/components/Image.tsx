import type { RibosomeImageProps } from "../../../dist/index.js";

// HeroUI v3 has no dedicated image primitive (only Avatar), so this stays a
// native <img> styled with the Tailwind tokens HeroUI ships with.
export const Image = ({ id, src, alt }: RibosomeImageProps) => (
  <img id={id} src={src} alt={alt ?? ""} className="h-auto max-w-full rounded-lg" />
);
