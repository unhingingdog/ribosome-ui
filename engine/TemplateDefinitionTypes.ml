type field_type = StringField | NumberField | TemplateList | InputList

type field_def = {
  name: string;
  field_type: field_type;
  required: bool;
  instructions: string;
}

type template_definition = {
  kind: string;
  intent: string;
  instructions: string;
  fields: field_def list;
}

let field name field_type instructions = {
  name;
  field_type;
  required = true;
  instructions;
}

let string_field name instructions = field name StringField instructions
let input_list_field name instructions = field name InputList instructions
let template_list_field name instructions = field name TemplateList instructions

let kind_field kind = string_field "kind" ("Always " ^ kind ^ ".")
let id_field subject = string_field "id" ("Stable id for this " ^ subject ^ ".")
