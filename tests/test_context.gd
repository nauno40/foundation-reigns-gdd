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

# --- Écart #2 : bonus de couverture +5 ---

func test_apply_cover_adds_bonus_to_linked_resource():
	ctx.initialize_new_reign()
	ctx.apply_cover({"name": "Prêtre scientifique", "bonus_resource": "religion", "bonus_value": 5})
	assert_eq(ctx.get_var("religion"), 55)

func test_apply_cover_without_bonus_is_noop():
	ctx.initialize_new_reign()
	ctx.apply_cover({"name": "Inconnu"})
	for resource in Context.RESOURCES:
		assert_eq(ctx.get_var(resource), 50)

# --- Écart #3 : perte de Terminus = game over ---

func test_terminus_lost_is_game_over():
	ctx.initialize_new_reign()
	ctx.set_var("planet_terminus_state", 0, true)
	assert_true(ctx.is_game_over())

func test_terminus_hostile_is_game_over():
	ctx.initialize_new_reign()
	ctx.set_var("planet_terminus_state", -1, true)
	assert_true(ctx.is_game_over())

func test_terminus_allied_no_game_over():
	ctx.initialize_new_reign()
	ctx.set_var("planet_terminus_state", 1, true)
	assert_false(ctx.is_game_over())

func test_terminus_absent_defaults_to_allied():
	ctx.initialize_new_reign()
	assert_false(ctx.is_game_over())

func test_game_over_reason_terminus():
	ctx.initialize_new_reign()
	ctx.set_var("planet_terminus_state", -1, true)
	assert_eq(ctx.get_game_over_reason(), "terminus lost")

# --- advance_turn : le temps avance à chaque décision (1 tour = 1 an) ---

func test_advance_turn_increments_turns_and_year():
	ctx.initialize_new_reign()
	ctx.set_var("year", 50, true)
	ctx.set_var("y_start", 50, true)
	ctx.set_var("age", 36)
	ctx.set_var("age_start", 36)
	ctx.advance_turn()
	assert_eq(ctx.get_var("turns"), 1)
	assert_eq(ctx.get_var("year"), 51)

func test_advance_turn_derives_age_from_elapsed_years():
	ctx.initialize_new_reign()
	ctx.set_var("year", 50, true)
	ctx.set_var("y_start", 50, true)
	ctx.set_var("age_start", 36)
	for i in range(10):
		ctx.advance_turn()
	assert_eq(ctx.get_var("year"), 60)
	assert_eq(ctx.get_var("age"), 46, "âge = age_start + années écoulées")

func test_advance_turn_age_follows_card_driven_year_jump():
	ctx.initialize_new_reign()
	ctx.set_var("year", 50, true)
	ctx.set_var("y_start", 50, true)
	ctx.set_var("age_start", 36)
	ctx.add_var("year", 5)  # une carte fait sauter 5 ans
	ctx.advance_turn()
	assert_eq(ctx.get_var("year"), 56)
	assert_eq(ctx.get_var("age"), 42)

func test_advance_turn_preserves_year_keep_flag():
	ctx.initialize_new_reign()
	ctx.set_var("year", 50, true)
	ctx.set_var("y_start", 50, true)
	ctx.set_var("age_start", 36)
	ctx.advance_turn()
	ctx.empty_non_keep()
	assert_eq(ctx.get_var("year"), 51, "year reste toKeep après advance_turn")

func test_advance_turn_cycles_month_1_to_12():
	ctx.initialize_new_reign()
	ctx.set_var("year", 1, true)
	ctx.set_var("y_start", 1, true)
	ctx.set_var("age_start", 36)
	var seen := {}
	for i in range(13):
		ctx.advance_turn()
		seen[int(ctx.get_var("month"))] = true
	assert_true(seen.has(1) and seen.has(12), "le mois cycle de 1 à 12")
	for m in seen:
		assert_true(m >= 1 and m <= 12, "mois dans 1..12")

# --- Jauge de maîtrise mentalique (15/06/2026) ---

func test_mentalic_grows_each_turn():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("legitimacy", 50)  # pas de bonus de maîtrise
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("mentalic", 0)), 1, "mentalic +1 par tour")
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("mentalic", 0)), 2)

func test_mentalic_bonus_when_legitimacy_high():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("legitimacy", 80)  # couverture maîtrisée → +2
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("mentalic", 0)), 2, "legitimacy haute → +2 par tour")

func test_mentalic_derives_facets():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("legitimacy", 50)
	ctx.set_var("mentalic", 49, true)
	ctx.advance_turn()  # → 50
	assert_eq(int(ctx.get_var("synaptic", 0)), 50, "synaptic = mentalic (0-100)")
	assert_eq(int(ctx.get_var("strength", 0)), 5, "strength = mentalic/10")
	assert_eq(int(ctx.get_var("mentalic_strength", 0)), 5)

func test_mentalic_caps_at_100():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("legitimacy", 100)
	ctx.set_var("mentalic", 100, true)
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("mentalic", 0)), 100, "mentalic plafonne à 100")

func test_mentalic_persists_across_reign():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("legitimacy", 50)
	for i in range(5):
		ctx.advance_turn()
	assert_eq(int(ctx.get_var("mentalic", 0)), 5)
	ctx.initialize_new_reign()  # mort → nouveau règne
	assert_eq(int(ctx.get_var("mentalic", 0)), 5, "la maîtrise mentalique survit au règne (toKeep)")

# --- Système de menace dérivé (15/06/2026) ---

func test_player_threat_derived_from_power_and_exposure():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("legitimacy", 50)       # exposition : (100-50)/12 = 4
	ctx.set_var("mentalic", 49, true)   # +1 → 50 ; 50/5 = 10
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("player:threat", 0)), 14,
		"player:threat = mentalic/5 + (100-legitimacy)/12")

func test_rival_threat_set_when_faction_hostile():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("relation_empire", -30)
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("cao_cao:threat", 0)), 1,
		"un rival impérial devient menaçant quand l'Empire est hostile")

func test_rival_threat_absent_when_faction_neutral():
	var ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("relation_empire", 0)
	ctx.advance_turn()
	assert_eq(int(ctx.get_var("cao_cao:threat", 0)), 0,
		"pas de menace rivale tant que la faction n'est pas hostile")
