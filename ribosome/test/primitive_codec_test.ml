open Ribosome.Template

let check_roundtrip decode encode v =
  let json = encode v in
  match decode json with
  | Ok _ -> Alcotest.(check bool) "roundtrip" true true
  | Error e -> Alcotest.fail ("roundtrip failed: " ^ Codec_error.to_string e)

let check_malformed name decode json =
  match decode json with
  | Ok _ -> Alcotest.fail (name ^ ": expected error")
  | Error _ -> Alcotest.(check bool) (name ^ ": reports error") true true

(* --- input --- *)

let test_input_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Input.decode Input.encode v)
    [
      Input.{ id = "name"; value = None };
      Input.{ id = "age"; value = Some (Int 42) };
      Input.{ id = "x"; value = Some (String "hi") };
    ]

let test_input_malformed () =
  check_malformed "input missing id" Input.decode (`Assoc []);
  check_malformed "input wrong id type" Input.decode (`Assoc [ ("id", `Int 1) ]);
  check_malformed "input wrong value type" Input.decode
    (`Assoc [ ("id", `String "x"); ("value", `Bool true) ])

(* --- select --- *)

let test_select_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Select.decode Select.encode v)
    [
      Select.{ id = "c"; label = "Color"; options = []; selected = None };
      Select.
        {
          id = "c";
          label = "Color";
          options = [ { value = "r"; label = "Red" } ];
          selected = Some "r";
        };
    ]

let test_select_malformed () =
  check_malformed "select missing options" Select.decode
    (`Assoc [ ("id", `String "c"); ("label", `String "l") ]);
  check_malformed "select missing label" Select.decode
    (`Assoc [ ("id", `String "c"); ("options", `List []) ]);
  check_malformed "select option missing label" Select.decode
    (`Assoc
       [
         ("id", `String "c");
         ("label", `String "l");
         ("options", `List [ `Assoc [ ("value", `String "r") ] ]);
       ])

(* --- button --- *)

let test_button_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Button.decode Button.encode v)
    [
      Button.{ id = "go"; label = "Go"; action = Submit; disabled = false };
      Button.{ id = "go"; label = "Go"; action = Submit; disabled = true };
      Button.
        {
          id = "nav";
          label = "Next";
          action = Navigate "/p2";
          disabled = false;
        };
      Button.
        { id = "c"; label = "Run"; action = Custom "do-x"; disabled = false };
    ]

let test_button_malformed () =
  check_malformed "button missing action" Button.decode
    (`Assoc [ ("id", `String "b"); ("label", `String "l") ]);
  check_malformed "button missing label" Button.decode
    (`Assoc [ ("id", `String "b"); ("action", `String "Submit") ])

(* --- text --- *)

let test_text_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Text.decode Text.encode v)
    [
      Text.{ id = "t"; text_type = Paragraph; value = "hello" };
      Text.{ id = "t"; text_type = H1; value = "Title" };
      Text.{ id = "t"; text_type = H6; value = "small" };
    ]

let test_text_malformed () =
  check_malformed "text unknown text_type" Text.decode
    (`Assoc
       [
         ("id", `String "t"); ("text_type", `String "H7"); ("value", `String "x");
       ]);
  check_malformed "text missing value" Text.decode
    (`Assoc [ ("id", `String "t"); ("text_type", `String "H1") ]);
  check_malformed "text text_type wrong type" Text.decode
    (`Assoc
       [ ("id", `String "t"); ("text_type", `Int 1); ("value", `String "x") ])

(* --- image --- *)

let test_image_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Image.decode Image.encode v)
    [ Image.{ id = "img"; src = "http://x"; alt = "desc" } ]

let test_image_malformed () =
  check_malformed "image missing src" Image.decode
    (`Assoc [ ("id", `String "img"); ("alt", `String "d") ]);
  check_malformed "image missing alt" Image.decode
    (`Assoc [ ("id", `String "img"); ("src", `String "http://x") ])

(* --- badge --- *)

let test_badge_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Badge.decode Badge.encode v)
    [
      Badge.{ id = "b"; label = "ok"; variant = Success };
      Badge.{ id = "b"; label = "ok"; variant = Neutral };
      Badge.{ id = "b"; label = "ok"; variant = Error };
    ]

let test_badge_malformed () =
  check_malformed "badge unknown variant" Badge.decode
    (`Assoc
       [
         ("id", `String "b");
         ("label", `String "l");
         ("variant", `String "Purple");
       ]);
  check_malformed "badge missing variant" Badge.decode
    (`Assoc [ ("id", `String "b"); ("label", `String "l") ])

(* --- stat --- *)

let test_stat_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Stat.decode Stat.encode v)
    [
      Stat.{ id = "s"; label = "count"; value = "42"; secondary = None };
      Stat.
        { id = "s"; label = "price"; value = "$10"; secondary = Some "was $20" };
    ]

let test_stat_malformed () =
  check_malformed "stat missing value" Stat.decode
    (`Assoc [ ("id", `String "s"); ("label", `String "l") ])

(* --- divider --- *)

let test_divider_roundtrip () =
  Stdlib.List.iter
    (fun v -> check_roundtrip Divider.decode Divider.encode v)
    [
      Divider.{ id = "d"; label = None };
      Divider.{ id = "d"; label = Some "section" };
    ]

let test_divider_malformed () =
  check_malformed "divider missing id" Divider.decode (`Assoc [])

let () =
  Alcotest.run "ribosome-primitive-codec"
    [
      ( "roundtrip",
        [
          Alcotest.test_case "input" `Quick test_input_roundtrip;
          Alcotest.test_case "select" `Quick test_select_roundtrip;
          Alcotest.test_case "button" `Quick test_button_roundtrip;
          Alcotest.test_case "text" `Quick test_text_roundtrip;
          Alcotest.test_case "image" `Quick test_image_roundtrip;
          Alcotest.test_case "badge" `Quick test_badge_roundtrip;
          Alcotest.test_case "stat" `Quick test_stat_roundtrip;
          Alcotest.test_case "divider" `Quick test_divider_roundtrip;
        ] );
      ( "malformed",
        [
          Alcotest.test_case "input" `Quick test_input_malformed;
          Alcotest.test_case "select" `Quick test_select_malformed;
          Alcotest.test_case "button" `Quick test_button_malformed;
          Alcotest.test_case "text" `Quick test_text_malformed;
          Alcotest.test_case "image" `Quick test_image_malformed;
          Alcotest.test_case "badge" `Quick test_badge_malformed;
          Alcotest.test_case "stat" `Quick test_stat_malformed;
          Alcotest.test_case "divider" `Quick test_divider_malformed;
        ] );
    ]
