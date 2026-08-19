type field_type = Templates.TemplateDefinitionTypes.field_type = StringField | NumberField | BoolField | ArrayField | TemplateList | InputList

type field_def = Templates.TemplateDefinitionTypes.field_def = {
  name: string;
  field_type: field_type;
  required: bool;
  instructions: string;
}

type template_definition = Templates.TemplateDefinitionTypes.template_definition = {
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

and button_action = Templates.Button.action =
  | Navigate of string
  | Submit
  | Custom of string

and button = Templates.Button.t = {
  kind: string;
  id: string;
  label: string;
  action: button_action;
  disabled: bool option;
}

and select_option = Templates.Select.option_ = {
  value: string;
  label: string;
}

and select = Templates.Select.t = {
  kind: string;
  id: string;
  label: string;
  options: select_option list;
  selected: string option;
}

and badge_variant = Templates.Badge.badge_variant = Neutral | Success | Warning | Error | Info

and badge = Templates.Badge.t = {
  kind: string;
  id: string;
  label: string;
  variant: badge_variant;
}

and stat = Templates.Stat.t = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option;
}

and divider = Templates.Divider.t = {
  kind: string;
  id: string;
  label: string option;
}

and diagram_size = Templates.Diagram.size = Compact | Regular | Tall

and diagram_tone = Templates.Diagram.tone = Primary | Secondary | Success | Warning | Danger | Muted

and diagram_point = Templates.Diagram.point = { x: int; y: int }

and diagram_primitive = Templates.Diagram.primitive =
  | Text of { id: string; at: diagram_point; value: string; tone: diagram_tone }
  | Line of { id: string; from_: diagram_point; to_: diagram_point; tone: diagram_tone }
  | Arrow of { id: string; from_: diagram_point; to_: diagram_point; tone: diagram_tone }
  | Rectangle of { id: string; at: diagram_point; width: int; height: int; tone: diagram_tone }
  | Circle of { id: string; at: diagram_point; radius: int; tone: diagram_tone }
  | Polyline of { id: string; points: diagram_point * diagram_point list; tone: diagram_tone }

and diagram = Templates.Diagram.t = {
  kind: string;
  id: string;
  title: string;
  size: diagram_size;
  primitives: diagram_primitive list;
}

and code_tone = Templates.Code.tone = Primary | Secondary | Success | Warning | Danger | Muted

and code_highlight = Templates.Code.highlight = {
  id: string;
  start_line: int;
  end_line: int;
  label: string;
  tone: code_tone;
}

and code = Templates.Code.t = {
  kind: string;
  id: string;
  path: string;
  language: string;
  line_start: int;
  source: string;
  highlights: code_highlight list;
}

and container = template Templates.Container.t and template_list = template Templates.List.t and template =
  | Submittable of submittable
  | Image of image
  | Text of text 
  | Container of container 
  | Broken of broken
  | Badge of badge
  | List of template_list
  | Stat of stat
  | Divider of divider
  | Diagram of diagram
  | Code of code

and submittable_field = Templates.Submittable.field =
  | FieldInput of input
  | FieldSelect of Templates.Select.t

and submittable = Templates.Submittable.t = {
  kind: string;
  id: string;
  value: submittable_field list;
  button: button option;
}

let badge_variant_of_string = Templates.Badge.badge_variant_of_string

let id_of_template = function
  | Submittable s -> s.id
  | Image i -> i.id
  | Text t -> t.id
  | Container c -> c.id
  | Broken _ -> ""
  | Badge b -> b.id
  | List l -> l.id
  | Stat s -> s.id
  | Divider d -> d.id
  | Diagram d -> d.id
  | Code c -> c.id
