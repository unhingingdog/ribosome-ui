import { Card, Typography } from "@heroui/react";

import type { RibosomeStatProps } from "../../../dist/index.js";

export const Stat = ({ id, label, value, secondary }: RibosomeStatProps) => (
  <Card id={id} variant="secondary">
    <Card.Header>
      <Card.Description>{label}</Card.Description>
      <Card.Title>{value}</Card.Title>
    </Card.Header>
    {secondary && (
      <Card.Content>
        <Typography type="body-sm" color="muted">
          {secondary}
        </Typography>
      </Card.Content>
    )}
  </Card>
);
