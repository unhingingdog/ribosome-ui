type update = Updated of Template.t | Pending | Rejected of string | Corrupted
type state

val create : unit -> state
val feed : state -> string -> state * update
