import { Card } from "@heroui/react";

import type { RibosomeContainerProps } from "../../../dist/index.js";

export const Container = ({ id, children }: RibosomeContainerProps) => (
  <Card id={id} data-kind="container">
    <Card.Content className="flex flex-col gap-3">{children}</Card.Content>
  </Card>
);
