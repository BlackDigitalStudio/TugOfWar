extends CanvasLayer
# Bottom-screen build bar that holds one or more BuildPill children.
# Relays their `pill_clicked` signals to listeners (the
# PlacementController) via its own `pill_clicked` signal, and exposes
# a `get_pill_for(building_type)` lookup so the controller can flip a
# pill's held/ready state after placement or cancel.
#
# NOTE: no `class_name BuildBar` — see scripts/buildings/tower.gd for
# why custom class_names are avoided in the M3 UI/placement chain.
# Pills are duck-typed via the `is_ready_to_build()` method so we
# don't need a type dependency on the BuildPill script.

signal pill_clicked(building_type: StringName)

var _pills: Array = []


func _ready() -> void:
	_find_pills(self)
	for p in _pills:
		if p.has_signal(&"pill_clicked"):
			p.pill_clicked.connect(_on_pill_clicked)


func get_pill_for(building_type: StringName):
	for p in _pills:
		if p.building_type == building_type:
			return p
	return null


func _find_pills(node: Node) -> void:
	if node.has_method(&"is_ready_to_build"):
		_pills.append(node)
	for child in node.get_children():
		_find_pills(child)


func _on_pill_clicked(building_type: StringName) -> void:
	pill_clicked.emit(building_type)
