class_name FoundationGameData

var cards: Array = []
var cards_by_deck: Dictionary = {}
var factions: Array = []
var planets: Array = []
var given_names: Array = []
var family_names: Array = []
var characters: Dictionary = {}
var covers: Dictionary = {}
var moods: Dictionary = {}
var seldon_crises: Dictionary = {}
var link_aliases: Dictionary = {}
var roles: Dictionary = {}
var deck_unlocks: Dictionary = {}   # id -> {id, name, subtitle}

var is_loaded: bool = false

func load_all() -> bool:
	var ok = true
	ok = ok and _load_array("res://data/foundation_cards.json", cards)
	ok = ok and _load_array("res://data/factions.json", factions)
	ok = ok and _load_array("res://data/planets.json", planets)
	ok = ok and _load_array("res://data/given_names.json", given_names)
	ok = ok and _load_array("res://data/family_names.json", family_names)
	ok = ok and _load_dict("res://data/characters.json", characters)
	ok = ok and _load_dict("res://data/covers.json", covers)
	ok = ok and _load_dict("res://data/moods.json", moods)
	ok = ok and _load_dict("res://data/seldon_crises.json", seldon_crises)
	ok = ok and _load_dict("res://data/link_aliases.json", link_aliases)
	ok = ok and _load_dict("res://data/roles.json", roles)
	var _du: Array = []
	if _load_array("res://data/deck_unlocks.json", _du):
		for e in _du:
			if e is Dictionary and e.has("id"):
				deck_unlocks[str(e["id"])] = e
	if ok:
		_index_by_deck()
		is_loaded = true
	return ok

func _load_array(path: String, target: Array) -> bool:
	var text = _read_file(path)
	if text == "":
		return false
	var result = JSON.parse_string(text)
	if not result is Array:
		push_error("FoundationGameData: expected Array in %s" % path)
		return false
	target.assign(result)
	return true

func _load_dict(path: String, target: Dictionary) -> bool:
	var text = _read_file(path)
	if text == "":
		return false
	var result = JSON.parse_string(text)
	if not result is Dictionary:
		push_error("FoundationGameData: expected Dictionary in %s" % path)
		return false
	target.merge(result)
	return true

func _read_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("FoundationGameData: cannot open %s" % path)
		return ""
	return file.get_as_text()

func _index_by_deck() -> void:
	cards_by_deck.clear()
	for card in cards:
		var deck: String = card.get("deck", "")
		if not cards_by_deck.has(deck):
			cards_by_deck[deck] = []
		cards_by_deck[deck].append(card)

func get_card_by_id(id: int) -> Dictionary:
	for card in cards:
		if card.get("id", -1) == id:
			return card
	return {}

func get_faction_by_id(id: String) -> Dictionary:
	for faction in factions:
		if faction.get("id", "") == id:
			return faction
	return {}

func get_planet_by_id(id: String) -> Dictionary:
	for planet in planets:
		if planet.get("id", "") == id:
			return planet
	return {}

# Sème planet_<id>_state depuis initial_state ; toKeep car les états
# diplomatiques survivent à la mort de l'Orateur.
func seed_planet_states(ctx: Context) -> void:
	for planet in planets:
		var id: String = planet.get("id", "")
		if id != "":
			ctx.set_var("planet_%s_state" % id, int(planet.get("initial_state", 0)), true)

# Sème relation_<faction_id> depuis starting_relation ; toKeep car les
# relations diplomatiques sont un état galactique, comme les planètes.
func seed_faction_relations(ctx: Context) -> void:
	for faction in factions:
		var id: String = faction.get("id", "")
		if id != "":
			ctx.set_var("relation_%s" % id, int(faction.get("starting_relation", 0)), true)

func get_random_name() -> String:
	if given_names.is_empty() or family_names.is_empty():
		return "Inconnu"
	var given = given_names[randi() % given_names.size()]
	var family = family_names[randi() % family_names.size()]
	return "%s %s" % [given, family]
