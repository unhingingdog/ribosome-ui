open Types

(* The below is regrettable, but better than a js FFI hack at createElement. Reconsider *)

module Keyable = struct
  type keyed_text = {
    key: string;
    id: string;
    kind: string;
    text_type: text_type;
    content: string;
  }

  type keyed_image = {
    key: string;
    id: string;
    kind: string;
    src: string;
    alt: string;
  }

  type keyed_badge = {
    key: string;
    id: string;
    kind: string;
    label: string;
    variant: badge_variant;
  }

  type keyed_stat = {
    key: string;
    id: string;
    kind: string;
    label: string;
    value: string;
    secondary: string option;
  }

  type keyed_divider = {
    key: string;
    id: string;
    kind: string;
    label: string option;
  }

  type keyed_broken = {
    key: string;
    message: string;
  }

  type keyed_submittable = {
    key: string;
    id: string;
    kind: string;
    value: Templates.Submittable.field list;
    button: button option;
    on_submit: SubmitTypes.submission_payload -> unit;
  }

  type keyed_container = {
    key: string;
    id: string;
    kind: string;
  }

  type keyed_list = {
    key: string;
    id: string;
    kind: string;
    ordered: bool option;
  }
end

open Keyable

let text_to_keyed (text: text) : keyed_text = {
  key = text.id;
  id = text.id;
  kind = text.kind;
  text_type = text.text_type;
  content = text.content;
}

let image_to_keyed (image: image) : keyed_image = {
  key = image.id;
  id = image.id;
  kind = image.kind;
  src = image.src;
  alt = image.alt;
}

let badge_to_keyed (badge: badge) : keyed_badge = {
  key = badge.id;
  id = badge.id;
  kind = badge.kind;
  label = badge.label;
  variant = badge.variant;
}

let stat_to_keyed (stat: stat) : keyed_stat = {
  key = stat.id;
  id = stat.id;
  kind = stat.kind;
  label = stat.label;
  value = stat.value;
  secondary = stat.secondary;
}

let divider_to_keyed (divider: divider) : keyed_divider = {
  key = divider.id;
  id = divider.id;
  kind = divider.kind;
  label = divider.label;
}

let broken_to_keyed = function
  | Soft message -> { key = "broken"; message }
  | Hard message -> { key = "broken"; message }

let submittable_to_keyed (submittable: submittable) on_submit : keyed_submittable = {
  key = submittable.id;
  id = submittable.id;
  kind = submittable.kind;
  value = submittable.value;
  button = submittable.button;
  on_submit;
}

let container_to_keyed (container: container) : keyed_container = {
  key = container.id;
  id = container.id;
  kind = container.kind;
}

let list_to_keyed (list: template_list) : keyed_list = {
  key = list.id;
  id = list.id;
  kind = list.kind;
  ordered = list.ordered;
}
