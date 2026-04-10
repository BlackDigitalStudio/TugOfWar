extends RefCounted
# Colocated tests for scripts/territory/territory_math.gd.
# These tests are the reference behavior that the ground shader in
# shaders/ground.gdshader must match fragment-for-fragment.

const TM := preload("res://scripts/territory/territory_math.gd")


# --- contribution ---------------------------------------------------------

func test_contribution_at_claim_center_is_sign() -> bool:
	# At distance 0 the quadratic term is (1 - 0)^2 = 1, so the
	# contribution equals `sign` exactly.
	var c := TM.contribution(Vector2(10, 10), 5.0, 1.0, Vector2(10, 10))
	return absf(c - 1.0) < 0.0001

func test_contribution_at_boundary_is_zero() -> bool:
	# At d == r, (1 - d/r)^2 = 0.
	var c := TM.contribution(Vector2.ZERO, 5.0, 1.0, Vector2(5, 0))
	return absf(c) < 0.0001

func test_contribution_past_boundary_is_zero() -> bool:
	var c := TM.contribution(Vector2.ZERO, 5.0, 1.0, Vector2(50, 0))
	return c == 0.0

func test_contribution_half_radius_is_one_quarter() -> bool:
	# At d == r/2, (1 - 0.5)^2 = 0.25.
	var c := TM.contribution(Vector2.ZERO, 10.0, 1.0, Vector2(5, 0))
	return absf(c - 0.25) < 0.0001

func test_contribution_sign_flip_inverts() -> bool:
	var pos := Vector2.ZERO
	var point := Vector2(2, 0)
	var pos_contrib := TM.contribution(pos, 5.0, 1.0, point)
	var neg_contrib := TM.contribution(pos, 5.0, -1.0, point)
	return absf(pos_contrib + neg_contrib) < 0.0001

func test_contribution_zero_radius_returns_zero() -> bool:
	# Guard against division-by-zero.
	var c := TM.contribution(Vector2.ZERO, 0.0, 1.0, Vector2(1, 0))
	return c == 0.0

func test_contribution_respects_distance_not_direction() -> bool:
	# Claims are radially symmetric.
	var a := TM.contribution(Vector2.ZERO, 10.0, 1.0, Vector2(3, 0))
	var b := TM.contribution(Vector2.ZERO, 10.0, 1.0, Vector2(0, 3))
	var c := TM.contribution(Vector2.ZERO, 10.0, 1.0, Vector2(-3, 0))
	return absf(a - b) < 0.0001 and absf(b - c) < 0.0001


# --- field_at (many claims) -----------------------------------------------

func test_field_empty_claims_is_zero() -> bool:
	return TM.field_at(Vector2(5, 5), []) == 0.0

func test_field_single_claim_matches_contribution() -> bool:
	var c := TM.Claim.new(Vector2(10, 0), 5.0, 1.0)
	var point := Vector2(12, 0)
	var f := TM.field_at(point, [c])
	var expected := TM.contribution(c.position, c.radius, c.claim_sign, point)
	return absf(f - expected) < 0.0001

func test_field_two_opposing_claims_cancel_at_midpoint() -> bool:
	# Player claim at (-5, 0) and enemy claim at (+5, 0), same radius.
	# The midpoint (0, 0) should have a field of exactly zero: each
	# claim contributes the same magnitude with opposite signs.
	var player := TM.Claim.new(Vector2(-5, 0), 10.0, 1.0)
	var enemy := TM.Claim.new(Vector2(5, 0), 10.0, -1.0)
	var f := TM.field_at(Vector2.ZERO, [player, enemy])
	return absf(f) < 0.0001

func test_field_two_opposing_claims_positive_toward_player() -> bool:
	# Same two claims, sampling closer to the player. Field should be
	# positive (player dominant).
	var player := TM.Claim.new(Vector2(-5, 0), 10.0, 1.0)
	var enemy := TM.Claim.new(Vector2(5, 0), 10.0, -1.0)
	var f := TM.field_at(Vector2(-3, 0), [player, enemy])
	return f > 0.0

func test_field_two_opposing_claims_negative_toward_enemy() -> bool:
	var player := TM.Claim.new(Vector2(-5, 0), 10.0, 1.0)
	var enemy := TM.Claim.new(Vector2(5, 0), 10.0, -1.0)
	var f := TM.field_at(Vector2(3, 0), [player, enemy])
	return f < 0.0

func test_field_two_same_sign_claims_reinforce() -> bool:
	# Two player claims close together should produce a field stronger
	# than either individually at a point near both.
	var a := TM.Claim.new(Vector2(-2, 0), 10.0, 1.0)
	var b := TM.Claim.new(Vector2(2, 0), 10.0, 1.0)
	var mid := Vector2.ZERO
	var single := TM.contribution(a.position, a.radius, a.claim_sign, mid)
	var combined := TM.field_at(mid, [a, b])
	return combined > single

func test_field_distant_point_is_zero() -> bool:
	# Point far outside every claim's radius.
	var claims := [
		TM.Claim.new(Vector2(-5, 0), 3.0, 1.0),
		TM.Claim.new(Vector2(5, 0), 3.0, -1.0),
	]
	var f := TM.field_at(Vector2(100, 100), claims)
	return f == 0.0

func test_field_ignores_null_entries() -> bool:
	# Defensive: a null in the array shouldn't crash the sum.
	var c := TM.Claim.new(Vector2.ZERO, 5.0, 1.0)
	var f := TM.field_at(Vector2(1, 0), [c, null])
	return f > 0.0
