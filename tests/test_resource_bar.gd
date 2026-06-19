extends GutTest

const BAR = preload("res://scenes/ResourceBar.tscn")
var bar

func before_each():
	bar = BAR.instantiate()
	add_child_autofree(bar)
	bar.setup("commerce", "Commerce")

func test_flash_direction_up_is_green():
	assert_eq(bar.flash_direction(1), Anim.settings.bar_flash_up,
		"une hausse flashe en vert")

func test_flash_direction_down_is_red():
	assert_eq(bar.flash_direction(-1), Anim.settings.bar_flash_down,
		"une baisse flashe en rouge")

func test_no_flash_when_value_unchanged():
	bar.update_value(50)
	bar._flash_color = Color(1, 1, 1, 0.0)
	bar.update_value(50)
	assert_almost_eq(bar._flash_color.a, 0.0, 0.001,
		"valeur inchangée : pas de flash")
