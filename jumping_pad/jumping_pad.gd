extends Area3D

@export var jump_force: float = 30.0

@onready var mushroom = %mushroom
var bounce_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Launch player
		var launch_dir = global_transform.basis.y.normalized()
		body.velocity = launch_dir * jump_force
		
		# Mushroom bounce animation
		if bounce_tween:
			bounce_tween.kill()
		
		bounce_tween = create_tween()
		# Squash
		mushroom.scale = Vector3(1.5, 0.4, 1.5)
		# Spring back
		bounce_tween.tween_property(mushroom, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
