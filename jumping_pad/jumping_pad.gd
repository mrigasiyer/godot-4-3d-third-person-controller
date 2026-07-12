extends Area3D

## Speed applied to the player along the pad's surface normal, far exceeding a normal jump.
@export var launch_speed := 27.0
## How squashed the cap gets at the instant of launch.
@export var squash_scale := Vector3(1.35, 0.55, 1.35)
## How long the cap takes to spring back to its resting shape.
@export var rebound_duration := 0.6

@onready var _mushroom: Node3D = %mushroom
@onready var _mushroom_rest_scale: Vector3 = _mushroom.scale

var _rebound_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return

	var launch_direction := global_transform.basis.y.normalized()
	body.velocity = launch_direction * launch_speed

	_play_bounce_animation()


func _play_bounce_animation() -> void:
	if _rebound_tween:
		_rebound_tween.kill()

	_mushroom.scale = squash_scale
	_rebound_tween = create_tween()
	_rebound_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_rebound_tween.tween_property(_mushroom, "scale", _mushroom_rest_scale, rebound_duration)
