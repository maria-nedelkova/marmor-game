## The router: the map, and one world at a time.
##
## Deliberately the only place that knows both screens exist. The map emits
## world_selected and knows nothing about playing; the world emits
## exit_requested and knows nothing about the map. Keeping that knowledge in
## one small node is what stops the two screens growing references to each
## other.
extends Node

const LEVEL_MAP := preload("res://game/ui/level_map.tscn")
const WORLD_SCENE := preload("res://game/ui/world_scene.tscn")

var _current: Control


func _ready() -> void:
	_show_map()


func _show_map() -> void:
	# The map reloads its progress in _ready, so returning from a cleared world
	# shows the new unlock without this needing to know that happened.
	var map: Control = LEVEL_MAP.instantiate()
	map.world_selected.connect(_on_world_selected)
	_swap_to(map)


func _on_world_selected(world_index: int) -> void:
	var world: Control = WORLD_SCENE.instantiate()
	world.world_index = world_index
	world.exit_requested.connect(_show_map)
	_swap_to(world)


func _swap_to(next: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = next
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(next)
