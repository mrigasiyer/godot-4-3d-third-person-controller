#!/bin/bash
# export_run.sh <run-name>
# Builds an isolated rollout snapshot for one agent run:
#   ~/rollouts/<run-name>/  =  git archive of task/jumppad-ablation
#                              + fresh git init (no history/remotes)
#                              + per-harness MCP configs (godot-mcp)
#                              + pre-imported Godot asset cache
# The snapshot contains ONLY the ablated game + SPEC.md. No verifier, no
# original, no branches, no reachable history.
set -euo pipefail

RUN_NAME="${1:?usage: export_run.sh <run-name>   e.g. fable5-1}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_DIR="$HOME/rollouts/$RUN_NAME"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

if [ -e "$RUN_DIR" ]; then
  echo "ERROR: $RUN_DIR already exists - every run gets a virgin snapshot." >&2
  exit 1
fi
mkdir -p "$RUN_DIR"

# 1. Export the ablation branch (tracked files only - no .git, no excludes)
git -C "$REPO" archive task/jumppad-ablation | tar -x -C "$RUN_DIR"

# 2. Fresh history starting at the snapshot
git -C "$RUN_DIR" init -q
git -C "$RUN_DIR" add -A
git -C "$RUN_DIR" -c user.name=rollout -c user.email=rollout@local \
  commit -qm "task snapshot"

# 3. MCP configs (godot-mcp) for each harness that reads project-local config
#    Claude Code:
cat > "$RUN_DIR/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["@coding-solo/godot-mcp"],
      "env": { "GODOT_PATH": "/Applications/Godot.app/Contents/MacOS/Godot" }
    }
  }
}
EOF
#    Gemini CLI:
mkdir -p "$RUN_DIR/.gemini"
cat > "$RUN_DIR/.gemini/settings.json" <<'EOF'
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["@coding-solo/godot-mcp"],
      "env": { "GODOT_PATH": "/Applications/Godot.app/Contents/MacOS/Godot" }
    }
  }
}
EOF
#    OpenCode:
cat > "$RUN_DIR/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "godot": {
      "type": "local",
      "command": ["npx", "@coding-solo/godot-mcp"],
      "environment": { "GODOT_PATH": "/Applications/Godot.app/Contents/MacOS/Godot" }
    }
  }
}
EOF
#    (Codex reads MCP servers from global ~/.codex/config.toml - one-time
#     setup, see codex_mcp_snippet.toml next to this script.)

# 4. Pre-import assets so no agent wastes effort on import friction
"$GODOT" --headless --path "$RUN_DIR" --import >/dev/null 2>&1 || true

echo "READY: $RUN_DIR"
