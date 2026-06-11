# Outil de capture : lance Main.tscn, attend, capture le viewport en PNG.
# Usage : godot --path . -s tools/screenshot.gd -- <sortie.png> [largeur] [hauteur] [frames] [mode]
# mode : "card" (défaut) | "death:<type>" | "map" | "states" | "reaction"
# "states" : force des valeurs warn/crit sur les barres + état affected,
# pour vérifier visuellement les états du prototype.
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "shot.png"
	var w := 460
	var h := 920
	var wait_frames := 30
	var mode := "card"
	if args.size() >= 1:
		out_path = args[0]
	if args.size() >= 3:
		w = int(args[1])
		h = int(args[2])
	if args.size() >= 4:
		wait_frames = int(args[3])
	if args.size() >= 5:
		mode = args[4]

	DisplayServer.window_set_size(Vector2i(w, h))
	change_scene_to_file("res://scenes/Main.tscn")
	_capture(out_path, wait_frames, mode)

func _capture(out_path: String, wait_frames: int, mode: String) -> void:
	for i in range(wait_frames):
		await process_frame
	if mode.begins_with("death"):
		var death_type := "military"
		if ":" in mode:
			death_type = mode.split(":")[1]
		current_scene._show_death_screen(death_type)
		for i in range(15):
			await process_frame
	elif mode == "map":
		current_scene._on_map_pressed()
		for i in range(15):
			await process_frame
	elif mode == "reaction":
		current_scene._card_screen._on_swipe_left()
		for i in range(60):
			await process_frame
	elif mode == "states":
		var ctx: Context = current_scene._ctx
		ctx.set_var("military", 12)   # crit bas
		ctx.set_var("religion", 20)   # warn bas
		ctx.set_var("commerce", 88)   # crit haut
		ctx.set_var("politics", 80)   # warn haut
		ctx.set_var("legitimacy", 30) # murmure de légitimité
		var screen = current_scene._card_screen
		screen._update_bars(ctx)
		screen._update_whisper(ctx)
		screen._set_affected(["religion", "politics"])
		for i in range(40):
			await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("SCREENSHOT_SAVED ", out_path, " ", img.get_width(), "x", img.get_height())
	quit()
