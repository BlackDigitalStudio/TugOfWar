class_name TerritoryMath
extends RefCounted
# Pure, stateless helpers for the territory scalar field.
#
# A "claim" is a weighted influence around a world point, represented as:
#   position : Vector2   (world XZ)
#   radius   : float     (how far the influence reaches)
#   sign     : float     (+1.0 for player team, -1.0 for enemy team)
#
# The contribution of a single claim at a point is a quadratic falloff
# inside the circle of radius `r`, and zero outside:
#
#     if d >= r: contribution = 0
#     else:      contribution = sign * (1 - d/r) ^ 2
#
# The total field F(x) is the sum of all claim contributions at x.
# Strong positive → blue territory, strong negative → red territory,
# |F| near zero → the dark central band.
#
# This file is the REFERENCE IMPLEMENTATION. The GPU shader at
# shaders/ground.gdshader ports the same formulas fragment-by-fragment;
# the tests in territory_math.test.gd pin down the numerical behavior
# that the shader must match.


# Plain data container for a single claim. Deliberately lightweight —
# doesn't hold a back-reference to a node, just the numbers needed to
# compute the field.
#
# NOTE: the sign field is named `claim_sign` (not `sign`) to avoid
# shadowing the GDScript built-in `sign()` function, which triggers an
# editor warning.
class Claim:
	extends RefCounted
	var position: Vector2
	var radius: float
	var claim_sign: float

	func _init(p: Vector2 = Vector2.ZERO, r: float = 1.0, s: float = 1.0) -> void:
		position = p
		radius = r
		claim_sign = s


# Contribution of a single claim at a world point. Deterministic,
# side-effect-free, safe to call millions of times per frame if needed.
static func contribution(claim_pos: Vector2, radius: float, claim_sign: float, point: Vector2) -> float:
	if radius <= 0.0:
		return 0.0
	var d := claim_pos.distance_to(point)
	if d >= radius:
		return 0.0
	var t := 1.0 - d / radius
	return claim_sign * t * t


# Total scalar field value at a point, summing every claim's
# contribution. Claims far outside their own radius contribute zero, so
# this is O(N) in the number of claims but with an early-out per claim.
static func field_at(point: Vector2, claims: Array) -> float:
	var total := 0.0
	for c in claims:
		if c == null:
			continue
		total += contribution(c.position, c.radius, c.claim_sign, point)
	return total
