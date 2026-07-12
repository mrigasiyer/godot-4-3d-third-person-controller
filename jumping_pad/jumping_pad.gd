extends Area3D

@export var launch_speed := 32.0

@onready var _mushroom_visual: Node3D = %mushroom
@onready var _cap_visual: Node3D = _find_cap_visual(_mushroom_visual)

var _cap_rest_position := Vector3.ZERO
var _cap_rest_scale := Vector3.ONE
var _cap_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_cap_rest_position = _cap_visual.position
	_cap_rest_scale = _cap_visual.scale


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return

	var player := body as Player
	var launch_direction := global_transform.basis.y.normalized()
	player.launch_from_jump_pad(launch_direction * launch_speed)
	_play_cap_reaction()


func _play_cap_reaction() -> void:
	if _cap_tween != null:
		_cap_tween.kill()

	_cap_visual.scale = _scaled_rest_scale(Vector3(1.22, 0.55, 1.22))
	_cap_visual.position = _cap_rest_position + Vector3.DOWN * 0.14

	_cap_tween = create_tween()
	_cap_tween.tween_property(_cap_visual, "scale", _scaled_rest_scale(Vector3(1.08, 1.22, 1.08)), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cap_tween.parallel().tween_property(_cap_visual, "position", _cap_rest_position + Vector3.UP * 0.04, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cap_tween.tween_property(_cap_visual, "scale", _scaled_rest_scale(Vector3(1.02, 0.92, 1.02)), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cap_tween.parallel().tween_property(_cap_visual, "position", _cap_rest_position + Vector3.DOWN * 0.02, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cap_tween.tween_property(_cap_visual, "scale", _cap_rest_scale, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_cap_tween.parallel().tween_property(_cap_visual, "position", _cap_rest_position, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _find_cap_visual(root: Node3D) -> Node3D:
	var candidates: Array[Node] = [root]
	while not candidates.is_empty():
		var node: Node = candidates.pop_front()
		if node is Node3D and _name_looks_like_cap(node.name):
			return node
		candidates.append_array(node.get_children())
	return root


func _name_looks_like_cap(node_name: StringName) -> bool:
	var lower_name := String(node_name).to_lower()
	return lower_name.contains("cap") or lower_name.contains("top") or lower_name.contains("hat")


func _scaled_rest_scale(multiplier: Vector3) -> Vector3:
	return Vector3(
		_cap_rest_scale.x * multiplier.x,
		_cap_rest_scale.y * multiplier.y,
		_cap_rest_scale.z * multiplier.z,
	)
