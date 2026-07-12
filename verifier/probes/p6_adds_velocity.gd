# PROBE P6 - "adds instead of overrides": the launch is added to the player's
# current velocity instead of replacing it. Feels right when walking on;
# landing from a fall nearly cancels the bounce. Violates the spec's
# "override, not add" requirement.
#
# Prediction: ~84.9 / 100 (T4 0/8; T3 partial ~2.9/10 at ratio ~2.3x)
# ACTUAL:     82.0 / 100 - caught slightly harder.
#   T3 0/10: measured gentle-drop peak 3.87 m -> ratio 1.68x, below the tent
#   floor (2.0x). The player falls further before physical overlap than the
#   back-of-envelope assumed, so += eats ~7 m/s of the launch.
#   T4 0/8 with a stronger signal than predicted: after the high fall the
#   detail reads "no launch after high fall" - 22 - 19 = ~3 m/s up, below the
#   6 m/s launch threshold. The pad literally fails to bounce a falling player.
extends Area3D

@export var impulse_strength := 10.0
@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				body.velocity += (Vector3.UP * body.jump_initial_impulse) + (transform.basis * Vector3.UP * impulse_strength)

				var tween := create_tween()
				mushroom.scale.y = 0.4
				tween.tween_property(mushroom, "scale:y", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	)
