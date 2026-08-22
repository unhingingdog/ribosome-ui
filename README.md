# Ribosome

Native OCaml server that turns a coding-agent harness into a generative-UI runtime.

See `architecture.md` for the full design and `plan.md` for the build plan.

## Packages

| Package | Description |
|---|---|
| `telomere` | Incremental JSON completion for streamed LLM output |
| `ribosome` | Typed template ADT, codec, validation, reconciliation, session state |
| `ribosome-server` | MCP control, harness stream, and WebSocket UI transport |

## Build

```bash
opam exec -- dune build @all
```

## Test

```bash
opam exec -- dune runtest
```

## Format

```bash
opam exec -- dune fmt
```
