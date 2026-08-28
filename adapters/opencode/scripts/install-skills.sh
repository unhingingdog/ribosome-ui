#!/usr/bin/env bash
set -euo pipefail

SKILL_SRC="$(cd "$(dirname "$0")/../../../skills" && pwd)"
SKILL_DST="${HOME}/.config/opencode/skills"

mkdir -p "$SKILL_DST"

for skill_dir in "$SKILL_SRC"/*/; do
  name="$(basename "$skill_dir")"
  if [ -f "$skill_dir/SKILL.md" ]; then
    mkdir -p "$SKILL_DST/$name"
    cp "$skill_dir/SKILL.md" "$SKILL_DST/$name/SKILL.md"
  fi
done
