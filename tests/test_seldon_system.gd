extends GutTest

var data: FoundationGameData
var ctx: Context
var seldon: SeldonSystem

func before_each():
	data = FoundationGameData.new()
	data.load_all()
	ctx = Context.new()
	ctx.initialize_new_reign()
	seldon = SeldonSystem.new(data, ctx)

# --- Couloir 1 (GDD §2.8) : religion > 30 · military < 60 · relation_military_kingdoms > -30 ---

func test_corridor_1_passes_with_default_values():
	# défauts : religion 50, military 50, relation absente (0)
	assert_true(seldon.evaluate_corridor(1))

func test_corridor_1_fails_on_low_religion():
	ctx.set_var("religion", 20)
	assert_false(seldon.evaluate_corridor(1))

func test_corridor_1_fails_on_high_military():
	ctx.set_var("military", 70)
	assert_false(seldon.evaluate_corridor(1))

func test_corridor_1_fails_on_bad_relation():
	ctx.set_var("relation_military_kingdoms", -40)
	assert_false(seldon.evaluate_corridor(1))

# --- Couloir 6 : équilibre des 4 ressources (30-70) + legitimacy > 60 ---

func test_corridor_6_passes_balanced():
	ctx.set_var("legitimacy", 80)
	assert_true(seldon.evaluate_corridor(6))

func test_corridor_6_fails_unbalanced_resource():
	ctx.set_var("legitimacy", 80)
	ctx.set_var("commerce", 80)
	assert_false(seldon.evaluate_corridor(6))

func test_unknown_crisis_fails():
	assert_false(seldon.evaluate_corridor(99))

# --- resolve_pending : consomme le marqueur posé par les cartes de dénouement ---

func test_resolve_pending_sets_passed_flag():
	ctx.set_var("evaluate_seldon_crisis", 1)
	seldon.resolve_pending()
	assert_eq(ctx.get_var("seldon_crisis_1"), 1)
	assert_eq(ctx.get_var("evaluate_seldon_crisis"), 0, "marqueur consommé")

func test_resolve_pending_sets_failed_flag():
	ctx.set_var("religion", 10)
	ctx.set_var("evaluate_seldon_crisis", 1)
	seldon.resolve_pending()
	assert_eq(ctx.get_var("seldon_crisis_1"), -1)

func test_resolve_pending_result_is_kept_after_death():
	ctx.set_var("evaluate_seldon_crisis", 1)
	seldon.resolve_pending()
	ctx.empty_non_keep()
	assert_eq(ctx.get_var("seldon_crisis_1"), 1, "le jalon survit à la mort (toKeep)")

func test_resolve_pending_noop_without_marker():
	seldon.resolve_pending()
	assert_eq(ctx.get_var("seldon_crisis_1", 0), 0)

# --- crises_passed : comptage pour l'évaluation finale ---

func test_crises_passed_counts_only_successes():
	ctx.set_var("seldon_crisis_1", 1, true)
	ctx.set_var("seldon_crisis_2", -1, true)
	ctx.set_var("seldon_crisis_4", 1, true)
	assert_eq(seldon.crises_passed(), 2)
