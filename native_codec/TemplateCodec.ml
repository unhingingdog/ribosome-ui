open Ribosome_core
open Melange_json.Primitives

type error = string

type text = {
  kind: string;
  id: string;
  text_type: string;
  value: string;
} [@@deriving json]

type image = {
  kind: string;
  id: string;
  src: string;
  alt: string;
} [@@deriving json]

type badge = {
  kind: string;
  id: string;
  label: string;
  variant: string;
} [@@deriving json]

type select_option = {
  value: string;
  label: string;
} [@@deriving json]

type select = {
  kind: string;
  id: string;
  label: string;
  options: select_option list;
  selected: string option [@json.option] [@json.drop_default];
} [@@deriving json]

type button = {
  kind: string;
  id: string;
  label: string;
  action: string;
  disabled: bool option [@json.option] [@json.drop_default];
} [@@deriving json]

type container = {
  kind: string;
  id: string;
  direction: string;
} [@@deriving json]

type template_list = {
  kind: string;
  id: string;
  ordered: bool option [@json.option] [@json.drop_default];
} [@@deriving json]

type submittable = {
  kind: string;
  id: string;
} [@@deriving json]

type stat = {
  kind: string;
  id: string;
  label: string;
  value: string;
  secondary: string option [@json.option] [@json.drop_default];
} [@@deriving json]

type divider = {
  kind: string;
  id: string;
  label: string option [@json.option] [@json.drop_default];
} [@@deriving json]

type diagram = {
  kind: string;
  id: string;
  title: string;
  size: string;
} [@@deriving json]

type code = {
  kind: string;
  id: string;
  path: string;
  language: string;
  line_start: int;
  source: string;
} [@@deriving json]

let ( let* ) = Result.bind

let decode_generated decoder value =
  try Ok (decoder value)
  with error -> Error (Printexc.to_string error)

let decode_object = function
  | `Assoc fields -> Ok fields
  | _ -> Error "expected object"

let decode_string = function
  | `String value -> Ok value
  | _ -> Error "expected string"

let decode_int = function
  | `Int value -> Ok value
  | _ -> Error "expected integer"

let required name decoder fields =
  match Stdlib.List.assoc_opt name fields with
  | Some value -> decoder value
  | None -> Error ("missing " ^ name)

let optional name decoder fields =
  match Stdlib.List.assoc_opt name fields with
  | Some value -> Result.map Option.some (decoder value)
  | None -> Ok None

let decode_point json =
  let* fields = decode_object json in
  let* x = required "x" decode_int fields in
  let* y = required "y" decode_int fields in
  Ok { Templates.Diagram.x; y }

let decode_diagram_size = function
  | "compact" -> Ok Templates.Diagram.Compact
  | "regular" -> Ok Templates.Diagram.Regular
  | "tall" -> Ok Templates.Diagram.Tall
  | _ -> Error "expected diagram size"

let decode_diagram_tone = function
  | "primary" -> Ok Templates.Diagram.Primary
  | "secondary" -> Ok Templates.Diagram.Secondary
  | "success" -> Ok Templates.Diagram.Success
  | "warning" -> Ok Templates.Diagram.Warning
  | "danger" -> Ok Templates.Diagram.Danger
  | "muted" -> Ok Templates.Diagram.Muted
  | _ -> Error "expected diagram tone"

let decode_code_tone = function
  | "primary" -> Ok Templates.Code.Primary
  | "secondary" -> Ok Templates.Code.Secondary
  | "success" -> Ok Templates.Code.Success
  | "warning" -> Ok Templates.Code.Warning
  | "danger" -> Ok Templates.Code.Danger
  | "muted" -> Ok Templates.Code.Muted
  | _ -> Error "expected code tone"

let decode_list decoder = function
  | `List values ->
    let rec loop decoded = function
      | [] -> Ok (Stdlib.List.rev decoded)
      | value :: remaining ->
        let* decoded_value = decoder value in
        loop (decoded_value :: decoded) remaining
    in
    loop [] values
  | _ -> Error "expected array"

let decode_input_value json =
  match decode_string json with
  | Ok value -> Ok (Types.String value)
  | Error _ -> Result.map (fun value -> Types.Int value) (decode_int json)

let decode_direction = function
  | "vertical" -> Ok Templates.Container.Vertical
  | "horizontal" -> Ok Templates.Container.Horizontal
  | _ -> Error "expected container direction"

let decode_text_type = function
  | "Paragraph" -> Ok Templates.Text.Paragraph
  | "H1" -> Ok Templates.Text.H1
  | "H2" -> Ok Templates.Text.H2
  | "H3" -> Ok Templates.Text.H3
  | "H4" -> Ok Templates.Text.H4
  | "H5" -> Ok Templates.Text.H5
  | "H6" -> Ok Templates.Text.H6
  | _ -> Error "expected text type"

let decode_badge_variant = function
  | "Neutral" -> Ok Templates.Badge.Neutral
  | "Success" -> Ok Templates.Badge.Success
  | "Warning" -> Ok Templates.Badge.Warning
  | "Error" -> Ok Templates.Badge.Error
  | "Info" -> Ok Templates.Badge.Info
  | _ -> Error "expected badge variant"

let decode_button_action = function
  | "Submit" -> Ok Templates.Button.Submit
  | value when String.length value >= 9 && String.sub value 0 9 = "Navigate:" ->
    Ok (Templates.Button.Navigate (String.sub value 9 (String.length value - 9)))
  | value when String.length value > 0 -> Ok (Templates.Button.Custom value)
  | _ -> Error "expected button action"

let with_legacy_text_value json =
  match json with
  | `Assoc fields when not (Stdlib.List.mem_assoc "value" fields) ->
    (match Stdlib.List.assoc_opt "content" fields with
     | Some content ->
       `Assoc (("value", content) :: Stdlib.List.remove_assoc "content" fields)
     | None -> json)
  | _ -> json

let without_fields names = function
  | `Assoc fields ->
    `Assoc (Stdlib.List.filter (fun (name, _) -> not (Stdlib.List.mem name names)) fields)
  | json -> json

let decode_input fields =
  let* kind = required "kind" decode_string fields in
  let* id = required "id" decode_string fields in
  let* value = optional "value" decode_input_value fields in
  Ok { Templates.Input.kind; id; value }

let decode_submittable_field json =
  let* fields = decode_object json in
  let* kind = required "kind" decode_string fields in
  match kind with
  | "input" -> Result.map (fun input -> Types.FieldInput input) (decode_input fields)
  | "select" ->
    let* value = decode_generated select_of_json json in
    Ok (Types.FieldSelect {
      Templates.Select.kind = value.kind;
      id = value.id;
      label = value.label;
      options = Stdlib.List.map (fun (option_ : select_option) -> {
        Templates.Select.value = option_.value;
        label = option_.label;
      }) value.options;
      selected = value.selected;
    })
  | _ -> Error "expected input or select"

let rec decode_template json =
  let* fields = decode_object json in
  let* kind = required "kind" decode_string fields in
  match kind with
  | "text" -> decode_text json
  | "image" -> decode_image json
  | "submittable" -> decode_submittable json fields
  | "container" -> decode_container json fields
  | "badge" -> decode_badge json
  | "list" -> decode_list_template json fields
  | "stat" -> decode_stat json
  | "divider" -> decode_divider json
  | "diagram" -> decode_diagram json fields
  | "code" -> decode_code json fields
  | "error" -> decode_broken fields
  | _ -> Error "unknown template kind"

and decode_text json =
  let* value = decode_generated text_of_json (with_legacy_text_value json) in
  let* text_type = decode_text_type value.text_type in
  Ok (Types.Text {
    Templates.Text.kind = value.kind;
    id = value.id;
    text_type;
    content = value.value;
  })

and decode_image json =
  let* value = decode_generated image_of_json json in
  Ok (Types.Image {
    Templates.Image.kind = value.kind;
    id = value.id;
    src = value.src;
    alt = value.alt;
  })

and decode_submittable json fields =
  let* header = decode_generated submittable_of_json (without_fields ["value"; "button"] json) in
  let* value = required "value" (decode_list decode_submittable_field) fields in
  let* button = optional "button" (fun button_json ->
    let* value = decode_generated button_of_json button_json in
    let* action = decode_button_action value.action in
    Ok {
      Templates.Button.kind = value.kind;
      id = value.id;
      label = value.label;
      action;
      disabled = value.disabled;
    }
  ) fields in
  Ok (Types.Submittable {
    Templates.Submittable.kind = header.kind;
    id = header.id;
    value;
    button;
  })

and decode_container json fields =
  let* header = decode_generated container_of_json (without_fields ["children"] json) in
  let* direction = decode_direction header.direction in
  let* children = required "children" (decode_list decode_template) fields in
  Ok (Types.Container {
    Templates.Container.kind = header.kind;
    id = header.id;
    direction;
    children;
  })

and decode_badge json =
  let* value = decode_generated badge_of_json json in
  let* variant = decode_badge_variant value.variant in
  Ok (Types.Badge {
    Templates.Badge.kind = value.kind;
    id = value.id;
    label = value.label;
    variant;
  })

and decode_list_template json fields =
  let* header = decode_generated template_list_of_json (without_fields ["children"] json) in
  let* children = required "children" (decode_list decode_template) fields in
  Ok (Types.List {
    Templates.List.kind = header.kind;
    id = header.id;
    ordered = header.ordered;
    children;
  })

and decode_stat json =
  let* value = decode_generated stat_of_json json in
  Ok (Types.Stat {
    Templates.Stat.kind = value.kind;
    id = value.id;
    label = value.label;
    value = value.value;
    secondary = value.secondary;
  })

and decode_divider json =
  let* value = decode_generated divider_of_json json in
  Ok (Types.Divider {
    Templates.Divider.kind = value.kind;
    id = value.id;
    label = value.label;
  })

and decode_diagram json fields =
  let* header = decode_generated diagram_of_json (without_fields ["primitives"] json) in
  let* size = decode_diagram_size header.size in
  let* primitives = required "primitives" (decode_list decode_diagram_primitive) fields in
  Ok (Types.Diagram {
    Templates.Diagram.kind = header.kind;
    id = header.id;
    title = header.title;
    size;
    primitives;
  })

and decode_diagram_primitive json =
  let* fields = decode_object json in
  let* shape = required "shape" decode_string fields in
  let* id = required "id" decode_string fields in
  let* tone_value = required "tone" decode_string fields in
  let* tone = decode_diagram_tone tone_value in
  match shape with
  | "text" ->
    let* at = required "at" decode_point fields in
    let* value = required "value" decode_string fields in
    Ok (Templates.Diagram.Text { id; at; value; tone })
  | "line" | "arrow" ->
    let* from_ = required "from" decode_point fields in
    let* to_ = required "to" decode_point fields in
    if shape = "line" then Ok (Templates.Diagram.Line { id; from_; to_; tone })
    else Ok (Templates.Diagram.Arrow { id; from_; to_; tone })
  | "rectangle" ->
    let* at = required "at" decode_point fields in
    let* width = required "width" decode_int fields in
    let* height = required "height" decode_int fields in
    Ok (Templates.Diagram.Rectangle { id; at; width; height; tone })
  | "circle" ->
    let* at = required "at" decode_point fields in
    let* radius = required "radius" decode_int fields in
    Ok (Templates.Diagram.Circle { id; at; radius; tone })
  | "polyline" ->
    let* points = required "points" (decode_list decode_point) fields in
    (match points with
     | first :: second :: remaining -> Ok (Templates.Diagram.Polyline { id; points = (first, second :: remaining); tone })
     | _ -> Error "expected polyline with at least two points")
  | _ -> Error "expected diagram primitive"

and decode_code json fields =
  let* header = decode_generated code_of_json (without_fields ["highlights"] json) in
  let* highlights = required "highlights" (decode_list decode_code_highlight) fields in
  Ok (Types.Code {
    Templates.Code.kind = header.kind;
    id = header.id;
    path = header.path;
    language = header.language;
    line_start = header.line_start;
    source = header.source;
    highlights;
  })

and decode_code_highlight json =
  let* fields = decode_object json in
  let* id = required "id" decode_string fields in
  let* start_line = required "start_line" decode_int fields in
  let* end_line = required "end_line" decode_int fields in
  let* label = required "label" decode_string fields in
  let* tone_value = required "tone" decode_string fields in
  let* tone = decode_code_tone tone_value in
  Ok { Templates.Code.id; start_line; end_line; label; tone }

and decode_broken fields =
  let* details = required "details" decode_string fields in
  Ok (Types.Broken (Templates.Broken.Hard details))

let decode_string_template value =
  try decode_template (Yojson.Basic.from_string value)
  with Yojson.Json_error error -> Error error

let encode_input_value = function
  | Types.Int value -> `Int value
  | Types.String value -> `String value

let encode_button_action = function
  | Templates.Button.Submit -> "Submit"
  | Templates.Button.Navigate url -> "Navigate:" ^ url
  | Templates.Button.Custom action -> action

let encode_input input =
  let fields = [
    ("kind", `String input.Templates.Input.kind);
    ("id", `String input.id);
  ] in
  match input.value with
  | Some value -> `Assoc (fields @ [("value", encode_input_value value)])
  | None -> `Assoc fields

let encode_select select =
  select_to_json {
    kind = select.Templates.Select.kind;
    id = select.id;
    label = select.label;
    options = Stdlib.List.map (fun (option_ : Templates.Select.option_) -> {
      value = option_.Templates.Select.value;
      label = option_.label;
    }) select.options;
    selected = select.selected;
  }

let encode_button button =
  button_to_json {
    kind = button.Templates.Button.kind;
    id = button.id;
    label = button.label;
    action = encode_button_action button.action;
    disabled = button.disabled;
  }

let encode_submittable_field = function
  | Types.FieldInput input -> encode_input input
  | Types.FieldSelect select -> encode_select select

let rec encode_template = function
  | Types.Text value -> text_to_json {
      kind = value.kind;
      id = value.id;
      text_type = Templates.Text.string_of_text_type value.text_type;
      value = value.content;
    }
  | Types.Image value -> image_to_json {
      kind = value.kind;
      id = value.id;
      src = value.src;
      alt = value.alt;
    }
  | Types.Submittable value ->
    let fields = [
      ("kind", `String value.kind);
      ("id", `String value.id);
      ("value", `List (Stdlib.List.map encode_submittable_field value.value));
    ] in
    (match value.button with
     | Some button -> `Assoc (fields @ [("button", encode_button button)])
     | None -> `Assoc fields)
  | Types.Container value ->
    let header = container_to_json {
      kind = value.kind;
      id = value.id;
      direction = Templates.Container.string_of_direction value.direction;
    } in
    (match header with
     | `Assoc fields -> `Assoc (fields @ [("children", `List (Stdlib.List.map encode_template value.children))])
     | _ -> assert false)
  | Types.Broken (Templates.Broken.Soft details)
  | Types.Broken (Templates.Broken.Hard details) -> `Assoc [
      ("kind", `String "error");
      ("details", `String details);
    ]
  | Types.Badge value -> badge_to_json {
      kind = value.kind;
      id = value.id;
      label = value.label;
      variant = Templates.Badge.string_of_badge_variant value.variant;
    }
  | Types.List value ->
    let header = template_list_to_json {
      kind = value.kind;
      id = value.id;
      ordered = value.ordered;
    } in
    (match header with
     | `Assoc fields -> `Assoc (fields @ [("children", `List (Stdlib.List.map encode_template value.children))])
     | _ -> assert false)
  | Types.Stat value -> stat_to_json {
      kind = value.kind;
      id = value.id;
      label = value.label;
      value = value.value;
      secondary = value.secondary;
    }
  | Types.Divider value -> divider_to_json {
      kind = value.kind;
      id = value.id;
      label = value.label;
    }
  | Types.Diagram value -> encode_diagram value
  | Types.Code value -> encode_code value

and encode_diagram value =
  let header = diagram_to_json {
    kind = value.Templates.Diagram.kind;
    id = value.id;
    title = value.title;
    size = encode_diagram_size value.size;
  } in
  match header with
  | `Assoc fields -> `Assoc (fields @ [("primitives", `List (Stdlib.List.map encode_diagram_primitive value.primitives))])
  | _ -> assert false

and encode_diagram_size = function
  | Templates.Diagram.Compact -> "compact"
  | Templates.Diagram.Regular -> "regular"
  | Templates.Diagram.Tall -> "tall"

and encode_diagram_tone = function
  | Templates.Diagram.Primary -> "primary"
  | Templates.Diagram.Secondary -> "secondary"
  | Templates.Diagram.Success -> "success"
  | Templates.Diagram.Warning -> "warning"
  | Templates.Diagram.Danger -> "danger"
  | Templates.Diagram.Muted -> "muted"

and encode_point point = `Assoc [("x", `Int point.Templates.Diagram.x); ("y", `Int point.y)]

and encode_diagram_primitive = function
  | Templates.Diagram.Text { id; at; value; tone } -> `Assoc [
      ("shape", `String "text"); ("id", `String id); ("at", encode_point at);
      ("value", `String value); ("tone", `String (encode_diagram_tone tone));
    ]
  | Templates.Diagram.Line { id; from_; to_; tone }
  | Templates.Diagram.Arrow { id; from_; to_; tone } as primitive ->
    let shape = match primitive with Templates.Diagram.Line _ -> "line" | Templates.Diagram.Arrow _ -> "arrow" | _ -> assert false in
    `Assoc [("shape", `String shape); ("id", `String id); ("from", encode_point from_); ("to", encode_point to_); ("tone", `String (encode_diagram_tone tone))]
  | Templates.Diagram.Rectangle { id; at; width; height; tone } -> `Assoc [
      ("shape", `String "rectangle"); ("id", `String id); ("at", encode_point at);
      ("width", `Int width); ("height", `Int height); ("tone", `String (encode_diagram_tone tone));
    ]
  | Templates.Diagram.Circle { id; at; radius; tone } -> `Assoc [
      ("shape", `String "circle"); ("id", `String id); ("at", encode_point at);
      ("radius", `Int radius); ("tone", `String (encode_diagram_tone tone));
    ]
  | Templates.Diagram.Polyline { id; points = (first, remaining); tone } -> `Assoc [
      ("shape", `String "polyline"); ("id", `String id);
      ("points", `List (Stdlib.List.map encode_point (first :: remaining)));
      ("tone", `String (encode_diagram_tone tone));
    ]

and encode_code value =
  let header = code_to_json {
    kind = value.Templates.Code.kind;
    id = value.id;
    path = value.path;
    language = value.language;
    line_start = value.line_start;
    source = value.source;
  } in
  match header with
  | `Assoc fields -> `Assoc (fields @ [("highlights", `List (Stdlib.List.map encode_code_highlight value.highlights))])
  | _ -> assert false

and encode_code_tone = function
  | Templates.Code.Primary -> "primary"
  | Templates.Code.Secondary -> "secondary"
  | Templates.Code.Success -> "success"
  | Templates.Code.Warning -> "warning"
  | Templates.Code.Danger -> "danger"
  | Templates.Code.Muted -> "muted"

and encode_code_highlight highlight = `Assoc [
    ("id", `String highlight.Templates.Code.id);
    ("start_line", `Int highlight.start_line);
    ("end_line", `Int highlight.end_line);
    ("label", `String highlight.label);
    ("tone", `String (encode_code_tone highlight.tone));
  ]
