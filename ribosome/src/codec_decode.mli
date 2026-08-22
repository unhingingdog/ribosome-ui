val ( let* ) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
val string : Yojson.Safe.t -> (string, Codec_error.t) result
val int : Yojson.Safe.t -> (int, Codec_error.t) result
val bool : Yojson.Safe.t -> (bool, Codec_error.t) result

val field :
  string ->
  (Yojson.Safe.t -> ('a, Codec_error.t) result) ->
  Yojson.Safe.t ->
  ('a, Codec_error.t) result

val optional_field :
  string ->
  (Yojson.Safe.t -> ('a, Codec_error.t) result) ->
  Yojson.Safe.t ->
  ('a option, Codec_error.t) result

val list :
  (Yojson.Safe.t -> ('a, Codec_error.t) result) ->
  Yojson.Safe.t ->
  ('a list, Codec_error.t) result

val enum : (string * 'a) list -> Yojson.Safe.t -> ('a, Codec_error.t) result
val object_ : Yojson.Safe.t -> (unit, Codec_error.t) result
