val definition : Template_definition.t

type direction = Vertical | Horizontal
type 'a t = { id : string; direction : direction; children : 'a list }
