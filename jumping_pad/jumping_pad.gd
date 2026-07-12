extends Area3D

@export var jump_force: float = 30.0

@onready var mushroom: Node3D = %mushroom
var bounce_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Direction the surface faces (Area3D's up vector)
		var launch_direction = global_transform.basis.y.normalized()
		
		# Reset momentum
		body.velocity = launch_direction * jump_force
		
		# Trigger visual reaction
		if bounce_tween and bounce_tween.is_valid():
			bounce_tween.kill()
		
		bounce_tween = create_tween()
		
		# Instantly squash down
		mushroom.scale = Vector3(1.4, 0.4, 1.4)
		
		# Spring back with elastic ease
		bounce_tween.tween_property(mushroom, "scale", Vector3.ONE, 0.8) \
			.set_trans(Tween.TRANS_ELASTIC) \
			.set_ease(Tween.EASE_OUT)
