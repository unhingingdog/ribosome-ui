import type { RibosomeConfig } from "../../../dist/index.js";

import { Badge } from "./Badge";
import { Broken } from "./Broken";
import { Button } from "./Button";
import { Container } from "./Container";
import { Divider } from "./Divider";
import { Image } from "./Image";
import { Input } from "./Input";
import { List } from "./List";
import { Select } from "./Select";
import { Stat } from "./Stat";
import { Submittable } from "./Submittable";
import { Text } from "./Text";

// HeroUI-backed component registry handed to the Ribosome engine.
export const components = {
  container: Container,
  broken: Broken,
  input: Input,
  submittable: Submittable,
  image: Image,
  text: Text,
  button: Button,
  select: Select,
  badge: Badge,
  list: List,
  stat: Stat,
  divider: Divider,
} satisfies Required<RibosomeConfig["components"]>;
