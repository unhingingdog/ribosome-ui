import { Input as HeroInput } from "@heroui/react";

import type { RibosomeInputProps } from "../../../dist/index.js";

// HeroUI `Input` accepts native input attributes, so `name`/`defaultValue`
// keep it working with the FormData-based submit flow.
export const Input = ({ id, value }: RibosomeInputProps) => (
  <HeroInput id={id} name={id} defaultValue={String(value ?? "")} />
);
