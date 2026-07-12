# Jumping Pad Verifier

Headless, deterministic grader for the jumping-pad task. Scores an attempt out
of **100** across 12 sub-checks (see rubric below) and prints a JSON report.

## Exact command

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path <project-under-test> \
  --script res://verifier/verify.gd
```

Where `<project-under-test>` is a working tree containing the game plus the
attempt to grade, with this `verifier/` directory overlaid into it (see
"Grading workflow" below). Requires Godot 4.6.x. Exit code is `0` if the score
is >= 60, `1` otherwise; the full per-check JSON report is written to stdout.

## Evaluation integrity — how this stays out of the agent's reach

- The verifier lives **only on the `verifier` branch** of the fork. It is never
  merged into `task/jumppad-ablation` (the branch the rollout agent's snapshot
  is exported from) and never merged into `main`.
- The rollout agent **never works inside this repository**. Each run receives a
  `git archive` export of `task/jumppad-ablation` in a fresh directory with a
  fresh `git init` — no history, no remotes, no other branches. The agent's
  working copy physically contains no path to this verifier, the original
  implementation on `main`, or any git history that includes either.
- Rollouts run with network access denied (no web fetch/search, no network
  shell commands) except for the local Godot MCP server, and every attempt's
  diff is scanned post-hoc for verbatim matches against the original
  implementation (`telltale_scan.sh`).

## Grading workflow

1. Export a clean grading workspace from `task/jumppad-ablation`.
2. Apply the attempt's diff to it.
3. Overlay this `verifier/` directory into the workspace.
4. Run the exact command above; collect the JSON report and score.

## Rubric (100 points)

| Check | Description | Pts |
|---|---|---|
| T1a | Regression guard: normal jump height matches original | 3 |
| T1b | Regression guard: pad's idle rest geometry matches original | 2 |
| T2 | Instant, real-physics launch on flat-pad contact (ballistic assertion) | 15 |
| T3 | Launch magnitude: continuous curve centered on ~3.4x normal jump | 10 |
| T4 | Launch overrides prior vertical velocity (walk-on vs fall-on parity) | 8 |
| T5 | Launch direction follows pad orientation (30-degree tilted pad) | 7 |
| T-MC | Midair directional control retained after launch | 5 |
| T10a | Non-player (enemy) does not trigger launch or squash | 5 |
| T10b | Non-player (crate) does not trigger launch or squash | 5 |
| T6 | Cap squashes on contact: depth (8) + instant snap timing (4) | 12 |
| T7 | Elastic rebound overshoots rest height (>= 2%) after the dip | 15 |
| T8 | Cap settles back to rest height (+/- 2%) within ~2 s | 7 |
| T9 | Squash re-triggers on a second bounce | 4 |
| T11 | Pad instances have independent state (untouched pad stays at rest) | 2 |

Gating: negative/stability checks only score when their positive prerequisite
exists, so the null (ablated) solution cannot collect vacuous passes. T8 and
T11 require the squash to have occurred (T6); T10a/b require the player launch
to exist (T2). Gated-out checks report "not evaluated" and score 0. The only
points available without implementing anything are the two regression guards
(T1a + T1b = 5), which measure "didn't break the rest of the game."

Unscored diagnostics (reported in the JSON, never scored):
- NEG-06: behavior under continuous overlap (player pinned inside the trigger
  volume for 3 s). Event-driven implementations recover to rest; per-frame
  re-trigger implementations stay compressed. Not scored because continuous
  contact cannot occur in normal play - the launch removes the player within a
  few frames - so scoring it would grade implementation, not outcome.

v1.1 hardening (spec v2 no longer states the 3.4x multiplier or squash
timing, so these bands are tightened around the original's actual measured
behavior rather than a spec'd constant):
- T3 magnitude band narrowed to a plateau of [3.2x, 3.65x] (was
  [3.0x, 3.8x]), zero below 2.6x / above 4.4x (was 2.0x / 5.5x).
- T6 split into depth (8 pts: full <= 55% of rest, half <= 70%, was a
  single 80%/90% band) and snap timing (4 pts: full credit only if the
  dip is reached within 3 frames of contact, half within 7 - the original
  sets the squashed scale on the same frame as contact; both known v1
  agent solutions eased the compression over ~6 frames instead of
  snapping, so this sub-check is empirically proven to discriminate).

Measurement notes:
- "Visual height" is the world-space vertical extent of the pad's visible
  geometry (union of its VisualInstance3D AABBs), so any implementation of the
  squash (tween, AnimationPlayer, different node) is graded by outcome, not
  mechanism. Vertical compression only is graded; horizontal widening is not
  required.
- The ballistic assertion: starting 3 physics frames after contact, 10
  consecutive airborne frames must satisfy |dv_y - (-30 * 1/60)| < 0.15 m/s
  with no input held, and v_y > 0 on the first sampled frame.
