val definition : Template_definition.t

type 'a t = { id : string; ordered : bool option; children : 'a list }

val decode :
  (Yojson.Safe.t -> ('a, Codec_error.t) result) ->
  Yojson.Safe.t ->
  ('a t, Codec_error.t) result

val encode : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t
