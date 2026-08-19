type config = {
  interface: string;
  port: int;
  cwd: string;
  skill_root: string;
}

let usage () =
  prerr_endline "usage: ribosome-dream --skill-root <path> [--interface <host>] [--port <port>] [--cwd <path>]";
  exit 2

let parse_port value =
  match int_of_string_opt value with
  | Some port when port > 0 && port < 65536 -> port
  | Some _ | None -> usage ()

let parse_arguments () =
  let interface = ref "127.0.0.1" in
  let port = ref 8787 in
  let cwd = ref (Sys.getcwd ()) in
  let skill_root = ref None in
  let arguments = Array.to_list Sys.argv |> List.tl in
  let rec loop = function
    | [] ->
      (match !skill_root with
       | Some skill_root -> { interface = !interface; port = !port; cwd = !cwd; skill_root }
       | None -> usage ())
    | "--interface" :: value :: remaining -> interface := value; loop remaining
    | "--port" :: value :: remaining -> port := parse_port value; loop remaining
    | "--cwd" :: value :: remaining -> cwd := value; loop remaining
    | "--skill-root" :: value :: remaining -> skill_root := Some value; loop remaining
    | _ -> usage ()
  in
  loop arguments

let codex_command = Codex_client.Stdio.command "codex" ["app-server"]

let run (config : config) =
  let bootstrap_config = Dream_server.Bootstrap.{
    interface = config.interface;
    port = config.port;
    codex_command;
    skill_root = config.skill_root;
    cwd = config.cwd;
  } in
  match Lwt_main.run (Dream_server.Bootstrap.start bootstrap_config) with
  | Error _ ->
    prerr_endline "ribosome-dream: failed to initialize Codex and the ribosome skill";
    exit 1
  | Ok ready ->
    let endpoint = Dream_server.Websocket.create ~ready () in
    Dream.run ~interface:config.interface ~port:config.port
      (Dream.router [
        Dream.get "/health" Dream_server.Bootstrap.health_handler;
        Dream_server.Websocket.route endpoint;
      ])

let () = run (parse_arguments ())
