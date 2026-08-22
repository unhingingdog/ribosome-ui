open Ribosome.Template

let test_construct_input () =
  let _ = Input.{ id = "name"; value = Some (String "hello") } in
  let _ = Input.{ id = "age"; value = Some (Int 42) } in
  let _ = Input.{ id = "empty"; value = None } in
  Alcotest.(check pass) "input constructed" () ()

let test_construct_select () =
  let _ =
    Select.
      {
        id = "color";
        label = "Color";
        options = [ { value = "red"; label = "Red" } ];
        selected = Some "red";
      }
  in
  Alcotest.(check pass) "select constructed" () ()

let test_construct_button () =
  let _ =
    Button.{ id = "go"; label = "Go"; action = Submit; disabled = false }
  in
  let _ =
    Button.
      {
        id = "nav";
        label = "Next";
        action = Navigate "/page2";
        disabled = true;
      }
  in
  let _ =
    Button.
      {
        id = "custom";
        label = "Run";
        action = Custom "run-script";
        disabled = false;
      }
  in
  Alcotest.(check pass) "button constructed" () ()

let test_construct_text () =
  let _ = Text.{ id = "title"; text_type = H1; value = "Hello" } in
  let _ = Text.{ id = "body"; text_type = Paragraph; value = "World" } in
  Alcotest.(check pass) "text constructed" () ()

let test_construct_image () =
  let _ =
    Image.{ id = "logo"; src = "https://example.com/x.png"; alt = "Logo" }
  in
  Alcotest.(check pass) "image constructed" () ()

let test_construct_badge () =
  let _ = Badge.{ id = "status"; label = "Active"; variant = Success } in
  Alcotest.(check pass) "badge constructed" () ()

let test_construct_stat () =
  let _ =
    Stat.{ id = "count"; label = "Items"; value = "42"; secondary = None }
  in
  let _ =
    Stat.
      {
        id = "price";
        label = "Price";
        value = "$10";
        secondary = Some "was $20";
      }
  in
  Alcotest.(check pass) "stat constructed" () ()

let test_construct_divider () =
  let _ = Divider.{ id = "sep"; label = None } in
  let _ = Divider.{ id = "sep2"; label = Some "Section" } in
  Alcotest.(check pass) "divider constructed" () ()

let test_enum_roundtrip () =
  List.iter
    (fun tt ->
      Alcotest.(check string)
        "text_type roundtrip"
        (Text.string_of_text_type tt)
        (Text.string_of_text_type
           (Text.text_type_of_string (Text.string_of_text_type tt))))
    [ Text.Paragraph; H1; H2; H3; H4; H5; H6 ];
  List.iter
    (fun v ->
      Alcotest.(check string)
        "badge_variant roundtrip"
        (Badge.string_of_badge_variant v)
        (Badge.string_of_badge_variant
           (Badge.badge_variant_of_string (Badge.string_of_badge_variant v))))
    [ Badge.Neutral; Success; Warning; Error; Info ];
  List.iter
    (fun a ->
      Alcotest.(check string)
        "action roundtrip"
        (Button.string_of_action a)
        (Button.string_of_action
           (Button.action_of_string (Button.string_of_action a))))
    [ Button.Submit; Navigate "/home"; Custom "do-thing" ]

let () =
  Alcotest.run "ribosome-template"
    [
      ( "construction",
        [
          Alcotest.test_case "input" `Quick test_construct_input;
          Alcotest.test_case "select" `Quick test_construct_select;
          Alcotest.test_case "button" `Quick test_construct_button;
          Alcotest.test_case "text" `Quick test_construct_text;
          Alcotest.test_case "image" `Quick test_construct_image;
          Alcotest.test_case "badge" `Quick test_construct_badge;
          Alcotest.test_case "stat" `Quick test_construct_stat;
          Alcotest.test_case "divider" `Quick test_construct_divider;
          Alcotest.test_case "enum roundtrip" `Quick test_enum_roundtrip;
        ] );
    ]
