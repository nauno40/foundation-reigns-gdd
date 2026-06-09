extends GutTest

var sys: RespawnSystem
var ctx: Context

func before_each():
	ctx = Context.new()
	sys = RespawnSystem.new(ctx)

func test_era_start_year_hardin():
	assert_eq(sys.get_era_start_year(50), 1)

func test_era_start_year_merchants():
	assert_eq(sys.get_era_start_year(120), 80)

func test_era_start_year_mallow():
	assert_eq(sys.get_era_start_year(280), 200)

func test_era_start_year_mulet():
	assert_eq(sys.get_era_start_year(320), 290)

func test_era_start_year_restoration():
	assert_eq(sys.get_era_start_year(450), 350)

func test_era_start_year_late_empire():
	assert_eq(sys.get_era_start_year(700), 600)

func test_respawn_resets_resources():
	ctx.set_var("year", 60, true)
	ctx.set_var("military", 10)
	sys.respawn("resource")
	assert_eq(ctx.get_var("military"), 50)

func test_respawn_resets_year_to_era_start():
	ctx.set_var("year", 60, true)
	sys.respawn("resource")
	assert_eq(ctx.get_var("year"), 1)

func test_respawn_natural_sets_legitimacy_100():
	ctx.set_var("year", 1, true)
	sys.respawn("natural")
	assert_eq(ctx.get_var("legitimacy"), 100)

func test_respawn_resource_sets_legitimacy_80():
	ctx.set_var("year", 1, true)
	sys.respawn("resource")
	assert_eq(ctx.get_var("legitimacy"), 80)

func test_respawn_exposed_sets_legitimacy_50():
	ctx.set_var("year", 1, true)
	sys.respawn("exposed")
	assert_eq(ctx.get_var("legitimacy"), 50)

func test_respawn_preserves_seldon_crises():
	ctx.set_var("year", 60, true)
	ctx.set_var("seldon_crisis_1", 1, true)
	sys.respawn("resource")
	assert_eq(ctx.get_var("seldon_crisis_1"), 1)
