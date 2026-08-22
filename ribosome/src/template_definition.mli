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

val field : string -> field_type -> string -> field_def
val optional_field : string -> field_type -> string -> field_def
val string_field : string -> string -> field_def
val number_field : string -> string -> field_def
val bool_field : string -> string -> field_def
val array_field : string -> string -> field_def
val object_field : string -> string -> field_def
val template_list_field : string -> string -> field_def
val input_list_field : string -> string -> field_def
val optional_string_field : string -> string -> field_def
val optional_bool_field : string -> string -> field_def
val kind_field : string -> field_def
val id_field : string -> field_def
