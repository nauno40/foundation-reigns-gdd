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
	if entry.has("nodes"):
		# Variantes conditionnelles : la première dont les conditions passent
		for node_id in entry["nodes"]:
			var candidate = _data.get_card_by_id(int(node_id))
			if candidate.is_empty():
				continue
			if _evaluator.evaluate_all(candidate.get("conditions", []), _ctx._vars):
				return candidate
		return {}
	match entry.get("action", ""):
		"enddispatch":
			pass  # rien : retour au tirage aléatoire
		"jump":
			_ctx.set_var("location", str(entry.get("planet", "terminus")), true)
		"jump_random":
			var here: String = str(_ctx.get_var("location", "terminus"))
			var others: Array = []
			for planet in _data.planets:
				if str(planet.get("id", "")) != here:
					others.append(str(planet["id"]))
			if not others.is_empty():
				_ctx.set_var("location", others[randi() % others.size()], true)
		_:
			push_warning("NarrativeModel: action d'alias inconnue '%s'" % str(entry.get("action")))
	return {}

func _get_eligible_cards() -> Array:
	var eligible: Array = []
	var current_turn: int = _ctx.get_var("turns", 0)
	var dev_deck: String = str(_ctx.get_var("dev_deck", ""))

	for card in _data.cards:
		var deck: String = card.get("deck", "")

		if dev_deck != "":
			if deck != dev_deck:
				continue
		else:
			if card.get("hidden", false):
				continue

			if int(card.get("weight", 1)) < 0:
				continue

			if deck.begins_with("planet_"):
				var here: String = str(_ctx.get_var("location", "terminus"))
				if deck.trim_prefix("planet_") != here:
					continue

			if _ctx.get_var("deck_" + deck, 1) == 0:
				continue

			if not _evaluator.evaluate_all(card.get("conditions", []), _ctx._vars):
				continue

			var card_id: int = card.get("id", 0)
			var last_seen: int = _ctx.get_var("lockturn_" + str(card_id), -9999)
			var lockturn: int = card.get("lockturn", 0)
			if current_turn - last_seen < lockturn:
				continue

		eligible.append(card)

	return eligible

# Intermède de renaissance (deck new_speaker, jeu de base) : les cartes
# w=-1 visibles sont dispatchées par conditions au début du règne, la
# plus spécifique d'abord — même règle que les cartes de mort.
func find_interlude_card() -> Dictionary:
	return _find_dispatched_card("new_speaker")

# Mort narrative (deck deaths, jeu de base) : carte déclencheur dont les
# conditions correspondent à l'état fatal. La plus spécifique (plus de
# conditions) l'emporte — la variante de rang prime sur la générique.
func find_death_card() -> Dictionary:
	return _find_dispatched_card("deaths")

func _find_dispatched_card(deck: String) -> Dictionary:
	var best: Dictionary = {}
	var best_count := -1
	for card in _data.cards:
		if str(card.get("deck", "")) != deck:
			continue
		if card.get("hidden", false) or int(card.get("weight", 1)) >= 0:
			continue
		var conditions: Array = card.get("conditions", [])
		if conditions.is_empty():
			continue
		if not _evaluator.evaluate_all(conditions, _ctx._vars):
			continue
		if conditions.size() > best_count:
			best = card
			best_count = conditions.size()
	return best

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
