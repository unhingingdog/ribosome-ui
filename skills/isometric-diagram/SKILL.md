---
name: isometric-diagram
description: Render architecture, infrastructure, or topology diagrams in 2:1 isometric projection using Ribosome diagram primitives. Use when the user asks for an isometric diagram, 3D architecture view, isometric topology, or wants to see system components arranged with depth.
---

# Isometric Diagram

Use the `ribosome` skill for syntax and stable IDs. Emit exactly one Ribosome JSON template. Emit no prose, Markdown fences, or surrounding text.

This skill produces isometric block diagrams — services, databases, queues, gateways arranged in true 2:1 isometric projection — using only Ribosome's `diagram` primitives. Every block has three visible faces: top (diamond), left face, and right face.

## Canvas

The diagram `size` is an object with integer `width` and `height`. This skill uses a `400 × 200` canvas. All coordinates are integers within those bounds: `x` from 0 to `width`, `y` from 0 to `height`.

## Grid Math (2:1 Isometric)

Choose a tile width `TW` divisible by 4 so that every division by 2 yields an integer. Set `TH = TW / 2`.

```
TW = 12, TH = 6
OX = 200, OY = 40   // grid origin — places grid top-center
```

Grid-to-screen projection for tile (col, row):

```
screenX = OX + (col - row) * (TW / 2)
screenY = OY + (col + row) * (TH / 2)
```

All values are integers. Never emit fractional coordinates.

## Drawing a Block

Each block is three polylines — top, left face, right face. All coordinates use the grid math above, with `h` as block height in integer screen units.

```
topFace = polyline [
  {x: screenX,          y: screenY - h},          // top point
  {x: screenX + TW/2,   y: screenY - h + TH/2},   // right point
  {x: screenX,          y: screenY - h + TH},      // bottom point
  {x: screenX - TW/2,   y: screenY - h + TH/2}     // left point
]

leftFace = polyline [
  {x: screenX - TW/2,   y: screenY - h + TH/2},   // top-left of top
  {x: screenX - TW/2,   y: screenY + TH/2},        // bottom-left at ground
  {x: screenX,          y: screenY + TH},           // bottom-center at ground
  {x: screenX,          y: screenY - h + TH}        // bottom-center of top
]

rightFace = polyline [
  {x: screenX,          y: screenY - h + TH},      // bottom-center of top
  {x: screenX,          y: screenY + TH},           // bottom-center at ground
  {x: screenX + TW/2,   y: screenY + TH/2},         // bottom-right at ground
  {x: screenX + TW/2,   y: screenY - h + TH/2}      // top-right of top
]
```

For a flat platform (h = 0), omit left and right faces — just the diamond top.

**Tones**: Use `"Default"` for the top face, `"Warning"` for the left face, `"Positive"` for the right face. This creates a consistent light-source-from-top-left illusion.

**Block label**: Place a `text` primitive at `{x: screenX, y: screenY - h + TH/2}` (center of the top face), `tone: "Info"`.

**Ground shadow (optional)**: A flat diamond at the base with `tone: "Warning"`, drawn before the block faces so it appears underneath.

Example block at grid (2, 1), height 8, TW=12:

screenX = 200 + (2-1)*6 = 206
screenY = 40 + (2+1)*3 = 49

```json
{"kind":"polyline","points":[{"x":206,"y":41},{"x":212,"y":44},{"x":206,"y":47},{"x":200,"y":44}],"tone":"Warning"},
{"kind":"polyline","points":[{"x":206,"y":33},{"x":212,"y":36},{"x":206,"y":39},{"x":200,"y":36}],"tone":"Default"},
{"kind":"polyline","points":[{"x":200,"y":36},{"x":200,"y":44},{"x":206,"y":47},{"x":206,"y":39}],"tone":"Warning"},
{"kind":"polyline","points":[{"x":206,"y":39},{"x":206,"y":47},{"x":212,"y":44},{"x":212,"y":36}],"tone":"Positive"},
{"kind":"text","text":"API","position":{"x":206,"y":37},"tone":"Info"}
```

## Depth Sorting

Ribosome paints primitives in source order. Blocks must be emitted sorted by `col + row` (ascending). Blocks further back draw first so front blocks occlude them.

Secondary sort: within the same (col+row), lower height blocks before taller ones.

## Connections (Arrows)

Arrows between blocks connect from the center of one block's right or bottom edge to another's left or top edge.

For an arrow from block A (colA, rowA) to block B (colB, rowB):

```
startX = OX + (colA - rowA) * (TW/2) + TW/2
startY = OY + (colA + rowA) * (TH/2) + TH/2
endX = OX + (colB - rowB) * (TW/2) - TW/2
endY = OY + (colB + rowB) * (TH/2) + TH/2
```

Draw arrows after all blocks so they render on top. Use `tone: "Info"` for the primary flow, `tone: "Default"` for secondary.

Arrow with label:

```json
{"kind":"arrow","start":{"x":212,"y":44},"stop":{"x":164,"y":68},"tone":"Info"},
{"kind":"text","text":"HTTPS","position":{"x":188,"y":54},"tone":"Info"}
```

## Zone Boundaries (Optional)

Group blocks into zones (e.g. "Public", "Private", "Data") using rectangles drawn before the blocks they contain. Use `tone: "Default"` for a border-only rectangle.

```json
{"kind":"rectangle","origin":{"x":100,"y":30},"size":{"width":200,"height":120},"tone":"Default"}
```

## Layout

Emit a root `container` with `id: "isometric-root"`, a `text` title, and the `diagram` template. If there's a legend, add it as a horizontal `container` of `badge` components below the diagram.

```json
{"kind":"container","id":"isometric-root","direction":"Vertical","children":[
  {"kind":"text","id":"iso-title","text_type":"H2","value":"System Topology"},
  {"kind":"diagram","id":"iso-diagram","title":"Infrastructure","size":{"width":400,"height":200},"primitives":[
    {"kind":"rectangle","origin":{"x":100,"y":30},"size":{"width":200,"height":120},"tone":"Default"}
  ]}
]}
```

## Cheat Sheet

| Concept | Formula / Method |
|---|---|
| Canvas | `{"width":400,"height":200}` |
| Grid origin | `OX = 200, OY = 40` (adjust for grid size) |
| Tile size | `TW = 12, TH = 6` (2:1 ratio, TW divisible by 4) |
| grid → screen X | `OX + (col - row) * (TW / 2)` |
| grid → screen Y | `OY + (col + row) * (TH / 2)` |
| Top face | Diamond polyline, 4 points |
| Left face | Parallelogram polyline, 4 points |
| Right face | Parallelogram polyline, 4 points |
| Top tone | `"Default"` (brightest) |
| Left tone | `"Warning"` (medium) |
| Right tone | `"Positive"` (between top and left) |
| Label position | Center of top face diamond |
| Sort order | Ascending by `col + row`, then by height |
| Arrow routing | Direct from edge midpoint to edge midpoint |
| Arrow tone | `"Info"` for primary, `"Default"` for secondary |

## Boundaries

- This is for static architecture/topology diagrams, not interactive scenes.
- Keep the grid manageable — 6×6 is the sweet spot for readable block sizes with labels.
- Do not draw more than 12 blocks. Beyond that, readability degrades. Split into multiple diagrams.
- All coordinates must be integers. Never emit fractional values.
