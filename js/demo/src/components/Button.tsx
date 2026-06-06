import { Button as HeroButton } from "@heroui/react";

import type { RibosomeButtonProps } from "../../../dist/index.js";

const navigatePrefix = "Navigate:";

export const Button = ({ id, label, action, disabled }: RibosomeButtonProps) => (
  <HeroButton
    id={id}
    // HeroUI/React Aria buttons use `type` for native form behaviour.
    type={action === "Submit" ? "submit" : "button"}
    isDisabled={disabled}
    // React Aria exposes `onPress` rather than `onClick`.
    onPress={() => {
      if (typeof action === "string" && action.startsWith(navigatePrefix)) {
        window.location.href = action.slice(navigatePrefix.length);
      }
    }}
  >
    {label}
  </HeroButton>
);
