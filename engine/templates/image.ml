open Melange_json.Primitives

type t = {
  kind: string;
  id: string;
  src: string;
  alt: string;
} [@@deriving json]
