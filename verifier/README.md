# Jumping Pad Verifier

Headless, deterministic grader for the jumping-pad task. Scores an attempt out
of **100** across 16 sub-checks (see rubric below) and prints a JSON report.

## Exact command

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path <project-under-test> \
  --script res://verifier/verify.gd
```

Requires Godot 4.6.x. `<project-under-test>` is the game plus the attempt to
grade, with this `verifier/` directory overlaid into it (see "Grading
workflow"). The per-check JSON report goes to stdout; exit code is `0` if the
score is >= 60.

## Writeup

The full writeup with charts and gameplay clips is at
[`writeup/report.html`](writeup/report.html). Its video clips are loaded via
relative paths, so **clone the repo and check out this `verifier` branch, then
open `report.html` from disk** — downloading that file on its own (e.g. via a
"raw" link) will leave the clips broken.

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
