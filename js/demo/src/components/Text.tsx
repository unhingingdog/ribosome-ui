import { Typography } from "@heroui/react";

import type { RibosomeTextProps, RibosomeTextType } from "../../../dist/index.js";

type TypographyType =
  | "h1"
  | "h2"
  | "h3"
  | "h4"
  | "h5"
  | "h6"
  | "body"
  | "body-sm"
  | "body-xs"
  | "code";

// Ribosome text_type -> HeroUI Typography `type`.
const typeMap: Record<RibosomeTextType, TypographyType> = {
  H1: "h1",
  H2: "h2",
  H3: "h3",
  H4: "h4",
  H5: "h5",
  H6: "h6",
  Paragraph: "body",
};

export const Text = ({ text_type, value }: RibosomeTextProps) => (
  <Typography type={typeMap[text_type] ?? "body"}>{value}</Typography>
);
