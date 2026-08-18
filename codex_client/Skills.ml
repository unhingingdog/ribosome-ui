type skill = {
  name: string;
  description: string;
  path: string;
  enabled: bool;
}

type phase =
  | Not_started
  | Setting_extra_roots of {
      id: Codex_protocol.JsonRpc.request_id;
      root: string;
      cwd: string;
    }
  | Listing of Codex_protocol.JsonRpc.request_id
  | Ready of skill

type error =
  | Already_started
  | Unexpected_event
  | Server_error of Codex_protocol.JsonRpc.error
  | Invalid_response of string
  | Missing_ribosome_skill
  | Ribosome_skill_disabled

type outcome =
  | Requested of Client.command
  | Skill_ready of skill

let ( let* ) = Result.bind

let extra_roots_params root =
  `Assoc [("extraRoots", `List [`String root])]

let list_params cwd =
  `Assoc [
    ("cwds", `List [`String cwd]);
    ("forceReload", `Bool true);
  ]

let start phase client root cwd =
  match phase with
  | Not_started ->
    let request, command, client = Client.request client "skills/extraRoots/set"
      (Some (extra_roots_params root)) in
    Ok (Requested command, client, Setting_extra_roots { id = request.id; root; cwd })
  | Setting_extra_roots _ | Listing _ | Ready _ -> Error Already_started

let required_string name fields =
  match Stdlib.List.assoc_opt name fields with
  | Some (`String value) -> Ok value
  | Some _ -> Error (Invalid_response ("expected string: " ^ name))
  | None -> Error (Invalid_response ("missing field: " ^ name))

let required_bool name fields =
  match Stdlib.List.assoc_opt name fields with
  | Some (`Bool value) -> Ok value
  | Some _ -> Error (Invalid_response ("expected boolean: " ^ name))
  | None -> Error (Invalid_response ("missing field: " ^ name))

let decode_skill = function
  | `Assoc fields ->
    let* name = required_string "name" fields in
    let* description = required_string "description" fields in
    let* path = required_string "path" fields in
    let* enabled = required_bool "enabled" fields in
    Ok { name; description; path; enabled }
  | _ -> Error (Invalid_response "expected skill object")

let decode_skills = function
  | `Assoc fields ->
    (match Stdlib.List.assoc_opt "data" fields with
     | Some (`List entries) ->
       let rec decode_entries skills = function
         | [] -> Ok skills
         | `Assoc entry :: remaining ->
           (match Stdlib.List.assoc_opt "skills" entry with
            | Some (`List metadata) ->
              let rec decode_metadata skills = function
                | [] -> decode_entries skills remaining
                | metadata :: remaining_metadata ->
                  let* skill = decode_skill metadata in
                  decode_metadata (skill :: skills) remaining_metadata
              in
              decode_metadata skills metadata
            | Some _ -> Error (Invalid_response "expected skills array")
            | None -> Error (Invalid_response "missing field: skills"))
         | _ :: _ -> Error (Invalid_response "expected skills list entry")
       in
       decode_entries [] entries
     | Some _ -> Error (Invalid_response "expected data array")
     | None -> Error (Invalid_response "missing field: data"))
  | _ -> Error (Invalid_response "expected skills response object")

let ribosome_skill skills =
  match Stdlib.List.find_opt (fun skill -> skill.name = "ribosome") skills with
  | Some ({ enabled = true; _ } as skill) -> Ok skill
  | Some { enabled = false; _ } -> Error Ribosome_skill_disabled
  | None -> Error Missing_ribosome_skill

let receive phase client event =
  match phase, event with
  | Setting_extra_roots { id; cwd; _ }, Client.Response { request; result = Ok _ }
    when request.id = id && request.method_ = "skills/extraRoots/set" ->
    let request, command, client = Client.request client "skills/list" (Some (list_params cwd)) in
    Ok (Requested command, client, Listing request.id)
  | Setting_extra_roots { id; _ }, Client.Response { request; result = Error error }
    when request.id = id && request.method_ = "skills/extraRoots/set" -> Error (Server_error error)
  | Listing id, Client.Response { request; result = Ok result }
    when request.id = id && request.method_ = "skills/list" ->
    let* skills = decode_skills result in
    let* skill = ribosome_skill skills in
    Ok (Skill_ready skill, client, Ready skill)
  | Listing id, Client.Response { request; result = Error error }
    when request.id = id && request.method_ = "skills/list" -> Error (Server_error error)
  | Not_started, _ | Setting_extra_roots _, _ | Listing _, _ | Ready _, _ -> Error Unexpected_event
