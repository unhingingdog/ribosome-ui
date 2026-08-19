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
      Types.Diagram {
        Templates.Diagram.kind = "diagram";
        id = "request-flow";
        title = "Request flow";
        size = Templates.Diagram.Regular;
        primitives = [
          Templates.Diagram.Rectangle {
            id = "client";
            at = { Templates.Diagram.x = 10; y = 30 };
            width = 20;
            height = 20;
            tone = Templates.Diagram.Primary;
          };
          Templates.Diagram.Arrow {
            id = "request";
            from_ = { Templates.Diagram.x = 30; y = 40 };
            to_ = { Templates.Diagram.x = 70; y = 40 };
            tone = Templates.Diagram.Secondary;
          };
          Templates.Diagram.Polyline {
            id = "return";
            points = (
              { Templates.Diagram.x = 70; y = 60 },
              [{ Templates.Diagram.x = 40; y = 70 }; { Templates.Diagram.x = 30; y = 60 }]
            );
            tone = Templates.Diagram.Muted;
          };
        ];
      };
      Types.Code {
        Templates.Code.kind = "code";
        id = "request-handler";
        path = "src/request.ml";
        language = "ocaml";
        line_start = 40;
        source = "let handle request =\n  validate request\n  |> dispatch";
        highlights = [{
          Templates.Code.id = "dispatch";
          start_line = 41;
          end_line = 42;
          label = "Validation gates dispatch";
          tone = Templates.Code.Primary;
        }];
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
    (match TemplateCodec.decode_string_template "{" with Error _ -> true | Ok _ -> false);
  assert_equal "a polyline needs two points" true
    (match TemplateCodec.decode_string_template
      "{\"kind\":\"diagram\",\"id\":\"diagram\",\"title\":\"Diagram\",\"size\":\"compact\",\"primitives\":[{\"shape\":\"polyline\",\"id\":\"line\",\"points\":[{\"x\":1,\"y\":2}],\"tone\":\"primary\"}]}"
     with Error _ -> true | Ok _ -> false);
  assert_equal "code requires its highlights" true
    (match TemplateCodec.decode_string_template
      "{\"kind\":\"code\",\"id\":\"snippet\",\"path\":\"src/a.ml\",\"language\":\"ocaml\",\"line_start\":1,\"source\":\"let x = 1\"}"
     with Error _ -> true | Ok _ -> false)

let () =
  test_round_trip ();
  test_accepts_legacy_text_content ();
  test_rejects_invalid_templates ()
