class_name Codex
extends Control

# Panneau « Tableau de bord » coulissant (nouveau template codex.jsx) :
# glisse du bas, 3 onglets — Personnages, Succès/Decks, Galaxie (fusionne
# l'ancienne GalaxyMap). Coquille visuelle : données statiques (placeholder
# façon data.jsx) ; le câblage aux vraies données (seen_*, deck_*, MetaSystem,
# planet_*_state) est différé à une passe ultérieure.

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const HOLO_GRID = preload("res://assets/shaders/holo_grid.gdshader")

# ── Données statiques (placeholder) ──────────────────────────────────
const CHARACTERS := [
	{"id": "seldon", "name": "Hari Seldon", "tag": "Fondateur du Plan", "met": true, "key": true},
	{"id": "hardin", "name": "Salvor Hardin", "tag": "Maire de Terminus", "met": true, "key": true},
	{"id": "pirenne", "name": "Lewis Pirenne", "tag": "Président du Conseil", "met": true, "key": false},
	{"id": "sermak", "name": "Sef Sermak", "tag": "Chef des Actionnistes", "met": true, "key": false},
	{"id": "anselm", "name": "Frère Anselm", "tag": "Église de la Science", "met": true, "key": false},
	{"id": "verisof", "name": "Poly Verisof", "tag": "Grand Prêtre & Ambassadeur", "met": true, "key": false},
	{"id": "lefkin", "name": "Prince Lefkin", "tag": "Régent d'Anacréon", "met": true, "key": false},
	{"id": "mallow", "name": "Hober Mallow", "tag": "Prince Marchand", "met": false, "key": true},
	{"id": "barr", "name": "Ducem Barr", "tag": "Patricien de Siwenna", "met": false, "key": false},
	{"id": "bayta", "name": "Bayta Darell", "tag": "Résistante", "met": false, "key": true},
	{"id": "mis", "name": "Ebling Mis", "tag": "Psychologue", "met": false, "key": false},
]
const ACHIEVEMENTS := [
	{"name": "Premier Orateur", "desc": "Prendre une première couverture.", "done": true},
	{"name": "Lecteur d'esprits", "desc": "Lire 5 humeurs différentes.", "done": true},
	{"name": "Main invisible", "desc": "Terminer un règne sans être démasqué.", "done": false},
	{"name": "Crise d'Anacréon", "desc": "Franchir la 1re Crise de Seldon (ans 50–80).", "done": false},
	{"name": "Vieil Orateur", "desc": "Mourir de vieillesse (×1.5 score).", "done": false},
]
const DECKS_META := [
	{"name": "Ambiant", "era": "Permanent", "unlocked": true},
	{"name": "Nouveau Speaker", "era": "Permanent", "unlocked": true},
	{"name": "Ère Hardin", "era": "Ans 1–80", "unlocked": true},
	{"name": "Église de la Science", "era": "Ans 50–200", "unlocked": true},
	{"name": "Menace Anacréon", "era": "Ans 1–150", "unlocked": true},
	{"name": "Ère des Marchands", "era": "Ans 80–250", "unlocked": false},
	{"name": "Ère Mallow", "era": "Ans 200–350", "unlocked": false},
	{"name": "Le Mulet", "era": "Ans 290–380", "unlocked": false},
	{"name": "Restauration", "era": "Ans 350–600", "unlocked": false},
	{"name": "Second Empire", "era": "Ans 600+", "unlocked": false},
]
const PLANETS := [
	{"id": "terminus", "name": "Terminus", "faction": "Première Fondation", "state": 1, "x": 18, "y": 64, "note": "Base permanente. La perdre = fin du Plan.", "base": true, "hidden": false},
	{"id": "trantor", "name": "Trantor", "faction": "Empire → Seconde Fondation", "state": 1, "x": 52, "y": 48, "note": "Capitale impériale déclinante.", "base": false, "hidden": false},
	{"id": "anacreon", "name": "Anacréon", "faction": "Royaumes militaristes", "state": -1, "x": 30, "y": 30, "note": "Première grande menace.", "base": false, "hidden": false},
	{"id": "santanni", "name": "Santanni", "faction": "Royaumes militaristes", "state": -1, "x": 40, "y": 18, "note": "Royaume des Quatre Provinces.", "base": false, "hidden": false},
	{"id": "smyrno", "name": "Smyrno", "faction": "Royaumes militaristes", "state": -1, "x": 22, "y": 44, "note": "Royaume des Quatre Provinces.", "base": false, "hidden": false},
	{"id": "askone", "name": "Askone", "faction": "Marchands", "state": 0, "x": 64, "y": 30, "note": "Cible commerciale de l'ère Mallow.", "base": false, "hidden": false},
	{"id": "korell", "name": "Korell", "faction": "Oligarques", "state": 0, "x": 76, "y": 42, "note": "République des Princes Marchands.", "base": false, "hidden": false},
	{"id": "siwenna", "name": "Siwenna", "faction": "Empire → Neotrantor", "state": 0, "x": 60, "y": 64, "note": "Province impériale. Chute de l'Empire.", "base": false, "hidden": false},
	{"id": "kalgan", "name": "Kalgan", "faction": "Mulet → Kalgan", "state": 0, "x": 82, "y": 72, "note": "Base du Mulet, puis seigneurie de guerre.", "base": false, "hidden": false},
	{"id": "neotrantor", "name": "Neotrantor", "faction": "Neotrantor", "state": 0, "x": 46, "y": 74, "note": "Vestige impérial après le sac de Trantor.", "base": false, "hidden": false},
	{"id": "rossem", "name": "Rossem", "faction": "Seconde Fondation", "state": 0, "x": 88, "y": 24, "note": "Planète glaciale. Couverture de la Seconde Fondation.", "base": false, "hidden": true},
	{"id": "sayshell", "name": "Sayshell", "faction": "Église de la Science", "state": 0, "x": 34, "y": 82, "note": "Culte de la Fondation, fin de partie.", "base": false, "hidden": false},
]

static func state_color(s: int) -> Color:
	match s:
		1: return Color("#5fcf8f")
		-1: return Color("#d96a5a")
	return Color("#8693a8")

static func state_label(s: int) -> String:
	match s:
		1: return "Alignée"
		-1: return "Hostile"
	return "Neutre"

var _open := false
var _tab := "chars"
var _panel: PanelContainer
var _tab_buttons := {}
var _body: VBoxContainer
var _tab_underlines := {}
var _galaxy: Control
var _planet_rects := []
var _selected_planet := ""
var _info_box: VBoxContainer

func _ready() -> void:
	visible = false
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#070b13")
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	_panel.add_child(root)

	# poignée de fermeture
	var grab := Button.new()
	grab.text = "FERMER ▼"
	grab.focus_mode = Control.FOCUS_NONE
	grab.add_theme_font_override("font", FONT_MONO)
	grab.add_theme_font_size_override("font_size", 8)
	grab.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	grab.custom_minimum_size = Vector2(0, 34)
	grab.pressed.connect(close)
	_style_flat_button(grab)
	root.add_child(grab)

	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	root.add_child(tabs)
	for entry in [["chars", "PERSONNAGES"], ["ach", "SUCCÈS / DECKS"], ["gal", "GALAXIE"]]:
		var b := Button.new()
		b.text = entry[1]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_override("font", FONT_MONO)
		b.add_theme_font_size_override("font_size", 9)
		_style_flat_button(b)
		var key: String = entry[0]
		b.pressed.connect(func(): _select_tab(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
		# soulignement de l'onglet actif (template .tab.on::after)
		var ul := ColorRect.new()
		ul.color = ThemeColors.ACCENT
		ul.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		ul.anchor_left = 0.18
		ul.anchor_right = 0.82
		ul.offset_top = -2.0
		ul.offset_bottom = 0.0
		ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ul.visible = false
		b.add_child(ul)
		_tab_underlines[key] = ul

	# corps défilant
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 9)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_bottom", 22)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	m.add_child(_body)

	_select_tab("chars")

func _style_flat_button(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.31, 0.839, 0.91, 0.06)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_hover_color", ThemeColors.ACCENT)
	b.add_theme_color_override("font_color", ThemeColors.INK_DIM)

# ── Ouverture / fermeture coulissante ────────────────────────────────

func open(tab := "chars") -> void:
	_select_tab(tab)
	visible = true
	_open = true
	_panel.position.y = size.y
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", 0.0, 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func close() -> void:
	if not _open:
		return
	_open = false
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", size.y, 0.32) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)

func _select_tab(tab: String) -> void:
	_tab = tab
	for key in _tab_buttons:
		_tab_buttons[key].add_theme_color_override("font_color",
			ThemeColors.ACCENT if key == tab else ThemeColors.INK_DIM)
		if _tab_underlines.has(key):
			_tab_underlines[key].visible = (key == tab)
	_render()

func _render() -> void:
	for c in _body.get_children():
		c.queue_free()
	match _tab:
		"chars": _render_chars()
		"ach": _render_ach()
		"gal": _render_gal()

# ── Onglet Personnages ───────────────────────────────────────────────

func _render_chars() -> void:
	var met := CHARACTERS.filter(func(c): return c["met"])
	var soon := CHARACTERS.filter(func(c): return not c["met"])
	_body.add_child(_section("RENCONTRÉS · %d" % met.size()))
	_body.add_child(_char_grid(met))
	_body.add_child(_section("À VENIR · %d" % soon.size()))
	_body.add_child(_char_grid(soon))

func _char_grid(list: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in list:
		grid.add_child(_char_block(c))
	return grid

func _char_block(c: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 7)

	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# carte carrée (aspect 1/1, template .cx-card) : hauteur = largeur
	card.resized.connect(func():
		if not is_equal_approx(card.custom_minimum_size.y, card.size.x):
			card.custom_minimum_size.y = card.size.x)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(13)
	if c["met"]:
		sb.bg_color = CardUtils.tone_for(c["id"])
	else:
		sb.bg_color = Color("#10151f")
	card.add_theme_stylebox_override("panel", sb)
	card.clip_contents = true
	vb.add_child(card)

	if c["met"]:
		# grille holographique (template .cx-card .cgrid)
		var grid := ColorRect.new()
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gm := ShaderMaterial.new()
		gm.shader = HOLO_GRID
		grid.material = gm
		card.add_child(grid)
		grid.resized.connect(func(): gm.set_shader_parameter("rect_size", grid.size))
		# buste teinté (comme la carte de jeu / template CharBlock)
		var bust := CardBust.new()
		bust.set_anchors_preset(Control.PRESET_FULL_RECT)
		bust.anchor_left = 0.18
		bust.anchor_right = 0.82
		bust.anchor_top = 0.20
		bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bust)
		bust.set_tone(CardUtils.tone_for(c["id"]))
		var letters := ""
		for w in str(c["name"]).split(" ", false):
			if w.length() > 0:
				letters += w[0].to_upper()
		bust.set_initials(letters.substr(0, 2))
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(center)
		var ini := Label.new()
		ini.add_theme_font_override("font", FONT_MONO)
		ini.add_theme_font_size_override("font_size", 22)
		ini.text = "? ? ?"
		ini.add_theme_color_override("font_color", Color("#3a4458"))
		center.add_child(ini)

	if c["key"]:
		var star := Label.new()
		star.text = "★"
		star.add_theme_color_override("font_color", ThemeColors.AMBER)
		star.position = Vector2(8, 6)
		card.add_child(star)

	var nm := Label.new()
	nm.text = c["name"] if c["met"] or c["key"] else "Inconnu"
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", ThemeColors.INK if c["met"] else Color("#5d6b82"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)

	var tg := Label.new()
	tg.text = str(c["tag"]).to_upper()
	tg.add_theme_font_override("font", FONT_MONO)
	tg.add_theme_font_size_override("font_size", 8)
	tg.add_theme_color_override("font_color", ThemeColors.ACCENT if c["met"] else Color("#4d586e"))
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(tg)
	return vb

# ── Onglet Succès / Decks ────────────────────────────────────────────

func _render_ach() -> void:
	_body.add_child(_section("SUCCÈS"))
	for a in ACHIEVEMENTS:
		_body.add_child(_ach_row(a))
	var unlocked := DECKS_META.filter(func(d): return d["unlocked"])
	var locked := DECKS_META.filter(func(d): return not d["unlocked"])
	_body.add_child(_section("DECKS DÉBLOQUÉS · %d/%d" % [unlocked.size(), DECKS_META.size()]))
	for d in unlocked:
		_body.add_child(_deck_chip(d, false))
	_body.add_child(_section("VERROUILLÉS"))
	for d in locked:
		_body.add_child(_deck_chip(d, true))

func _ach_row(a: Dictionary) -> Control:
	# boîte arrondie bordée (template .ach)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.018)
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(1)
	sb.border_color = ThemeColors.LINE
	sb.content_margin_left = 13
	sb.content_margin_right = 13
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	box.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 11)
	box.add_child(hb)

	# coche en cercle (template .chk : rempli accent si done)
	var chk := Panel.new()
	chk.custom_minimum_size = Vector2(22, 22)
	chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.set_corner_radius_all(11)
	cs.set_border_width_all(1)
	if a["done"]:
		cs.bg_color = ThemeColors.ACCENT
		cs.border_color = ThemeColors.ACCENT
	else:
		cs.bg_color = Color(0, 0, 0, 0)
		cs.border_color = ThemeColors.LINE
	chk.add_theme_stylebox_override("panel", cs)
	if a["done"]:
		var ck := Label.new()
		ck.text = "✓"
		ck.set_anchors_preset(Control.PRESET_FULL_RECT)
		ck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ck.add_theme_font_size_override("font_size", 12)
		ck.add_theme_color_override("font_color", Color("#04121a"))
		chk.add_child(ck)
	hb.add_child(chk)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	var nm := Label.new()
	nm.text = a["name"]
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", ThemeColors.INK if a["done"] else ThemeColors.INK_DIM)
	vb.add_child(nm)
	var ds := Label.new()
	ds.text = a["desc"]
	ds.add_theme_font_size_override("font_size", 11)
	ds.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ds)
	hb.add_child(vb)
	return box

func _deck_chip(d: Dictionary, locked: bool) -> Control:
	# chip arrondi bordé (template .deckchip)
	var box := PanelContainer.new()
	box.modulate.a = 0.4 if locked else 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.012)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = ThemeColors.LINE
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	box.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	box.add_child(hb)
	var nm := Label.new()
	nm.text = d["name"]
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 13)
	nm.add_theme_color_override("font_color", ThemeColors.INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	var er := Label.new()
	er.text = (d["era"] + (" 🔒" if locked else ""))
	er.add_theme_font_override("font", FONT_MONO)
	er.add_theme_font_size_override("font_size", 9)
	er.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
	hb.add_child(er)
	return box

# ── Onglet Galaxie ───────────────────────────────────────────────────

func _render_gal() -> void:
	_galaxy = Control.new()
	_galaxy.custom_minimum_size = Vector2(0, 300)
	_galaxy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_galaxy.draw.connect(_draw_galaxy)
	_galaxy.gui_input.connect(_galaxy_input)
	_galaxy.resized.connect(func(): _galaxy.queue_redraw())
	_body.add_child(_galaxy)

	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 16)
	for pair in [[1, "Alignée"], [0, "Neutre"], [-1, "Hostile"]]:
		var l := Label.new()
		l.text = "● " + pair[1]
		l.add_theme_font_override("font", FONT_MONO)
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", state_color(pair[0]))
		legend.add_child(l)
	_body.add_child(legend)

	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 4)
	_body.add_child(_info_box)
	_render_planet_info()

func _draw_galaxy() -> void:
	var sz: Vector2 = _galaxy.size
	var side: float = min(sz.x, sz.y)
	if side <= 0.0:
		return
	var origin := Vector2((sz.x - side) / 2.0, 0.0)
	# fond + bras concentriques
	_galaxy.draw_rect(Rect2(origin, Vector2(side, side)), Color("#080d16"))
	var c := origin + Vector2(side, side) * 0.5
	for f in [0.42, 0.28, 0.14]:
		_galaxy.draw_arc(c, side * f, 0.0, TAU, 64, Color(0.31, 0.839, 0.91, 0.06), 1.0, true)
	# planètes
	_planet_rects.clear()
	for p in PLANETS:
		var pos := origin + Vector2(p["x"] / 100.0 * side, p["y"] / 100.0 * side)
		var col := state_color(p["state"])
		var r := 7.0 if p["base"] else 5.5
		if _selected_planet == p["id"]:
			_galaxy.draw_arc(pos, r + 5.0, 0.0, TAU, 32, col, 1.5, true)
		_galaxy.draw_circle(pos, r + 3.0, Color(col.r, col.g, col.b, 0.25))
		_galaxy.draw_circle(pos, r, col)
		_planet_rects.append({"id": p["id"], "pos": pos, "r": r + 6.0})

func _galaxy_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for pr in _planet_rects:
			if event.position.distance_to(pr["pos"]) <= pr["r"]:
				_selected_planet = pr["id"]
				_galaxy.queue_redraw()
				_render_planet_info()
				return

func _render_planet_info() -> void:
	for c in _info_box.get_children():
		c.queue_free()
	var p := {}
	for x in PLANETS:
		if x["id"] == _selected_planet:
			p = x
			break
	if p.is_empty():
		var empty := Label.new()
		empty.text = "Touchez une planète pour observer son état et sa faction."
		empty.add_theme_font_override("font", FONT_SPECTRAL)
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(empty)
		return
	var head := HBoxContainer.new()
	var nm := Label.new()
	nm.text = p["name"] + (" ◆" if p["base"] else "")
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", ThemeColors.INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var st := Label.new()
	st.text = state_label(p["state"]).to_upper()
	st.add_theme_font_override("font", FONT_MONO)
	st.add_theme_font_size_override("font_size", 9)
	st.add_theme_color_override("font_color", state_color(p["state"]))
	head.add_child(st)
	_info_box.add_child(head)
	var fc := Label.new()
	fc.text = str(p["faction"]).to_upper() + (" · CACHÉE" if p["hidden"] else "")
	fc.add_theme_font_override("font", FONT_MONO)
	fc.add_theme_font_size_override("font_size", 9)
	fc.add_theme_color_override("font_color", ThemeColors.ACCENT)
	_info_box.add_child(fc)
	var nt := Label.new()
	nt.text = p["note"]
	nt.add_theme_font_override("font", FONT_SPECTRAL)
	nt.add_theme_font_size_override("font_size", 13)
	nt.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_box.add_child(nt)

# ── Section helper ───────────────────────────────────────────────────

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_MONO)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color("#6b768c"))
	return l
