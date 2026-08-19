type size = Compact | Regular | Tall

type tone = Primary | Secondary | Success | Warning | Danger | Muted

type point = { x: int; y: int }

type primitive =
  | Text of { id: string; at: point; value: string; tone: tone }
  | Line of { id: string; from_: point; to_: point; tone: tone }
  | Arrow of { id: string; from_: point; to_: point; tone: tone }
  | Rectangle of { id: string; at: point; width: int; height: int; tone: tone }
  | Circle of { id: string; at: point; radius: int; tone: tone }
  | Polyline of { id: string; points: point * point list; tone: tone }

type t = {
  kind: string;
  id: string;
  title: string;
  size: size;
  primitives: primitive list;
}

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "diagram";
    intent = "Draw a self-contained explanatory diagram on a 100 by 100 canvas.";
    instructions = "Use diagram when a visual explanation makes a flow, relationship, or structure clearer. The canvas coordinates are integer percentages: x runs left to right and y runs top to bottom, both from 0 to 100. Choose compact, regular, or tall for size. Primitives are painted in source order. Every primitive needs a stable id and a named tone: primary, secondary, success, warning, danger, or muted. Use text with at and value; line and arrow with from and to; rectangle with top-left at, width, and height; circle with centre at and radius; and polyline with at least two points. Preserve diagram and primitive ids when updating an existing diagram. Do not use images, RGB values, executable content, or Ratatui-specific properties.";
    fields = [
      kind_field "diagram";
      id_field "diagram";
      string_field "title" "Short title shown above the diagram.";
      string_field "size" "One of compact, regular, or tall.";
      array_field "primitives" "Ordered drawing primitives for the 100 by 100 canvas.";
    ];
  }
