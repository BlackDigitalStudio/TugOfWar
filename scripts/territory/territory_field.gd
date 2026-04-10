extends Node
# TerritoryField — autoload singleton.
#
# Holds the set of currently active "claim contributors" (any node with
# global_position: Vector3, claim_radius: float, and team_sign: float),
# and pushes their state into a target ShaderMaterial on demand.
#
# Contributors register themselves on _enter_tree() and unregister on
# _exit_tree(); the Ground node calls sync_to_material() in its _process
# each frame to keep the shader in sync.
#
# Uniform layout (must match shaders/ground.gdshader):
#   int    claim_count
#   vec2   claim_positions[MAX_CLAIMS]
#   float  claim_radii[MAX_CLAIMS]
#   float  claim_signs[MAX_CLAIMS]

const MAX_CLAIMS: int = 64

var _claims: Array = []


func register(claimable: Object) -> void:
	if claimable == null:
		return
	if not _claims.has(claimable):
		_claims.append(claimable)


func unregister(claimable: Object) -> void:
	_claims.erase(claimable)


# Returns a snapshot of currently-registered claims as an array of
# TerritoryMath.Claim instances. Useful for debugging and tests.
func snapshot_claims() -> Array:
	const TM := preload("res://scripts/territory/territory_math.gd")
	var out: Array = []
	for c in _claims:
		if c == null or not is_instance_valid(c):
			continue
		var p: Vector3 = c.global_position
		out.append(TM.Claim.new(Vector2(p.x, p.z), c.claim_radius, c.team_sign))
	return out


# Push the current claim set into the given ShaderMaterial. Safe to call
# every frame; the data volumes are tiny (a few dozen floats).
#
# Contributors must expose:
#   - global_position   : Vector3
#   - claim_radius      : float   (outer / maximum influence)
#   - min_claim_radius  : float   (inner guaranteed bubble)
#   - team_sign         : float   (+1 player, -1 enemy)
func sync_to_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return

	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	var min_radii := PackedFloat32Array()
	var signs := PackedFloat32Array()
	positions.resize(MAX_CLAIMS)
	radii.resize(MAX_CLAIMS)
	min_radii.resize(MAX_CLAIMS)
	signs.resize(MAX_CLAIMS)

	var count := 0
	for c in _claims:
		if count >= MAX_CLAIMS:
			break
		if c == null or not is_instance_valid(c):
			continue
		var p: Vector3 = c.global_position
		positions[count] = Vector2(p.x, p.z)
		radii[count] = c.claim_radius
		# Defensive: fall back to a small default if the contributor
		# doesn't expose min_claim_radius (shouldn't happen with the
		# Building base class).
		min_radii[count] = c.min_claim_radius if ("min_claim_radius" in c) else 0.0
		signs[count] = c.team_sign
		count += 1

	mat.set_shader_parameter(&"claim_count", count)
	mat.set_shader_parameter(&"claim_positions", positions)
	mat.set_shader_parameter(&"claim_radii", radii)
	mat.set_shader_parameter(&"claim_min_radii", min_radii)
	mat.set_shader_parameter(&"claim_signs", signs)


func claim_count() -> int:
	return _claims.size()


# Sample the territory scalar field at a world XZ point on the CPU.
# Used by the placement controller to decide whether a candidate
# building position is on friendly territory. The shader computes
# exactly the same function per pixel; this method is the CPU mirror.
func field_at(point_xz: Vector2) -> float:
	const TM := preload("res://scripts/territory/territory_math.gd")
	var total := 0.0
	for c in _claims:
		if c == null or not is_instance_valid(c):
			continue
		var p: Vector3 = c.global_position
		total += TM.contribution(
			Vector2(p.x, p.z),
			c.claim_radius,
			c.team_sign,
			point_xz
		)
	return total
