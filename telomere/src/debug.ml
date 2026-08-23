let enabled = Sys.getenv_opt "RIBOSOME_DEBUG" = Some "1"

let log category msg =
  if enabled then Printf.eprintf "[telomere:%s] %s\n%!" category msg
