extends Node3D
class_name DebugOrbit
# Debug helper that orbits its PARENT Node3D in a circle on the XZ
# plane. Attach as a child of any Node3D you want to see moving.
#
# This exists purely to visually confirm the territory shader updates
# in real time (the enemy barracks orbit in M2/M3). Delete in M4 once
# real unit motion replaces the need for fake movement.

@export var enabled: bool = true
@export var speed_rad_per_sec: float = 0.4
@export var radius: float = 4.0

var _center: Vector3 = Vector3.ZERO
var _phase: float = 0.0
var _parent: Node3D


func _ready() -> void:
	_parent = get_parent() as Node3D
	if _parent != null:
		_center = _parent.global_position


func _process(delta: float) -> void:
	if not enabled or _parent == null or speed_rad_per_sec == 0.0:
		return
	_phase += delta * speed_rad_per_sec
	var off := Vector3(
		cos(_phase) * radius,
		0.0,
		sin(_phase) * radius
	)
	_parent.global_position = _center + off
