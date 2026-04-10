extends "res://scripts/buildings/building.gd"
# Barracks — spawns units on a steady interval. In M3 this is a tag
# class with spawner-flavored defaults; the actual spawn logic lands
# in M4 when unit classes exist.
#
# NOTE: deliberately no `class_name Barracks` — see tower.gd.

func _init() -> void:
	max_hp = 140
	claim_radius = 7.0
	min_claim_radius = 1.5
