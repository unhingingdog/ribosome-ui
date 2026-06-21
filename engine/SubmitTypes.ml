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

(* 
  TREE Parser
  1. walk, tree, and serialise using existing serialise functions.
  2. if you encounter the input node that matches the one of the lists in the input
  then include the user response 
*)

let serialise_tree_state (_template: Types.template) (_input: submitted_input list) =
  (* TODO: implement recursive tree walk with value injection *)
  Js.Json.string "TODO"
