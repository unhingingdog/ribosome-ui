#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVER_PORT="${RIBOSOME_SERVER_PORT:-8787}"
SESSION_ID="${RIBOSOME_SESSION_ID:-rs-1}"
SKIP_SERVER="${SKIP_SERVER:-0}"
DEBUG="${RIBOSOME_DEBUG:-1}"
LOG_DIR="$ROOT/.logs"
PIDS=()

cleanup() {
  echo ""
  echo "Shutting down…"
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  if [ "$DEBUG" = "1" ]; then
    echo ""
    echo "─── Server log ───"
    cat "$LOG_DIR/server.log" 2>/dev/null || true
    echo ""
    echo "─── Web log ───"
    cat "$LOG_DIR/web.log" 2>/dev/null || true
    echo ""
    echo "─── TUI log ───"
    cat "$LOG_DIR/tui.log" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$LOG_DIR"

if [ "$SKIP_SERVER" = "1" ]; then
  echo "═══════════════════════════════════════════════════════════"
  echo "  Ribosome UI Demo  (OpenCode mode — server spawned by OpenCode)"
  echo "═══════════════════════════════════════════════════════════"
  STEPS=3
else
  echo "═══════════════════════════════════════════════════════════"
  echo "  Ribosome UI Demo  (standalone mode — no harness)"
  echo "═══════════════════════════════════════════════════════════"
  STEPS=4
fi
echo ""

# ── 1. Build OCaml server ────────────────────────────────────
echo "[1/$STEPS] Building ribosome-server…"
cd "$ROOT"
opam exec -- dune build @all 2>&1 | tail -1
echo "  ✓ built"

if [ "$SKIP_SERVER" = "1" ]; then
  # ── 2. Install frontend deps ───────────────────────────────
  echo "[2/$STEPS] Installing frontend dependencies…"
  cd "$ROOT/frontends"
  pnpm install --frozen-lockfile 2>&1 | tail -1
  echo "  ✓ installed"
else
  # ── 2. Install frontend deps ───────────────────────────────
  echo "[2/$STEPS] Installing frontend dependencies…"
  cd "$ROOT/frontends"
  pnpm install --frozen-lockfile 2>&1 | tail -1
  echo "  ✓ installed"

  # ── 3. Start ribosome-server ───────────────────────────────
  echo "[3/$STEPS] Starting ribosome-server on port $SERVER_PORT…"
  cd "$ROOT"
  RIBOSOME_DEBUG="$DEBUG" "$ROOT/_build/default/ribosome-server/bin/main.exe" --port "$SERVER_PORT" \
    > "$LOG_DIR/server.log" 2>&1 &
  PIDS+=($!)
  sleep 1
  if ! kill -0 "${PIDS[-1]}" 2>/dev/null; then
    echo "  ✗ server failed to start"
    cat "$LOG_DIR/server.log"
    exit 1
  fi
  echo "  ✓ server running (pid ${PIDS[-1]})  logs: $LOG_DIR/server.log"
fi

# ── Start web + TUI ─────────────────────────────────────────
step=$STEPS
echo "[$step/$STEPS] Starting frontend clients…"

cd "$ROOT/frontends"
RIBOSOME_DEBUG="$DEBUG" pnpm --filter @ribosome/web dev > "$LOG_DIR/web.log" 2>&1 &
PIDS+=($!)
sleep 2
echo "  ✓ web client → http://localhost:5173?session_id=$SESSION_ID"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Web:         http://localhost:5173?session_id=$SESSION_ID"
echo "  Storybook:   http://localhost:5173/templates"
echo "  Logs:        $LOG_DIR/{server,web,tui}.log"
echo ""
if [ "$SKIP_SERVER" = "1" ]; then
  echo "  Server is NOT running — OpenCode will spawn it."
  echo ""
  echo "  OpenCode config (~/.config/opencode/opencode.jsonc):"
  echo ""
  echo '  "mcp": {'
  echo '    "ribosome": {'
  echo '      "type": "local",'
  echo '      "command": ["'"$ROOT"'/_build/default/ribosome-server/bin/main.exe", "--stdio", "--port", "'"$SERVER_PORT"'"],'
  echo '      "enabled": true'
  echo '    }'
  echo '  },'
  echo '  "plugin": {'
  echo '    "ribosome": ["@ribosome/opencode-adapter"]'
  echo '  }'
  echo ""
  echo "  Then start OpenCode. The web UI shows the home screen."
  echo "  Type a subject and submit — that triggers the agent."
else
  echo "  TUI:  cd frontends/packages/tui && RIBOSOME_DEBUG=1 bun --preload @opentui/solid/preload src/index.tsx $SESSION_ID"
  echo ""
  echo "  Server is running standalone (no harness attached)."
  echo "  The web UI shows the home screen with an input field."
  echo "  To use with OpenCode: SKIP_SERVER=1 ./demo.sh"
fi
if [ "$DEBUG" = "1" ]; then
  echo ""
  echo "  Debug logs active. RIBOSOME_DEBUG=0 ./demo.sh to silence."
fi
echo ""
echo "  Ctrl+C to stop."
echo "═══════════════════════════════════════════════════════════"
echo ""

wait
