open Melange_json.Primitives

type t = {
  kind: string;
  id: string;
  value: Input.t list;
} [@@deriving json]
