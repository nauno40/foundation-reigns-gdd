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
	var card = model.draw_card()
	var id = card.get("id")
	model.mark_card_seen(card)
	var lockturn = card.get("lockturn", 0)
	if lockturn > 0:
		for i in range(5):
			ctx.add_var("turns", 1)
			var next_card = model.draw_card()
			if ctx.get_var("turns") < lockturn:
				assert_ne(next_card.get("id"), id,
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
