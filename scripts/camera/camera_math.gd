class_name CameraMath
extends RefCounted
# Pure, stateless helpers for the camera rig. Every function is static and
# takes all of its inputs as arguments — no @onready, no signals, no tree
# access. This is deliberate: it makes the logic trivially testable from a
# *.test.gd file without a live SceneTree.
#
# Coordinate conventions used throughout:
#
#  * World axes follow Godot defaults: +X right, +Y up, -Z "forward".
#  * In the M1/M2 scene the camera looks down at the XZ ground plane.
#  * Keyboard pan input is expressed as a Vector3 where .x and .z are the
#    horizontal pan components and .y is unused (always 0).
#  * Screen-space mouse position and viewport size are in pixel units
#    where +X is right, +Y is DOWN (Godot viewport coordinates).
#
# The mouse-boost model is POSITION-based, not velocity-based: while a
# keyboard pan direction is held, the boost strength depends on where
# the cursor sits relative to the screen center, in the same direction
# as the pan. The farther out and the more aligned, the stronger the
# boost. This is persistent — the cursor does not need to keep moving.


# Read a 2D keyboard pan direction from four boolean key states, normalized
# to unit length. Returns Vector3.ZERO when no keys are held.
static func read_input_dir(up: bool, down: bool, left: bool, right: bool) -> Vector3:
	var dir := Vector3.ZERO
	if up:
		dir.z -= 1.0
	if down:
		dir.z += 1.0
	if left:
		dir.x -= 1.0
	if right:
		dir.x += 1.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	return dir


# Clamp a proposed new zoom level into [zoom_min, zoom_max]. Used for the
# scroll-wheel handler; the caller provides the signed delta (positive =
# zoom out in orthographic size terms).
static func clamp_zoom(current: float, delta: float, zoom_min: float, zoom_max: float) -> float:
	return clampf(current + delta, zoom_min, zoom_max)


# Compute the current mouse-boost multiplier based on the cursor
# POSITION relative to the screen center.
#
# The boost is only non-trivial when:
#   (a) the player is holding a keyboard pan direction, AND
#   (b) the cursor is offset from screen center in a direction that
#       agrees with the keyboard pan direction (positive dot product).
#
# Boost strength scales with BOTH:
#   - how far from screen center the cursor is (0..1 at corners), AND
#   - how well aligned the cursor offset is with the keyboard direction
#     (dot product of normalized vectors, 0..1 range when positive).
#
# The result is persistent: as long as the cursor stays at the same
# offset, the boost stays at the same value — no decay, no velocity
# dependence. Moving the cursor toward the edge increases the boost
# gradually.
#
# Returns 1.0 when not boosting, or a value in (1.0, 1.0 + max_extra]
# when boosting.
#
# Arguments:
#   mouse_pos      : current mouse position in viewport pixels
#   viewport_size  : total viewport dimensions in pixels (Vector2)
#   keyboard_dir   : world-space keyboard pan direction (.y ignored)
#   max_extra      : upper bound on the additional speed fraction
#                    (e.g. 1.0 → at full boost speed is 2× base)
static func mouse_boost_factor(
	mouse_pos: Vector2,
	viewport_size: Vector2,
	keyboard_dir: Vector3,
	max_extra: float
) -> float:
	var kb_2d := Vector2(keyboard_dir.x, keyboard_dir.z)
	if kb_2d.length_squared() < 0.0001:
		return 1.0
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0

	var center := viewport_size * 0.5
	var offset := mouse_pos - center
	# Distance from center to corner — the maximum possible offset.
	var half_diag := center.length()
	if half_diag <= 0.0:
		return 1.0

	var offset_len := offset.length()
	if offset_len < 0.0001:
		return 1.0
	var distance_factor := clampf(offset_len / half_diag, 0.0, 1.0)

	var offset_unit := offset / offset_len
	var kb_unit := kb_2d.normalized()
	var alignment := offset_unit.dot(kb_unit)
	if alignment <= 0.0:
		return 1.0

	# Both factors are in [0, 1]; their product is a smooth ramp from
	# no boost (at center or perpendicular) to max boost (at corner
	# when perfectly aligned).
	var boost := distance_factor * alignment
	return 1.0 + max_extra * boost


# Apply the "cozy soft boundary" drag to a proposed target velocity.
# Inward motion (toward the origin / activity center) is unaffected.
# Outward motion is attenuated progressively once past `radius`, reaching
# full stop `falloff` units further out.
#
# Arguments:
#   position        : current rig position (Vector3)
#   target_velocity : the velocity the input layer wants to apply
#   center          : reference point (world origin in M1, will become
#                     "nearest friendly entity centroid" in M3+)
#   radius          : distance from center at which drag begins
#   falloff         : additional distance over which drag ramps 0 -> 1
#
# Returns the velocity after drag, safe to pass into movement integration.
static func apply_soft_bound(
	position: Vector3,
	target_velocity: Vector3,
	center: Vector3,
	radius: float,
	falloff: float
) -> Vector3:
	var offset := position - center
	var dist := offset.length()
	if dist <= radius or dist < 0.0001:
		return target_velocity
	if falloff <= 0.0:
		# Guard against divide-by-zero: treat as hard cut at the radius.
		var outward_hard := offset.normalized()
		var oc_hard := target_velocity.dot(outward_hard)
		if oc_hard <= 0.0:
			return target_velocity
		return target_velocity - outward_hard * oc_hard

	var over := dist - radius
	# drag=1 just outside the radius, drag=0 once we've crossed `falloff`.
	var drag := clampf(1.0 - over / falloff, 0.0, 1.0)
	var outward := offset.normalized()
	var outward_component := target_velocity.dot(outward)
	if outward_component <= 0.0:
		# Moving inward — no attenuation.
		return target_velocity
	return target_velocity - outward * outward_component * (1.0 - drag)
