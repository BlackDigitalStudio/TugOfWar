class_name Building
extends Node3D
# Base class for all buildings in Tug of War.
#
# A Building has HP, a team, and a "claim radius" that controls how
# strongly it influences the territory scalar field. It self-registers
# with the TerritoryField autoload on _enter_tree so the ground shader
# updates automatically.
#
# Tower and Barracks extend this class and set different defaults.
# Real combat / spawn behavior lands in M4.
#
# Duck-type contract consumed by TerritoryField:
#   - global_position : Vector3
#   - claim_radius    : float
#   - team_sign       : float (+1 for PLAYER, -1 for ENEMY)

enum Team { PLAYER, ENEMY }

signal hp_changed(new_hp: int, max_hp_value: int)
signal destroyed()

@export var team: Team = Team.PLAYER
@export var max_hp: int = 100
## Outer / maximum influence radius. This is the falloff radius for the
## claim's smooth contribution to the territory field.
@export var claim_radius: float = 6.0
## Inner guaranteed bubble. Inside this radius, opposing-team claims
## are shielded to zero in the ground shader, so the building always
## retains a core of its own color even when surrounded.
@export var min_claim_radius: float = 1.0

var hp: int = -1  # -1 = uninitialized; set in _enter_tree from max_hp

var team_sign: float:
	get:
		return 1.0 if team == Team.PLAYER else -1.0


func _enter_tree() -> void:
	if hp < 0:
		hp = max_hp
	add_to_group(&"buildings")
	_register_with_territory()


func _exit_tree() -> void:
	_unregister_with_territory()


func take_damage(amount: int) -> void:
	const BM := preload("res://scripts/buildings/building_math.gd")
	var new_hp := BM.apply_damage(hp, amount)
	if new_hp == hp:
		return
	hp = new_hp
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		destroy()


func destroy() -> void:
	destroyed.emit()
	queue_free()


func _register_with_territory() -> void:
	var tf := _territory_field()
	if tf != null:
		tf.register(self)


func _unregister_with_territory() -> void:
	var tf := _territory_field()
	if tf != null:
		tf.unregister(self)


func _territory_field() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"/root/TerritoryField")
	return null
