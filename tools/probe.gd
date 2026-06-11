# Sonde de debug : imprime les rects de la hiérarchie UI après chargement.
extends SceneTree

func _init() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	_probe()

func _probe() -> void:
	for i in range(20):
		await process_frame
	var main = current_scene
	print("viewport: ", root.get_visible_rect().size)
	for path in ["UIRoot", "UIRoot/Frame", "UIRoot/Frame/Content",
			"UIRoot/Frame/Content/CardScreen",
			"UIRoot/Frame/Content/CardScreen/MainVBox",
			"UIRoot/Frame/Content/CardScreen/MainVBox/TopBar",
			"UIRoot/Frame/Content/CardScreen/MainVBox/CardArea",
			"UIRoot/Frame/Content/CardScreen/MainVBox/CardArea/CardPanel"]:
		var n = main.get_node_or_null(path)
		if n == null:
			print(path, " -> ABSENT")
		elif n is Control:
			print(path, " pos=", n.position, " size=", n.size)
	quit()
