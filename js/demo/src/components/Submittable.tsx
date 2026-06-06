import { Button, Form, Input, Label, TextField } from "@heroui/react";

import type { RibosomeSubmittableProps } from "../../../dist/index.js";
import { Select } from "./Select";

export const Submittable = ({ id, value, on_submit }: RibosomeSubmittableProps) => (
  <Form
    id={id}
    className="flex flex-col gap-4"
    onSubmit={(event) => {
      event.preventDefault();
      const formData = new FormData(event.currentTarget);

      const payload = {
        templateId: id,
        values: value.map((field) => ({
          id: field.id,
          value:
            (formData.get(field.id) as string | null) ??
            (field.kind === "select" ? field.selected ?? "" : field.value),
        })),
      };

      on_submit(payload);
    }}
  >
    {value.map((field) =>
      field.kind === "select" ? (
        <Select key={field.id} {...field} />
      ) : (
        // TextField wires the label + name onto its child Input so the value
        // shows up in FormData under `field.id`.
        <TextField key={field.id} name={field.id} defaultValue={String(field.value ?? "")}>
          <Label>{field.id}</Label>
          <Input />
        </TextField>
      ),
    )}
    <Button type="submit">Submit</Button>
  </Form>
);
