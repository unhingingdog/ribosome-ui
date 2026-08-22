type field_type =
  | StringField
  | NumberField
  | BoolField
  | ArrayField
  | ObjectField
  | TemplateList
  | InputList

type field_def = {
  name : string;
  field_type : field_type;
  required : bool;
  instructions : string;
}

type scope = TopLevel | NestedOnly

type t = {
  kind : string;
  scope : scope;
  intent : string;
  instructions : string;
  fields : field_def list;
}

let field name field_type instructions =
  { name; field_type; required = true; instructions }

let optional_field name field_type instructions =
  { name; field_type; required = false; instructions }

let string_field name instructions = field name StringField instructions
let number_field name instructions = field name NumberField instructions
let bool_field name instructions = field name BoolField instructions
let array_field name instructions = field name ArrayField instructions
let object_field name instructions = field name ObjectField instructions
let template_list_field name instructions = field name TemplateList instructions
let input_list_field name instructions = field name InputList instructions

let optional_string_field name instructions =
  optional_field name StringField instructions

let optional_bool_field name instructions =
  optional_field name BoolField instructions

let kind_field kind = string_field "kind" ("Always " ^ kind ^ ".")
let id_field subject = string_field "id" ("Stable id for this " ^ subject ^ ".")
