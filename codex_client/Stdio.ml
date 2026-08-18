open Lwt.Infix

type command = {
  program: string;
  arguments: string list;
}

type error = Closed

type t = {
  process: Lwt_process.process_full;
  stderr: Buffer.t;
  stderr_limit: int;
  stderr_reader: unit Lwt.t;
  mutable closed: bool;
}

let command program arguments = { program; arguments }

let append_stderr stderr limit line =
  let remaining = limit - Buffer.length stderr in
  if remaining > 0 then Buffer.add_substring stderr line 0 (min remaining (String.length line))

let start ?(stderr_limit = 8192) command =
  let process = Lwt_process.open_process_full
    (command.program, Array.of_list (command.program :: command.arguments)) in
  let stderr = Buffer.create stderr_limit in
  let rec capture () =
    Lwt_io.read_line_opt process#stderr >>= function
    | Some line ->
      append_stderr stderr stderr_limit (line ^ "\n");
      capture ()
    | None -> Lwt.return_unit
  in
  let stderr_reader = capture () in
  { process; stderr; stderr_limit; stderr_reader; closed = false }

let send_line t line =
  if t.closed then Lwt.return (Error Closed)
  else
    Lwt_io.write_line t.process#stdin line >>= fun () ->
    Lwt_io.flush t.process#stdin >|= fun () -> Ok ()

let receive_line t =
  if t.closed then Lwt.return_none
  else Lwt_io.read_line_opt t.process#stdout

let stderr t = Buffer.contents t.stderr

let wait t = t.process#status

let shutdown t =
  if t.closed then t.process#status
  else begin
    t.closed <- true;
    Lwt.catch
      (fun () -> Lwt_io.close t.process#stdin)
      (fun _ -> Lwt.return_unit) >>= fun () ->
    Lwt.pick [
      t.process#status;
      (Lwt_unix.sleep 1.0 >>= fun () ->
       t.process#terminate;
       t.process#status);
    ] >>= fun status ->
    t.stderr_reader >|= fun () -> status
  end
