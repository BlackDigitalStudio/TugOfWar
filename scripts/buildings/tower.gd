extends "res://scripts/buildings/building.gd"
# Tower — stationary defender. In M3 this is purely a tag class with
# defender-flavored defaults; the actual shoot-nearest-enemy-unit
# logic lands in M4 when units exist to shoot.
#
# NOTE: deliberately no `class_name Tower` — cross-script class_name
# resolution in Godot 4 headless first-load order is fragile, so
# subclasses are referenced via `preload()` constants instead.

func _init() -> void:
	max_hp = 80
	claim_radius = 5.0
	min_claim_radius = 1.0
