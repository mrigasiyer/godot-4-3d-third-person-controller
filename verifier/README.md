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
| T2 | Latency (continuous, 7) + real-physics gate (binary, 4) + time-to-peak precision (continuous, 4) | 15 |
| T3 | Launch magnitude: continuous curve peaked at ~3.43x normal jump, no flat bands | 10 |
| T4a | Vertical-override mismatch: continuous, full credit near 0%, zero by 35% | 5 |
| T4b | Horizontal-override residual speed: continuous, full credit near 0, zero by 8 m/s | 3 |
| T5a | Tilt-direction along-lean push: ramps to full credit at the original's ~5.00 m/s | 5 |
| T5b | Tilted launch magnitude matches flat-pad launch: continuous, peaked at ratio 1.0 | 2 |
| T-MC | Midair directional control retained after launch | 5 |
| T10a | Non-player (enemy) does not trigger launch or squash | 5 |
| T10b | Non-player (crate) does not trigger launch or squash | 5 |
| T6 | Cap squashes on contact: depth (8) + instant snap timing (4) | 12 |
| T7 | Elastic rebound overshoots rest height: continuous curve peaked at original's 122.4% | 15 |
| T8 | Cap settles back to rest: continuous, full credit within 0.5%, zero by 8% deviation | 7 |
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
- T6 split into depth (8 pts: full <= 55% of rest, half <= 70%, was a
  single 80%/90% band) and snap timing (4 pts: full credit only if the
  dip is reached within 3 frames of contact, half within 7 - the original
  sets the squashed scale on the same frame as contact; both known v1
  agent solutions eased the compression over ~6 frames instead of
  snapping, so this sub-check is empirically proven to discriminate).

v1.3 hardening (T3 redesign, based on real campaign data): the original
piecewise tent had a flat [3.2x, 3.65x] plateau, which meant any two guesses
inside it scored identically, and a hard cliff to zero outside it. Across 13
real agent runs, nobody derived the original's exact ratio through reasoning
alone - the specific number is an arbitrary original design choice, not
recoverable from the remaining (unablated) files, only approachable through
in-engine iteration nobody attempted - so a punishing all-or-nothing band was
overstating what "verification" could realistically achieve. Replaced with a
continuous, asymmetric curve peaked at the original's measured ratio (3.43x,
+/- 0.05 tolerance for full credit): steep down to zero by 2.0x on the
undershoot side (the spec's "far beyond a normal jump" is an explicit floor -
too weak fails it outright), gentle down to zero by 12.0x on the overshoot
side (still satisfies "far beyond", just imprecise, so it should cost points
gradually, not fall off a cliff). Every distinct ratio now scores distinctly:
e.g. 4.0x -> 9.4/10, 5.6x -> 7.5/10, 6.4x -> 6.6/10, 8.75x -> 3.8/10.

v1.2 hardening (spec-neutral - both ride on requirements already stated):
- T4/T5 split: T4a/T5a keep the prior vertical-override and tilt-direction
  logic; new T4b (3 pts) requires that a player sprinting onto a flat pad
  does not carry that horizontal momentum through the bounce - the
  original's launch is a single atomic velocity assignment, which is
  mathematically zero horizontal for an untilted pad. New T5b (2 pts)
  requires the tilted-pad launch speed to stay within 0.75-1.25x of the
  flat-pad launch speed, catching implementations that bolt an extra
  sideways push onto the usual vertical launch instead of redirecting one
  vector along the pad's orientation.
- T2's ballistic check now walks the WHOLE ascent (up to 90 frames, was a
  fixed 10-frame window right after launch) so an implementation that
  fakes physics briefly and drifts later doesn't pass, and cross-checks
  that the actual time-to-peak matches what the measured launch speed
  predicts (tolerance +/- 3 frames) - catching cumulative drift that
  per-frame tolerance alone can miss.

v1.4 hardening: continuous scoring extended to T2, T4a, T4b, T5a, T5b, using
whichever shape actually matches the underlying measurement rather than one
pattern forced everywhere:
- T2 split into three parts: latency (7 pts, zero-decay, full credit within
  2 frames of contact - matches the original) + a real-physics gate (4 pts,
  kept binary on purpose - whether gravity genuinely governs the motion vs.
  a scripted tween is categorical, exactly what defeats the position-tween
  probe) + time-to-peak precision (4 pts, zero-decay, only scored once the
  gate passes - how closely the observed flight time matches what the
  measured launch speed predicts).
- T4a (5 pts) and T4b (3 pts): zero-decay on override mismatch / residual
  speed - both are naturally >=0 with an ideal of exactly 0 (the original
  measures ~0% mismatch and 0.00 m/s residual respectively).
- T5a (5 pts): ramp-to-target, not peak-decay - full credit is reached at
  the original's measured along-lean push (~5.00 m/s) and stays full beyond
  it, since more push in the right direction isn't wrong on its own (overall
  magnitude is T5b's job).
- T5b (2 pts): peak-decay around ratio 1.0 (perfect tilted/flat consistency),
  replacing the old binary [0.75x, 1.25x] band.
- Left binary on purpose: T1a/T1b (regression guards), T9/T10a/T10b/T11 (bug
  presence is categorical, not a judgment call), T-MC (every run so far -
  original included - lands on ~the same value; no real spread to measure).

Measurement notes:
- "Visual height" is the world-space vertical extent of the pad's visible
  geometry (union of its VisualInstance3D AABBs), so any implementation of the
  squash (tween, AnimationPlayer, different node) is graded by outcome, not
  mechanism. Vertical compression only is graded; horizontal widening is not
  required.
- The ballistic assertion: starting 3 physics frames after contact, 10
  consecutive airborne frames must satisfy |dv_y - (-30 * 1/60)| < 0.15 m/s
  with no input held, and v_y > 0 on the first sampled frame.
