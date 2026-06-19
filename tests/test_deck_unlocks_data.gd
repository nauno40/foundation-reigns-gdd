extends GutTest

var gd: FoundationGameData

func before_all():
	gd = FoundationGameData.new()
	gd.load_all()

func test_deck_unlocks_loaded():
	assert_gt(gd.deck_unlocks.size(), 0, "deck_unlocks doit être chargé")

func test_deck_unlocks_ids_exist_in_cards():
	var decks := {}
	for c in gd.cards:
		decks[str(c.get("deck", ""))] = true
	for id in gd.deck_unlocks:
		assert_true(decks.has(id), "le deck jalon '%s' doit exister dans les cartes" % id)

func test_deck_unlock_entries_have_name():
	for id in gd.deck_unlocks:
		assert_ne(str(gd.deck_unlocks[id].get("name", "")), "", "%s doit avoir un nom" % id)
