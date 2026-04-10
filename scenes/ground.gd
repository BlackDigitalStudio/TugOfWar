extends MeshInstance3D
# Ground plane + territory shader sync.
#
# Owns the zone-color ground ShaderMaterial. Each frame, asks the
# TerritoryField autoload to push the active claims into our shader
# uniforms. If a ContourOverlay child MeshInstance3D exists, its
# alpha-to-coverage contour material is synced as well so both
# shaders see the same claim data.


var _shader_material: ShaderMaterial = null
var _contour_material: ShaderMaterial = null


func _ready() -> void:
	_shader_material = material_override as ShaderMaterial
	if _shader_material == null:
		push_error("Ground: material_override is not a ShaderMaterial. Check main.tscn.")

	var overlay := get_node_or_null(^"ContourOverlay")
	if overlay is MeshInstance3D:
		_contour_material = (overlay as MeshInstance3D).material_override as ShaderMaterial


func _process(_delta: float) -> void:
	var tf := get_node_or_null(^"/root/TerritoryField")
	if tf == null:
		return
	if _shader_material != null:
		tf.sync_to_material(_shader_material)
	if _contour_material != null:
		tf.sync_to_material(_contour_material)
