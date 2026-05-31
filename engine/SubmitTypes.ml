open Melange_json.Primitives

type submitted_value = SubmittedInt of int | SubmittedString of string [@@deriving json]
type submitted_input = {
  id: string;
  value: submitted_value;
} [@@deriving json]

type submission_payload = {
  template_id: string;
  values: submitted_input list;
} [@@deriving json]

