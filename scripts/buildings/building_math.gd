class_name BuildingMath
extends RefCounted
# Pure, stateless helpers for building math:
#   - HP damage application
#   - Placement validity (friendly territory + non-overlap)
#   - Cooldown progression and fill fraction
#
# All functions are static and take their inputs as arguments. No
# tree access, no signals, no autoload lookups. Trivially testable.


# Apply `damage` to `current_hp`, clamped to zero. Negative or zero
# damage is a no-op (returns current_hp unchanged).
static func apply_damage(current_hp: int, damage: int) -> int:
	if damage <= 0:
		return current_hp
	return max(0, current_hp - damage)


# Returns true if a point with the given territory field value is on
# the player's friendly side. `friendly_sign` is +1 for the player,
# -1 for the enemy. A field value on the friendly side has the SAME
# sign as the team's own sign (player team sign +1 → F > 0).
static func is_on_friendly_territory(field_value: float, friendly_sign: float) -> bool:
	return field_value * friendly_sign > 0.0


# Returns true if `candidate_xz` is at least `min_distance` away from
# every point in `existing_xz`. Useful for preventing new buildings
# from overlapping existing ones.
static func is_clear_of_buildings(
	candidate_xz: Vector2,
	existing_xz: Array,
	min_distance: float
) -> bool:
	if min_distance <= 0.0:
		return true
	var min_sq := min_distance * min_distance
	for other in existing_xz:
		if other is Vector2:
			if candidate_xz.distance_squared_to(other) < min_sq:
				return false
	return true


# Advance a cooldown timer by `delta` seconds, clamped to zero.
static func advance_cooldown(remaining: float, delta: float) -> float:
	return max(0.0, remaining - delta)


# Map a cooldown timer to a fill fraction in [0, 1], where 0 = just
# reset and 1 = ready. Guards against division by zero.
static func cooldown_fill_fraction(remaining: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)


# A cooldown is ready when its remaining time has reached (or passed)
# zero.
static func is_cooldown_ready(remaining: float) -> bool:
	return remaining <= 0.0
