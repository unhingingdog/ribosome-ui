let write source payload =
  match Sys.getenv_opt "RIBOSOME_DEBUG_LOG" with
  | None -> ()
  | Some path ->
    let channel = open_out_gen [Open_creat; Open_text; Open_append] 0o600 path in
    Printf.fprintf channel "%.3f %s %s\n" (Unix.gettimeofday ()) source payload;
    close_out channel
