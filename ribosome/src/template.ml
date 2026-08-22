module Input = Template_input
module Select = Template_select
module Button = Template_button
module Text = Template_text
module Image = Template_image
module Badge = Template_badge
module Stat = Template_stat
module Divider = Template_divider
module Container = Template_container
module List = Template_list
module Submittable = Template_submittable
module Tone = Template_tone
module Diagram = Template_diagram
module Code = Template_code
module Definition = Template_definition
module Registry = Template_registry
module Codec_error = Codec_error
module Decode = Codec_decode
module Encode = Codec_encode

type t =
  | Text of Template_text.t
  | Image of Template_image.t
  | Badge of Template_badge.t
  | Stat of Template_stat.t
  | Divider of Template_divider.t
  | Diagram of Template_diagram.t
  | Code of Template_code.t
  | Container of t Template_container.t
  | List of t Template_list.t
  | Submittable of Template_submittable.t

let id = function
  | Text t -> t.id
  | Image t -> t.id
  | Badge t -> t.id
  | Stat t -> t.id
  | Divider t -> t.id
  | Diagram t -> t.id
  | Code t -> t.id
  | Container t -> t.id
  | List t -> t.id
  | Submittable t -> t.id

let children = function
  | Container c -> Some c.children
  | List l -> Some l.children
  | _ -> None

let rec decode json =
  let open Codec_decode in
  let* kind = field "kind" string json in
  match kind with
  | "text" ->
      let* t = Text.decode json in
      Ok (Text t)
  | "image" ->
      let* t = Image.decode json in
      Ok (Image t)
  | "badge" ->
      let* t = Badge.decode json in
      Ok (Badge t)
  | "stat" ->
      let* t = Stat.decode json in
      Ok (Stat t)
  | "divider" ->
      let* t = Divider.decode json in
      Ok (Divider t)
  | "diagram" ->
      let* t = Diagram.decode json in
      Ok (Diagram t)
  | "code" ->
      let* t = Code.decode json in
      Ok (Code t)
  | "container" ->
      let* t = Container.decode_child decode json in
      Ok (Container t)
  | "list" ->
      let* t = List.decode decode json in
      Ok (List t)
  | "submittable" ->
      let* t = Submittable.decode json in
      Ok (Submittable t)
  | "input" | "select" | "button" ->
      Error
        (Codec_error.make [ Field "kind" ] InvalidValue
           ("kind '" ^ kind ^ "' is nested-only and cannot appear at root"))
  | _ ->
      Error
        (Codec_error.make [ Field "kind" ] UnknownEnum ("unknown kind: " ^ kind))

let rec encode = function
  | Text t -> Text.encode t
  | Image t -> Image.encode t
  | Badge t -> Badge.encode t
  | Stat t -> Stat.encode t
  | Divider t -> Divider.encode t
  | Diagram t -> Diagram.encode t
  | Code t -> Code.encode t
  | Container t -> Container.encode_child encode t
  | List t -> List.encode encode t
  | Submittable t -> Submittable.encode t

let decode_string s =
  match Yojson.Safe.from_string s with
  | json -> decode json
  | exception _ -> Error (Codec_error.make [] WrongType "invalid JSON string")

let encode_string t = Yojson.Safe.to_string (encode t)
