extends GutTest

var ctx: Context

func before_each():
	ctx = Context.new()

func test_get_missing_returns_default():
	assert_eq(ctx.get_var("military"), 0)

func test_set_and_get():
	ctx.set_var("military", 50)
	assert_eq(ctx.get_var("military"), 50)

func test_add_var():
	ctx.set_var("military", 40)
	ctx.add_var("military", 10)
	assert_eq(ctx.get_var("military"), 50)

func test_add_var_negative():
	ctx.set_var("military", 40)
	ctx.add_var("military", -15)
	assert_eq(ctx.get_var("military"), 25)

func test_tokeep_persists_after_empty():
	ctx.set_var("year", 120, true)
	ctx.set_var("military", 60, false)
	ctx.empty_non_keep()
	assert_eq(ctx.get_var("year"), 120)
	assert_eq(ctx.get_var("military"), 0)

func test_non_tokeep_cleared():
	ctx.set_var("military", 60, false)
	ctx.empty_non_keep()
	assert_eq(ctx.get_var("military"), 0)

func test_set_overwrite():
	ctx.set_var("politics", 30)
	ctx.set_var("politics", 55)
	assert_eq(ctx.get_var("politics"), 55)

func test_default_resources_at_50():
	ctx.initialize_new_reign()
	assert_eq(ctx.get_var("military"),  50)
	assert_eq(ctx.get_var("religion"),  50)
	assert_eq(ctx.get_var("commerce"),  50)
	assert_eq(ctx.get_var("politics"),  50)
	assert_eq(ctx.get_var("legitimacy"), 100)

func test_initialize_keeps_tokeep():
	ctx.set_var("year", 80, true)
	ctx.initialize_new_reign()
	assert_eq(ctx.get_var("year"), 80)

func test_is_game_over_at_zero():
	ctx.set_var("military", 0)
	assert_true(ctx.is_game_over())

func test_is_game_over_at_hundred():
	ctx.set_var("religion", 100)
	assert_true(ctx.is_game_over())

func test_no_game_over_normal():
	ctx.initialize_new_reign()
	assert_false(ctx.is_game_over())
