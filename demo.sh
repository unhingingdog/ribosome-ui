#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVER_PORT="${RIBOSOME_SERVER_PORT:-8787}"
SESSION_ID="${RIBOSOME_SESSION_ID:-rs-1}"
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
    echo "─── OpenCode log ───"
    cat "$LOG_DIR/opencode.log" 2>/dev/null || true
    echo ""
    echo "─── Web log ───"
    cat "$LOG_DIR/web.log" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$LOG_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "  Ribosome UI Demo  (OpenCode integrated mode)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── 1. Build OCaml server ────────────────────────────────────
echo "[1/5] Building ribosome-server…"
cd "$ROOT"
opam exec -- dune build @all 2>&1 | tail -1
echo "  ✓ built"

# ── 2. Build opencode-adapter ────────────────────────────────
echo "[2/5] Building opencode-adapter…"
cd "$ROOT/adapters/opencode"
npm run build 2>&1 | tail -1
echo "  ✓ built"

# ── 3. Install plugin and skills ──────────────────────────────
echo "[3/5] Installing plugin and skills…"
mkdir -p "$HOME/.config/opencode/plugins"
cat > "$HOME/.config/opencode/plugins/ribosome.js" << PLUGIN
export { default } from "$ROOT/adapters/opencode/dist/src/entry.js";
PLUGIN

SKILL_DST="$HOME/.config/opencode/skills"
mkdir -p "$SKILL_DST"
for skill_dir in "$ROOT/skills"/*/; do
  name="$(basename "$skill_dir")"
  if [ -f "$skill_dir/SKILL.md" ]; then
    mkdir -p "$SKILL_DST/$name"
    cp "$skill_dir/SKILL.md" "$SKILL_DST/$name/SKILL.md"
  fi
done
echo "  ✓ plugin and skills installed"

# ── 4. Start ribosome-server (HTTP/WS only) ──────────────────
echo "[4/5] Starting ribosome-server on port $SERVER_PORT…"
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
echo "  ✓ server running (pid ${PIDS[-1]})"

# ── 4b. Start OpenCode serve (loads adapter plugin) ──────────
echo "  Starting OpenCode server (headless)…"
RIBOSOME_DEBUG="$DEBUG" opencode serve --port 4097 \
  > "$LOG_DIR/opencode.log" 2>&1 &
PIDS+=($!)
for i in $(seq 1 15); do
  if curl -s --max-time 2 http://127.0.0.1:4097/global/health > /dev/null 2>&1; then
    break
  fi
  sleep 1
done
# Create a session to trigger plugin load (plugins load lazily in serve mode)
curl -s --max-time 10 -X POST http://127.0.0.1:4097/session \
  -H "Content-Type: application/json" -d '{"title":"ribosome"}' > /dev/null 2>&1 || true
sleep 2
echo "  ✓ opencode server ready"

# ── 5. Start web UI ──────────────────────────────────────────
echo "[5/5] Starting web client…"
cd "$ROOT/frontends"
pnpm install --frozen-lockfile 2>&1 | tail -1
RIBOSOME_DEBUG="$DEBUG" pnpm --filter @ribosome/web dev > "$LOG_DIR/web.log" 2>&1 &
PIDS+=($!)
sleep 2
echo "  ✓ web client ready"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Web:       http://localhost:5173?session_id=$SESSION_ID"
echo "  Storybook: http://localhost:5173/templates"
echo "  TUI:       cd frontends && pnpm --filter @ribosome/tui dev $SESSION_ID"
echo "  Logs:      $LOG_DIR/{opencode,web}.log"
echo ""
echo "  Open the web URL, type a subject, click Submit."
echo "  The headless agent will generate a template and the"
echo "  UI will update in real-time."
echo ""
if [ "$DEBUG" = "1" ]; then
  echo "  Debug logs active. RIBOSOME_DEBUG=0 ./demo.sh to silence."
fi
echo ""
echo "  Ctrl+C to stop."
echo "═══════════════════════════════════════════════════════════"
echo ""

wait
