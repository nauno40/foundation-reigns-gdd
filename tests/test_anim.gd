extends GutTest

# Anim est un autoload : accessible directement via le singleton.

func test_smooth_converges_toward_target():
	var v := 0.0
	for i in range(200):
		v = Anim.smooth(v, 10.0, 12.0, 1.0 / 60.0)
	assert_almost_eq(v, 10.0, 0.01, "smooth doit converger vers la cible")

func test_smooth_is_monotonic_toward_target():
	var v := 0.0
	var prev := v
	for i in range(10):
		v = Anim.smooth(v, 10.0, 12.0, 1.0 / 60.0)
		assert_gt(v, prev, "chaque pas se rapproche de la cible")
		assert_lt(v, 10.0, "sans jamais dépasser")
		prev = v

func test_format_count_clamps_to_target():
	assert_eq(Anim.format_count(7.4, 10), "7")
	assert_eq(Anim.format_count(9.9, 10), "10")
	assert_eq(Anim.format_count(12.0, 10), "10",
		"ne dépasse jamais la cible")

func test_settings_loaded():
	assert_not_null(Anim.settings, "la Resource AnimSettings doit être chargée")
	assert_almost_eq(Anim.settings.card_rot_offset_factor, 0.045, 0.0001)
