extends Area3D

@export var launch_speed := 28.0
@export var squash_scale := Vector3(1.18, 0.55, 1.18)
@export var overshoot_scale := Vector3(0.94, 1.16, 0.94)
@export var squash_offset := 0.12

@onready var _mushroom: Node3D = %mushroom

var _cap: Node3D
var _cap_rest_position := Vector3.ZERO
var _cap_rest_scale := Vector3.ONE
var _cap_tween: Tween


func _ready() -> void:
	_cap = _find_cap_mesh(_mushroom)
	_cap_rest_position = _cap.position
	_cap_rest_scale = _cap.scale
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return

	var player := body as Player
	player.launch_from_jump_pad(global_transform.basis.y.normalized() * launch_speed)
	_play_bounce_animation()


func _play_bounce_animation() -> void:
	if _cap_tween != null:
		_cap_tween.kill()

	_cap.position = _cap_rest_position + Vector3.DOWN * squash_offset
	_cap.scale = _cap_rest_scale * squash_scale

	_cap_tween = create_tween()
	_cap_tween.set_parallel(true)
	_cap_tween.tween_property(_cap, "position", _cap_rest_position, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_cap_tween.tween_property(_cap, "scale", _cap_rest_scale * overshoot_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cap_tween.chain().tween_property(_cap, "scale", _cap_rest_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _find_cap_mesh(root: Node3D) -> Node3D:
	var cap := _find_highest_mesh(root, null)
	return cap if cap != null else root


func _find_highest_mesh(node: Node, current_best: MeshInstance3D) -> MeshInstance3D:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if current_best == null or _get_mesh_center_height(mesh_node) > _get_mesh_center_height(current_best):
			current_best = mesh_node

	for child in node.get_children():
		current_best = _find_highest_mesh(child, current_best)

	return current_best


func _get_mesh_center_height(mesh_node: MeshInstance3D) -> float:
	return mesh_node.to_global(mesh_node.get_aabb().get_center()).y
