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

val id : t -> string
val children : t -> t list option
