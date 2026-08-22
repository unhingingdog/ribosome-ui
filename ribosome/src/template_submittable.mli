type field = FieldInput of Template_input.t | FieldSelect of Template_select.t
type t = { id : string; value : field list; button : Template_button.t option }
