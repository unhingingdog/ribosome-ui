open Types

let hello_world input = print_endline ("hello " ^ input)
;;

let double l r = l + r
;;

let handle_template template = match template with
    | Text t -> t.content
    | Image i -> i.alt
    | Container _ -> "container" 
    | Submittable _ -> "submittable"
    | Input i -> (match i.value with
      | String s -> s
      | Int i -> Int.to_string i
    ) 
;;

