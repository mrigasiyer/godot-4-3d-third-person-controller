# PROBE P7 - "position tween": fakes the launch by animating the player's
# position upward. The player visibly rises ~8 m - a verifier that only asked
# "did the player get high?" would pass this. Ours grades velocity + ballistic
# gravity integration, which a position animation cannot produce.
# Squash kept fully correct to isolate the launch cheat.
#
# Prediction: 45.0 / 100 (launch checks fail, full visual block passes)
# ACTUAL:     34.0 / 100 - caught harder: T8 and T9 also failed, legitimately.
#   The cheat creates an infinite fake-bounce loop: gravity accumulates in the
#   player's real velocity during the tween ride, they plummet back at ~25 m/s,
#   re-enter the trigger, and re-fire squash + rise forever. T8's settle window
#   caught the cap mid-re-squash (60% deviation). T9's teleported player was
#   yanked away by a still-alive rise tween ("no second contact") - the
#   animation fights external control of the character. Both are real,
#   player-visible misbehaviors of the cheat, not verifier artifacts.
extends Area3D

@export var impulse_strength := 10.0
@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var rise := create_tween()
				rise.tween_property(body, "global_position",
					body.global_position + Vector3.UP * 7.9, 0.75).set_ease(Tween.EASE_OUT)

				var tween := create_tween()
				mushroom.scale.y = 0.4
				tween.tween_property(mushroom, "scale:y", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	)
