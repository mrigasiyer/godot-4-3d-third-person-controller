extends Area3D

## Launch speed applied along the pad's surface normal, tuned well beyond the
## player's own jump so the pad always sends them higher than they could
## manage unassisted.
const LAUNCH_SPEED := 28.0

## How far the cap squashes down the instant it's hit.
const SQUASH_SCALE := Vector3(1.3, 0.55, 1.3)
const SQUASH_DURATION := 0.06
## Bouncy rebound back to rest, overshooting past the normal shape.
const REBOUND_DURATION := 0.6

@onready var _mushroom: Node3D = %mushroom

var _squash_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	var launch_direction := global_transform.basis.y.normalized()
	body.launch(launch_direction * LAUNCH_SPEED)
	_play_bounce_visual()


func _play_bounce_visual() -> void:
	if _squash_tween:
		_squash_tween.kill()
	_mushroom.scale = Vector3.ONE
	_squash_tween = create_tween()
	_squash_tween.tween_property(_mushroom, "scale", SQUASH_SCALE, SQUASH_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_mushroom, "scale", Vector3.ONE, REBOUND_DURATION) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
