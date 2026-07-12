# PROBE P3 - "linear rebound": complete implementation except the cap returns
# to rest linearly - no elastic overshoot, no wobble. Visually plausible at a
# glance; misses the spec's explicit "overshoots and settles" requirement.
# (First run by hand as a live demo before formalization - scored 85.0.)
#
# Prediction: 85.0 / 100
#   loses T7 (15) only - "post-dip max height 100% of rest (need >= 102%)"
extends Area3D

@export var impulse_strength := 10.0
@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				body.velocity = (Vector3.UP * body.jump_initial_impulse) + (transform.basis * Vector3.UP * impulse_strength)

				var tween := create_tween()
				mushroom.scale.y = 0.4
				tween.tween_property(mushroom, "scale:y", 1.0, 1.0)
	)
