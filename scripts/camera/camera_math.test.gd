extends RefCounted
# Colocated tests for scripts/camera/camera_math.gd.

const CM := preload("res://scripts/camera/camera_math.gd")


# --- read_input_dir --------------------------------------------------------

func test_input_dir_idle_is_zero() -> bool:
	var d := CM.read_input_dir(false, false, false, false)
	return d == Vector3.ZERO

func test_input_dir_up_is_negative_z() -> bool:
	var d := CM.read_input_dir(true, false, false, false)
	return d == Vector3(0, 0, -1)

func test_input_dir_right_is_positive_x() -> bool:
	var d := CM.read_input_dir(false, false, false, true)
	return d == Vector3(1, 0, 0)

func test_input_dir_diagonal_is_unit_length() -> bool:
	var d := CM.read_input_dir(true, false, false, true)  # up-right
	return absf(d.length() - 1.0) < 0.0001

func test_input_dir_opposing_cancels() -> bool:
	var d := CM.read_input_dir(true, true, false, false)  # up + down
	return d == Vector3.ZERO


# --- clamp_zoom ------------------------------------------------------------

func test_zoom_clamps_upper_bound() -> bool:
	return CM.clamp_zoom(1.5, 0.1, 0.7, 1.5) == 1.5

func test_zoom_clamps_lower_bound() -> bool:
	return CM.clamp_zoom(0.7, -0.1, 0.7, 1.5) == 0.7

func test_zoom_normal_step() -> bool:
	return absf(CM.clamp_zoom(1.0, 0.1, 0.7, 1.5) - 1.1) < 0.0001

func test_zoom_allows_negative_delta_inside_range() -> bool:
	return absf(CM.clamp_zoom(1.0, -0.1, 0.7, 1.5) - 0.9) < 0.0001


# --- mouse_boost_factor ----------------------------------------------------

const VP := Vector2(1920, 1080)
const CENTER := Vector2(960, 540)

func test_boost_factor_one_when_keyboard_idle() -> bool:
	# No keyboard direction → no boost, regardless of cursor position.
	var b := CM.mouse_boost_factor(Vector2(10, 10), VP, Vector3.ZERO, 1.0)
	return b == 1.0

func test_boost_factor_one_at_screen_center() -> bool:
	# Cursor exactly at center → no offset → no boost.
	var b := CM.mouse_boost_factor(CENTER, VP, Vector3(0, 0, -1), 1.0)
	return b == 1.0

func test_boost_factor_one_when_cursor_perpendicular() -> bool:
	# Keyboard: up (world -Z → screen -Y). Cursor offset purely right
	# (screen +X). Dot product is zero → no boost.
	var cursor := CENTER + Vector2(300, 0)
	var b := CM.mouse_boost_factor(cursor, VP, Vector3(0, 0, -1), 1.0)
	return b == 1.0

func test_boost_factor_one_when_cursor_opposite() -> bool:
	# Keyboard: up. Cursor offset DOWN the screen → negative dot → no boost.
	var cursor := CENTER + Vector2(0, 300)
	var b := CM.mouse_boost_factor(cursor, VP, Vector3(0, 0, -1), 1.0)
	return b == 1.0

func test_boost_factor_greater_than_one_when_aligned() -> bool:
	# Keyboard: up. Cursor offset UP the screen (screen -Y). Positive
	# dot → boost > 1.
	var cursor := CENTER + Vector2(0, -300)
	var b := CM.mouse_boost_factor(cursor, VP, Vector3(0, 0, -1), 1.0)
	return b > 1.0

func test_boost_factor_persists_for_static_cursor() -> bool:
	# This is the core behavioral guarantee of the new model: the
	# caller does NOT pass any velocity, so a cursor that hasn't
	# moved in 10 frames still produces the same boost as a moving
	# one. We verify by calling twice with identical inputs and
	# checking the result matches.
	var cursor := CENTER + Vector2(200, -400)
	var a := CM.mouse_boost_factor(cursor, VP, Vector3(0, 0, -1), 1.0)
	var b := CM.mouse_boost_factor(cursor, VP, Vector3(0, 0, -1), 1.0)
	return a == b and a > 1.0

func test_boost_factor_scales_with_distance_from_center() -> bool:
	# Same direction of offset, but farther from center → stronger
	# boost.
	var near_cursor := CENTER + Vector2(0, -50)
	var far_cursor := CENTER + Vector2(0, -400)
	var kb := Vector3(0, 0, -1)
	var near_boost := CM.mouse_boost_factor(near_cursor, VP, kb, 1.0)
	var far_boost := CM.mouse_boost_factor(far_cursor, VP, kb, 1.0)
	return far_boost > near_boost

func test_boost_factor_scales_with_alignment() -> bool:
	# Same offset magnitude, different alignment angles. A perfectly
	# aligned cursor should boost more than one at 45°.
	var aligned := CENTER + Vector2(0, -300)
	var diag := CENTER + Vector2(212, -212)  # same length, 45° off
	var kb := Vector3(0, 0, -1)
	var ba := CM.mouse_boost_factor(aligned, VP, kb, 1.0)
	var bd := CM.mouse_boost_factor(diag, VP, kb, 1.0)
	return ba > bd and bd > 1.0

func test_boost_factor_max_at_corner_aligned() -> bool:
	# Cursor at the top-left corner, keyboard pressing up-left.
	# Distance factor ~1, alignment ~1 (both unit-length and pointing
	# the same way), so boost ~= 1 + max_extra.
	var cursor := Vector2(0, 0)  # top-left corner
	var kb := CM.read_input_dir(true, false, true, false)  # up-left
	var b := CM.mouse_boost_factor(cursor, VP, kb, 1.0)
	# Expect very close to 2.0 (1 + 1*1*1).
	return b > 1.95

func test_boost_factor_zero_viewport_safe() -> bool:
	# Degenerate viewport size should not crash or return NaN.
	var b := CM.mouse_boost_factor(Vector2(0, 0), Vector2.ZERO, Vector3(0, 0, -1), 1.0)
	return b == 1.0

func test_boost_factor_respects_max_extra() -> bool:
	# With max_extra = 0, boost must always be exactly 1.0.
	var cursor := Vector2(0, 0)
	var kb := CM.read_input_dir(true, false, true, false)
	var b := CM.mouse_boost_factor(cursor, VP, kb, 0.0)
	return b == 1.0


# --- apply_soft_bound ------------------------------------------------------

func test_soft_bound_no_drag_inside_radius() -> bool:
	var v := CM.apply_soft_bound(
		Vector3(10, 0, 0),     # well inside 30-unit radius
		Vector3(1, 0, 0),      # outward velocity
		Vector3.ZERO,
		30.0,
		10.0
	)
	return v == Vector3(1, 0, 0)

func test_soft_bound_inward_motion_unattenuated_past_radius() -> bool:
	var v := CM.apply_soft_bound(
		Vector3(35, 0, 0),
		Vector3(-1, 0, 0),
		Vector3.ZERO,
		30.0,
		10.0
	)
	return v == Vector3(-1, 0, 0)

func test_soft_bound_outward_motion_partially_damped() -> bool:
	# At 35 units (5 past 30-unit radius, falloff 10), drag factor is 0.5,
	# so outward velocity of 1.0 should be halved to 0.5.
	var v := CM.apply_soft_bound(
		Vector3(35, 0, 0),
		Vector3(1, 0, 0),
		Vector3.ZERO,
		30.0,
		10.0
	)
	return absf(v.x - 0.5) < 0.0001 and v.y == 0.0 and v.z == 0.0

func test_soft_bound_outward_motion_fully_stopped() -> bool:
	var v := CM.apply_soft_bound(
		Vector3(45, 0, 0),
		Vector3(1, 0, 0),
		Vector3.ZERO,
		30.0,
		10.0
	)
	return v.length() < 0.0001

func test_soft_bound_respects_center_offset() -> bool:
	var v := CM.apply_soft_bound(
		Vector3(135, 0, 0),
		Vector3(1, 0, 0),
		Vector3(100, 0, 0),
		30.0,
		10.0
	)
	return absf(v.x - 0.5) < 0.0001
