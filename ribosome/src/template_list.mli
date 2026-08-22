val definition : Template_definition.t

type 'a t = { id : string; ordered : bool option; children : 'a list }
