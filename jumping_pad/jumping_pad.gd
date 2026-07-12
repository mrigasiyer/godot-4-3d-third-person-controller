extends Area3D

@export var bounce_force: float = 30.0

@onready var mushroom: Node3D = %mushroom
var bounce_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Override velocity to ensure momentum doesn't carry through, sending them in the pad's UP direction
		body.velocity = global_transform.basis.y.normalized() * bounce_force
		
		if bounce_tween and bounce_tween.is_valid():
			bounce_tween.kill()
		
		bounce_tween = create_tween()
		# Squash down instantly
		bounce_tween.tween_property(mushroom, "scale", Vector3(1.3, 0.4, 1.3), 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Spring back
		bounce_tween.tween_property(mushroom, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
