external get_body : Fetch.Response.t -> 'body Js.Nullable.t = "body" [@@mel.get]
external get_reader : 'body -> 'reader = "getReader" [@@mel.send]

type completion_reason =
  | Complete
  | Failed of string

let reject message = Js.Promise.reject (Failure message)

(* TODO: this is ugly. Consider refactor. *)
let promise_error_to_string : Js.Promise.error -> string = [%mel.raw {|
  (err) => {
    if (err == null) return String(err);
    if (typeof err._1 === "string") return err._1;
    if (err.cause != null && typeof err.cause._1 === "string") return err.cause._1;
    if (typeof err.message === "string") return err.message;
    return String(err);
  }
|}]

let notify_complete ~on_done =
  on_done Complete

let notify_failed ~on_done ~on_error message =
  on_done (Failed message);
  on_error message

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

let request_config ?(headers=[||]) body =
  Fetch.RequestInit.make
    ~method_:Post
    ~headers:(Fetch.HeadersInit.makeWithArray headers)
    ~body:(Fetch.BodyInit.make body)
    ()

let post ~url ~headers ~body ~on_chunk ~on_done ~on_error =
  ignore (
    Fetch.fetchWithInit url (request_config ~headers body)
    |> Js.Promise.then_ require_ok
    |> Js.Promise.then_ require_body
    |> Js.Promise.then_ (fun body ->
      body
      |> get_reader
      |> Stream.pump ~on_chunk ~on_done:(fun () -> notify_complete ~on_done))
    |> Js.Promise.catch (fun exn ->
      let message = promise_error_to_string exn in
      notify_failed ~on_done ~on_error message;
      Js.Promise.resolve ()))
