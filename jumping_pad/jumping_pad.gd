extends Area3D

## The force applied to the player when they step on the pad.
## A normal jump is around 12.0, so 35.0 is "far stronger".
@export var launch_force := 35.0

@onready var mushroom: Node3D = %mushroom


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Requirement 6: This behavior is specific to the player character only.
	# Using the class_name Player defined in player.gd.
	if body is Player:
		_launch_player(body)


func _launch_player(player: Player) -> void:
	# Requirement 4: The jump pad launches the character in the direction its surface faces.
	# global_transform.basis.y points "up" relative to the pad's rotation.
	var launch_direction := global_transform.basis.y.normalized()
	
	# Requirement 1: It launches the player character upward (physics response).
	# Requirement 3: whatever momentum they already had doesn't carry through the bounce.
	# Setting the velocity directly ensures previous momentum is discarded.
	player.velocity = launch_direction * launch_force
	
	# Trigger visual feedback on the player character skin for consistency.
	var skin = player.get_node_or_null("CharacterRotationRoot/CharacterSkin")
	if skin and skin.has_method("jump"):
		skin.jump()
	
	# Requirement 5: The mushroom jump pad's cap visibly reacts to the bounce.
	_play_bounce_animation()


func _play_bounce_animation() -> void:
	if not mushroom:
		return
	
	# Requirement 5: Each new contact re-triggers the launch and restarts the animation.
	# Using a Tween for the "rubbery rebound that wobbles".
	var tween := create_tween()
	
	# Start by resetting scale in case a tween was already running.
	mushroom.scale = Vector3.ONE
	
	# Requirement 5: Instantly and momentarily squashes down.
	# Squash Y and expand X/Z to maintain perceived volume.
	tween.tween_property(mushroom, "scale", Vector3(1.4, 0.3, 1.4), 0.05)
	
	# Requirement 5: Springs back ... bouncy, rubbery rebound that wobbles past its normal shape.
	# TRANS_ELASTIC with EASE_OUT provides the requested wobbling effect.
	tween.tween_property(mushroom, "scale", Vector3.ONE, 0.8)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)
