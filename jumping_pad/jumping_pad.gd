extends Area3D

## Speed at which the player is launched off the pad. Far stronger than a normal
## jump so the character is sent well beyond their highest reachable height.
@export var launch_speed := 30.0

## How much the cap flattens on impact (fraction of its rest height kept).
@export var squash_amount := 0.5
## How long the cap takes to wobble back to its resting shape.
@export var rebound_time := 0.7

@onready var _mushroom: Node3D = %mushroom

var _rest_scale := Vector3.ONE
var _squash_tween: Tween


func _ready() -> void:
	_rest_scale = _mushroom.scale
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Only the player character reacts to the pad. Enemies, projectiles, boxes and
	# anything else pass straight through without launching or animating.
	if not body is Player:
		return

	_launch(body)
	_squash_cap()


func _launch(player: Player) -> void:
	# Launch along the direction the pad's surface faces: straight up for a flat
	# pad, up-and-outward for one resting on a slope. Overwriting the velocity
	# (instead of adding to it) discards whatever momentum the player arrived with,
	# so every contact sends them to the same result. Horizontal air control is
	# untouched, so the player keeps steering mid-flight, and because this is a
	# genuine velocity change the character still collides with ceilings and walls.
	var launch_direction := global_transform.basis.y.normalized()
	player.velocity = launch_direction * launch_speed


func _squash_cap() -> void:
	# Instantly flatten the cap, then let it spring back with a bouncy, rubbery
	# rebound that overshoots its rest shape before settling. Re-triggered from
	# scratch on every contact.
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()

	var squashed := Vector3(
		_rest_scale.x / squash_amount,
		_rest_scale.y * squash_amount,
		_rest_scale.z / squash_amount,
	)
	_mushroom.scale = squashed

	_squash_tween = create_tween()
	_squash_tween.tween_property(_mushroom, "scale", _rest_scale, rebound_time) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
