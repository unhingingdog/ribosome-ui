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
