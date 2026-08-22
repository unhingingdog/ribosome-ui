val definition : Template_definition.t

type direction = Vertical | Horizontal
type 'a t = { id : string; direction : direction; children : 'a list }

val decode_child :
  (Yojson.Safe.t -> ('a, Codec_error.t) result) ->
  Yojson.Safe.t ->
  ('a t, Codec_error.t) result

val encode_child : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t
