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

let input_value_of_json = Templates.Input.input_value_of_json
let input_value_to_json = Templates.Input.input_value_to_json

type input = Templates.Input.t = {
  kind: string;
  id: string;
  value: input_value
}

let input_of_json = Templates.Input.of_json
let input_to_json = Templates.Input.to_json

type submittable_field = Templates.Submittable.field =
  | FieldInput of input
  | FieldSelect of Templates.Select.t

let submittable_field_of_json = Templates.Submittable.field_of_json
let submittable_field_to_json = Templates.Submittable.field_to_json

type submittable = Templates.Submittable.t = {
  kind: string;
  id: string;
  value: submittable_field list;
}

let submittable_of_json = Templates.Submittable.of_json
let submittable_to_json = Templates.Submittable.to_json

type image = Templates.Image.t = {
  kind: string;
  id: string;
  src: string;
  alt: string;
}

let image_of_json = Templates.Image.of_json
let image_to_json = Templates.Image.to_json

type text_type = Templates.Text.text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6

let text_type_of_string = Templates.Text.text_type_of_string
let string_of_text_type = Templates.Text.string_of_text_type
let text_type_of_json = Templates.Text.text_type_of_json
let text_type_to_json = Templates.Text.text_type_to_json

type text = Templates.Text.t = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

let text_of_json = Templates.Text.of_json
let text_to_json = Templates.Text.to_json

type broken = Templates.Broken.t =
  | Soft  of string
  | Hard of string

let broken_of_json = Templates.Broken.of_json
let broken_to_json = Templates.Broken.to_json

type button_action = Templates.Button.action =
  | Navigate of string
  | Submit
  | Custom of string

let button_action_of_json = Templates.Button.action_of_json

type button = Templates.Button.t = {
  kind: string;
  id: string;
  label: string;
  action: button_action;
  disabled: bool option;
}

let button_of_json = Templates.Button.of_json

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

let select_of_json = Templates.Select.of_json

type badge_variant = Templates.Badge.badge_variant = Neutral | Success | Warning | Error | Info

let badge_variant_of_string = Templates.Badge.badge_variant_of_string
let badge_variant_of_json = Templates.Badge.badge_variant_of_json

type badge = Templates.Badge.t = {
  kind: string;
  id: string;
  label: string;
  variant: badge_variant;
}

let badge_of_json = Templates.Badge.of_json

type stat = Templates.Stat.t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

let stat_of_json = Templates.Stat.of_json

type divider = Templates.Divider.t = {
  kind: string;
  id: string;
  label: string option;
}

let divider_of_json = Templates.Divider.of_json

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

let container_of_json = Templates.Container.of_json
let template_list_of_json = Templates.List.of_json
