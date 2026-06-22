open React
open Types

type 'props component = 'props -> element
type 'props component_match = ('props component * 'props)

module Keyable = FrontendKeyable.Keyable

type template_component =
  | Submittable of Keyable.keyed_submittable component
  | Image of Keyable.keyed_image component
  | Text of Keyable.keyed_text component
  | Container of Keyable.keyed_container component
  | Badge of Keyable.keyed_badge component
  | List of Keyable.keyed_list component
  | Stat of Keyable.keyed_stat component
  | Divider of Keyable.keyed_divider component
  | Broken of Keyable.keyed_broken component

type component_registry = {
  submittable: Keyable.keyed_submittable component option;
  image: Keyable.keyed_image component option;
  text: Keyable.keyed_text component option;
  container: Keyable.keyed_container component;
  button: button component option;
  badge: Keyable.keyed_badge component option;
  list: Keyable.keyed_list component option;
  stat: Keyable.keyed_stat component option;
  divider: Keyable.keyed_divider component option;
  broken: Keyable.keyed_broken component;
}

let render component props =
  React.createElement component props

let broken_message component_type =
  { Keyable.key = "broken"; message = ("Used missing component: " ^ component_type) }

let rec render_template_with_submit
  (template: template)
  (registry: component_registry)
  (on_submit: SubmitTypes.submission_payload -> unit)
  : element =
  match template with
    | Container container ->
        let children = List.map (fun sub_template -> render_template_with_submit sub_template registry on_submit) container.children in
        React.createElementVariadic registry.container (FrontendKeyable.container_to_keyed container) (Array.of_list children)

    | List list ->
        let children = List.map (fun sub_template -> render_template_with_submit sub_template registry on_submit) list.children in
        (match registry.list with
        | Some c -> React.createElementVariadic c (FrontendKeyable.list_to_keyed list) (Array.of_list children)
        | None -> (render registry.broken (broken_message "list")))

    | Submittable submittable ->
      (match registry.submittable with
      | Some c ->  render c (FrontendKeyable.submittable_to_keyed submittable on_submit)
      | None -> (render registry.broken (broken_message "submittable")))

    | Image image ->
      (match registry.image with
      | Some c ->  render c (FrontendKeyable.image_to_keyed image)
      | None -> (render registry.broken (broken_message "image")))

    | Text text ->
      (match registry.text with
      | Some c ->  render c (FrontendKeyable.text_to_keyed text)
      | None -> (render registry.broken (broken_message "text")))

    | Badge badge ->
      (match registry.badge with
      | Some c -> render c (FrontendKeyable.badge_to_keyed badge)
      | None -> (render registry.broken (broken_message "badge")))

    | Stat stat ->
      (match registry.stat with
      | Some c -> render c (FrontendKeyable.stat_to_keyed stat)
      | None -> (render registry.broken (broken_message "stat")))

    | Divider divider ->
      (match registry.divider with
      | Some c -> render c (FrontendKeyable.divider_to_keyed divider)
      | None -> (render registry.broken (broken_message "divider")))

    | Broken broken ->
      let c = registry.broken in
      match broken with
      | Soft message ->  render c (FrontendKeyable.broken_to_keyed (Soft message))
      | Hard message -> render c (FrontendKeyable.broken_to_keyed (Hard message))

let render_template (template: template) (registry: component_registry) : element =
  render_template_with_submit template registry (fun _ -> ())

type dom_handle =
  | Element of Dom.element 
  | Id of string

let create_renderer handle =
  let element = match handle with
    | Element e -> Some e
    | Id id -> ReactDOM.querySelector ("#" ^ id)
  in
  match element with
  | Some el -> 
      let root = ReactDOM.Client.createRoot el in
      Some (ReactDOM.Client.render root)
  | None -> None
