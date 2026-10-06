## The map's behaviour, not its looks.
##
## What is worth asserting here is the gating: a locked world must not be
## startable, and the unlock frontier must be the only thing that decides it.
## Appearance is checked by rendering the scene to a PNG and looking at it —
## see dev/capture.tscn — which is not something a test can do for you.
extends GdUnitTestSuite

const LEVEL_MAP := preload("res://game/ui/level_map.tscn")


## Instantiates the map against a specific profile rather than whatever is on
## disk. This is why `progress` is injectable — a test that read the real save
## would pass or fail depending on how far the developer had played.
func _map_with(unlocked_through: int) -> Control:
	var progress := PlayerProgress.new()
	progress.period = PlayerProgress.current_period()
	progress.unlocked_through = unlocked_through

	var map: Control = LEVEL_MAP.instantiate()
	map.progress = progress
	add_child(map)
	map.size = Vector2(720, 1280)
	return map


func _world_buttons(map: Control) -> Array:
	var out: Array = []
	for child in map.get_children():
		if child is Button:
			out.append(child)
	return out


func test_every_world_gets_a_node() -> void:
	var map := _map_with(0)
	assert_int(_world_buttons(map).size()).is_equal(Worlds.COUNT)
	map.queue_free()


func test_locked_worlds_are_disabled_and_unlocked_ones_are_not() -> void:
	var map := _map_with(2)
	var buttons := _world_buttons(map)
	for i in buttons.size():
		assert_bool(buttons[i].disabled) \
			.override_failure_message("world %d disabled=%s with frontier 2" % [i + 1, buttons[i].disabled]) \
			.is_equal(i > 2)
	map.queue_free()


func test_tapping_an_unlocked_world_emits_its_index() -> void:
	var map := _map_with(3)
	var seen: Array[int] = []
	map.world_selected.connect(func(index: int) -> void: seen.append(index))

	_world_buttons(map)[2].pressed.emit()
	assert_array(seen).is_equal([2])
	map.queue_free()


## Belt and braces: the handler itself refuses a locked world, so the gate does
## not depend solely on the Button being disabled. A disabled Button is a UI
## detail and could be restyled away; this is the rule.
func test_a_locked_world_cannot_be_started_even_if_its_button_fires() -> void:
	var map := _map_with(1)
	var seen: Array[int] = []
	map.world_selected.connect(func(index: int) -> void: seen.append(index))

	_world_buttons(map)[5].pressed.emit()
	assert_array(seen).is_empty()

	_world_buttons(map)[1].pressed.emit()
	assert_array(seen).is_equal([1])
	map.queue_free()


func test_the_whole_map_opens_when_everything_is_unlocked() -> void:
	var map := _map_with(Worlds.COUNT - 1)
	for button in _world_buttons(map):
		assert_bool(button.disabled).is_false()
	map.queue_free()


## Positions are fractions of the viewport, so every node must land inside the
## screen at any size — including the narrow phones the layout was not authored
## against.
func test_nodes_stay_on_screen_at_any_viewport() -> void:
	for viewport in [Vector2(320, 568), Vector2(720, 1280), Vector2(1080, 1920)]:
		var map := _map_with(Worlds.COUNT - 1)
		map.size = viewport
		for button in _world_buttons(map):
			var centre: Vector2 = button.position + button.size * 0.5
			assert_bool(centre.x >= 0.0 and centre.x <= viewport.x) \
				.override_failure_message("node centre %s off screen at %s" % [centre, viewport]) \
				.is_true()
			assert_bool(centre.y >= 0.0 and centre.y <= viewport.y) \
				.override_failure_message("node centre %s off screen at %s" % [centre, viewport]) \
				.is_true()
		map.queue_free()
