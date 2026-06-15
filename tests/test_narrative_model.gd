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
	assert_eq(int(card.get("id", 0)), 1002, "un alias {node} force la carte cible")

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

# --- weight -1 : carte atteignable par link, jamais dans le tirage aléatoire ---

func test_negative_weight_excluded_from_random_draw():
	data.cards.append({
		"id": 99903, "label": "w_neg", "deck": "ambient",
		"weight": -1, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"}, "conditions": [],
	})
	var eligible = model._get_eligible_cards()
	for card in eligible:
		assert_ne(int(card.get("id", 0)), 99903,
			"weight -1 : jamais dans le tirage aléatoire")

# --- Decks planétaires : actifs seulement sur la planète courante ---

func test_planet_deck_filtered_by_location():
	data.cards.append({
		"id": 99904, "label": "p_anac", "deck": "planet_anacreon",
		"weight": 5, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"}, "conditions": [],
	})
	ctx.set_var("location", "terminus", true)
	for card in model._get_eligible_cards():
		assert_ne(int(card.get("id", 0)), 99904,
			"deck planet_anacreon inactif depuis terminus")
	ctx.set_var("location", "anacreon", true)
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_has(ids, 99904, "deck planet_anacreon actif sur anacreon")

func test_location_defaults_to_terminus_for_planet_decks():
	data.cards.append({
		"id": 99905, "label": "p_term", "deck": "planet_terminus",
		"weight": 5, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"}, "conditions": [],
	})
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_has(ids, 99905, "sans location posée, on est sur terminus")

func test_link_alias_jump_random_changes_location():
	ctx.set_var("location", "terminus", true)
	ctx.set_var("link", "_jump_somewhere")
	var card = model.draw_card()
	var loc = str(ctx.get_var("location", ""))
	assert_ne(loc, "terminus", "destination aléatoire différente de la planète courante")
	assert_false(card.is_empty())

# --- Deck hyperjumps : le voyage passe par une carte narrative payante ---

func test_jump_alias_resolves_to_travel_card():
	ctx.set_var("link", "_jump_kalgan")
	var card = model.draw_card()
	assert_eq(int(card.get("id", 0)), 25613, "_jump_kalgan mène à la carte du capitaine")
	model.apply_outcomes(card.get("yesOutcome", []))
	assert_eq(str(ctx.get_var("location", "")), "kalgan", "embarquer pose la destination")
	assert_eq(ctx.get_var("commerce", 50), 45, "le voyage coûte 5 de commerce")
	ctx.empty_non_keep()
	assert_eq(str(ctx.get_var("location", "")), "kalgan", "location survit à la mort (toKeep)")

# --- Deck deaths : la mort par ressource passe par une carte narrative ---

func test_find_death_card_matches_resource_state():
	ctx.set_var("military", 100)
	var card = model.find_death_card()
	assert_eq(int(card.get("id", 0)), 24402,
		"militaire à 100 → carte de mort correspondante (variante de base)")

func test_find_death_card_prefers_rank_variant():
	ctx.set_var("military", 100)
	ctx.set_var("rank", 3)
	var card = model.find_death_card()
	assert_eq(int(card.get("id", 0)), 24400,
		"avec rank > 2, la variante la plus spécifique gagne")

func test_find_death_card_empty_when_alive():
	var card = model.find_death_card()
	assert_true(card.is_empty(), "pas de carte de mort quand tout va bien")

# --- Intermède : dispatch des cartes w=-1 de new_speaker à la renaissance ---

func test_find_interlude_card_matches_conditions():
	# 4 conditions : plus spécifique que toute carte réelle du deck
	data.cards.append({
		"id": 99906, "label": "interlude_test", "deck": "new_speaker",
		"weight": -1, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"},
		"conditions": [{"variable": "turns", "op": "equal", "value": 0},
			{"variable": "times_died", "op": "above", "value": 3},
			{"variable": "test_flag_a", "op": "equal", "value": 7},
			{"variable": "test_flag_b", "op": "equal", "value": 7}],
	})
	ctx.set_var("turns", 0)
	ctx.set_var("times_died", 5)
	ctx.set_var("test_flag_a", 7)
	ctx.set_var("test_flag_b", 7)
	var card = model.find_interlude_card()
	assert_eq(int(card.get("id", 0)), 99906,
		"la carte la plus spécifique est dispatchée")

func test_find_interlude_card_empty_outside_reign_start():
	# en début de règne (turns 0), le débrief générique 21236 matche toujours ;
	# hors début de règne, aucun intermède ne doit être dispatché
	ctx.set_var("turns", 5)
	var card = model.find_interlude_card()
	assert_true(card.is_empty(), "aucun intermède hors début de règne")

func test_generic_debrief_dispatched_at_reign_start():
	ctx.set_var("turns", 0)
	var card = model.find_interlude_card()
	assert_eq(int(card.get("id", 0)), 21236,
		"le débrief générique joue par défaut au début du règne")

func test_link_alias_conditional_nodes_picks_first_match():
	data.cards.append({"id": 99907, "label": "v1", "deck": "new_speaker",
		"weight": 1, "lockturn": 0, "hidden": true, "question": {"FR": "?"},
		"conditions": [{"variable": "tyranny", "op": "above", "value": 1}]})
	data.cards.append({"id": 99908, "label": "v2", "deck": "new_speaker",
		"weight": 1, "lockturn": 0, "hidden": true, "question": {"FR": "?"},
		"conditions": [{"variable": "tyranny", "op": "equal", "value": 0}]})
	data.link_aliases["_test_variants"] = {"nodes": [99907, 99908]}
	ctx.set_var("link", "_test_variants")
	var card = model.draw_card()
	assert_eq(int(card.get("id", 0)), 99908, "première variante dont les conditions passent")

func test_link_bare_word_alias_resolves():
	data.link_aliases["refugees"] = {"node": 1003}
	ctx.set_var("link", "refugees")
	var card = model.draw_card()
	assert_eq(int(card.get("id", 0)), 1003, "un alias sans underscore se résout aussi")

# --- Dispatcher d'événements w=-1 + gate de lieu corrigé (15/06/2026) ---

func test_planet_ruler_not_location_gated():
	# "planet_ruler" n'est pas un monde : il doit être tirable partout.
	data.cards.append({"id": 999001, "deck": "planet_ruler", "weight": 5000,
		"lockturn": 0, "hidden": false, "conditions": []})
	ctx.set_var("location", "terminus")
	var found := false
	for i in range(80):
		var c := model.draw_card()
		if int(c.get("id", 0)) == 999001:
			found = true
			break
		model.mark_card_seen(c)  # simule le jeu réel : consomme la carte tirée
	assert_true(found, "planet_ruler doit être tirable quel que soit le lieu")

func test_real_planet_deck_still_location_gated():
	data.cards.append({"id": 999002, "deck": "planet_korell", "weight": 5000,
		"lockturn": 0, "hidden": false, "conditions": []})
	ctx.set_var("location", "terminus")  # pas korell
	for i in range(40):
		assert_ne(int(model.draw_card().get("id", 0)), 999002,
			"planet_korell ne doit pas sortir hors de Korell")

func test_event_card_dispatched_when_conditions_met():
	data.cards.append({"id": 999003, "deck": "ambient", "weight": -1,
		"lockturn": 0, "hidden": false,
		"conditions": [{"variable": "year", "op": "equal", "value": 1},
			{"variable": "custom_event_flag", "op": "equal", "value": 7}]})
	ctx.set_var("year", 1)
	ctx.set_var("custom_event_flag", 7)
	assert_eq(int(model.draw_card().get("id", 0)), 999003,
		"un événement w=-1 dont les conditions passent doit être dispatché")

func test_event_card_not_redispatched_once_seen():
	data.cards.append({"id": 999004, "deck": "ambient", "weight": -1,
		"lockturn": 0, "hidden": false,
		"conditions": [{"variable": "year", "op": "equal", "value": 1},
			{"variable": "custom_event_flag", "op": "equal", "value": 7}]})
	ctx.set_var("year", 1)
	ctx.set_var("custom_event_flag", 7)
	ctx.set_var("seen_999004", 1)
	assert_ne(int(model.draw_card().get("id", 0)), 999004,
		"un événement déjà vu ne doit pas se redéclencher")

func test_event_card_excludes_special_decks():
	data.cards.append({"id": 999005, "deck": "deaths", "weight": -1,
		"lockturn": 0, "hidden": false,
		"conditions": [{"variable": "year", "op": "equal", "value": 1},
			{"variable": "custom_event_flag", "op": "equal", "value": 7}]})
	ctx.set_var("year", 1)
	ctx.set_var("custom_event_flag", 7)
	assert_ne(int(model.draw_card().get("id", 0)), 999005,
		"les cartes deaths ne sont pas auto-dispatchées comme événements")
