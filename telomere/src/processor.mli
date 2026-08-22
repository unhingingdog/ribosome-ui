type processor_state
type output = Pending | Completion of string | Corrupted

val create_processor : unit -> processor_state
val feed : processor_state -> string -> output * processor_state
