let queues : (string, string Queue.t) Hashtbl.t = Hashtbl.create 16

let push session_id msg =
  let q =
    match Hashtbl.find_opt queues session_id with
    | Some q -> q
    | None ->
      let q = Queue.create () in
      Hashtbl.add queues session_id q;
      q
  in
  Queue.push msg q

let drain session_id =
  match Hashtbl.find_opt queues session_id with
  | None -> []
  | Some q ->
      let msgs = ref [] in
      Queue.iter (fun m -> msgs := m :: !msgs) q;
      Queue.clear q;
      List.rev !msgs
