extends GutTest

var data: FoundationGameData

func before_each():
	data = FoundationGameData.new()

func test_load_all_succeeds():
	var ok = data.load_all()
	assert_true(ok, "load_all should return true")
	assert_true(data.is_loaded)

func test_cards_loaded():
	data.load_all()
	assert_gte(data.cards.size(), 20)

func test_factions_loaded():
	data.load_all()
	assert_eq(data.factions.size(), 9)

func test_planets_loaded():
	data.load_all()
	assert_eq(data.planets.size(), 12)

func test_decks_indexed():
	data.load_all()
	assert_true(data.cards_by_deck.has("ambient"))
	assert_true(data.cards_by_deck.has("hardin_era"))

func test_get_card_by_id():
	data.load_all()
	var card = data.get_card_by_id(1001)
	assert_eq(card.get("label", ""), "rumeur_terminus")

func test_random_name_not_empty():
	data.load_all()
	var name = data.get_random_name()
	assert_ne(name, "")
	assert_ne(name, "Inconnu")
