extends Node

# Capture du jeu réel pour comparaison au template. Charge Main.tscn, attend,
# screenshot /tmp/new_<mode>.png. Modes : card (défaut), codex, codexach, codexgal, death.
#   godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- card

func _ready() -> void:
	get_window().size = Vector2i(1000, 980)
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "card"
	await _wait(70)
	var game = main.get_node("Row/Frame/Game")
	match mode:
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
		_:
			pass
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/new_%s.png" % mode)
	print("SAVED ", mode, " ", img.get_size())
	get_tree().quit()

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
