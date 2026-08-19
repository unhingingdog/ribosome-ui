type tone = Primary | Secondary | Success | Warning | Danger | Muted

type highlight = {
  id: string;
  start_line: int;
  end_line: int;
  label: string;
  tone: tone;
}

type t = {
  kind: string;
  id: string;
  path: string;
  language: string;
  line_start: int;
  source: string;
  highlights: highlight list;
}

let definition : TemplateDefinitionTypes.template_definition =
  let open TemplateDefinitionTypes in
  {
    kind = "code";
    intent = "Show a relevant source snippet with labelled highlighted ranges.";
    instructions = "Use code only for a source-code topic. Provide a concise, self-contained snippet from the relevant file, not invented code. path is repository-relative, language names the source language, and line_start is the absolute line number of the first source line. highlights is an ordered list of non-overlapping inclusive ranges. Every highlight has a stable id, start_line, end_line, short label, and tone: primary, secondary, success, warning, danger, or muted. Keep source indentation exact. Preserve the code and highlight ids when the logical snippet remains the same.";
    fields = [
      kind_field "code";
      id_field "code view";
      string_field "path" "Repository-relative path for the displayed snippet.";
      string_field "language" "Source language name.";
      field "line_start" NumberField "Absolute line number of the first source line.";
      string_field "source" "Exact, concise source snippet.";
      array_field "highlights" "Ordered labelled source-line ranges.";
    ];
  }
