# Sonde de debug : imprime les rects de la hiérarchie UI après chargement.
extends SceneTree

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800))
	change_scene_to_file("res://scenes/Main.tscn")
	_probe()

func _probe() -> void:
	for i in range(40):
		await process_frame
	var main = current_scene
	print("viewport: ", root.get_visible_rect().size)
	var base = "UIRoot/Frame/Content/CardScreen/"
	for path in ["UIRoot/Frame", "UIRoot/Frame/Content",
			base + "MainVBox",
			base + "MainVBox/CardArea",
			base + "MainVBox/CardArea/CardPanel",
			base + "MainVBox/CardArea/CardPanel/CardVBox",
			base + "MainVBox/CardArea/CardPanel/CardVBox/Portrait",
			base + "MainVBox/CardArea/CardPanel/CardVBox/QBody",
			base + "MainVBox/CardArea/CardPanel/CardVBox/QBody/QVBox/QuestionLabel"]:
		var n = main.get_node_or_null(path)
		if n == null:
			print(path, " -> ABSENT")
		elif n is Control:
			print(path.replace(base, "…/"), " pos=", n.position, " size=", n.size,
				" min=", n.get_combined_minimum_size())
	quit()
