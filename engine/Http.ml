external get_body : Fetch.Response.t -> 'body Js.Nullable.t = "body" [@@mel.get]
external get_reader : 'body -> 'reader = "getReader" [@@mel.send]

let reject message = Js.Promise.reject (Failure message)

let response_error res =
  "HTTP request failed: "
  ^ string_of_int (Fetch.Response.status res)
  ^ " "
  ^ Fetch.Response.statusText res

let require_ok res =
  if Fetch.Response.ok res then Js.Promise.resolve res else reject (response_error res)

let require_body res =
  match res |> get_body |> Js.Nullable.toOption with
  | None -> reject "HTTP response did not include a body"
  | Some body -> Js.Promise.resolve body

let request_config key body = 
    (Fetch.RequestInit.make
      ~method_:Post
      ~headers:(Fetch.HeadersInit.makeWithArray [|
        ("Authorization", "Bearer " ^ key);
        ("Content-Type", "application/json");
      |])
      ~body:(Fetch.BodyInit.make body)
      ())

let post ~url ~api_key ~body ~on_chunk ~on_done ~on_error =
  Fetch.fetchWithInit url (request_config api_key body)
  |> Js.Promise.then_ require_ok
  |> Js.Promise.then_ require_body
  |> Js.Promise.then_ (fun body -> body |> get_reader |> Stream.pump ~on_chunk ~on_done)
  |> Js.Promise.catch (fun exn ->
    on_error exn;
    Js.Promise.resolve ())
