import { Alert } from "@heroui/react";

import type { RibosomeBrokenProps } from "../../../dist/index.js";

// The engine renders this for missing/partial components, passing { message }.
export const Broken = ({ message }: RibosomeBrokenProps) => (
  <Alert status="danger">
    <Alert.Indicator />
    <Alert.Content>
      <Alert.Title>Render error</Alert.Title>
      <Alert.Description>{message}</Alert.Description>
    </Alert.Content>
  </Alert>
);
