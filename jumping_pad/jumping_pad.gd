extends Area3D

## Launch speed given to the player on contact. Chosen well above the character's
## normal jump so the pad clearly out-launches any regular jump.
@export var launch_force := 32.0

## How long the mushroom cap takes to spring back and settle after squashing.
@export var rebound_time := 0.7

## Scale the cap snaps to at the instant of launch (squashed down, spread wide).
@export var squash_scale := Vector3(1.3, 0.55, 1.3)

@onready var _mushroom: Node3D = %mushroom

var _rest_scale := Vector3.ONE
var _cap_tween: Tween


func _ready() -> void:
	_rest_scale = _mushroom.scale
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Only the player character bounces; everything else passes through untouched.
	if not body is Player:
		return

	# Launch along the pad's surface normal so a flat pad throws straight up and a
	# tilted pad throws up and outward. Overwriting velocity discards any incoming
	# momentum, so the result is identical no matter how the player arrived. The
	# player keeps its usual midair air-control from _physics_process.
	var launch_direction := global_transform.basis.y.normalized()
	body.velocity = launch_direction * launch_force

	_play_bounce_animation()


func _play_bounce_animation() -> void:
	# Restart from scratch on every contact.
	if _cap_tween and _cap_tween.is_valid():
		_cap_tween.kill()

	# Instant squash, then a bouncy elastic rebound that wobbles past the rest
	# shape before settling.
	_mushroom.scale = Vector3(
		_rest_scale.x * squash_scale.x,
		_rest_scale.y * squash_scale.y,
		_rest_scale.z * squash_scale.z,
	)
	_cap_tween = create_tween()
	_cap_tween.tween_property(_mushroom, "scale", _rest_scale, rebound_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
