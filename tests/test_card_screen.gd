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
	screen._portrait_bearer_name.text = "SENTINEL"
	screen._portrait_initials.text = "XX"
	screen._update_portrait({"bearer": null, "key": false})
	assert_eq(screen._portrait_bearer_name.text, "",
		"bearer null doit donner un nom vide, pas une erreur Nil")
	assert_eq(screen._portrait_initials.text, "",
		"bearer null doit donner des initiales vides")

func test_update_portrait_with_bearer_string():
	screen._update_portrait({"bearer": "Hari Seldon", "key": true})
	assert_eq(screen._portrait_bearer_name.text, "Hari Seldon")
	assert_eq(screen._portrait_initials.text, "HS")
