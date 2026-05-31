open React
open Types

type 'props component = 'props -> element
type 'props component_match = ('props component * 'props)

type submittable_props = {
  kind: string;
  id: string;
  value: input list;
  on_submit: SubmitTypes.submission_payload -> unit;
}

type template_component = 
  | Input of input component
  | Submittable of submittable_props component
  | Image of image component
  | Text of text component
  | Container of container component
  | Broken of broken component 

type component_registry = {
  input: input component option;
  submittable: submittable_props component option;
  image: image component option;
  text: text component option;
  container: container component;
  broken: string component;
}

let render component props = 
  React.createElement component props

let broken_message component_type =
  ("Used missing component: " ^ component_type)

let submittable_to_props (submittable: submittable) on_submit = {
  kind = submittable.kind;
  id = submittable.id;
  value = submittable.value;
  on_submit;
}

let rec render_template_with_submit
  (template: template)
  (registry: component_registry)
  (on_submit: SubmitTypes.submission_payload -> unit)
  : element =
  match template with 
    | Container container -> 
        let children = List.map (fun sub_template -> render_template_with_submit sub_template registry on_submit) container.children in
        React.createElementVariadic registry.container container (Array.of_list children)

    | Input input ->  
      (match registry.input with
      | Some c ->  render c input
      | None -> (render registry.broken (broken_message "input")))

    | Submittable submittable ->  
      (match registry.submittable with
      | Some c ->  render c (submittable_to_props submittable on_submit)
      | None -> (render registry.broken (broken_message "submittable")))

    | Image image ->  
      (match registry.image with
      | Some c ->  render c image
      | None -> (render registry.broken (broken_message "image")))

    | Text text ->  
      (match registry.text with
      | Some c ->  render c text 
      | None -> (render registry.broken (broken_message "text")))

    | Broken broken ->  
      let c = registry .broken in
      match broken with
      | Soft message ->  render c message 
      | Hard message -> render c message

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
