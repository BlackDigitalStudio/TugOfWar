extends Node3D
class_name CameraRig
# Top-down orthographic camera rig for Tug of War.
#
# Responsibilities:
#   * Read keyboard pan input (WASD + arrow keys) each frame.
#   * Apply a POSITION-BASED mouse boost: while keyboard pan is held,
#     speed is multiplied by CameraMath.mouse_boost_factor(cursor_pos,
#     viewport_size, keyboard_dir, max_boost_extra). The boost persists
#     for as long as the cursor stays in an offset that agrees with the
#     keyboard direction — no velocity, no decay.
#   * Apply the cozy soft-boundary drag when the rig is panned far from
#     the activity center (origin in M1/M2; will become
#     nearest-friendly-centroid from M3 onward).
#   * Smooth the velocity for feel.
#   * Handle scroll-wheel zoom, clamped to [zoom_min, zoom_max].
#
# All non-trivial math lives in scripts/camera/camera_math.gd as pure
# static functions, so it can be unit-tested without a scene tree.

const CM := preload("res://scripts/camera/camera_math.gd")

@export_group("Pan")
@export var pan_speed: float = 10.0
@export var pan_smoothing: float = 10.0
## Maximum extra speed from the position-based mouse boost, as a
## fraction of pan_speed. 2.0 = up to +200% speed (3x total) when the
## cursor is at a corner perfectly aligned with the keyboard pan.
@export var max_boost_extra: float = 2.0

@export_group("Zoom")
@export var base_ortho_size: float = 12.0
@export var zoom_default: float = 1.0
@export var zoom_min: float = 0.7
@export var zoom_max: float = 1.5
@export var zoom_step: float = 0.1
## Higher = snappier zoom response. The current zoom level lerps
## toward the target at rate zoom_smoothing per second.
@export var zoom_smoothing: float = 12.0

@export_group("Soft bounds")
@export var soft_bound_radius: float = 20.0
@export var soft_bound_falloff: float = 8.0

@onready var camera: Camera3D = $Camera3D

var _velocity: Vector3 = Vector3.ZERO
# Zoom is split into TARGET (where the player wants to be) and
# CURRENT (what's actually applied to the camera). Scroll input
# updates the target; _process lerps current toward target for a
# smooth, continuous zoom instead of discrete jumps.
var _zoom_target: float = 1.0
var _zoom_current: float = 1.0


func _ready() -> void:
	_zoom_target = zoom_default
	_zoom_current = zoom_default
	_apply_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(zoom_step)


func _process(delta: float) -> void:
	var kb_dir := CM.read_input_dir(
		Input.is_key_pressed(KEY_W) or Input.is_action_pressed(&"ui_up"),
		Input.is_key_pressed(KEY_S) or Input.is_action_pressed(&"ui_down"),
		Input.is_key_pressed(KEY_A) or Input.is_action_pressed(&"ui_left"),
		Input.is_key_pressed(KEY_D) or Input.is_action_pressed(&"ui_right")
	)

	var target_velocity := Vector3.ZERO
	if kb_dir != Vector3.ZERO:
		var vp := get_viewport()
		var viewport_size := Vector2.ZERO
		var mouse_pos := Vector2.ZERO
		if vp != null:
			viewport_size = vp.get_visible_rect().size
			mouse_pos = vp.get_mouse_position()
		var boost := CM.mouse_boost_factor(mouse_pos, viewport_size, kb_dir, max_boost_extra)
		target_velocity = kb_dir * (pan_speed * boost)

	# M1/M2: soft bound proxy uses world origin as the activity center.
	# M3+ will replace Vector3.ZERO with the centroid of the nearest
	# friendly entities.
	target_velocity = CM.apply_soft_bound(
		position,
		target_velocity,
		Vector3.ZERO,
		soft_bound_radius,
		soft_bound_falloff
	)

	var blend := clampf(pan_smoothing * delta, 0.0, 1.0)
	_velocity = _velocity.lerp(target_velocity, blend)
	position += _velocity * delta

	# Smooth zoom: exponential approach of current toward target.
	if not is_equal_approx(_zoom_current, _zoom_target):
		var zoom_blend := clampf(zoom_smoothing * delta, 0.0, 1.0)
		_zoom_current = lerpf(_zoom_current, _zoom_target, zoom_blend)
		_apply_zoom()


func _zoom_by(delta_zoom: float) -> void:
	_zoom_target = CM.clamp_zoom(_zoom_target, delta_zoom, zoom_min, zoom_max)


func _apply_zoom() -> void:
	if camera != null:
		camera.size = base_ortho_size * _zoom_current
