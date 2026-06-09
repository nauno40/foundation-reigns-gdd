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

func get_random_name() -> String:
	if given_names.is_empty() or family_names.is_empty():
		return "Inconnu"
	var given = given_names[randi() % given_names.size()]
	var family = family_names[randi() % family_names.size()]
	return "%s %s" % [given, family]
