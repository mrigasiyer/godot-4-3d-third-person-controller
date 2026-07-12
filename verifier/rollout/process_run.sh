#!/bin/bash
# process_run.sh <run-name>
# For a finished rollout in ~/rollouts/<run-name>:
#   1. captures the agent's diff onto branch runs/<run-name> (from the
#      ablation base), with transcript + meta as committed evidence
#   2. telltale-scans the diff against the original implementation
#   3. grades it headless on a throwaway workspace (attempt + verifier overlay)
#   4. commits the grade report into the same branch
set -euo pipefail

RUN_NAME="${1:?usage: process_run.sh <run-name>}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_DIR="$HOME/rollouts/$RUN_NAME"
LOG_DIR="$HOME/rollouts/logs"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
BRANCH="runs/$RUN_NAME"

[ -d "$RUN_DIR" ] || { echo "no such run dir: $RUN_DIR" >&2; exit 1; }

# --- 1. extract the agent's diff (vs the snapshot root commit) --------------
cd "$RUN_DIR"
git add -A
git -c user.name=rollout -c user.email=rollout@local \
  commit -qm "agent attempt (post-run capture)" --allow-empty
ROOT="$(git rev-list --max-parents=0 HEAD)"
PATCH="$(mktemp -t "$RUN_NAME.patch")"
git diff "$ROOT"..HEAD -- . ':(exclude).godot' > "$PATCH"
echo "patch: $(wc -l < "$PATCH" | tr -d ' ') lines"

# --- 2. capture branch with evidence ----------------------------------------
WT="$(mktemp -d -t "capture-$RUN_NAME")/wt"
git -C "$REPO" worktree add -q -B "$BRANCH" "$WT" task/jumppad-ablation
if [ -s "$PATCH" ]; then
  git -C "$WT" apply --whitespace=nowarn "$PATCH"
fi
git -C "$WT" add -A
git -C "$WT" commit -qm "Agent attempt: $RUN_NAME" --allow-empty

mkdir -p "$WT/rollout_evidence"
cp "$LOG_DIR/$RUN_NAME.log"  "$WT/rollout_evidence/transcript.log" 2>/dev/null || true
cp "$LOG_DIR/$RUN_NAME.meta" "$WT/rollout_evidence/run.meta"       2>/dev/null || true

# --- 3. telltale scan: verbatim overlap with the original --------------------
TELL="$WT/rollout_evidence/telltale.txt"
{
  echo "telltale scan for $RUN_NAME"
  echo "distinctive original lines (len>=25) found verbatim in the diff:"
  MATCHES=0
  while IFS= read -r line; do
    norm="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ "${#norm}" -ge 25 ] || continue
    if grep -qF "$norm" <(grep '^+' "$PATCH" | sed 's/^+//;s/^[[:space:]]*//;s/[[:space:]]*$//'); then
      echo "  MATCH: $norm"
      MATCHES=$((MATCHES + 1))
    fi
  done < <(git -C "$REPO" show main:jumping_pad/jumping_pad.gd)
  echo "total distinctive matches: $MATCHES"
  echo "(0-1 = plausible convergence; 2+ = review transcript for exfiltration)"
} > "$TELL"
tail -2 "$TELL"

# --- 4. grade: attempt + verifier overlay in the capture worktree ------------
git -C "$REPO" archive verifier verifier | tar -x -C "$WT"
"$GODOT" --headless --path "$WT" --import > /dev/null 2>&1 || true
set +e
"$GODOT" --headless --path "$WT" --script res://verifier/verify.gd \
  > "$WT/rollout_evidence/grade.log" 2>&1
set -e
rm -rf "$WT/verifier"
grep "=== SCORE" "$WT/rollout_evidence/grade.log" || echo "WARNING: no score line - inspect grade.log"

git -C "$WT" add rollout_evidence
git -C "$WT" commit -qm "Evidence for $RUN_NAME: transcript, meta, telltale, grade"

# --- cleanup ------------------------------------------------------------------
git -C "$REPO" worktree remove --force "$WT"
echo ""
echo "=== PROCESSED: $RUN_NAME -> branch $BRANCH ==="
echo "view grade:  git -C \"$REPO\" show $BRANCH:rollout_evidence/grade.log | tail -20"
