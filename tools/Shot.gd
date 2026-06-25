extends Node

# Harnais de capture (scène → autoloads chargés). Choix du rendu via argument :
#   godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- card
#   ... -- death        ... -- codex        ... -- codexgal
# Sauvegarde /tmp/shot_<mode>.png puis quitte.

func _ready() -> void:
	get_window().size = Vector2i(460, 920)
	var bg := ColorRect.new()
	bg.color = Color("#05070d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "card"

	var data = FoundationGameData.new()
	data.load_all()
	var ctx = _make_ctx()

	match mode:
		"death": await _shot_death(ctx)
		"codex": await _shot_codex("chars")
		"codexach": await _shot_codex("ach")
		"codexgal": await _shot_codex("gal")
		"unlock": await _shot_unlock(data, ctx)
		"main": await _shot_main(data)
		_: await _shot_card(data, ctx)

	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shot_%s.png" % mode)
	print("SAVED ", mode, " ", img.get_size())
	get_tree().quit()

func _make_ctx() -> Context:
	var ctx = Context.new()
	ctx.set_var("military", 8)
	ctx.set_var("religion", 50)
	ctx.set_var("commerce", 92)
	ctx.set_var("politics", 34)
	ctx.set_var("legitimacy", 20)
	ctx.set_var("year", 64)
	ctx.set_var("y_start", 1)
	ctx.set_var("age", 38)
	ctx.set_var("turns", 27)
	ctx.set_var("cover_name", "Prêtre scientifique")
	return ctx

func _shot_card(data, ctx) -> void:
	# valeurs façon « An 1 » (≈50) + légitimité haute (pas de murmure), comme le template
	ctx.set_var("military", 52)
	ctx.set_var("religion", 50)
	ctx.set_var("commerce", 48)
	ctx.set_var("politics", 55)
	ctx.set_var("legitimacy", 100)
	ctx.set_var("year", 1)
	ctx.set_var("age", 36)
	var cs = load("res://scenes/CardScreen.tscn").instantiate()
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cs)
	cs.setup(data)
	var card := {
		"id": 7,
		"bearer": "hari_seldon",
		"role": "Président du Conseil",
		"key": true,
		"question": {"FR": "« Anacréon réclame une base militaire sur Terminus. Le Conseil n'ose ni refuser, ni céder. Que dois-je leur dire, Orateur ? »"},
		"leftAnswer": {"title": {"FR": "« Refusez. Fermement. »"}},
		"rightAnswer": {"title": {"FR": "« Gagnons du temps. »"}},
	}
	cs.show_card(card, ctx)
	await _wait(75)

func _shot_main(data) -> void:
	Globals.start_mode = Globals.StartMode.CONTINUE   # saute le briefing
	var main = load("res://scenes/Main.tscn").instantiate()
	main.preloaded_data = data
	add_child(main)
	await _wait(110)

func _shot_unlock(data, ctx) -> void:
	var cs = load("res://scenes/CardScreen.tscn").instantiate()
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cs)
	cs.setup(data)
	var card := {
		"id": 7, "bearer": "hari_seldon", "role": "Président du Conseil", "key": true,
		"question": {"FR": "« Que dois-je leur dire, Orateur ? »"},
		"leftAnswer": {"title": {"FR": "« Refusez. »"}},
		"rightAnswer": {"title": {"FR": "« Temporisons. »"}},
	}
	cs.show_card(card, ctx)
	await _wait(30)
	cs.play_deck_unlock({"id": "anacreon_throne", "name": "Le Trône d'Anacréon"})
	await _wait(28)   # mi-animation : cartes qui glissent + bannière

func _shot_death(ctx) -> void:
	var ds = load("res://scenes/DeathScreen.tscn").instantiate()
	ds.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ds)
	ds.show_death(ctx, "military", "Prêtre scientifique",
		{"score": 410, "rank_name": "Initié III", "total": 1240, "ranked_up": false})
	ds.show()
	await _wait(120)

func _shot_codex(tab: String) -> void:
	var cx = load("res://scenes/Codex.tscn").instantiate()
	cx.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cx)
	cx.open(tab)
	await _wait(60)

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
