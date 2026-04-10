extends Node3D
# A semi-transparent preview of a building that follows the cursor
# while the player is placing it. Not a real Building (no HP, no
# territory claim, no groups); it's just a visual.
#
# The ghost has two visual states:
#   - INVALID (default, also when over enemy territory or overlapping
#     another building): gray albedo, slow alpha pulse.
#   - VALID (on friendly territory, clear of other buildings): solid
#     team-color albedo, constant alpha.
#
# The PlacementController drives the ghost's world position every
# frame with spring/ease smoothing, and toggles the valid state via
# `set_valid(bool)`.
#
# NOTE: no `class_name GhostBuilding` — see scripts/buildings/tower.gd.

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _is_valid: bool = false
var _team_color: Color = Color(0.35, 0.5, 0.9, 0.7)
var _time: float = 0.0


func set_type(building_type: StringName, team_is_player: bool = true) -> void:
	_team_color = Color(0.35, 0.5, 0.9, 0.7) if team_is_player else Color(0.9, 0.35, 0.35, 0.7)

	if _mesh != null:
		_mesh.queue_free()
		_mesh = null

	var cyl := CylinderMesh.new()
	if building_type == &"tower":
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 2.0
	else:
		# default / barracks
		cyl.top_radius = 0.9
		cyl.bottom_radius = 0.9
		cyl.height = 1.5

	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0.55, 0.55, 0.6, 0.5)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_mesh = MeshInstance3D.new()
	_mesh.mesh = cyl
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position = Vector3(0, cyl.height * 0.5, 0)
	add_child(_mesh)


func set_valid(valid: bool) -> void:
	_is_valid = valid
	_apply_color()


func _process(delta: float) -> void:
	_time += delta
	if not _is_valid and _material != null:
		var pulse := 0.35 + 0.15 * sin(_time * 5.0)
		var c := _material.albedo_color
		c.a = pulse
		_material.albedo_color = c


func _apply_color() -> void:
	if _material == null:
		return
	if _is_valid:
		_material.albedo_color = _team_color
	else:
		_material.albedo_color = Color(0.55, 0.55, 0.6, 0.5)
