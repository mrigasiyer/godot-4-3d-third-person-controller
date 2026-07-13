extends SceneTree
## Headless verifier for the jumping-pad task. Scores an attempt out of 100.
##
## Run:
##   godot --headless --path <project-under-test> --script res://verifier/verify.gd
##
## Design (see verifier/README.md for the rubric):
## - Builds minimal arenas in code from the game's real scenes (player, pad,
##   beetle, crate) instead of loading the full level, so measurements are
##   deterministic: fixed 60 Hz physics, fixed spawns, no RNG.
## - Grades observable outcomes only. The squash is measured as the world-space
##   vertical extent of the pad's visible geometry (union of VisualInstance3D
##   AABBs), so tween / AnimationPlayer / any-node implementations all count.
## - The launch is graded from the player's actual flight (velocity + ballistic
##   gravity integration), which rejects scripted position animations.

const PLAYER_SCENE := "res://player/player.tscn"
const PAD_SCENE := "res://jumping_pad/jumping_pad.tscn"
const BEETLE_SCENE := "res://enemies/beetle_bot.tscn"
const CRATE_SCENE := "res://box/box.tscn"

# -- Calibration constants (validated against the original implementation) ----
const DT := 1.0 / 60.0
const PLAYER_GRAVITY := 30.0        # player.gd integrates velocity.y at -30 m/s^2
const EXPECTED_JUMP := 2.3          # normal tap-jump peak height on original (m)
const JUMP_TOLERANCE := 0.30        # regression guard band around EXPECTED_JUMP
const LAUNCH_VY_MIN := 6.0          # upward velocity that counts as "launched"
const CONTACT_GRACE_FRAMES := 6     # max frames between pad contact and launch
const BALLISTIC_EPS := 0.15        # |dv_y - (-g*dt)| tolerance per frame
const MC_SPEED_GAIN := 1.5          # m/s horizontal gain proving midair control
const NONPLAYER_VY_MAX := 3.0       # any more upward velocity = it got launched
const RUN_SPEED := 8.0              # matches player.gd's move_speed default
const EXPECTED_REST_H := 1.607      # pad rest visual height, measured on original assets
const REST_H_TOL_RATIO := 0.05      # +/-5% band for the T1b rest-height regression guard
## v1.4 hardening: continuous scoring extended to every check that measures a
## real precision spectrum (a "distance from the original's exact value" or
## "distance from zero" quantity). Three distinct shapes, chosen by what the
## underlying measurement actually looks like - not one pattern forced
## everywhere:
##   - zero-decay: full credit near 0, decaying to 0 by some threshold. Used
##     for anything that's naturally >=0 with an ideal of exactly 0 (override
##     mismatch, residual velocity, timing deviation, settle deviation).
##   - ramp-to-target: 0 credit at 0, ramping up to full credit at the
##     original's measured value, then staying full beyond it. Used where
##     "too little" is a real failure but "too much" isn't inherently wrong
##     (a magnitude dimension already covered by a separate check).
##   - peak-decay: full credit at the original's measured value, decaying on
##     BOTH sides. Used for true ratios where over- and under-shooting are
##     both real, distinct failure modes (T3's magnitude, T7's overshoot,
##     T5b's tilt-consistency ratio).
## Left binary on purpose: T1a/T1b (regression guards - broke it or didn't),
## T2's physics-realism gate (real physics or a scripted fake - categorical),
## T9/T10a/T10b/T11 (bug presence, not a judgment call), T-MC (every run so
## far - original included - lands on ~the same value; no real spread to
## differentiate).

# T4a: vertical-override mismatch - zero-decay (original measures ~0%)
const T4A_MISMATCH_TOL := 0.02
const T4A_MISMATCH_ZERO_AT := 0.35
# T4b: horizontal-override residual speed - zero-decay (original measures 0.00 m/s)
const T4B_RESIDUAL_TOL := 0.5
const T4B_RESIDUAL_ZERO_AT := 8.0   # matches RUN_SPEED - full residual = total failure
# T5a: tilt-direction along-lean push - ramp-to-target (original measures ~5.00 m/s)
const T5A_TARGET := 5.0
# T5b: tilt-magnitude consistency ratio - peak-decay around 1.0 (perfect consistency)
const T5B_PEAK := 1.0
const T5B_PEAK_TOL := 0.05
const T5B_ZERO_LO := 0.4
const T5B_ZERO_HI := 2.0
# T2 latency - zero-decay from a low frame count (original measures 2 frames);
# zero point reuses CONTACT_GRACE_FRAMES below.
const T2_LATENCY_TOL := 2.0
# T2 flight-time precision (only scored if the physics-realism gate passes)
const T2_TIME_TOL := 1.0
const T2_TIME_ZERO_AT := 6.0
const ASCENT_CHECK_MAX_FRAMES := 90 # cap on how far into the ascent the ballistic check walks
const MIN_ASCENT_CHECK_FRAMES := 8  # below this the ascent was too short to say anything
# Magnitude scoring curve (ratio of pad peak to normal jump peak). The spec
# gives no number (v2: "far beyond the highest jump"), so full credit centers
# on the original's actual measured ratio (~3.43x) and every ratio away from
# it scores continuously less - no flat plateau, no cliff edges, so a 3.5x
# guess and a 6.4x guess get meaningfully different scores instead of both
# landing in the same all-or-nothing band. Asymmetric on purpose: undershoot
# is a harder floor (the spec explicitly demands "far beyond" a normal jump,
# so a weak launch fails that outright), overshoot is a gentler, wider slope
# (still satisfies "far beyond", just imprecise, so it should lose points
# gradually rather than falling off a cliff).
const RATIO_PEAK := 3.43            # original's measured ratio - full credit center
const RATIO_PEAK_TOL := 0.05        # +/- band around the peak that still counts as "exact"
const RATIO_ZERO_LO := 2.0          # at/below this, launch doesn't read as "far beyond" at all
const RATIO_ZERO_HI := 12.0         # at/above this, launch is absurdly overpowered
# T7 overshoot curve: peaked at the original's measured overshoot (122.4%),
# decays to 0 at exactly 100% (no overshoot = fails "wobbles past normal
# shape" outright) and to 0 by 160% (absurdly bouncy).
const OVERSHOOT_PEAK := 1.224
const OVERSHOOT_PEAK_TOL := 0.02
const OVERSHOOT_ZERO_LO := 1.0
const OVERSHOOT_ZERO_HI := 1.6
# T8 settle curve: full credit within 0.5% of perfectly settled (the
# original measures ~0.0%), decaying to 0 by 8% deviation.
const SETTLE_TOL := 0.005
const SETTLE_ZERO_AT := 0.08
# Squash-depth band (dip / rest), tightened around the original's ~40% dip.
const DIP_FULL := 0.55
const DIP_HALF := 0.70
# Snap timing: frames from contact to reaching the dip. The original sets
# the squashed scale on the SAME frame as contact (an instant snap, not an
# eased compression) - both known v1 agent solutions eased this over ~6
# frames, so this check is empirically proven to discriminate.
const SNAP_FULL_FRAMES := 3
const SNAP_HALF_FRAMES := 7

var _checks: Array = []
var _meta := {}
var _diagnostics: Array = []
var _score := 0.0


func _initialize() -> void:
	_main()


func _main() -> void:
	for i in 8:
		await physics_frame

	var jump_peak := await _scenario_calibration()
	var flat := await _scenario_flat_pad(jump_peak)
	await _scenario_fall_parity(flat.get("peak_gentle", -1.0))
	await _scenario_horizontal_override()
	await _scenario_tilted_pad(flat.get("launch_speed", -1.0))
	var launched: bool = flat.get("launched", false)
	await _scenario_nonplayer("T10a", "Enemy does not trigger the pad", BEETLE_SCENE, launched)
	await _scenario_nonplayer("T10b", "Crate does not trigger the pad", CRATE_SCENE, launched)

	_finish()


# =============================== Scenarios ===================================

## T1 - measure the normal tap-jump peak; regression guard on player movement.
func _scenario_calibration() -> float:
	var arena := _make_arena(false, 0.0)
	var player := _spawn_player(arena, Vector3(0, 0.1, 0))
	if player == null:
		_add("T1a", "Jump-height regression guard", 3, 0, "player scene failed to load")
		_free_arena(arena)
		return -1.0

	var grounded := false
	for i in 120:
		await physics_frame
		if player.is_on_floor():
			grounded = true
			break
	if not grounded:
		_add("T1a", "Jump-height regression guard", 3, 0, "player never grounded")
		_free_arena(arena)
		return -1.0

	var y0: float = player.global_position.y
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")

	var peak := y0
	for f in 240:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
		if f > 10 and player.is_on_floor():
			break

	var jump_peak := peak - y0
	_meta["jump_peak_m"] = snappedf(jump_peak, 0.001)
	var ok := absf(jump_peak - EXPECTED_JUMP) <= JUMP_TOLERANCE
	_add("T1a", "Jump-height regression guard", 3, 3 if ok else 0,
		"normal jump peak %.2f m (expected %.2f +/- %.2f)" % [jump_peak, EXPECTED_JUMP, JUMP_TOLERANCE])
	_free_arena(arena)
	return jump_peak


## T2/T3/T-MC/T6/T7/T8/T9 - the flat-pad scenario. One long recorded timeline.
func _scenario_flat_pad(jump_peak: float) -> Dictionary:
	var out := {}
	var arena := _make_arena(true, 0.0)
	var pad: Node3D = arena.pad
	var player := _spawn_player(arena, Vector3(0, 1.8, 0))
	if player == null or pad == null:
		for c in [["T1b", 2], ["T2", 15], ["T3", 10], ["TMC", 5], ["T6", 12], ["T7", 15], ["T8", 7], ["T9", 4], ["T11", 2]]:
			_add(c[0], "flat-pad scenario", c[1], 0, "scene failed to load")
		_free_arena(arena)
		return out

	# T11: a second, far-away pad instance that nothing ever touches.
	var pad_b: Node3D = null
	var pad_scene_b := load(PAD_SCENE)
	if pad_scene_b:
		pad_b = pad_scene_b.instantiate()
		arena.root.add_child(pad_b)
		pad_b.global_position = Vector3(-6, 0, 0)

	await physics_frame
	var rest_h := _pad_visual_height(pad)
	var rest_b := _pad_visual_height(pad_b) if pad_b else 0.0
	var hb_lo := INF
	var hb_hi := -INF

	# T1b: the pad's idle rest geometry must match the original game's.
	_meta["pad_rest_height_m"] = snappedf(rest_h, 0.001)
	if EXPECTED_REST_H <= 0.0:
		_add("T1b", "Pad rest-height regression guard", 2, 0,
			"UNCALIBRATED: measured rest height %.3f m - bake into EXPECTED_REST_H" % rest_h)
	else:
		var rest_ok := absf(rest_h - EXPECTED_REST_H) <= REST_H_TOL_RATIO * EXPECTED_REST_H
		_add("T1b", "Pad rest-height regression guard", 2, 2 if rest_ok else 0,
			"rest height %.3f m (expected %.3f +/- %.0f%%)" % [rest_h, EXPECTED_REST_H, REST_H_TOL_RATIO * 100.0])

	var ys: Array[float] = []
	var vels: Array[Vector3] = []
	var hs: Array[float] = []
	var contact_f := -1
	var launch_f := -1

	var total_frames := 200
	var f := 0
	while f < total_frames:
		await physics_frame
		ys.append(player.global_position.y)
		vels.append(player.velocity)
		hs.append(_pad_visual_height(pad))
		if pad_b:
			var hb := _pad_visual_height(pad_b)
			hb_lo = minf(hb_lo, hb)
			hb_hi = maxf(hb_hi, hb)
		if contact_f < 0 and _in_pad_zone(player, pad):
			contact_f = f
			total_frames = maxi(total_frames, contact_f + 140)
		if launch_f < 0 and player.velocity.y > LAUNCH_VY_MIN:
			launch_f = f
		# Midair-control probe: after the ballistic window, hold one move action.
		if launch_f >= 0:
			if f == launch_f + 15:
				Input.action_press("move_up")
			elif f == launch_f + 35:
				Input.action_release("move_up")
			elif f == launch_f + 60:
				# Move the player clear of the pad so the visual curve can
				# settle without a second bounce contaminating T8.
				player.global_position.x += 8.0
				player.velocity.x = 0.0
				player.velocity.z = 0.0
		f += 1
	Input.action_release("move_up")

	# ---- T2: instant, real-physics launch --------------------------------
	var t2_pts := 0.0
	var t2_detail := ""
	if contact_f < 0:
		t2_detail = "player never reached the pad zone"
	elif launch_f < 0:
		t2_detail = "no upward launch detected (max v_y %.2f)" % _max_vy(vels)
	else:
		var latency := launch_f - contact_f
		if latency >= 0:
			var latency_pts := _zero_decay_score(float(latency), T2_LATENCY_TOL, float(CONTACT_GRACE_FRAMES)) * 7.0
			t2_pts += latency_pts
			t2_detail = "launched %d frame(s) after contact (full credit <= %d) [%.1f/7]" % [latency, int(T2_LATENCY_TOL), latency_pts]
		else:
			t2_detail = "launch preceded contact somehow (frame %d)" % latency
		var ballistic := _check_ballistic(vels, launch_f)
		if ballistic.gate_ok:
			t2_pts += 4.0
			t2_detail += "; real physics verified [4.0/4]"
			if ballistic.time_mismatch_valid:
				var time_pts := _zero_decay_score(ballistic.time_mismatch_frames, T2_TIME_TOL, T2_TIME_ZERO_AT) * 4.0
				t2_pts += time_pts
				t2_detail += "; time-to-peak off by %.1f frames (full credit <= %.0f) [%.1f/4]" \
					% [ballistic.time_mismatch_frames, T2_TIME_TOL, time_pts]
			else:
				t2_detail += "; time-to-peak not observed within window [0.0/4]"
		else:
			t2_detail += "; not real physics: " + ballistic.gate_error + " [0.0/4, 0.0/4]"
	_add("T2", "Instant real-physics launch on contact", 15, t2_pts, t2_detail)

	# ---- T3: launch magnitude (continuous tent around ~3.4x) -------------
	var peak_gentle := -1.0
	if launch_f >= 0:
		var top := -INF
		for i in range(launch_f, ys.size()):
			top = maxf(top, ys[i])
		peak_gentle = top - ys[launch_f]
	out["peak_gentle"] = peak_gentle
	if launch_f < 0:
		_add("T3", "Launch magnitude ~3.4x normal jump", 10, 0, "no launch")
	else:
		var baseline := jump_peak if jump_peak > 0.1 else EXPECTED_JUMP
		var ratio := peak_gentle / baseline
		var t3_pts := _tent_score(ratio) * 10.0
		_add("T3", "Launch magnitude ~3.4x normal jump", 10, t3_pts,
			"pad peak %.2f m / jump %.2f m = %.2fx" % [peak_gentle, baseline, ratio])

	# ---- T-MC: midair directional control --------------------------------
	if launch_f < 0 or launch_f + 35 >= vels.size():
		_add("TMC", "Midair control retained", 5, 0, "no launch / flight too short")
	else:
		var h0 := 0.0
		for i in range(launch_f + 12, launch_f + 15):
			h0 = maxf(h0, _hspeed(vels[i]))
		var h1 := 0.0
		for i in range(launch_f + 15, launch_f + 36):
			h1 = maxf(h1, _hspeed(vels[i]))
		var gained := h1 - h0
		_add("TMC", "Midair control retained", 5, 5 if gained >= MC_SPEED_GAIN else 0,
			"horizontal speed gained %.2f m/s under held input (need >= %.1f)" % [gained, MC_SPEED_GAIN])

	out["launched"] = launch_f >= 0
	out["launch_speed"] = vels[launch_f].length() if launch_f >= 0 else -1.0

	# ---- T6/T7/T8: the squash curve ---------------------------------------
	var squash_occurred := false
	if contact_f < 0 or rest_h <= 0.0:
		_add("T6", "Cap squashes on contact", 12, 0, "no contact / no visible pad geometry")
		_add("T7", "Elastic rebound overshoots rest height", 15, 0, "no contact")
		_add("T8", "Cap settles back to rest", 7, 0, "no contact")
	else:
		var dip_min := INF
		var dip_f := -1
		for i in range(contact_f, mini(contact_f + 30, hs.size())):
			if hs[i] < dip_min:
				dip_min = hs[i]
				dip_f = i
		var dip_ratio := dip_min / rest_h
		squash_occurred = dip_ratio < 0.95
		var snap_latency := dip_f - contact_f

		var depth_pts := 0.0
		if dip_ratio <= DIP_FULL:
			depth_pts = 8.0
		elif dip_ratio <= DIP_HALF:
			depth_pts = 4.0

		var snap_pts := 0.0
		if squash_occurred:
			if snap_latency <= SNAP_FULL_FRAMES:
				snap_pts = 4.0
			elif snap_latency <= SNAP_HALF_FRAMES:
				snap_pts = 2.0

		_add("T6", "Cap squashes on contact (depth + instant snap)", 12, depth_pts + snap_pts,
			"depth: dipped to %.0f%% of rest (full <= %.0f%%, half <= %.0f%%) [%.1f/8]; snap: reached dip %d frame(s) after contact (full <= %d, half <= %d) [%.1f/4]"
			% [dip_ratio * 100.0, DIP_FULL * 100.0, DIP_HALF * 100.0, depth_pts,
			   snap_latency, SNAP_FULL_FRAMES, SNAP_HALF_FRAMES, snap_pts])

		var overshoot := -INF
		if dip_ratio < 0.95:
			for i in range(dip_f + 1, mini(contact_f + 110, hs.size())):
				overshoot = maxf(overshoot, hs[i])
		var over_ratio := overshoot / rest_h if overshoot > 0.0 else 0.0
		var t7_pts := _overshoot_score(over_ratio) * 15.0
		_add("T7", "Elastic rebound overshoots rest height", 15, t7_pts,
			"post-dip max height %.1f%% of rest (peak credit at %.1f%%, need > 100%% for any credit)"
			% [over_ratio * 100.0, OVERSHOOT_PEAK * 100.0])

		# Gated on T6: "returned to rest" is vacuous if it never squashed.
		if not squash_occurred:
			_add("T8", "Cap settles back to rest within ~2 s", 7, 0,
				"not evaluated: cap never squashed")
		else:
			var settle_worst := 0.0
			var s_lo := contact_f + 108
			var s_hi := mini(contact_f + 132, hs.size())
			if s_hi <= s_lo:
				settle_worst = 1.0
			else:
				for i in range(s_lo, s_hi):
					var dev := absf(hs[i] - rest_h) / rest_h
					settle_worst = maxf(settle_worst, dev)
			var t8_pts := _settle_score(settle_worst) * 7.0
			_add("T8", "Cap settles back to rest within ~2 s", 7, t8_pts,
				"worst deviation in settle window %.1f%% (full credit <= %.1f%%, zero by %.0f%%)"
				% [settle_worst * 100.0, SETTLE_TOL * 100.0, SETTLE_ZERO_AT * 100.0])

	# ---- T9: re-trigger on a second bounce --------------------------------
	if contact_f < 0 or rest_h <= 0.0:
		_add("T9", "Squash re-triggers on second bounce", 4, 0, "no first contact")
	else:
		player.global_position = Vector3(0, 1.8, 0)
		player.velocity = Vector3.ZERO
		var c2 := -1
		for i in 50:
			await physics_frame
			if pad_b:
				hb_lo = minf(hb_lo, _pad_visual_height(pad_b))
			if c2 < 0 and _in_pad_zone(player, pad):
				c2 = i
				break
		var dip2 := INF
		if c2 >= 0:
			for i in 40:
				await physics_frame
				dip2 = minf(dip2, _pad_visual_height(pad))
				if pad_b:
					hb_lo = minf(hb_lo, _pad_visual_height(pad_b))
		var ok2 := c2 >= 0 and dip2 <= 0.90 * rest_h
		_add("T9", "Squash re-triggers on second bounce", 4, 4 if ok2 else 0,
			"second dip to %.0f%% of rest (need <= 90%%)" % ((dip2 / rest_h) * 100.0) if c2 >= 0 else "no second contact")

	# ---- NEG-06 (unscored diagnostic): behavior under continuous overlap ---
	# Continuous contact cannot occur in normal play (the launch removes the
	# player within a few frames), so this is reported but never scored:
	# scoring it would grade the implementation, not the observable outcome.
	if contact_f >= 0 and rest_h > 0.0:
		var compressed := 0
		var window := 0
		for i in 180:
			player.global_position = Vector3(0, 0.8, 0)
			player.velocity = Vector3.ZERO
			await physics_frame
			if pad_b:
				hb_lo = minf(hb_lo, _pad_visual_height(pad_b))
			if i >= 60:
				window += 1
				if _pad_visual_height(pad) < 0.9 * rest_h:
					compressed += 1
		_diagnostics.append({
			"id": "NEG06",
			"name": "Continuous-overlap behavior (unscored)",
			"detail": "cap compressed for %d%% of a 2 s pinned-contact window; event-driven implementations recover to rest (~0%%), per-frame re-trigger implementations stay compressed (~100%%)." % int(100.0 * compressed / maxf(1.0, float(window))),
		})

	# ---- T11: pad instances have independent state -------------------------
	if pad_b == null or rest_b <= 0.0:
		_add("T11", "Pad instances have independent state", 2, 0, "second pad failed to load")
	elif not squash_occurred:
		_add("T11", "Pad instances have independent state", 2, 0,
			"not evaluated: primary pad never squashed")
	else:
		var dev_b := maxf(absf(hb_lo - rest_b), absf(hb_hi - rest_b)) / rest_b
		_add("T11", "Pad instances have independent state", 2, 2 if dev_b <= 0.02 else 0,
			"untouched pad's height deviated %.1f%% from its rest (limit 2%%)" % (dev_b * 100.0))

	_free_arena(arena)
	return out


## T4 - landing from a high fall must reach the same peak as a gentle drop.
func _scenario_fall_parity(peak_gentle: float) -> void:
	var arena := _make_arena(true, 0.0)
	var pad: Node3D = arena.pad
	var player := _spawn_player(arena, Vector3(0, 7.4, 0))
	if player == null or pad == null or peak_gentle <= 0.0:
		_add("T4a", "Launch overrides prior vertical velocity", 5, 0,
			"prerequisite missing (no gentle-drop launch to compare against)")
		_free_arena(arena)
		return

	var ys: Array[float] = []
	var launch_f := -1
	for f in 220:
		await physics_frame
		ys.append(player.global_position.y)
		if launch_f < 0 and player.velocity.y > LAUNCH_VY_MIN:
			launch_f = f

	if launch_f < 0:
		_add("T4a", "Launch overrides prior vertical velocity", 5, 0, "no launch after high fall")
	else:
		var top := -INF
		for i in range(launch_f, ys.size()):
			top = maxf(top, ys[i])
		var peak_fall := top - ys[launch_f]
		var mismatch := absf(peak_fall - peak_gentle) / maxf(peak_fall, peak_gentle)
		var t4a_pts := _zero_decay_score(mismatch, T4A_MISMATCH_TOL, T4A_MISMATCH_ZERO_AT) * 5.0
		_add("T4a", "Launch overrides prior vertical velocity", 5, t4a_pts,
			"gentle-drop peak %.2f m vs high-fall peak %.2f m (mismatch %.0f%%, full credit <= %.0f%%)"
			% [peak_gentle, peak_fall, mismatch * 100.0, T4A_MISMATCH_TOL * 100.0])
	_free_arena(arena)


## T4b - a player sprinting onto a flat pad must not carry that horizontal
## momentum through the bounce; the launch alone decides the outcome.
func _scenario_horizontal_override() -> void:
	var arena := _make_arena(true, 0.0)
	var pad: Node3D = arena.pad
	if pad == null:
		_add("T4b", "Launch overrides prior horizontal velocity", 3, 0, "pad failed to load")
		_free_arena(arena)
		return

	# Spawn just outside the trigger zone, already moving at running speed
	# toward the pad's center, so contact happens within a few frames with
	# substantial horizontal velocity still intact (no camera/input needed -
	# direct velocity injection, same convention as the high-fall spawn above).
	var spawn := pad.global_transform * Vector3(-1.3, 1.4, 0)
	var scene := load(PLAYER_SCENE)
	var player: CharacterBody3D = scene.instantiate() if scene else null
	if player == null:
		_add("T4b", "Launch overrides prior horizontal velocity", 3, 0, "player scene failed to load")
		_free_arena(arena)
		return
	player.position = spawn
	arena.root.add_child(player)
	var approach_dir := (pad.global_position - spawn)
	approach_dir.y = 0.0
	approach_dir = approach_dir.normalized()
	player.velocity = approach_dir * RUN_SPEED

	var launch_f := -1
	var hv_at_launch := -1.0
	for f in 120:
		await physics_frame
		if launch_f < 0 and player.velocity.y > LAUNCH_VY_MIN:
			launch_f = f
			hv_at_launch = _hspeed(player.velocity)
			break

	if launch_f < 0:
		_add("T4b", "Launch overrides prior horizontal velocity", 3, 0, "no launch reached")
	else:
		var t4b_pts := _zero_decay_score(hv_at_launch, T4B_RESIDUAL_TOL, T4B_RESIDUAL_ZERO_AT) * 3.0
		_add("T4b", "Launch overrides prior horizontal velocity", 3, t4b_pts,
			"horizontal speed at launch %.2f m/s from a %.1f m/s run-up (full credit <= %.1f)"
			% [hv_at_launch, RUN_SPEED, T4B_RESIDUAL_TOL])
	_free_arena(arena)


## T5a/T5b - a 30-degree tilted pad must launch with a horizontal component
## along its lean direction (T5a), at a total speed consistent with the
## flat-pad launch (T5b) - catching implementations that redirect one launch
## vector (correct) vs. bolting an extra sideways push on top (inconsistent
## magnitude across orientations).
func _scenario_tilted_pad(flat_launch_speed: float) -> void:
	var arena := _make_arena(true, 30.0)
	var pad: Node3D = arena.pad
	var player := _spawn_player(arena, pad.global_transform * Vector3(0, 1.4, 0) + Vector3(0, 1.5, 0)) if pad else null
	if player == null or pad == null:
		_add("T5a", "Launch follows pad orientation", 5, 0, "scene failed to load")
		_add("T5b", "Tilted launch magnitude matches flat-pad launch", 2, 0, "scene failed to load")
		_free_arena(arena)
		return

	var lean := pad.global_transform.basis.y
	var lean_h := Vector3(lean.x, 0, lean.z)
	if lean_h.length() < 0.1:
		_add("T5a", "Launch follows pad orientation", 5, 0, "internal: pad not tilted")
		_add("T5b", "Tilted launch magnitude matches flat-pad launch", 2, 0, "internal: pad not tilted")
		_free_arena(arena)
		return
	lean_h = lean_h.normalized()

	var launch_vel := Vector3.ZERO
	var launch_f := -1
	for f in 160:
		await physics_frame
		if launch_f < 0 and player.velocity.y > LAUNCH_VY_MIN:
			launch_f = f
			launch_vel = player.velocity
			break

	if launch_f < 0:
		_add("T5a", "Launch follows pad orientation", 5, 0, "no launch on tilted pad")
		_add("T5b", "Tilted launch magnitude matches flat-pad launch", 2, 0, "no launch on tilted pad")
	else:
		var along := Vector3(launch_vel.x, 0, launch_vel.z).dot(lean_h)
		var t5a_pts := _ramp_to_target_score(along, T5A_TARGET) * 5.0
		_add("T5a", "Launch follows pad orientation", 5, t5a_pts,
			"horizontal launch component along lean %.2f m/s (full credit at >= %.2f)" % [along, T5A_TARGET])

		if flat_launch_speed <= 0.0:
			_add("T5b", "Tilted launch magnitude matches flat-pad launch", 2, 0,
				"prerequisite missing (no flat-pad launch speed to compare against)")
		else:
			var tilt_speed := launch_vel.length()
			var ratio := tilt_speed / flat_launch_speed
			var t5b_pts := _ratio_peak_decay_score(ratio, T5B_PEAK, T5B_PEAK_TOL, T5B_ZERO_LO, T5B_ZERO_HI) * 2.0
			_add("T5b", "Tilted launch magnitude matches flat-pad launch", 2, t5b_pts,
				"tilted launch speed %.2f m/s vs flat launch speed %.2f m/s (ratio %.2fx, peak credit at %.2fx)"
				% [tilt_speed, flat_launch_speed, ratio, T5B_PEAK])
	_free_arena(arena)


## T10 - non-player bodies must neither launch nor squash the pad.
## Gated on the player launch existing: with no launch at all, "doesn't launch
## non-players" would be a vacuous pass for the null solution.
func _scenario_nonplayer(id: String, label: String, scene_path: String, has_launch: bool) -> void:
	if not has_launch:
		_add(id, label, 5, 0, "not evaluated: no player launch exists to discriminate against")
		return
	var arena := _make_arena(true, 0.0)
	var pad: Node3D = arena.pad
	var scene := load(scene_path)
	var body: RigidBody3D = scene.instantiate() if scene else null
	if body == null or pad == null:
		_add(id, label, 5, 0, "scene failed to load: " + scene_path)
		_free_arena(arena)
		return
	# Spawn overlapping the pad's trigger volume so contact is guaranteed
	# even for bodies that don't fall (e.g. zero gravity scale).
	# Positioned before add_child (same spawn-ordering rule as the player).
	body.position = Vector3(0, 0.9, 0)
	arena.root.add_child(body)

	await physics_frame
	var rest_h := _pad_visual_height(pad)
	var max_vy := -INF
	var min_h := INF
	for f in 120:
		await physics_frame
		if f > 3:
			max_vy = maxf(max_vy, body.linear_velocity.y)
		min_h = minf(min_h, _pad_visual_height(pad))

	var launched := max_vy > NONPLAYER_VY_MAX
	var squashed := rest_h > 0.0 and min_h < 0.95 * rest_h
	var pts := 5 if (not launched and not squashed) else 0
	_add(id, label, 5, pts,
		"max upward velocity %.2f m/s (limit %.1f); pad min height %.0f%% of rest (limit 95%%)"
		% [max_vy, NONPLAYER_VY_MAX, (min_h / rest_h * 100.0) if rest_h > 0 else 0.0])
	_free_arena(arena)


# ================================ Helpers ====================================

func _make_arena(with_pad: bool, tilt_deg: float) -> Dictionary:
	var arena_root := Node3D.new()
	arena_root.name = "Arena"

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 3  # Entities + Level, so every body lands on it
	var cshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(80, 2, 80)
	cshape.shape = fbox
	floor_body.add_child(cshape)
	floor_body.position = Vector3(0, -1, 0)  # top surface at y = 0
	arena_root.add_child(floor_body)

	var pad: Node3D = null
	if with_pad:
		var pad_scene := load(PAD_SCENE)
		if pad_scene:
			pad = pad_scene.instantiate()
			pad.rotation.z = deg_to_rad(tilt_deg)
			arena_root.add_child(pad)

	root.add_child(arena_root)
	return {"root": arena_root, "pad": pad}


func _free_arena(arena: Dictionary) -> void:
	for a in ["jump", "move_up"]:
		Input.action_release(a)
	if is_instance_valid(arena.root):
		arena.root.queue_free()
	await physics_frame
	await physics_frame


func _spawn_player(arena: Dictionary, spawn: Vector3) -> CharacterBody3D:
	var scene := load(PLAYER_SCENE)
	if scene == null:
		return null
	var player: CharacterBody3D = scene.instantiate()
	# Position BEFORE entering the tree: adding first would let the player
	# exist at the origin - inside the pad - for one instant, triggering it.
	player.position = spawn
	arena.root.add_child(player)
	return player


## World-space vertical extent of the pad's visible geometry. Implementation-
## agnostic squash measurement: any mechanism that compresses the rendered
## mushroom shows up here.
func _pad_visual_height(pad: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for vi in _collect_visuals(pad):
		var aabb: AABB = vi.get_aabb()
		var xf: Transform3D = vi.global_transform
		for i in 8:
			var corner := xf * aabb.get_endpoint(i)
			lo = minf(lo, corner.y)
			hi = maxf(hi, corner.y)
	return (hi - lo) if hi > lo else 0.0


func _collect_visuals(node: Node) -> Array:
	var found := []
	if node is VisualInstance3D and node.is_visible_in_tree():
		found.append(node)
	for child in node.get_children():
		found += _collect_visuals(child)
	return found


## Geometric contact probe: player mid-body inside the pad's (oriented) trigger
## region. Used only to timestamp contact; detection mechanism is the agent's.
func _in_pad_zone(player: Node3D, pad: Node3D) -> bool:
	var local: Vector3 = pad.global_transform.affine_inverse() * (player.global_position + Vector3.UP * 0.5)
	return absf(local.x) <= 0.95 and absf(local.z) <= 0.95 and local.y >= -0.2 and local.y <= 2.0


## Free flight under the player's own gravity: consecutive per-frame v_y deltas
## must equal -g*dt, checked across the WHOLE ascent (not just a short window
## right after launch) so an implementation that fakes physics briefly and
## drifts later doesn't slip through. Rejects position-tween "launches".
## Returns a dict: gate_ok/gate_error (binary - is this real physics at all,
## a categorical question) and time_mismatch_frames/time_mismatch_valid
## (continuous - only meaningful once the gate passes, how precisely the
## observed time-to-peak matches what the measured launch speed predicts).
func _check_ballistic(vels: Array[Vector3], launch_f: int) -> Dictionary:
	var result := {"gate_ok": false, "gate_error": "", "time_mismatch_valid": false, "time_mismatch_frames": 0.0}
	var first := launch_f + 3
	if first >= vels.size() - 1:
		result.gate_error = "flight window too short"
		return result
	if vels[first].y <= 0.0:
		result.gate_error = "not moving upward at frame %d" % first
		return result

	var i := first
	var checked := 0
	while i < vels.size() - 1 and vels[i].y > 0.0 and checked < ASCENT_CHECK_MAX_FRAMES:
		var dvy := vels[i + 1].y - vels[i].y
		if absf(dvy + PLAYER_GRAVITY * DT) > BALLISTIC_EPS:
			result.gate_error = "dv_y %.3f at frame %d (expected %.3f +/- %.2f)" \
				% [dvy, i, -PLAYER_GRAVITY * DT, BALLISTIC_EPS]
			return result
		i += 1
		checked += 1
	if checked < MIN_ASCENT_CHECK_FRAMES:
		result.gate_error = "ascent too short to verify (%d frames)" % checked
		return result

	result.gate_ok = true
	if i < vels.size() and vels[i].y <= 0.0:
		var predicted_frames := vels[first].y / (PLAYER_GRAVITY * DT)
		var actual_frames := float(i - first)
		result.time_mismatch_valid = true
		result.time_mismatch_frames = absf(actual_frames - predicted_frames)
	return result


func _hspeed(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _max_vy(vels: Array[Vector3]) -> float:
	var m := -INF
	for v in vels:
		m = maxf(m, v.y)
	return m


## Asymmetric linear peak, continuous (no flat plateau, no cliff edges): 1.0
## within RATIO_PEAK_TOL of RATIO_PEAK, ramping steeply to 0 at RATIO_ZERO_LO
## on the undershoot side and gently to 0 at RATIO_ZERO_HI on the overshoot
## side. Every distinct ratio gets a distinct score. Returns 0..1.
func _tent_score(ratio: float) -> float:
	if absf(ratio - RATIO_PEAK) <= RATIO_PEAK_TOL:
		return 1.0
	if ratio < RATIO_PEAK:
		if ratio <= RATIO_ZERO_LO:
			return 0.0
		return (ratio - RATIO_ZERO_LO) / (RATIO_PEAK - RATIO_PEAK_TOL - RATIO_ZERO_LO)
	if ratio >= RATIO_ZERO_HI:
		return 0.0
	return 1.0 - (ratio - RATIO_PEAK - RATIO_PEAK_TOL) / (RATIO_ZERO_HI - RATIO_PEAK - RATIO_PEAK_TOL)


## Same asymmetric-peak shape as _tent_score, applied to T7's overshoot ratio.
func _overshoot_score(ratio: float) -> float:
	if absf(ratio - OVERSHOOT_PEAK) <= OVERSHOOT_PEAK_TOL:
		return 1.0
	if ratio < OVERSHOOT_PEAK:
		if ratio <= OVERSHOOT_ZERO_LO:
			return 0.0
		return (ratio - OVERSHOOT_ZERO_LO) / (OVERSHOOT_PEAK - OVERSHOOT_PEAK_TOL - OVERSHOOT_ZERO_LO)
	if ratio >= OVERSHOOT_ZERO_HI:
		return 0.0
	return 1.0 - (ratio - OVERSHOOT_PEAK - OVERSHOOT_PEAK_TOL) / (OVERSHOOT_ZERO_HI - OVERSHOOT_PEAK - OVERSHOOT_PEAK_TOL)


## One-sided decay for T8's settle deviation: full credit near 0, ramping to
## 0 by SETTLE_ZERO_AT. Deviation can't be negative, so no undershoot side.
func _settle_score(deviation: float) -> float:
	if deviation <= SETTLE_TOL:
		return 1.0
	if deviation >= SETTLE_ZERO_AT:
		return 0.0
	return 1.0 - (deviation - SETTLE_TOL) / (SETTLE_ZERO_AT - SETTLE_TOL)


## Generic zero-decay: full credit within TOL of 0, ramping to 0 by ZERO_AT.
## For any "distance from a perfect zero" measurement (override mismatch,
## residual velocity, timing deviation). Value must be >= 0.
func _zero_decay_score(value: float, tol: float, zero_at: float) -> float:
	if value <= tol:
		return 1.0
	if value >= zero_at:
		return 0.0
	return 1.0 - (value - tol) / (zero_at - tol)


## Ramps from 0 credit (no push at all) up to full credit at TARGET, then
## stays full beyond it - used where "too little" is a real failure but
## "too much" isn't inherently wrong (magnitude is a separate check's job).
func _ramp_to_target_score(value: float, target: float) -> float:
	if value <= 0.0:
		return 0.0
	if value >= target:
		return 1.0
	return value / target


## Generic asymmetric-peak shape (parameterized twin of _tent_score /
## _overshoot_score): full credit within TOL of PEAK, decaying linearly to 0
## at ZERO_LO (below) and ZERO_HI (above). For ratios with real failure
## modes on both sides.
func _ratio_peak_decay_score(ratio: float, peak: float, tol: float, zero_lo: float, zero_hi: float) -> float:
	if absf(ratio - peak) <= tol:
		return 1.0
	if ratio < peak:
		if ratio <= zero_lo:
			return 0.0
		return (ratio - zero_lo) / (peak - tol - zero_lo)
	if ratio >= zero_hi:
		return 0.0
	return 1.0 - (ratio - peak - tol) / (zero_hi - peak - tol)


func _add(id: String, name: String, max_pts: float, pts: float, detail: String) -> void:
	pts = clampf(pts, 0.0, max_pts)
	_checks.append({
		"id": id, "name": name,
		"max": max_pts, "points": snappedf(pts, 0.1),
		"passed": pts >= max_pts - 0.001,
		"detail": detail,
	})
	_score += pts


func _finish() -> void:
	var report := {
		"task": "jumping-pad",
		"godot": Engine.get_version_info().string,
		"meta": _meta,
		"checks": _checks,
		"diagnostics": _diagnostics,
		"score": snappedf(_score, 0.1),
		"max_score": 100,
	}
	print("=== JUMPPAD VERIFIER REPORT ===")
	print(JSON.stringify(report, "  "))
	print("=== SCORE: %.1f / 100 ===" % _score)
	quit(0 if _score >= 60.0 else 1)
