extends Control

# Galerie d'animations — outil de dev pour tester rapidement toutes les
# animations portées de Reigns 3K, sur les VRAIS écrans du jeu.
#
# Lancer :  godot scenes/AnimGallery.tscn
# (ou définir AnimGallery.tscn comme scène principale le temps d'un test)
#
# Panneau de gauche : un bouton par animation. Zone de droite : la scène
# concernée (carte de base + overlays mort / carte galactique / menu / options).

const CARD_SCREEN  = preload("res://scenes/CardScreen.tscn")
const DEATH_SCREEN = preload("res://scenes/DeathScreen.tscn")
const GALAXY_MAP   = preload("res://scenes/GalaxyMap.tscn")
const OPTIONS      = preload("res://scenes/OptionsScreen.tscn")
const MAIN_MENU    = preload("res://scenes/MainMenu.tscn")

var _stage: Control
var _status: Label
var _card                       # CardScreen (base permanente)
var _ctx: Context
var _overlay: Control           # overlay courant (mort / map / menu / options)
var _bar_up := true             # alterne le sens du flash des barres

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx = _make_ctx()
	_build_ui()
	_card = CARD_SCREEN.instantiate()
	_stage.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	_replay_card(false)

# ── Données de démo ──────────────────────────────────────────────────

func _make_ctx() -> Context:
	var ctx := Context.new()
	ctx.initialize_new_reign()
	ctx.set_var("year", 42, true)
	ctx.set_var("y_start", 1, true)
	ctx.set_var("age", 38)
	ctx.set_var("turns", 37)
	ctx.set_var("cover_name", "Marchand local")
	ctx.set_var("military", 55)
	ctx.set_var("religion", 48)
	ctx.set_var("commerce", 52)
	ctx.set_var("politics", 50)
	ctx.set_var("legitimacy", 70)
	ctx.set_var("mood", "neutral")
	return ctx

func _demo_card(flip := false) -> Dictionary:
	var c := {
		"id": 9001,
		"deck": "seldon_vault" if flip else "ambient",
		"bearer": "Salvor Hardin",
		"question": {"FR": "Une rumeur circule à Terminus : la Fondation serait en danger de l'intérieur. Comment réagir, Orateur ?"},
		"leftAnswer": {"title": {"FR": "Ignorer"}, "reaction": {"FR": "Vous faites confiance au Plan de Seldon."}},
		"rightAnswer": {"title": {"FR": "Enquêter"}, "reaction": {"FR": "Vous activez discrètement votre réseau."}},
	}
	if flip:
		c["flip_intro"] = true
	return c

# ── Construction de l'interface ──────────────────────────────────────

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Panneau de boutons (gauche)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(248, 0)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var title := Label.new()
	title.text = "GALERIE D'ANIMATIONS"
	list.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(0.6, 0.8, 0.9)
	list.add_child(_status)

	_section(list, "— CARTE —")
	_btn(list, "Entrée (rejouer)", func(): _replay_card(false))
	_btn(list, "Flip-in (révélation)", func(): _replay_card(true))
	_btn(list, "Wobble de défaite", _do_defeat)
	_btn(list, "Barres : flash hausse/baisse", _do_bar_flash)
	_btn(list, "Année : défilé", _do_year)
	var note := Label.new()
	note.text = "(la grille holo dérive en continu)"
	note.modulate = Color(0.5, 0.5, 0.6)
	list.add_child(note)

	_section(list, "— ÉCRANS (overlay) —")
	_btn(list, "Écran de mort", _open_death)
	_btn(list, "Carte galactique : teinte", _open_map)
	_btn(list, "Menu : splash", _open_menu)
	_btn(list, "Options : entrée", _open_options)
	_btn(list, "Options : sortie", _close_options_animated)
	_btn(list, "← Retour carte", _close_overlay)

	# Zone de scène (droite)
	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	root.add_child(_stage)

func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.9, 0.7, 0.35)
	parent.add_child(l)

func _btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)

func _say(text: String) -> void:
	_status.text = text

# ── Animations de carte ──────────────────────────────────────────────

func _replay_card(flip: bool) -> void:
	_close_overlay()
	_card.show_card(_demo_card(flip), _ctx)
	_say("Flip-in (révélation)" if flip else "Entrée verticale + fondu")

func _do_defeat() -> void:
	_close_overlay()
	_card.play_defeat()
	_say("Wobble + chute de la carte (TriggerDefeat). « Entrée » pour la remettre.")

func _do_bar_flash() -> void:
	_close_overlay()
	var target := 82 if _bar_up else 18
	for key in ["military", "religion", "commerce", "politics"]:
		_card._bars[key].update_value(target)
	_say("Flash %s des barres (ValueAct)" % ("hausse (vert)" if _bar_up else "baisse (rouge)"))
	_bar_up = not _bar_up

func _do_year() -> void:
	_close_overlay()
	var y := int(_ctx.get_var("year", 42)) + randi_range(25, 90)
	_ctx.set_var("year", y, true)
	_card._update_info(_ctx)
	_say("Année qui défile jusqu'à l'an %d (TweenYearRoutine)" % y)

# ── Overlays ─────────────────────────────────────────────────────────

func _open_overlay(node: Control) -> void:
	_close_overlay()
	_overlay = node
	_stage.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)

func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _open_death() -> void:
	var d := DEATH_SCREEN.instantiate()
	_open_overlay(d)
	await get_tree().process_frame
	d.show_death(_ctx, "legitimacy", "Marchand local", {})
	_say("Écran de mort : révélation séquencée (cause → titre → stats → Seldon)")

func _open_map() -> void:
	var m := GALAXY_MAP.instantiate()
	var gd := FoundationGameData.new()
	gd.load_all()
	m.setup(gd)
	_open_overlay(m)
	await get_tree().process_frame
	m.update(_ctx)  # état de base (sans transition)
	# randomise les états puis ré-applique → transition de teinte animée
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(m):
		for pid in m._buttons:
			_ctx.set_var("planet_%s_state" % pid, [-1, 0, 1].pick_random(), true)
		m.update(_ctx)
	_say("Carte galactique : transition de teinte des planètes (AnimateTint)")

func _open_menu() -> void:
	Globals.start_mode = Globals.StartMode.NONE  # évite l'auto-démarrage
	var menu := MAIN_MENU.instantiate()
	_open_overlay(menu)
	await get_tree().process_frame
	# désactive la navigation (c'est une démo) et rejoue le splash
	for b in [menu._new_btn, menu._cont_btn, menu._opts_btn, menu._quit_btn]:
		b.disabled = true
	menu._menu_enter()
	_say("Menu principal : splash en cascade (SplashAnimation)")

func _open_options() -> void:
	var o := OPTIONS.instantiate()
	_open_overlay(o)
	o.back_pressed.connect(_close_overlay)
	await get_tree().process_frame
	o.animate_in()
	_say("Options : entrée en fondu + sections en cascade. « sortie » ou Retour pour fermer.")

func _close_options_animated() -> void:
	if is_instance_valid(_overlay) and _overlay.has_method("animate_out"):
		_overlay.animate_out(_close_overlay)
		_say("Options : sortie en fondu")
	else:
		_say("Ouvre d'abord « Options : entrée ».")
