# PROBE P5 - "launches everything": correct player behavior, but the pad
# fails to filter - enemies, crates, anything that touches it gets launched
# and triggers the squash. Written generically (CharacterBody3D vs RigidBody3D)
# because the naive unfiltered version would crash on RigidBodies (no
# `velocity` property) and accidentally do nothing.
#
# Prediction: 90.0 / 100 (loses T10a + T10b only)
# ACTUAL:     48.0 / 100 - caught much harder than predicted.
#   T10a/b failed as predicted (beetle 21.82 m/s, crate 20.49 m/s up).
#   Unpredicted: with no player filter, the ARENA FLOOR (a StaticBody3D the
#   pad rests on) triggers the pad at startup - the same thing the terrain
#   would do in the real game. "Rest" height was measured mid-squash (0.643 m,
#   the 0.4x fingerprint), failing T1b and collapsing the whole visual block.
#   Verdict: not a verifier artifact - a real, visible defect of unfiltered
#   pads (they squash spontaneously at level load). Contamination can only
#   affect spec-violating implementations; a correctly filtered pad ignores
#   the floor, so no valid solution can be false-negatived by this.
extends Area3D

@export var impulse_strength := 10.0
@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			var boost := (Vector3.UP * 12.0) + (transform.basis * Vector3.UP * impulse_strength)
			if body is CharacterBody3D:
				body.velocity = boost
			elif body is RigidBody3D:
				body.linear_velocity = boost

			var tween := create_tween()
			mushroom.scale.y = 0.4
			tween.tween_property(mushroom, "scale:y", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	)
