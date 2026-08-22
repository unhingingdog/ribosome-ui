val optional :
  string ->
  'a option ->
  ('a -> Yojson.Safe.t) ->
  (string * Yojson.Safe.t) list ->
  (string * Yojson.Safe.t) list

val obj : (string * Yojson.Safe.t) list -> Yojson.Safe.t
