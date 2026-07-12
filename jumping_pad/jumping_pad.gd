extends Area3D

## Launches the player character off the pad like a springboard.
##
## The launch is a real physics response: the player's velocity is fully
## overwritten with a strong impulse pointing along the pad's surface normal,
## so previous momentum never carries through the bounce and mid-air steering
## still works. Only the player character triggers the pad; anything else
## passes through untouched.

## Launch speed applied along the pad's up direction. Far stronger than the
## character's highest normal jump so the bounce sends them way up.
@export var launch_impulse := 30.0

## How far the mushroom cap squashes down at the instant of launch.
@export var squash_scale := Vector3(1.3, 0.5, 1.3)
## Duration of the springy rebound back to the resting shape.
@export var rebound_duration := 0.7

@onready var _mushroom: Node3D = %mushroom

var _cap_rest_scale := Vector3.ONE
var _rebound_tween: Tween


func _ready() -> void:
	_cap_rest_scale = _mushroom.scale
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# The pad only reacts to the player character. Enemies, projectiles and
	# anything else simply pass through.
	if not body is Player:
		return

	_launch(body)
	_play_cap_squash()


func _launch(player: Player) -> void:
	# Launch along the surface the pad faces: straight up when flat on the
	# ground, up-and-outward when resting on a slope. Overwriting velocity
	# (rather than adding to it) discards whatever momentum the player arrived
	# with, so the bounce always resolves to the same result. Horizontal air
	# control is restored by the player's own movement code the next frame.
	var launch_direction := global_transform.basis.y.normalized()
	player.velocity = launch_direction * launch_impulse


func _play_cap_squash() -> void:
	# Snap the cap into a squash instantly, then let it spring back with a
	# rubbery elastic rebound that wobbles past its rest shape before settling.
	# Each contact restarts the animation from the squashed pose.
	if _rebound_tween and _rebound_tween.is_valid():
		_rebound_tween.kill()

	_mushroom.scale = _cap_rest_scale * squash_scale

	_rebound_tween = create_tween()
	_rebound_tween.tween_property(_mushroom, "scale", _cap_rest_scale, rebound_duration) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
