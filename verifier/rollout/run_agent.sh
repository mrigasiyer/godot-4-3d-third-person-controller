#!/bin/bash
# run_agent.sh <agent> <n>
#   agent: fable5 | opus48 | sonnet | gemini3flash | gemini31pro | minimax
#   n:     run number (1, 2, 3, ...)
# Exports a virgin snapshot, launches the agent autonomously with the fixed
# kickoff prompt, and captures transcript + metadata under ~/rollouts/logs/.
set -euo pipefail

AGENT="${1:?usage: run_agent.sh <agent> <n>}"
N="${2:?usage: run_agent.sh <agent> <n>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_NAME="$AGENT-$N"
RUN_DIR="$HOME/rollouts/$RUN_NAME"
LOG_DIR="$HOME/rollouts/logs"
PROMPT="$(cat "$HERE/prompt.txt")"

mkdir -p "$LOG_DIR"
"$HERE/export_run.sh" "$RUN_NAME"

META="$LOG_DIR/$RUN_NAME.meta"
LOG="$LOG_DIR/$RUN_NAME.log"
{
  echo "run: $RUN_NAME"
  echo "agent: $AGENT"
  echo "started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$META"

cd "$RUN_DIR"
START=$SECONDS
set +e
case "$AGENT" in
  fable5)
    echo "harness: claude-code $(claude --version 2>/dev/null | head -1)" >> "$META"
    echo "model: fable (Claude Fable 5)" >> "$META"
    claude -p "$PROMPT" --model fable --verbose --output-format stream-json \
      > "$LOG" 2>&1
    ;;
  opus48)
    echo "harness: claude-code $(claude --version 2>/dev/null | head -1)" >> "$META"
    echo "model: opus (Claude Opus 4.8)" >> "$META"
    claude -p "$PROMPT" --model opus --verbose --output-format stream-json \
      > "$LOG" 2>&1
    ;;
  sonnet)
    echo "harness: claude-code $(claude --version 2>/dev/null | head -1)" >> "$META"
    echo "model: sonnet (Claude Sonnet)" >> "$META"
    claude -p "$PROMPT" --model sonnet --verbose --output-format stream-json \
      > "$LOG" 2>&1
    ;;
  gemini3flash)
    echo "harness: gemini-cli $(gemini --version 2>/dev/null | head -1)" >> "$META"
    echo "model: gemini-3-flash-preview" >> "$META"
    GEMINI_CLI_TRUST_WORKSPACE=true gemini -p "$PROMPT" \
      -m gemini-3-flash-preview --approval-mode yolo \
      > "$LOG" 2>&1
    ;;
  gemini31pro)
    echo "harness: opencode $(opencode --version 2>/dev/null | head -1)" >> "$META"
    echo "model: openrouter/google/gemini-3.1-pro-preview" >> "$META"
    opencode run --model openrouter/google/gemini-3.1-pro-preview "$PROMPT" \
      > "$LOG" 2>&1
    ;;
  minimax)
    echo "harness: opencode $(opencode --version 2>/dev/null | head -1)" >> "$META"
    echo "model: openrouter/minimax/minimax-m3" >> "$META"
    opencode run --model openrouter/minimax/minimax-m3 "$PROMPT" \
      > "$LOG" 2>&1
    ;;
  *)
    echo "unknown agent: $AGENT" >&2; exit 2 ;;
esac
EXIT_CODE=$?
set -e

{
  echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "wall_seconds: $((SECONDS - START))"
  echo "exit_code: $EXIT_CODE"
  echo "files_changed:"
  git -C "$RUN_DIR" status --porcelain
} >> "$META"

echo ""
echo "=== ROLLOUT DONE: $RUN_NAME (exit $EXIT_CODE, $((SECONDS - START))s) ==="
echo "transcript: $LOG"
echo "meta:       $META"
echo "diff stat:"
git -C "$RUN_DIR" diff --stat | tail -5
