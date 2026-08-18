open Ribosome_core
open Ribosome_native_codec

let assert_equal label expected actual =
  if expected <> actual then failwith label

let template =
  Types.Container {
    Templates.Container.kind = "container";
    id = "root";
    direction = Templates.Container.Vertical;
    children = [
      Types.Text {
        Templates.Text.kind = "text";
        id = "title";
        text_type = Templates.Text.H1;
        content = "Profile";
      };
      Types.Image {
        Templates.Image.kind = "image";
        id = "avatar";
        src = "https://example.com/avatar.png";
        alt = "Avatar";
      };
      Types.Badge {
        Templates.Badge.kind = "badge";
        id = "status";
        label = "Active";
        variant = Templates.Badge.Success;
      };
      Types.List {
        Templates.List.kind = "list";
        id = "metrics";
        ordered = Some true;
        children = [
          Types.Stat {
            Templates.Stat.kind = "stat";
            id = "points";
            label = "Points";
            value = "42";
            secondary = Some "This week";
          };
          Types.Divider {
            Templates.Divider.kind = "divider";
            id = "boundary";
            label = None;
          };
        ];
      };
      Types.Submittable {
        Templates.Submittable.kind = "submittable";
        id = "profile";
        value = [
          Templates.Submittable.FieldInput {
            Templates.Input.kind = "input";
            id = "name";
            value = Some (Templates.Input.String "Alice");
          };
          Templates.Submittable.FieldSelect {
            Templates.Select.kind = "select";
            id = "role";
            label = "Role";
            options = [{ Templates.Select.value = "admin"; label = "Admin" }];
            selected = Some "admin";
          };
        ];
        button = Some {
          Templates.Button.kind = "button";
          id = "save";
          label = "Save";
          action = Templates.Button.Navigate "/saved";
          disabled = Some false;
        };
      };
    ];
  }

let test_round_trip () =
  let encoded = TemplateCodec.encode_template template in
  match TemplateCodec.decode_template encoded with
  | Ok decoded ->
    assert_equal "round trip preserves every template variant" template decoded
  | Error error -> failwith error

let test_accepts_legacy_text_content () =
  assert_equal "content remains accepted for legacy text"
    (Ok (Types.Text {
      Templates.Text.kind = "text";
      id = "notice";
      text_type = Templates.Text.Paragraph;
      content = "Notice";
    }))
    (TemplateCodec.decode_string_template
      "{\"kind\":\"text\",\"id\":\"notice\",\"text_type\":\"Paragraph\",\"content\":\"Notice\"}")

let test_rejects_invalid_templates () =
  assert_equal "unknown kind is rejected" (Error "unknown template kind")
    (TemplateCodec.decode_string_template "{\"kind\":\"unknown\"}");
  assert_equal "missing required field is rejected" true
    (match TemplateCodec.decode_string_template "{\"kind\":\"container\",\"id\":\"root\",\"children\":[]}" with
     | Error _ -> true
     | Ok _ -> false);
  assert_equal "invalid json is rejected" true
    (match TemplateCodec.decode_string_template "{" with Error _ -> true | Ok _ -> false)

let () =
  test_round_trip ();
  test_accepts_legacy_text_content ();
  test_rejects_invalid_templates ()
