extends Area3D

## Launch speed applied along the pad's local up direction. Far stronger than the player's own jump.
@export var launch_force := 26.0
## How much the mushroom cap squashes down at the instant of launch.
@export var squash_scale := Vector3(1.3, 0.55, 1.3)
## Duration of the initial squash-down.
@export var squash_duration := 0.06
## Duration of the elastic rebound back to resting shape.
@export var rebound_duration := 0.5

@onready var _mushroom: Node3D = %mushroom

var _bounce_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return

	var launch_direction := global_transform.basis.y.normalized()
	body.launch(launch_direction * launch_force)
	_play_bounce_animation()


func _play_bounce_animation() -> void:
	if _bounce_tween:
		_bounce_tween.kill()

	_mushroom.scale = Vector3.ONE
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_mushroom, "scale", squash_scale, squash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_mushroom, "scale", Vector3.ONE, rebound_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
