# Outil de capture : lance Main.tscn, attend, capture le viewport en PNG.
# Usage : godot --path . -s tools/screenshot.gd -- <sortie.png> [largeur] [hauteur] [frames]
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "shot.png"
	var w := 460
	var h := 920
	var wait_frames := 30
	if args.size() >= 1:
		out_path = args[0]
	if args.size() >= 3:
		w = int(args[1])
		h = int(args[2])
	if args.size() >= 4:
		wait_frames = int(args[3])

	DisplayServer.window_set_size(Vector2i(w, h))
	change_scene_to_file("res://scenes/Main.tscn")
	_capture(out_path, wait_frames)

func _capture(out_path: String, wait_frames: int) -> void:
	for i in range(wait_frames):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("SCREENSHOT_SAVED ", out_path, " ", img.get_width(), "x", img.get_height())
	quit()
