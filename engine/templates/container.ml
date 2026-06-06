type 'template t = {
  kind: string;
  id: string;
  children: 'template list
}

let of_json json =
  let open Melange_json.Of_json in
  {
    kind = field "kind" string json;
    id = field "id" string json;
    children = [];
  }
