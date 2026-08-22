type error = { path : string; message : string }
type ctx = { path : string; ids : string list }

let push ctx segment = { ctx with path = ctx.path ^ segment }
let add_id ctx id = { ctx with ids = id :: ctx.ids }

let empty_id_error ctx id =
  if id = "" then [ { path = ctx.path; message = "id must not be empty" } ]
  else []

let rec validate_template ctx tmpl : error list * ctx =
  let id = Template.id tmpl in
  let ctx = add_id ctx id in
  let errors = empty_id_error ctx id in
  match tmpl with
  | Template.Text _ -> (errors, ctx)
  | Template.Image _ -> (errors, ctx)
  | Template.Badge _ -> (errors, ctx)
  | Template.Stat _ -> (errors, ctx)
  | Template.Divider _ -> (errors, ctx)
  | Template.Diagram d ->
      let d_errors = validate_diagram ctx d in
      (errors @ d_errors, ctx)
  | Template.Code c ->
      let c_errors = validate_code ctx c in
      (errors @ c_errors, ctx)
  | Template.Container c ->
      let child_errors, child_ctx =
        validate_children ctx "children" c.children
      in
      (errors @ child_errors, child_ctx)
  | Template.List l ->
      let child_errors, child_ctx =
        validate_children ctx "children" l.children
      in
      (errors @ child_errors, child_ctx)
  | Template.Submittable s ->
      let sub_errors, sub_ctx = validate_submittable ctx s in
      (errors @ sub_errors, sub_ctx)

and validate_children ctx field_name children : error list * ctx =
  let acc_errors, _, final_ctx =
    Stdlib.List.fold_left
      (fun (errors, idx, ctx) child ->
        let child_ctx =
          push ctx ("." ^ field_name ^ "[" ^ string_of_int idx ^ "]")
        in
        let child_errors, child_ctx = validate_template child_ctx child in
        (errors @ child_errors, idx + 1, child_ctx))
      ([], 0, ctx) children
  in
  (acc_errors, final_ctx)

and validate_diagram ctx (d : Template_diagram.t) : error list =
  let errors =
    if d.size.width <= 0 then
      [
        { path = ctx.path ^ ".size.width"; message = "width must be positive" };
      ]
    else []
  in
  let errors =
    if d.size.height <= 0 then
      errors
      @ [
          {
            path = ctx.path ^ ".size.height";
            message = "height must be positive";
          };
        ]
    else errors
  in
  let prim_errors, _ =
    Stdlib.List.fold_left
      (fun (errors, idx) prim ->
        let prim_ctx = push ctx (".primitives[" ^ string_of_int idx ^ "]") in
        let errors =
          match prim with
          | Template_diagram.Circle { radius; _ } ->
              if radius <= 0 then
                errors
                @ [
                    {
                      path = prim_ctx.path ^ ".radius";
                      message = "radius must be positive";
                    };
                  ]
              else errors
          | Template_diagram.Polyline { points; _ } ->
              if Stdlib.List.length points < 2 then
                errors
                @ [
                    {
                      path = prim_ctx.path ^ ".points";
                      message = "polyline must have at least 2 points";
                    };
                  ]
              else errors
          | _ -> errors
        in
        (errors, idx + 1))
      (errors, 0) d.primitives
  in
  prim_errors

and validate_code ctx (c : Template_code.t) : error list =
  let errors =
    if c.line_start < 1 then
      [
        { path = ctx.path ^ ".line_start"; message = "line_start must be >= 1" };
      ]
    else []
  in
  let h_errors, _ =
    Stdlib.List.fold_left
      (fun (errors, idx) (h : Template_code.highlight) ->
        let h_ctx = push ctx (".highlights[" ^ string_of_int idx ^ "]") in
        let errors =
          if h.start_line > h.end_line then
            errors
            @ [
                {
                  path = h_ctx.path;
                  message =
                    "start_line (" ^ string_of_int h.start_line
                    ^ ") must not exceed end_line (" ^ string_of_int h.end_line
                    ^ ")";
                };
              ]
          else errors
        in
        let errors =
          if h.start_line < c.line_start then
            errors
            @ [
                {
                  path = h_ctx.path ^ ".start_line";
                  message =
                    "start_line must be >= line_start ("
                    ^ string_of_int c.line_start ^ ")";
                };
              ]
          else errors
        in
        (errors, idx + 1))
      (errors, 0) c.highlights
  in
  h_errors

and validate_submittable ctx (s : Template_submittable.t) : error list * ctx =
  let errors, _, ctx =
    Stdlib.List.fold_left
      (fun (errors, idx, ctx) field ->
        let field_ctx = push ctx (".value[" ^ string_of_int idx ^ "]") in
        let field_errors, ctx =
          match field with
          | Template_submittable.FieldInput input ->
              validate_input field_ctx input
          | FieldSelect select -> validate_select_field field_ctx select
        in
        (errors @ field_errors, idx + 1, ctx))
      ([], 0, ctx) s.value
  in
  match s.button with
  | None -> (errors, ctx)
  | Some btn ->
      let btn_errors, ctx = validate_button ctx btn in
      (errors @ btn_errors, ctx)

and validate_input ctx (input : Template_input.t) : error list * ctx =
  let ctx = add_id ctx input.id in
  let errors = empty_id_error ctx input.id in
  (errors, ctx)

and validate_select_field ctx (select : Template_select.t) : error list * ctx =
  let ctx = add_id ctx select.id in
  let errors = empty_id_error ctx select.id in
  let errors =
    match select.selected with
    | None -> errors
    | Some sel ->
        let valid_values =
          Stdlib.List.map
            (fun (o : Template_select.option_) -> o.value)
            select.options
        in
        if not (Stdlib.List.mem sel valid_values) then
          errors
          @ [
              {
                path = ctx.path ^ ".selected";
                message = "selected value '" ^ sel ^ "' is not in options";
              };
            ]
        else errors
  in
  (errors, ctx)

and validate_button ctx (b : Template_button.t) : error list * ctx =
  let ctx = add_id ctx b.id in
  let errors = empty_id_error ctx b.id in
  let errors =
    match b.action with
    | Submit -> errors
    | Navigate url ->
        if url = "" then
          errors
          @ [
              {
                path = ctx.path ^ ".action";
                message = "Navigate action must have a non-empty URL";
              };
            ]
        else errors
    | Custom action ->
        if action = "" then
          errors
          @ [
              {
                path = ctx.path ^ ".action";
                message = "Custom action must be non-empty";
              };
            ]
        else errors
  in
  (errors, ctx)

let find_duplicates ids =
  let sorted = Stdlib.List.sort String.compare ids in
  let rec loop prev = function
    | [] -> []
    | x :: rest -> if x = prev && x <> "" then x :: loop x rest else loop x rest
  in
  match sorted with [] -> [] | x :: rest -> loop x rest

let validate tree : error list =
  let ctx = { path = "root"; ids = [] } in
  let errors, ctx = validate_template ctx tree in
  let dupes = find_duplicates ctx.ids in
  let dup_errors =
    Stdlib.List.map
      (fun id -> { path = "root"; message = "duplicate id across tree: " ^ id })
      dupes
  in
  errors @ dup_errors
