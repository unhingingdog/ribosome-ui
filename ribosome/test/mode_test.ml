let read_file path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let s = really_input_string ic len in
  close_in ic;
  s

let string_contains haystack needle =
  let rec search i =
    if i > String.length haystack - String.length needle then false
    else if String.sub haystack i (String.length needle) = needle then true
    else search (i + 1)
  in
  search 0

let skill_content () =
  let cwd = Sys.getcwd () in
  let paths =
    [
      "skills/ribosome/SKILL.md";
      "../../../skills/ribosome/SKILL.md";
      "../../../../skills/ribosome/SKILL.md";
      cwd ^ "/skills/ribosome/SKILL.md";
      cwd ^ "/../../../skills/ribosome/SKILL.md";
      cwd ^ "/../../../../skills/ribosome/SKILL.md";
    ]
  in
  let rec try_paths = function
    | [] ->
        Alcotest.fail ("cannot find skills/ribosome/SKILL.md from cwd=" ^ cwd)
    | p :: rest -> if Sys.file_exists p then read_file p else try_paths rest
  in
  try_paths paths

let test_ui_mode () =
  Alcotest.(check string) "ui mode id" "ui" Ribosome.Mode.ui.id;
  Alcotest.(check (list string))
    "ui mode skills"
    [ "skills/ribosome/SKILL.md" ]
    Ribosome.Mode.ui.skills

let test_registry_has_ui () =
  Alcotest.(check bool)
    "registry has ui" true
    (Stdlib.List.mem "ui"
       (Stdlib.List.map
          (fun (m : Ribosome.Mode.t) -> m.id)
          Ribosome.Mode_registry.all))

let test_registry_rejects_unknown () =
  Alcotest.(check bool)
    "unknown mode rejected" true
    (Ribosome.Mode_registry.for_id "nonexistent" = None)

let test_skill_file_exists () =
  let content = skill_content () in
  Alcotest.(check bool) "skill file not empty" true (String.length content > 0)

let test_skill_contains_all_kinds () =
  let content = skill_content () in
  let kinds =
    Stdlib.List.map
      (fun (d : Ribosome.Template.Definition.t) -> d.kind)
      Ribosome.Template.Registry.all
  in
  Stdlib.List.iter
    (fun kind ->
      Alcotest.(check bool)
        ("skill mentions kind: " ^ kind)
        true
        (string_contains content kind))
    kinds

let test_skill_contains_container_direction () =
  let content = skill_content () in
  Alcotest.(check bool)
    "skill mentions Vertical" true
    (string_contains content "Vertical");
  Alcotest.(check bool)
    "skill mentions Horizontal" true
    (string_contains content "Horizontal")

let test_skill_contains_code () =
  let content = skill_content () in
  Alcotest.(check bool)
    "skill mentions code" true
    (string_contains content "code")

let test_skill_contains_diagram () =
  let content = skill_content () in
  Alcotest.(check bool)
    "skill mentions diagram" true
    (string_contains content "diagram")

let test_skill_contains_json_only_instruction () =
  let content = skill_content () in
  Alcotest.(check bool)
    "skill mentions raw template JSON" true
    (string_contains content "raw template JSON")

let () =
  Alcotest.run "ribosome-mode"
    [
      ( "mode",
        [
          Alcotest.test_case "ui mode" `Quick test_ui_mode;
          Alcotest.test_case "registry has ui" `Quick test_registry_has_ui;
          Alcotest.test_case "registry rejects unknown" `Quick
            test_registry_rejects_unknown;
        ] );
      ( "skill",
        [
          Alcotest.test_case "skill file exists" `Quick test_skill_file_exists;
          Alcotest.test_case "skill contains all kinds" `Quick
            test_skill_contains_all_kinds;
          Alcotest.test_case "skill contains container direction" `Quick
            test_skill_contains_container_direction;
          Alcotest.test_case "skill contains code" `Quick
            test_skill_contains_code;
          Alcotest.test_case "skill contains diagram" `Quick
            test_skill_contains_diagram;
          Alcotest.test_case "skill contains json-only instruction" `Quick
            test_skill_contains_json_only_instruction;
        ] );
    ]
