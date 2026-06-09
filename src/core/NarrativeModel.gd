class_name NarrativeModel

var _data: FoundationGameData
var _ctx: Context
var _evaluator: ConditionEvaluator
var _lockturn_tracker: Dictionary = {}  # card_id -> turn_last_seen

func _init(data: FoundationGameData, ctx: Context) -> void:
	_data = data
	_ctx = ctx
	_evaluator = ConditionEvaluator.new()

func draw_card() -> Dictionary:
	# Forced link takes absolute priority
	var link = str(_ctx.get_var("link", ""))
	if link != "" and link != "0":
		_ctx.set_var("link", "")
		var linked = _data.get_card_by_id(int(link))
		if not linked.is_empty():
			return linked

	var eligible = _get_eligible_cards()
	if eligible.is_empty():
		push_warning("NarrativeModel: no eligible cards — returning empty")
		return {}

	return _weighted_random(eligible)

func _get_eligible_cards() -> Array:
	var eligible: Array = []
	var current_turn: int = _ctx.get_var("turns", 0)

	for card in _data.cards:
		# Check deck is active
		var deck: String = card.get("deck", "")
		if _ctx.get_var("deck_" + deck, 1) == 0:
			continue

		# Check conditions
		if not _evaluator.evaluate_all(card.get("conditions", []), _ctx._vars):
			continue

		# Check lockturn
		var card_id: int = card.get("id", 0)
		var last_seen: int = _lockturn_tracker.get(card_id, -9999)
		var lockturn: int = card.get("lockturn", 0)
		if current_turn - last_seen < lockturn:
			continue

		eligible.append(card)

	return eligible

func _weighted_random(cards: Array) -> Dictionary:
	var total_weight: int = 0
	for card in cards:
		total_weight += card.get("weight", 1)

	var roll: int = randi() % max(total_weight, 1)
	var cumulative: int = 0
	for card in cards:
		cumulative += card.get("weight", 1)
		if roll < cumulative:
			return card

	return cards[-1]

func mark_card_seen(card: Dictionary) -> void:
	var card_id: int = card.get("id", 0)
	var turn: int = _ctx.get_var("turns", 0)
	_lockturn_tracker[card_id] = turn
	_ctx.set_var("seen_" + str(card_id), 1)

func apply_outcomes(outcomes: Array) -> void:
	for outcome in outcomes:
		var variable: String = outcome.get("variable", "")
		var int_value: int = outcome.get("intValue", 0)
		var add_op: bool = outcome.get("addOperation", true)
		var to_keep: bool = outcome.get("toKeep", false)

		if variable == "":
			continue

		if add_op:
			_ctx.add_var(variable, int_value)
			if to_keep:
				_ctx._keep_flags[variable] = true
		else:
			_ctx.set_var(variable, int_value, to_keep)
