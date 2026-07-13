extends Area3D

@export var jump_force: float = 35.0

@onready var mushroom: Node3D = %mushroom

var _bounce_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Launch the player upward based on the pad's normal
		body.velocity = global_transform.basis.y.normalized() * jump_force
		
		# Force the player to play the jump animation
		if body.has_node("CharacterRotationRoot/CharacterSkin"):
			var skin = body.get_node("CharacterRotationRoot/CharacterSkin")
			if skin.has_method("jump"):
				skin.jump()
		
		# Animate the mushroom cap bouncing
		if _bounce_tween and _bounce_tween.is_valid():
			_bounce_tween.kill()
			
		# Instantly squash
		mushroom.scale = Vector3(1.5, 0.4, 1.5)
		
		# Spring back with elastic easing
		_bounce_tween = create_tween()
		_bounce_tween.tween_property(mushroom, "scale", Vector3.ONE, 0.8) \
			.set_trans(Tween.TRANS_ELASTIC) \
			.set_ease(Tween.EASE_OUT)
