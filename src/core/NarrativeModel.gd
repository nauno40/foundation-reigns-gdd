class_name NarrativeModel

var _data: FoundationGameData
var _ctx: Context
var _evaluator: ConditionEvaluator

func _init(data: FoundationGameData, ctx: Context) -> void:
	_data = data
	_ctx = ctx
	_evaluator = ConditionEvaluator.new()

func draw_card() -> Dictionary:
	# Forced link takes absolute priority
	var link = str(_ctx.get_var("link", ""))
	if link != "" and link != "0":
		_ctx.set_var("link", "")
		if link.begins_with("_"):
			var resolved = _resolve_alias(link)
			if not resolved.is_empty():
				return resolved
			# alias d'action ou inconnu : retombe sur le tirage aléatoire
		else:
			var linked = _data.get_card_by_id(int(link))
			if not linked.is_empty():
				return linked

	var eligible = _get_eligible_cards()
	if eligible.is_empty():
		push_warning("NarrativeModel: no eligible cards — returning empty")
		return {}

	return _weighted_random(eligible)

# Alias système du jeu de base : {"node": id} force une carte,
# {"action": ...} déclenche un effet moteur puis rend la main au tirage.
func _resolve_alias(alias: String) -> Dictionary:
	var entry: Dictionary = _data.link_aliases.get(alias, {})
	if entry.is_empty():
		push_warning("NarrativeModel: alias de link inconnu '%s'" % alias)
		return {}
	if entry.has("node"):
		return _data.get_card_by_id(int(entry["node"]))
	match entry.get("action", ""):
		"enddispatch":
			pass  # rien : retour au tirage aléatoire
		"jump":
			_ctx.set_var("location", str(entry.get("planet", "terminus")), true)
		_:
			push_warning("NarrativeModel: action d'alias inconnue '%s'" % str(entry.get("action")))
	return {}

func _get_eligible_cards() -> Array:
	var eligible: Array = []
	var current_turn: int = _ctx.get_var("turns", 0)

	for card in _data.cards:
		# Hidden cards are link-only (crisis/quest sequences)
		if card.get("hidden", false):
			continue

		# Check deck is active
		var deck: String = card.get("deck", "")
		if _ctx.get_var("deck_" + deck, 1) == 0:
			continue

		# Check conditions
		if not _evaluator.evaluate_all(card.get("conditions", []), _ctx._vars):
			continue

		# Check lockturn — stocké dans Context pour survivre au rechargement
		var card_id: int = card.get("id", 0)
		var last_seen: int = _ctx.get_var("lockturn_" + str(card_id), -9999)
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
	_ctx.set_var("lockturn_" + str(card_id), turn)
	_ctx.set_var("seen_" + str(card_id), 1)

func apply_outcomes(outcomes: Array) -> void:
	for outcome in outcomes:
		var variable: String = outcome.get("variable", "")
		var int_value = outcome.get("intValue", 0)
		var add_op: bool = outcome.get("addOperation", true)
		var to_keep: bool = outcome.get("toKeep", false)

		if variable == "":
			continue

		# stringValue (format du jeu de base) — force le mode "set"
		var sv = str(outcome.get("stringValue", ""))
		if sv != "":
			_ctx.set_var(variable, sv, to_keep)
			continue

		if add_op:
			_ctx.add_var(variable, int_value)
			if to_keep:
				_ctx._keep_flags[variable] = true
		else:
			_ctx.set_var(variable, int_value, to_keep)
