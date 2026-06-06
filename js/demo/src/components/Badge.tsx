import { Chip } from "@heroui/react";

import type {
  RibosomeBadgeProps,
  RibosomeBadgeVariant,
} from "../../../dist/index.js";

type ChipColor = "default" | "accent" | "success" | "warning" | "danger";

// Ribosome badge variant -> HeroUI Chip `color`.
const colorMap: Record<RibosomeBadgeVariant, ChipColor> = {
  Neutral: "default",
  Success: "success",
  Warning: "warning",
  Error: "danger",
  Info: "accent",
};

export const Badge = ({ label, variant }: RibosomeBadgeProps) => (
  <Chip color={colorMap[variant] ?? "default"}>{label}</Chip>
);
