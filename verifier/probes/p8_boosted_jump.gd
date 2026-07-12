# PROBE P8 - "boosted global jump": the pad implementation itself is the
# original (correct), but the player's base jump impulse is tampered with
# (12.0 -> 20.0 in player.gd). Models an agent that "improves the feel" by
# touching things outside the feature - the spec forbids changing anything
# else about the game.
#
# This probe is TWO changes on the bench:
#   1. this file (identical to the original pad script)
#   2. player.gd: @export var jump_initial_impulse := 12.0  ->  20.0
#
# Prediction: ~89.7 / 100
#   T1a (3) fails: normal tap-jump peak ~6.6 m vs expected 2.30 +/- 0.30.
#   T3 partial: pad launch becomes 30 m/s -> peak ~15 m, but measured against
#   the inflated jump J~6.6 m the ratio is ~2.3x -> roughly 2.7/10 on the tent.
#   Everything else passes - the pad itself is correct.
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
				tween.tween_property(mushroom, "scale:y", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	)
