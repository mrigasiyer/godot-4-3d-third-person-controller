#!/bin/bash
# regrade_run.sh <run-name>
# Re-grades an already-captured run (runs/<run-name> branch) against the
# CURRENT verifier, without re-running the agent. Builds a throwaway
# worktree from that branch's already-materialized code, overlays the
# current verifier/, runs it, and updates rollout_evidence/grade.log with
# a new commit (old grade.log stays in history for comparison).
set -euo pipefail

RUN_NAME="${1:?usage: regrade_run.sh <run-name>}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
BRANCH="runs/$RUN_NAME"

WT="$(mktemp -d -t "regrade-$RUN_NAME")/wt"
git -C "$REPO" worktree add -q "$WT" "$BRANCH"

rm -rf "$WT/verifier"
git -C "$REPO" archive verifier verifier | tar -x -C "$WT"
"$GODOT" --headless --path "$WT" --import > /dev/null 2>&1 || true
set +e
"$GODOT" --headless --path "$WT" --script res://verifier/verify.gd \
  > "$WT/rollout_evidence/grade.log" 2>&1
set -e
rm -rf "$WT/verifier"
grep "=== SCORE" "$WT/rollout_evidence/grade.log" || echo "WARNING: no score line"

git -C "$WT" add rollout_evidence/grade.log
git -C "$WT" -c user.name=rollout -c user.email=rollout@local \
  commit -qm "Regrade $RUN_NAME against current verifier" --allow-empty

git -C "$REPO" worktree remove --force "$WT"
