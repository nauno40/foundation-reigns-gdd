extends GutTest

var sys: LegitimacySystem
var ctx: Context

func before_each():
	ctx = Context.new()
	ctx.initialize_new_reign()
	sys = LegitimacySystem.new(ctx)

func test_initial_legitimacy_100():
	assert_eq(ctx.get_var("legitimacy"), 100)

func test_apply_delta_reduces():
	sys.apply_delta(-15)
	assert_eq(ctx.get_var("legitimacy"), 85)

func test_apply_delta_clamps_at_zero():
	sys.apply_delta(-200)
	assert_eq(ctx.get_var("legitimacy"), 0)

func test_apply_delta_clamps_at_hundred():
	sys.apply_delta(200)
	assert_eq(ctx.get_var("legitimacy"), 100)

func test_is_critical_below_15():
	sys.apply_delta(-90)
	assert_true(sys.is_critical())

func test_is_not_critical_above_15():
	assert_false(sys.is_critical())

func test_is_exposed_at_zero():
	sys.apply_delta(-100)
	assert_true(sys.is_exposed())

func test_get_signal_level_high():
	assert_eq(sys.get_signal_level(), LegitimacySystem.SignalLevel.NORMAL)

func test_get_signal_level_suspicious():
	sys.apply_delta(-70)
	assert_eq(sys.get_signal_level(), LegitimacySystem.SignalLevel.SUSPICIOUS)

func test_get_signal_level_critical():
	sys.apply_delta(-90)
	assert_eq(sys.get_signal_level(), LegitimacySystem.SignalLevel.CRITICAL)
