# PROBE P4 - "never recovers": correct launch, cap squashes to 40% on contact
# and simply stays there. The pad ends up permanently flattened.
#
# Prediction: 78.0 / 100
#   loses T7 (15) - no post-dip rise, max stays at 40% of rest
#   loses T8 (7)  - settle window finds the cap 60% away from rest
#   T9 (4) passes vacuously: the cap is permanently below the 90% dip
#   threshold, so "second dip" cannot be distinguished from "never recovered".
#   Accepted: T8 is the check that owns non-recovery, and it catches it.
#   NEG-06 diagnostic should read ~100% compressed (unscored, informative).
extends Area3D

@export var impulse_strength := 10.0
@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				body.velocity = (Vector3.UP * body.jump_initial_impulse) + (transform.basis * Vector3.UP * impulse_strength)
				mushroom.scale.y = 0.4
	)
