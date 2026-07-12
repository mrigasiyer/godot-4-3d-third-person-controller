extends Area3D

## The force applied to the player when they step on the pad.
@export var launch_force := 30.0

@onready var _mushroom: Node3D = %mushroom

var _initial_mushroom_scale: Vector3
var _tween: Tween

func _ready() -> void:
	if _mushroom:
		_initial_mushroom_scale = _mushroom.scale
	
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# 6. This behavior is specific to the player character only.
	if body is Player:
		# 1. It launches the player character upward.
		# 4. The jump pad launches the character in the direction its surface faces.
		var launch_direction := global_transform.basis.y.normalized()
		
		# 1. The character is instantly propelled into the air.
		# 3. Whatever momentum they already had doesn't carry through the bounce.
		# Setting the velocity directly resets previous momentum and applies the launch impulse.
		body.velocity = launch_direction * launch_force
		
		# 5. The mushroom jump pad's cap visibly reacts to the bounce.
		_play_bounce_animation()
		
		# Trigger the player's jump animation to make it feel natural.
		# We use the conventional path for the character skin.
		var skin = body.get_node_or_null("CharacterRotationRoot/CharacterSkin")
		if skin and skin.has_method("jump"):
			skin.jump()


func _play_bounce_animation() -> void:
	if not _mushroom:
		return
		
	# 5. Each new contact re-triggers the launch and restarts the mushroom jump pad's cap animation.
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_mushroom.scale = _initial_mushroom_scale
	
	# 5. At the instant of launch, the mushroom cap instantly and momentarily squashes down.
	# We squash on the Y axis and expand on X and Z to simulate volume conservation.
	var squash_scale := Vector3(_initial_mushroom_scale.x * 1.5, _initial_mushroom_scale.y * 0.4, _initial_mushroom_scale.z * 1.5)
	var stretch_scale := Vector3(_initial_mushroom_scale.x * 0.8, _initial_mushroom_scale.y * 1.6, _initial_mushroom_scale.z * 0.8)
	var wobble_scale := Vector3(_initial_mushroom_scale.x * 1.1, _initial_mushroom_scale.y * 0.9, _initial_mushroom_scale.z * 1.1)
	
	# Instant squash (very short duration)
	_tween.tween_property(_mushroom, "scale", squash_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 5. It then springs back toward its normal shape, having a bouncy, rubbery rebound 
	# that wobbles past its normal shape before finally settling at rest.
	_tween.tween_property(_mushroom, "scale", stretch_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_mushroom, "scale", wobble_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_mushroom, "scale", _initial_mushroom_scale, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
