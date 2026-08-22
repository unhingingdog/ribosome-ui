let all : Mode.t list = [ Mode.ui ]
let for_id id = Stdlib.List.find_opt (fun (m : Mode.t) -> m.id = id) all
