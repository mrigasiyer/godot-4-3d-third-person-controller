extends Area3D

@export var launch_force: float = 35.0

@onready var mushroom = %mushroom
var bounce_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var launch_dir = global_transform.basis.y.normalized()
		body.velocity = launch_dir * launch_force
		
		# Make the character play the jump animation
		if body._character_skin:
			body._character_skin.jump()
		
		# Animate the mushroom cap
		if bounce_tween and bounce_tween.is_valid():
			bounce_tween.kill()
		bounce_tween = create_tween()
		bounce_tween.tween_property(mushroom, "scale", Vector3(1.2, 0.4, 1.2), 0.05).set_trans(Tween.TRANS_LINEAR)
		bounce_tween.tween_property(mushroom, "scale", Vector3(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
