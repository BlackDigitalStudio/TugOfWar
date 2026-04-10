extends Node
# Coordinates the build-a-building flow:
#   1. BuildBar emits pill_clicked(type).
#   2. This controller spawns a GhostBuilding that lag-follows the
#      ground point under the cursor.
#   3. Each frame, it checks validity (friendly territory +
#      non-overlapping) and pushes the result to the ghost.
#   4. Left-click on a valid spot instantiates the real Building,
#      resets the pill cooldown, and exits placement.
#   5. Right-click / Escape cancels placement without resetting the
#      cooldown.
#
# NOTE: no `class_name PlacementController` — class_name resolution
# in Godot 4 headless first-load is fragile, so cross-script refs go
# through preload constants and duck-typed calls.

const BM := preload("res://scripts/buildings/building_math.gd")
const GhostScript := preload("res://scripts/placement/ghost_building.gd")
const TOWER_SCRIPT := preload("res://scripts/buildings/tower.gd")
const BARRACKS_SCRIPT := preload("res://scripts/buildings/barracks.gd")

@export var camera_path: NodePath
@export var build_bar_path: NodePath
@export var follow_smoothing: float = 12.0
@export var min_distance_between_buildings: float = 2.5
@export var ground_y: float = 0.0

var _camera: Camera3D = null
var _build_bar: Node = null
var _active_type: StringName = &""
var _ghost: Node3D = null
var _target_xz: Vector2 = Vector2.ZERO
var _current_xz: Vector2 = Vector2.ZERO


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_build_bar = get_node_or_null(build_bar_path)
	if _build_bar != null and _build_bar.has_signal(&"pill_clicked"):
		_build_bar.pill_clicked.connect(_on_pill_clicked)


func _process(delta: float) -> void:
	if _ghost == null:
		return
	_update_ghost_target()
	var blend := clampf(follow_smoothing * delta, 0.0, 1.0)
	_current_xz = _current_xz.lerp(_target_xz, blend)
	_ghost.global_position = Vector3(_current_xz.x, ground_y, _current_xz.y)
	_ghost.call(&"set_valid", _is_placement_valid(_current_xz))


func _unhandled_input(event: InputEvent) -> void:
	if _ghost == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _is_placement_valid(_current_xz):
				_place(_current_xz)
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE:
			_cancel()
			get_viewport().set_input_as_handled()


func _on_pill_clicked(building_type: StringName) -> void:
	if _ghost != null:
		_cancel()
	_active_type = building_type
	_ghost = GhostScript.new()
	_ghost.call(&"set_type", building_type, true)
	add_child(_ghost)
	_update_ghost_target()
	_current_xz = _target_xz
	_ghost.global_position = Vector3(_current_xz.x, ground_y, _current_xz.y)
	_ghost.call(&"set_valid", _is_placement_valid(_current_xz))

	if _build_bar != null:
		var pill = _build_bar.call(&"get_pill_for", _active_type)
		if pill != null:
			pill.call(&"set_held", true)


func _cancel() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _build_bar != null and _active_type != &"":
		var pill = _build_bar.call(&"get_pill_for", _active_type)
		if pill != null:
			pill.call(&"set_held", false)
	_active_type = &""


func _place(xz: Vector2) -> void:
	var real := _spawn_real_building(_active_type)
	if real != null:
		get_tree().current_scene.add_child(real)
		real.global_position = Vector3(xz.x, ground_y, xz.y)

	if _build_bar != null and _active_type != &"":
		var pill = _build_bar.call(&"get_pill_for", _active_type)
		if pill != null:
			pill.call(&"reset_cooldown")

	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_active_type = &""


func _update_ghost_target() -> void:
	if _camera == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var mouse := vp.get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return
	var t := (ground_y - origin.y) / dir.y
	if t < 0.0:
		return
	var hit := origin + dir * t
	_target_xz = Vector2(hit.x, hit.z)


func _is_placement_valid(xz: Vector2) -> bool:
	var tf := get_node_or_null(^"/root/TerritoryField")
	if tf == null:
		return false
	var field_value: float = tf.call(&"field_at", xz)
	if not BM.is_on_friendly_territory(field_value, 1.0):
		return false

	var buildings := get_tree().get_nodes_in_group(&"buildings")
	var others: Array[Vector2] = []
	for b in buildings:
		if b is Node3D:
			var p: Vector3 = (b as Node3D).global_position
			others.append(Vector2(p.x, p.z))
	return BM.is_clear_of_buildings(xz, others, min_distance_between_buildings)


func _spawn_real_building(building_type: StringName) -> Node3D:
	var b: Node3D = null
	if building_type == &"tower":
		b = TOWER_SCRIPT.new()
	elif building_type == &"barracks":
		b = BARRACKS_SCRIPT.new()
	if b == null:
		return null

	# Attach a visible cylinder mesh.
	var cyl := CylinderMesh.new()
	if building_type == &"tower":
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 2.0
	else:
		cyl.top_radius = 0.9
		cyl.bottom_radius = 0.9
		cyl.height = 1.5

	var mat := StandardMaterial3D.new()
	# Default to player color; in a multi-team future this comes from `b.team`.
	mat.albedo_color = Color(0.35, 0.5, 0.9)
	mat.roughness = 0.7

	var mesh := MeshInstance3D.new()
	mesh.mesh = cyl
	mesh.material_override = mat
	mesh.position = Vector3(0, cyl.height * 0.5, 0)
	b.add_child(mesh)
	return b
