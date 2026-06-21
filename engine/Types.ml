type field_type = TemplateDefinitionTypes.field_type = StringField | NumberField | BoolField | ArrayField | TemplateList | InputList

type field_def = TemplateDefinitionTypes.field_def = {
  name: string;
  field_type: field_type;
  required: bool;
  instructions: string;
}

type template_definition = TemplateDefinitionTypes.template_definition = {
  kind: string;
  intent: string;
  instructions: string;
  fields: field_def list;
}

type input_value = Templates.Input.input_value = Int of int | String of string

let deserialise_input_value = Templates.Input.deserialise_input_value
let serialise_input_value = Templates.Input.serialise_input_value

type input = Templates.Input.t = {
  kind: string;
  id: string;
  value: input_value option
}

let deserialise_input = Templates.Input.deserialise
let serialise_input = Templates.Input.serialise

type submittable_field = Templates.Submittable.field =
  | FieldInput of input
  | FieldSelect of Templates.Select.t

let deserialise_submittable_field = Templates.Submittable.deserialise_field
let serialise_submittable_field = Templates.Submittable.serialise_field

type submittable = Templates.Submittable.t = {
  kind: string;
  id: string;
  value: submittable_field list;
}

let deserialise_submittable = Templates.Submittable.deserialise
let serialise_submittable = Templates.Submittable.serialise

type image = Templates.Image.t = {
  kind: string;
  id: string;
  src: string;
  alt: string;
}

let deserialise_image = Templates.Image.deserialise
let serialise_image = Templates.Image.serialise

type text_type = Templates.Text.text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6

let text_type_of_string = Templates.Text.text_type_of_string
let string_of_text_type = Templates.Text.string_of_text_type
let deserialise_text_type = Templates.Text.deserialise_text_type
let serialise_text_type = Templates.Text.serialise_text_type

type text = Templates.Text.t = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

let deserialise_text = Templates.Text.deserialise
let serialise_text = Templates.Text.serialise

type broken = Templates.Broken.t =
  | Soft  of string
  | Hard of string

let deserialise_broken = Templates.Broken.deserialise
let serialise_broken = Templates.Broken.serialise

type button_action = Templates.Button.action =
  | Navigate of string
  | Submit
  | Custom of string

let deserialise_button_action = Templates.Button.deserialise_action

type button = Templates.Button.t = {
  kind: string;
  id: string;
  label: string;
  action: button_action;
  disabled: bool option;
}

let deserialise_button = Templates.Button.deserialise

type select_option = Templates.Select.option_ = {
  value: string;
  label: string;
}

type select = Templates.Select.t = {
  kind: string;
  id: string;
  label: string;
  options: select_option list;
  selected: string option;
}

let deserialise_select = Templates.Select.deserialise

type badge_variant = Templates.Badge.badge_variant = Neutral | Success | Warning | Error | Info

let badge_variant_of_string = Templates.Badge.badge_variant_of_string
let deserialise_badge_variant = Templates.Badge.deserialise_badge_variant

type badge = Templates.Badge.t = {
  kind: string;
  id: string;
  label: string;
  variant: badge_variant;
}

let deserialise_badge = Templates.Badge.deserialise

type stat = Templates.Stat.t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

let deserialise_stat = Templates.Stat.deserialise

type divider = Templates.Divider.t = {
  kind: string;
  id: string;
  label: string option;
}

let deserialise_divider = Templates.Divider.deserialise

type container = template Templates.Container.t and template_list = template Templates.List.t and template =
  | Input of input
  | Submittable of submittable
  | Image of image
  | Text of text 
  | Container of container 
  | Broken of broken
  | Button of button
  | Select of select
  | Badge of badge
  | List of template_list
  | Stat of stat
  | Divider of divider

let deserialise_container = Templates.Container.deserialise
let deserialise_template_list = Templates.List.deserialise
