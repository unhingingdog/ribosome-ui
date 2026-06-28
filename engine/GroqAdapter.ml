open Utils.Log

let string_field name obj =
  match Js.Dict.get obj name with
  | None -> None
  | Some value -> Js.Json.decodeString value

let object_field name obj =
  match Js.Dict.get obj name with
  | None -> None
  | Some value -> Js.Json.decodeObject value

let first_object_field name obj =
  match Js.Dict.get obj name with
  | None -> None
  | Some value ->
    (match Js.Json.decodeArray value with
     | None -> None
     | Some array ->
       if Array.length array = 0 then None else Js.Json.decodeObject (Array.get array 0))

let chat_completion_delta obj =
  match first_object_field "choices" obj with
  | None -> None
  | Some choice ->
    (match object_field "delta" choice with
     | None -> None
     | Some delta -> string_field "content" delta)

let text_delta payload =
  try
    if String.equal payload "[DONE]" then
      Ok None
    else begin
      debug "[ribosome groq] payload" payload;
      match payload |> Melange_json.of_string |> Js.Json.decodeObject with
      | None -> Error "Groq stream payload was not a JSON object"
      | Some obj ->
        let delta = chat_completion_delta obj in
        debug "[ribosome groq] extracted text delta" delta;
        Ok delta
    end
  with err ->
    Error (Printexc.to_string err)

let stream_adapter = text_delta
