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

type container = {
  kind: string;
  id: string;
  children: container_child list 
} and container_child = 
  | Input of input 
  | Submittable of submittable  
  | Container of container
  | Image of image
  | Text of text [@@deriving json]

type template = 
  | Input of input
  | Submittable of submittable
  | Image of image
  | Text of text 
  | Container of container [@@deriving json]
