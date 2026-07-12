# PROBE P1 - "launch only": the player is launched correctly, but the mushroom
# cap never animates. A lazy/cheating solution that nails the physics and
# skips the visual entirely.
#
# Prediction: 60.0 / 100
#   loses T6 (12) squash, T7 (15) overshoot, T9 (4) re-trigger
#   T8 (7) and T11 (2) gate out as "not evaluated" (no squash occurred)
#   everything else passes (T1a/T1b/T2/T3/TMC/T4/T5/T10 = 60)
extends Area3D

@export var impulse_strength := 10.0


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				body.velocity = (Vector3.UP * body.jump_initial_impulse) + (transform.basis * Vector3.UP * impulse_strength)
	)
