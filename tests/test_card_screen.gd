extends GutTest

const CARD_SCREEN = preload("res://scenes/CardScreen.tscn")

var screen

func before_each():
	screen = CARD_SCREEN.instantiate()
	add_child_autofree(screen)

func test_flicker_node_exists():
	var flicker = screen.get_node_or_null(
		"MainVBox/CardArea/CardPanel/CardVBox/Portrait/Flicker")
	assert_not_null(flicker,
		"le script référence Portrait/Flicker — le nœud doit exister dans la scène")

func test_update_portrait_with_null_bearer():
	# Dans le JSON, bearer vaut null pour les PNJ : la clé existe,
	# donc card.get("bearer", "") retourne null, pas le défaut.
	screen._bearer_name.text = "SENTINEL"
	screen._initials.text = "XX"
	screen._update_portrait({"id": 42, "bearer": null, "key": false})
	assert_ne(screen._bearer_name.text, "SENTINEL",
		"bearer null ne doit pas provoquer d'erreur Nil")

func test_update_portrait_with_bearer_string():
	screen._update_portrait({"id": 1, "bearer": "Hari Seldon", "key": true})
	assert_eq(screen._bearer_name.text, "Hari Seldon")
	assert_eq(screen._initials.text, "HS")

func test_null_bearer_with_game_data_generates_npc_name():
	var data = FoundationGameData.new()
	data.load_all()
	screen.setup(data)
	screen._update_portrait({"id": 1001, "bearer": null})
	assert_ne(screen._bearer_name.text, "",
		"un PNJ doit recevoir un nom généré quand game_data est fourni")

func test_canonical_bearer_shows_keytag():
	var data = FoundationGameData.new()
	data.load_all()
	screen.setup(data)
	screen._update_portrait({"id": 3001, "bearer": "hari_seldon"})
	assert_eq(screen._bearer_name.text, "Hari Seldon")
	assert_true(screen._keytag.visible, "Figure du Plan visible pour un canonique")
