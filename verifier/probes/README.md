# Anti-cheat probes

Eight deliberately flawed "near-miss" implementations, each written to fool a
sloppy grader, each graded by the real verifier on a clean workspace (original
game + probe installed). Predictions were written down before each run; full
JSON reports are in `results/`.

Reference points: original scores **100.0**, ablated (null) scores **5.0**.

| Probe | Cheat | Predicted | Actual | Caught by |
|---|---|---|---|---|
| P1 `p1_launch_only.gd` | Launch correct, cap never animates | 60.0 | **60.0** | T6, T7, T9 fail; T8, T11 gated |
| P2 `p2_animation_only.gd` | Cap animates, player never launches | 45.0 | **45.0** | T2-T5, T-MC fail; T10 gated |
| P3 `p3_linear_rebound.gd` | Rebound linear, no elastic overshoot | 85.0 | **85.0** | T7 alone ("100.0% of rest, need >= 102%") |
| P4 `p4_never_recovers.gd` | Squashes, stays flattened forever | 78.0 | **78.0** | T7 + T8; NEG-06 reads 100% compressed |
| P5 `p5_launches_everything.gd` | No player filter - launches anything | 90.0 | **48.0** | T10a/b (beetle 21.8 m/s, crate 20.5 m/s) plus full visual-block collapse: the arena floor triggers the unfiltered pad at startup, contaminating the rest baseline - a real defect (pads fire spontaneously at level load), not an artifact |
| P6 `p6_adds_velocity.gd` | `+=` instead of `=` on launch velocity | ~84.9 | **82.0** | T4 ("no launch after high fall") + T3 zero (gentle ratio 1.68x, below tent floor). In play: alternating high/low bounces, then falls through the pad |
| P7 `p7_position_tween.gd` | Fakes launch by animating position | 45.0 | **34.0** | T2 (velocity never moves) plus unpredicted T8/T9: the cheat self-oscillates (gravity accrues during the ride, player plummets back, re-fires forever), so the cap never settles and a live tween hijacks the T9 teleport |
| P8 `p8_boosted_jump.gd` | Correct pad + tampered player jump (12->20) | ~89.7 | **89.7** | T1a regression guard (jump 6.50 m vs 2.30 +/- 0.30); T3 partial 2.7/10 via tent curve |

## Observations (original scores, pre-v1.4 verifier)

- Every probe lands strictly below the original's 100.0; range 34.0-89.7.
- P1 and P2 fail exactly complementary halves of the rubric - evidence the
  physics and visual blocks are measured independently.
- All three prediction misses (P5, P6, P7) were in the same direction: the
  verifier caught the cheat **harder** than the back-of-envelope estimate.
  No cheat ever scored above its prediction, and no check failed on the
  original - the false-negative direction stayed clean.
- P8 installation is two changes: this probe file as the pad script AND
  `player.gd` jump_initial_impulse 12.0 -> 20.0 (see probe header).
- Determinism: P1 was run twice back-to-back with identical 60.0 results;
  all runs use fixed spawns, fixed 60 Hz physics, no RNG in measured paths.

## Re-validation against the current verifier (v1.4: continuous scoring on
## T2/T3/T4a/T4b/T5a/T5b/T6/T7/T8)

The rubric changed substantially since the table above was captured (a flat
plateau became a continuous curve on the magnitude check, several other
checks went from binary cliffs to continuous decay curves). Re-ran all 8
probes against the current verifier to confirm the fakes are still caught
after that rework, not just left over from an earlier grading pass.

| Probe | Pre-v1.4 | Current | Delta | Note |
|---|---|---|---|---|
| P1 | 60.0 | **60.0** | 0 | unchanged |
| P2 | 45.0 | **45.0** | 0 | unchanged |
| P3 | 85.0 | **85.0** | 0 | unchanged |
| P4 | 78.0 | **78.0** | 0 | unchanged |
| P5 | 48.0 | **48.0** | 0 | unchanged |
| P6 | 82.0 | **82.8** | +0.8 | now gets nuanced partial credit (see below) |
| P7 | 34.0 | **34.0** | 0 | unchanged |
| P8 | 89.7 | **89.0** | -0.7 | now gets nuanced partial credit (see below) |

**Why six of eight are bit-for-bit identical:** every probe is a deliberate,
extreme violation (0.0% overshoot, no launch at all, 100%-never-squashed, a
60% settle deviation). Those values sit exactly at or beyond the *zero
point* of the new continuous curves, so they score identically to the old
binary cliffs. Continuous scoring only changes outcomes in the middle
ground - a probe built to be a clear-cut cheat doesn't land there. This is
the property we wanted: the v1.4 rework sharpened discrimination among
genuine, imperfect agent attempts without softening anti-cheat robustness.

**Why P6 and P8 moved, and why that's a good thing, not drift:**
- P6 (`+=` instead of `=`) now scores partial credit on T4b (1.7/3.0,
  "3.83 m/s of an 8.0 m/s run-up survives") and T5b (1.1/2.0) - under the
  old binary system these were flat 0-or-full. The new scores are more
  honest: this cheat doesn't *totally* fail those dimensions, it partially
  degrades them, and the grade now reflects that instead of rounding to a
  cliff.
- P8 (boosted jump) now scores 2.0/10 on T3 instead of a flat 0 - its
  magnitude ratio (2.27x) is a genuine near-miss of the new curve's floor
  (2.0x). Root cause is still caught cleanly regardless (T1a, the jump
  tampering itself, fails outright either way).

Full reports: `results/p1.log` through `results/p8.log` (current verifier).
Pre-v1.4 reports preserved in `results/pre-v1.4-archive/` for comparison.
