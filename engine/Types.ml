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

type input = Templates.Input.t = {
  kind: string;
  id: string;
  value: input_value option
}

type submittable_field = Templates.Submittable.field =
  | FieldInput of input
  | FieldSelect of Templates.Select.t

type submittable = Templates.Submittable.t = {
  kind: string;
  id: string;
  value: submittable_field list;
}

type image = Templates.Image.t = {
  kind: string;
  id: string;
  src: string;
  alt: string;
}

type text_type = Templates.Text.text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6

let text_type_of_string = Templates.Text.text_type_of_string
let string_of_text_type = Templates.Text.string_of_text_type

type text = Templates.Text.t = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
}

type broken = Templates.Broken.t =
  | Soft  of string
  | Hard of string

type button_action = Templates.Button.action =
  | Navigate of string
  | Submit
  | Custom of string

type button = Templates.Button.t = {
  kind: string;
  id: string;
  label: string;
  action: button_action;
  disabled: bool option;
}

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

type badge_variant = Templates.Badge.badge_variant = Neutral | Success | Warning | Error | Info

let badge_variant_of_string = Templates.Badge.badge_variant_of_string

type badge = Templates.Badge.t = {
  kind: string;
  id: string;
  label: string;
  variant: badge_variant;
}

type stat = Templates.Stat.t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

type divider = Templates.Divider.t = {
  kind: string;
  id: string;
  label: string option;
}

type container = template Templates.Container.t and template_list = template Templates.List.t and template =
  | Submittable of submittable
  | Image of image
  | Text of text 
  | Container of container 
  | Broken of broken
  | Button of button
  | Badge of badge
  | List of template_list
  | Stat of stat
  | Divider of divider
