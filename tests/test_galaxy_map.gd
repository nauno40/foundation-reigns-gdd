extends GutTest

const MAP = preload("res://scenes/GalaxyMap.tscn")
var map

func before_each():
	map = MAP.instantiate()
	add_child_autofree(map)

func test_state_color_allied():
	assert_eq(map.state_color(1), map.COLOR_ALLIED)

func test_state_color_hostile():
	assert_eq(map.state_color(-1), map.COLOR_HOSTILE)

func test_state_color_neutral():
	assert_eq(map.state_color(0), map.COLOR_NEUTRAL)
