open Melange_json.Primitives

type t =
  | Soft  of string
  | Hard of string [@@deriving json]
