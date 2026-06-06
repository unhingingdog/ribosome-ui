import { Label, ListBox, Select as HeroSelect } from "@heroui/react";

import type { RibosomeSelectProps } from "../../../dist/index.js";

// HeroUI Select is a compound React Aria component. `name` makes it participate
// in native form submission, and the selected ListBox.Item `id` is the value.
export const Select = ({ id, label, options, selected }: RibosomeSelectProps) => (
  <HeroSelect
    id={id}
    name={id}
    defaultValue={selected ?? null}
    placeholder="Select..."
  >
    <Label>{label}</Label>
    <HeroSelect.Trigger>
      <HeroSelect.Value />
      <HeroSelect.Indicator />
    </HeroSelect.Trigger>
    <HeroSelect.Popover>
      <ListBox>
        {options.map((option) => (
          <ListBox.Item key={option.value} id={option.value} textValue={option.label}>
            {option.label}
          </ListBox.Item>
        ))}
      </ListBox>
    </HeroSelect.Popover>
  </HeroSelect>
);
