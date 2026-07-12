extends Area3D

@export var launch_force := 30.0

@onready var _mushroom: Node3D = %mushroom

var _initial_scale: Vector3
var _tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _mushroom.get_child_count() > 0:
		_initial_scale = _mushroom.get_child(0).scale
	else:
		_initial_scale = Vector3.ONE


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_launch_player(body)
		_animate_mushroom()


func _launch_player(player: Player) -> void:
	# Reset velocity as per SPEC.md: "whatever momentum they already had doesn't carry through the bounce"
	player.velocity = Vector3.ZERO
	
	# Launch in the direction the surface faces
	var launch_direction = global_transform.basis.y.normalized()
	player.velocity = launch_direction * launch_force
	
	# Trigger jump animation on player for a better feel
	var character_skin = player.get_node_or_null("CharacterRotationRoot/CharacterSkin")
	if character_skin and character_skin.has_method("jump"):
		character_skin.jump()


func _animate_mushroom() -> void:
	if _mushroom.get_child_count() == 0:
		return
		
	var mesh = _mushroom.get_child(0)
	
	if _tween:
		_tween.kill()
	
	# Instantly squash down
	mesh.scale = _initial_scale * Vector3(1.5, 0.5, 1.5)
	
	# Create a tween for the bouncy rebound
	_tween = create_tween()
	# Wobble past normal shape and settle
	_tween.tween_property(mesh, "scale", _initial_scale, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
