import { Separator, Typography } from "@heroui/react";

import type { RibosomeDividerProps } from "../../../dist/index.js";

export const Divider = ({ label }: RibosomeDividerProps) => {
  if (!label) {
    return <Separator className="my-3" />;
  }

  // HeroUI Separator has no label slot, so compose a labelled divider.
  return (
    <div className="my-3 flex items-center gap-3">
      <Separator className="flex-1" />
      <Typography type="body-sm" color="muted">
        {label}
      </Typography>
      <Separator className="flex-1" />
    </div>
  );
};
