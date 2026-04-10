extends Button
# A single pill in the build bar. Displays a building type name and
# a cooldown countdown; when cooldown reaches zero the pill becomes
# clickable. Clicking a ready pill emits `pill_clicked(building_type)`
# and transitions the pill into "held" state (disabled until the
# player either places the building or cancels placement).
#
# NOTE: no `class_name BuildPill` — see scripts/buildings/tower.gd.

const BM := preload("res://scripts/buildings/building_math.gd")

signal pill_clicked(building_type: StringName)

@export var building_type: StringName = &"tower"
@export var cooldown_total: float = 6.0
@export var start_remaining: float = 3.0

var _remaining: float = 0.0
var _held: bool = false


func _ready() -> void:
	_remaining = start_remaining
	custom_minimum_size = Vector2(140, 96)
	pressed.connect(_on_pressed)
	_refresh_label()


func _process(delta: float) -> void:
	if _held or _remaining <= 0.0:
		return
	_remaining = BM.advance_cooldown(_remaining, delta)
	_refresh_label()


func is_ready_to_build() -> bool:
	return BM.is_cooldown_ready(_remaining) and not _held


func set_held(held: bool) -> void:
	_held = held
	_refresh_label()


func reset_cooldown() -> void:
	_remaining = cooldown_total
	_held = false
	_refresh_label()


func _on_pressed() -> void:
	if is_ready_to_build():
		pill_clicked.emit(building_type)


func _refresh_label() -> void:
	var label := String(building_type).capitalize()
	if _held:
		text = "%s\n(placing)" % label
	elif _remaining <= 0.0:
		text = "%s\nREADY" % label
	else:
		text = "%s\n%0.1fs" % [label, _remaining]
	disabled = _held or _remaining > 0.0
