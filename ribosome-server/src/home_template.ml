(* Deterministic templates served by the server before agent generation.

   The home screen is the only hard-coded part of the UI — a vertical container
   with a title, subtitle, and a submittable form. The submit button carries a
   [start:submit] action so the frontend knows to send [request_generation]
   instead of [component_event].

   The templates tree is a storybook containing all 13 component kinds in a
   single vertical container, used by the [/templates] debug endpoint. *)

let home_json =
  {|{
  "kind": "container",
  "id": "home-root",
  "direction": "Vertical",
  "children": [
    {
      "kind": "text",
      "id": "home-title",
      "text_type": "H1",
      "value": "Ribosome"
    },
    {
      "kind": "text",
      "id": "home-subtitle",
      "text_type": "Paragraph",
      "value": "Enter a subject to begin a conversation."
    },
    {
      "kind": "submittable",
      "id": "home-form",
      "value": [
        { "kind": "input", "id": "home-input" }
      ],
      "button": {
        "kind": "button",
        "id": "home-submit",
        "label": "Submit",
        "action": "start:submit"
      }
    }
  ]
}|}

let templates_json =
  {|{
  "kind": "container",
  "id": "storybook-root",
  "direction": "Vertical",
  "children": [
    {
      "kind": "text",
      "id": "sb-text",
      "text_type": "H2",
      "value": "Text Component"
    },
    {
      "kind": "image",
      "id": "sb-image",
      "src": "https://example.com/logo.png",
      "alt": "Example image"
    },
    {
      "kind": "badge",
      "id": "sb-badge",
      "label": "Active",
      "variant": "Success"
    },
    {
      "kind": "stat",
      "id": "sb-stat",
      "label": "Requests",
      "value": "1,204",
      "secondary": "+12% from last week"
    },
    {
      "kind": "divider",
      "id": "sb-divider",
      "label": "Interactive Components"
    },
    {
      "kind": "diagram",
      "id": "sb-diagram",
      "title": "Sample Diagram",
      "size": { "width": 400, "height": 200 },
      "primitives": [
        { "kind": "line", "start": { "x": 10, "y": 10 }, "stop": { "x": 100, "y": 100 }, "tone": "Default" },
        { "kind": "arrow", "start": { "x": 100, "y": 100 }, "stop": { "x": 200, "y": 50 }, "tone": "Info" },
        { "kind": "rectangle", "origin": { "x": 150, "y": 10 }, "size": { "width": 80, "height": 60 }, "tone": "Default" },
        { "kind": "circle", "center": { "x": 300, "y": 100 }, "radius": 40, "tone": "Positive" },
        { "kind": "polyline", "points": [ { "x": 10, "y": 180 }, { "x": 100, "y": 150 }, { "x": 200, "y": 180 } ], "tone": "Warning" },
        { "kind": "text", "text": "Label", "position": { "x": 50, "y": 50 }, "tone": "Info" }
      ]
    },
    {
      "kind": "code",
      "id": "sb-code",
      "path": "example.ml",
      "language": "ocaml",
      "line_start": 1,
      "source": "let () = print_endline \"hello\"",
      "highlights": [ { "start_line": 1, "end_line": 1, "tone": "Positive" } ]
    },
    {
      "kind": "container",
      "id": "sb-container",
      "direction": "Horizontal",
      "children": [
        { "kind": "text", "id": "sb-container-a", "text_type": "Paragraph", "value": "Left" },
        { "kind": "text", "id": "sb-container-b", "text_type": "Paragraph", "value": "Right" }
      ]
    },
    {
      "kind": "list",
      "id": "sb-list",
      "ordered": true,
      "children": [
        { "kind": "text", "id": "sb-list-1", "text_type": "Paragraph", "value": "First item" },
        { "kind": "text", "id": "sb-list-2", "text_type": "Paragraph", "value": "Second item" }
      ]
    },
    {
      "kind": "submittable",
      "id": "sb-submittable",
      "value": [
        { "kind": "input", "id": "sb-input", "value": "default text" },
        { "kind": "select", "id": "sb-select", "label": "Choose", "options": [
          { "value": "a", "label": "Option A" },
          { "value": "b", "label": "Option B" }
        ], "selected": "a" }
      ],
      "button": {
        "kind": "button",
        "id": "sb-button",
        "label": "Submit",
        "action": "Submit"
      }
    }
  ]
}|}

let home_tree =
  match Ribosome.Template.decode_string home_json with
  | Ok t -> t
  | Error e ->
      failwith
        ("home_template: home_json failed to decode: "
        ^ Ribosome.Template.Codec_error.to_string e)

let templates_tree =
  match Ribosome.Template.decode_string templates_json with
  | Ok t -> t
  | Error e ->
      failwith
        ("home_template: templates_json failed to decode: "
        ^ Ribosome.Template.Codec_error.to_string e)
