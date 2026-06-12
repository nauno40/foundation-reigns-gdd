extends GutTest

var model: NarrativeModel
var data: FoundationGameData
var ctx: Context

func before_each():
	data = FoundationGameData.new()
	data.load_all()
	ctx = Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("year", 1)
	model = NarrativeModel.new(data, ctx)

func test_draw_returns_card():
	var card = model.draw_card()
	assert_false(card.is_empty(), "Should draw a card")
	assert_true(card.has("id"))

func test_lockturn_prevents_repeat():
	var card = data.get_card_by_id(1001)  # lockturn 10
	model.mark_card_seen(card)
	for i in range(5):
		ctx.add_var("turns", 1)
		var next_card = model.draw_card()
		assert_ne(int(next_card.get("id", 0)), 1001,
			"Card should not repeat within lockturn")

func test_link_takes_priority():
	ctx.set_var("link", "1002")
	var card = model.draw_card()
	assert_eq(card.get("id"), 1002)
	assert_eq(ctx.get_var("link", ""), "", "link should be cleared after use")

func test_conditions_filter_cards():
	ctx.set_var("year", 1)
	for i in range(20):
		var card = model.draw_card()
		var conditions = card.get("conditions", [])
		var evaluator = ConditionEvaluator.new()
		assert_true(evaluator.evaluate_all(conditions, ctx._vars),
			"Drawn card must pass conditions")

func test_apply_yes_outcome():
	ctx.set_var("commerce", 50)
	var outcomes = [
		{"variable": "commerce", "intValue": -10, "addOperation": true, "toKeep": false}
	]
	model.apply_outcomes(outcomes)
	assert_eq(ctx.get_var("commerce"), 40)

func test_apply_no_outcome_set():
	var outcomes = [
		{"variable": "politics", "intValue": 30, "addOperation": false, "toKeep": false}
	]
	model.apply_outcomes(outcomes)
	assert_eq(ctx.get_var("politics"), 30)

func test_apply_tokeep_outcome():
	var outcomes = [
		{"variable": "year", "intValue": 5, "addOperation": true, "toKeep": true}
	]
	ctx.set_var("year", 1)
	model.apply_outcomes(outcomes)
	ctx.empty_non_keep()
	assert_eq(ctx.get_var("year"), 6)

# --- Écart #5 : persistance du lockturn via Context ---

func test_mark_card_seen_records_lockturn_in_context():
	ctx.set_var("turns", 4)
	var card = data.get_card_by_id(1001)
	model.mark_card_seen(card)
	assert_eq(ctx.get_var("lockturn_1001", -1), 4,
		"lockturn doit être stocké dans Context pour survivre au rechargement")

func test_lockturn_respected_after_reload():
	var card = data.get_card_by_id(1001)  # lockturn 10
	model.mark_card_seen(card)
	var model2 = NarrativeModel.new(data, ctx)  # simule un rechargement de partie
	ctx.add_var("turns", 1)
	for i in range(30):
		var next_card = model2.draw_card()
		assert_ne(int(next_card.get("id", 0)), 1001,
			"une carte vue récemment ne doit pas réapparaître après rechargement")

# --- Cartes hidden : réservées aux enchaînements link (séquences de crise) ---

func test_hidden_cards_excluded_from_random_draw():
	data.cards.append({
		"id": 99901, "label": "hidden_test", "deck": "ambient",
		"weight": 1000, "lockturn": 0, "hidden": true,
		"question": {"FR": "?"}, "conditions": [],
	})
	var eligible = model._get_eligible_cards()
	for card in eligible:
		assert_ne(int(card.get("id", 0)), 99901,
			"une carte hidden ne doit jamais sortir du tirage aléatoire")

func test_hidden_card_reachable_via_link():
	data.cards.append({
		"id": 99902, "label": "hidden_link_test", "deck": "ambient",
		"weight": 1, "lockturn": 0, "hidden": true,
		"question": {"FR": "?"}, "conditions": [],
	})
	ctx.set_var("link", "99902")
	var card = model.draw_card()
	assert_eq(card.get("id"), 99902, "une carte hidden reste accessible via link")

# --- Crise 1 : le déclencheur n'est éligible que dans sa fenêtre (ans 50-80) ---

func test_crisis_trigger_eligible_in_window():
	ctx.set_var("year", 60)
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_has(ids, 8001, "8001 doit être éligible à l'an 60")

func test_crisis_trigger_not_eligible_before_window():
	ctx.set_var("year", 30)
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_does_not_have(ids, 8001, "8001 ne doit pas être éligible à l'an 30")

func test_crisis_trigger_not_eligible_once_resolved():
	ctx.set_var("year", 60)
	ctx.set_var("seldon_crisis_1", 1, true)
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_does_not_have(ids, 8001, "8001 ne doit pas revenir une fois la crise résolue")

# --- Aliases de link (structure du jeu de base) ---

func test_link_alias_node_resolves():
	data.link_aliases["_test_alias"] = {"node": 1002}
	ctx.set_var("link", "_test_alias")
	var card = model.draw_card()
	assert_eq(card.get("id"), 1002, "un alias {node} force la carte cible")

func test_link_alias_enddispatch_returns_to_pool():
	ctx.set_var("link", "_enddispatch")
	var card = model.draw_card()
	assert_false(card.is_empty(), "_enddispatch retombe sur le tirage aléatoire")
	assert_eq(str(ctx.get_var("link", "")), "", "link consommé")

func test_link_alias_jump_changes_location():
	ctx.set_var("link", "_jump_anacreon")
	var card = model.draw_card()
	assert_eq(ctx.get_var("location", ""), "anacreon", "le saut change la planète")
	assert_false(card.is_empty(), "après le saut, tirage normal")

func test_link_unknown_alias_falls_back():
	ctx.set_var("link", "_alias_inconnu")
	var card = model.draw_card()
	assert_false(card.is_empty(), "alias inconnu : avertissement + tirage normal")

func test_outcome_string_value_sets_link_alias():
	# les cartes posent les aliases via stringValue (format du jeu de base)
	model.apply_outcomes([{"variable": "link", "stringValue": "_enddispatch",
		"intValue": 0, "addOperation": false, "toKeep": false}])
	assert_eq(str(ctx.get_var("link", "")), "_enddispatch")
