# Ribosome

Native OCaml MCP server that turns an agent harness into a generative-UI runtime. The agent calls `tools/call start` over MCP stdio; harness deltas stream through Telomere into a typed template ADT; UI clients receive revisioned updates by stable ID.

```
           ┌──────────┐     ┌───────────┐     ┌──────────┐
  Harness  │   MCP    │     │  Telomere  │     │    UI    │
  ───────► │ stdio    │────►│  → ADT     │────►│ WebSocket│────► Client
           │ start    │     │  → reconcile│    │          │
           └──────────┘     └───────────┘     └──────────┘
```

## Quick start

<!-- TODO: write quick start guide -->
```
opam install . --deps-only --with-test --yes
opam exec -- dune build @all
opam exec -- ribosome-server
```

<!-- TODO: describe --port, --mcp-port, etc -->

## Documentation

| Document | Purpose |
|---|---|
| [`architecture.md`](./architecture.md) | Full architecture, invariants, template ADT, planes, session state |
| [`PROTOCOL.md`](./PROTOCOL.md) | Wire formats, adapter HOWTO, UI client HOWTO |
| [`plan.md`](./plan.md) | Build plan and task history |

## Packages

```
telomere ──► ribosome ──► ribosome-server
                 │                    │
          adapters/opencode     frontends/packages
          (TypeScript)          ├── ui-core (shared)
                               ├── web (Solid → DOM)
                               └── tui (@opentui/solid → terminal)
```

| Package | Tests | Purpose |
|---|---|---|
| `telomere` | 44 | Incremental JSON completion |
| `ribosome` | 93 | Template ADT, validation, reconciliation, session |
| `ribosome-server` | 7 + integration | MCP, harness stream, UI WebSocket transport |
| `adapters/opencode` | 80 | Thin TypeScript harness adapter |
| `frontends/ui-core` | 64 | Shared types, codec, transport, Solid store, renderer |
| `frontends/web` | — | Solid → DOM renderer + demo app |
| `frontends/tui` | — | @opentui/solid → terminal renderer + demo app |

## Build

```bash
opam exec -- dune build @all
opam exec -- dune runtest
opam exec -- dune fmt
```

## Adapter

```bash
cd adapters/opencode
npm ci
npx tsc --noEmit
npx vitest run
```

<!-- TODO: adapter usage, config, MCP setup -->

## Frontends

```bash
cd frontends
pnpm install
pnpm -r typecheck
pnpm -r test
pnpm dev:web          # Vite dev server
pnpm build:web        # Production build
pnpm dev:tui          # TUI client (run from frontends/)
```

## Migration from legacy (v0)

<!-- TODO: write migration guide -->

The previous Melange/React web implementation has been removed. There is no backward-compatible JS facade. The new architecture uses:

- MCP stdio for control (not HTTP)
- WebSocket for deltas and UI (not SSE poll)
- Typed OCaml ADT (not dynamic template registry in JS)

## Security

<!-- TODO: write security guidance -->

- Loopback binding by default
- Channel nonce expectations
- Harness adapters can inject user turns
- Log redaction

## License

<!-- TODO -->
