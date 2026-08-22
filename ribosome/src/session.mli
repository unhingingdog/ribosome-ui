type generation = { id : string; next_seq : int }

type t = {
  id : string;
  mode : Mode.t;
  tree : Template.t option;
  revision : int;
  generation : generation option;
  incremental : Incremental.state;
}

val create : id:string -> mode:Mode.t -> t
val start_generation : t -> gen_id:string -> (t, string) result

val feed_delta :
  t ->
  gen_id:string ->
  seq:int ->
  delta:string ->
  (t * Incremental.update, string) result

val complete_generation : t -> gen_id:string -> (t, string) result
val fail_generation : t -> gen_id:string -> (t, string) result
val cancel_generation : t -> gen_id:string -> (t, string) result
