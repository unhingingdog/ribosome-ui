type error = { path : string; message : string }

val validate : Template.t -> error list
