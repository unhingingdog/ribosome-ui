type event =
  | Click of { target_id : string }
  | Change of { target_id : string; value : Template_input.input_value }
  | Submit of { target_id : string }

val apply : Template.t -> event -> (Template.t * event, string) result
