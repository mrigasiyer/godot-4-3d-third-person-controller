extends Area3D

@export var launch_speed := 26.0
@export var squash_y_scale := 0.52
@export var squash_xz_scale := 1.16
@export var squash_drop := 0.18
@export var rebound_duration := 0.55

@onready var _visual_root: Node3D = %mushroom

var _cap_parts: Array[Node3D] = []
var _cap_rest_scales: Dictionary = {}
var _cap_rest_positions: Dictionary = {}
var _cap_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_cap_parts = _find_cap_parts()
	for part in _cap_parts:
		_cap_rest_scales[part] = part.scale
		_cap_rest_positions[part] = part.position


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return

	var launch_direction := global_transform.basis.y.normalized()
	if launch_direction.is_zero_approx():
		launch_direction = Vector3.UP

	player.launch_from_jump_pad(launch_direction * launch_speed)
	_play_cap_squash()


func _find_cap_parts() -> Array[Node3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_visual_root, meshes)
	if meshes.is_empty():
		return [_visual_root]

	var named_cap_parts: Array[Node3D] = []
	for mesh in meshes:
		var part_name := mesh.name.to_lower()
		if part_name.contains("cap") or part_name.contains("top") or part_name.contains("hat"):
			named_cap_parts.append(mesh)
	if not named_cap_parts.is_empty():
		return named_cap_parts

	var min_y: float = INF
	var max_y: float = -INF
	var mesh_heights: Dictionary = {}
	for mesh in meshes:
		var center_y: float = _visual_root.to_local(mesh.to_global(mesh.get_aabb().get_center())).y
		mesh_heights[mesh] = center_y
		min_y = min(min_y, center_y)
		max_y = max(max_y, center_y)

	var cap_parts: Array[Node3D] = []
	var cap_height: float = lerp(min_y, max_y, 0.45)
	for mesh in meshes:
		var mesh_height: float = mesh_heights[mesh]
		if mesh_height >= cap_height:
			cap_parts.append(mesh)
	if not cap_parts.is_empty():
		return cap_parts
	return [_visual_root]


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _play_cap_squash() -> void:
	if _cap_tween:
		_cap_tween.kill()

	_set_cap_rebound(0.0)
	_cap_tween = create_tween()
	_cap_tween.tween_method(Callable(self, "_set_cap_rebound"), 0.0, 1.0, rebound_duration)
	_cap_tween.finished.connect(_restore_cap)


func _set_cap_rebound(progress: float) -> void:
	var compression := exp(-5.0 * progress) * cos(TAU * 3.0 * progress)
	for part in _cap_parts:
		var rest_scale: Vector3 = _cap_rest_scales[part]
		var rest_position: Vector3 = _cap_rest_positions[part]
		part.scale = Vector3(
			rest_scale.x * (1.0 + (squash_xz_scale - 1.0) * compression),
			rest_scale.y * (1.0 - (1.0 - squash_y_scale) * compression),
			rest_scale.z * (1.0 + (squash_xz_scale - 1.0) * compression),
		)
		part.position = rest_position - Vector3.UP * squash_drop * compression


func _restore_cap() -> void:
	for part in _cap_parts:
		part.scale = _cap_rest_scales[part]
		part.position = _cap_rest_positions[part]
