extends Area3D

@export var launch_force: float = 40.0

@onready var mushroom: Node3D = %mushroom

var tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Overwrite momentum completely, launch in facing direction
		body.velocity = global_transform.basis.y.normalized() * launch_force
		
		# Try to play the jump animation if available
		var skin_path = "CharacterRotationRoot/CharacterSkin"
		if body.has_node(skin_path):
			var skin = body.get_node(skin_path)
			if skin.has_method("jump"):
				skin.jump()
		
		# Animate the mushroom squash and bounce
		if tween and tween.is_valid():
			tween.kill()
		
		tween = create_tween()
		
		# Instantly squash down
		mushroom.scale = Vector3(1.5, 0.3, 1.5)
		
		# Spring back to normal with an elastic wobble
		tween.tween_property(mushroom, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
