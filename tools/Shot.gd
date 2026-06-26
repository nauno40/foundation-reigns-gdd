extends Node

# Capture du jeu réel pour comparaison au template. Charge Main.tscn, attend,
# screenshot /tmp/new_<mode>.png. Modes : card (défaut), codex, codexach, codexgal, death.
#   godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- card

func _ready() -> void:
	get_window().size = Vector2i(460, 920)
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "card"
	await _wait(70)
	var game = main.get_node("Row/Frame/Game")
	match mode:
		"editorsim":
			# reproduit le rendu éditeur : seuls les @tool enfants s'affichent (via _editor_preview)
			var resrow = game.get_node("MainVBox/TopBar/TopMargin/TopVBox/ResRow")
			for g in resrow.get_children(): g._editor_preview()
			game.get_node("MainVBox/Panel/PanelMargin/PanelVBox/CardStage/CardView")._editor_preview()
			await _wait(12)
		"codex": game._codex.open("chars"); await _wait(40)
		"codexach": game._codex.open("ach"); await _wait(40)
		"codexgal": game._codex.open("gal"); await _wait(40)
		"death":
			# force une mort ressource
			game.res["military"] = 4
			game.card = Data.DECK[2]  # sermak : left mil-6
			game._cardview.show_card(game.card)
			await _wait(10)
			game._on_committed(true)
			await _wait(90)
		"unlock":
			game._play_deck_unlock(Data.DECK_UNLOCKS[0])
			await _wait(22)   # cartes en train de glisser sous la carte + bandeau
		"gauges":
			# niveaux contrastés pour vérifier le remplissage
			game.res = {"military": 8, "religion": 50, "commerce": 92, "politics": 34}
			game._refresh_all()
			await _wait(50)
		"flash":
			# capture en cours d'animation (flash ▲/▼ + remplissage)
			game.res = {"military": 60, "religion": 40, "commerce": 55, "politics": 50}
			game._refresh_all()
			await _wait(40)
			game.card = Data.DECK[2]  # sermak : right mil+12 com-10 rel-4
			game._cardview.show_card(game.card)
			await _wait(5)
			game._on_committed(false)
			await _wait(14)   # ~0.23s : ▲/▼ visibles + remplissage en cours
		_:
			pass
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/new_%s.png" % mode)
	print("SAVED ", mode, " ", img.get_size())
	get_tree().quit()

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
