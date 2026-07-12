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

## Observations

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
