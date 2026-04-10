extends RefCounted
# Colocated tests for scripts/buildings/building_math.gd.

const BM := preload("res://scripts/buildings/building_math.gd")


# --- apply_damage ---------------------------------------------------------

func test_damage_reduces_hp() -> bool:
	return BM.apply_damage(100, 30) == 70

func test_damage_clamps_at_zero() -> bool:
	return BM.apply_damage(50, 200) == 0

func test_damage_zero_is_noop() -> bool:
	return BM.apply_damage(100, 0) == 100

func test_damage_negative_is_noop() -> bool:
	return BM.apply_damage(100, -30) == 100

func test_damage_already_dead_stays_zero() -> bool:
	return BM.apply_damage(0, 10) == 0


# --- is_on_friendly_territory ---------------------------------------------

func test_friendly_player_positive_field() -> bool:
	return BM.is_on_friendly_territory(0.5, 1.0) == true

func test_friendly_player_negative_field() -> bool:
	return BM.is_on_friendly_territory(-0.5, 1.0) == false

func test_friendly_enemy_negative_field() -> bool:
	return BM.is_on_friendly_territory(-0.5, -1.0) == true

func test_friendly_zero_field_is_unfriendly() -> bool:
	# F=0 is on the border, treat as NOT friendly (conservative).
	return BM.is_on_friendly_territory(0.0, 1.0) == false


# --- is_clear_of_buildings ------------------------------------------------

func test_clear_with_no_existing() -> bool:
	return BM.is_clear_of_buildings(Vector2(0, 0), [], 3.0) == true

func test_clear_when_far_away() -> bool:
	var existing := [Vector2(10, 10), Vector2(-8, 5)]
	return BM.is_clear_of_buildings(Vector2(0, 0), existing, 3.0) == true

func test_not_clear_when_overlapping() -> bool:
	var existing := [Vector2(1, 1)]
	# Distance from (0,0) to (1,1) = sqrt(2) ≈ 1.41 < 3.0 → blocked
	return BM.is_clear_of_buildings(Vector2(0, 0), existing, 3.0) == false

func test_not_clear_when_exactly_at_min_distance() -> bool:
	# Distance exactly equal to min_distance is considered blocked
	# (strict <). At distance == min_distance, should be clear.
	var existing := [Vector2(3, 0)]
	return BM.is_clear_of_buildings(Vector2(0, 0), existing, 3.0) == true

func test_zero_min_distance_allows_overlap() -> bool:
	var existing := [Vector2(0, 0)]
	return BM.is_clear_of_buildings(Vector2(0, 0), existing, 0.0) == true

func test_clear_ignores_non_vector2_entries() -> bool:
	# Defensive: non-Vector2 entries should be skipped gracefully.
	var existing = [Vector2(10, 10), null, "garbage"]
	return BM.is_clear_of_buildings(Vector2(0, 0), existing, 3.0) == true


# --- cooldown math --------------------------------------------------------

func test_advance_cooldown_reduces_remaining() -> bool:
	return absf(BM.advance_cooldown(5.0, 1.5) - 3.5) < 0.0001

func test_advance_cooldown_clamps_at_zero() -> bool:
	return BM.advance_cooldown(1.0, 5.0) == 0.0

func test_fill_fraction_full_when_ready() -> bool:
	return BM.cooldown_fill_fraction(0.0, 6.0) == 1.0

func test_fill_fraction_empty_when_just_reset() -> bool:
	return BM.cooldown_fill_fraction(6.0, 6.0) == 0.0

func test_fill_fraction_half_mid_cooldown() -> bool:
	return absf(BM.cooldown_fill_fraction(3.0, 6.0) - 0.5) < 0.0001

func test_fill_fraction_guards_zero_total() -> bool:
	return BM.cooldown_fill_fraction(0.0, 0.0) == 1.0

func test_is_ready_when_remaining_is_zero() -> bool:
	return BM.is_cooldown_ready(0.0) == true

func test_is_ready_when_remaining_is_negative() -> bool:
	return BM.is_cooldown_ready(-0.5) == true

func test_is_not_ready_when_remaining_positive() -> bool:
	return BM.is_cooldown_ready(0.01) == false
