(* Dream WebSocket transport for Ribosome.

   Provides /v1/harness and /v1/ui routes. Route handlers are thin codecs
   around runtime functions. Enforces loopback binding by default. *)

let loopback = "127.0.0.1"
let max_message_size = 1 lsl 20 (* 1 MiB *)

type runtime = { harness : Harness_runtime.t; ui : Ui_runtime.t }

let create ~harness ~ui = { harness; ui }

let routes runtime =
  [
    Dream.get "/v1/harness" (Harness_handler.handler ~runtime:runtime.harness);
    Dream.get "/v1/ui" (Ui_handler.handler ~runtime:runtime.ui);
    Dream.get "/health" (fun _ -> Dream.json "{\"status\":\"ok\"}");
  ]

let start ?(interface_ = loopback) ?(port = 8787) runtime =
  Dream.run ~interface:interface_ ~port (Dream.router (routes runtime))
