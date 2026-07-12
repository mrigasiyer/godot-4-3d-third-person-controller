# PROBE P2 - "animation only": the cap squash/elastic rebound is perfect, but
# the player is never launched. Inverse of P1 - all show, no go.
#
# Prediction: 45.0 / 100
#   loses T2 (15), T3 (10), T-MC (5), T4 (8), T5 (7) - no launch exists
#   T10a/b (5+5) gate out as "not evaluated" (no launch to discriminate against)
#   keeps T1a/T1b (5), T6 (12), T7 (15), T8 (7), T9 (4), T11 (2) = 45
extends Area3D

@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var tween := create_tween()
				mushroom.scale.y = 0.4
				tween.tween_property(mushroom, "scale:y", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	)
