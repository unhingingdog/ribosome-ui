open Melange_json.Primitives

type input_value = Int of int | String of string [@@deriving json]

type input = {
  kind: string;
  id: string;
  value: input_value 
} [@@deriving json]

type submittable = {
  kind: string;
  id: string;
  value: input list;
} [@@deriving json]

type image = {
  kind: string;
  id: string;
  src: string;
  alt: string;
} [@@deriving json]

type text_type = Paragraph | H1 | H2 | H3 | H4 | H5 | H6 [@@deriving json]
type text = {
  kind: string;
  id: string;
  text_type: text_type;
  content: string
} [@@deriving json]

type broken =
  | Soft  of string
  | Hard of string [@@deriving json]

type container = {
  kind: string;
  id: string;
  children: template list 
} and template = 
  | Input of input
  | Submittable of submittable
  | Image of image
  | Text of text 
  | Container of container 
  | Broken of broken

let container_of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    children = []
  }
