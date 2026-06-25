class_name Codex
extends Control

# Panneau « Tableau de bord » coulissant (port de codex.jsx) : 3 onglets.

const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const HOLO_GRID = preload("res://assets/shaders/holo_grid.gdshader")

var _open := false
var _tab := "chars"
var _panel: PanelContainer
var _tab_buttons := {}
var _tab_underlines := {}
var _body: VBoxContainer
var _galaxy: Control
var _planet_rects := []
var _selected := ""
var _info: VBoxContainer

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

	var grab := Button.new()
	grab.text = "FERMER ▼"
	grab.focus_mode = Control.FOCUS_NONE
	grab.add_theme_font_override("font", FONT_MONO)
	grab.add_theme_font_size_override("font_size", 8)
	grab.custom_minimum_size = Vector2(0, 34)
	grab.pressed.connect(close)
	_flat(grab)
	root.add_child(grab)

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
		_flat(b)
		var key: String = entry[0]
		b.pressed.connect(func(): _select(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
		var ul := ColorRect.new()
		ul.color = Pal.ACCENT
		ul.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		ul.anchor_left = 0.18; ul.anchor_right = 0.82
		ul.offset_top = -2.0; ul.offset_bottom = 0.0
		ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ul.visible = false
		b.add_child(ul)
		_tab_underlines[key] = ul

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_bottom", 22)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 9)
	m.add_child(_body)
	_select("chars")

func _flat(b: Button) -> void:
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.31, 0.839, 0.91, 0.06)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_hover_color", Pal.ACCENT)
	b.add_theme_color_override("font_color", Pal.INK_DIM)

func open(tab := "chars") -> void:
	_select(tab)
	visible = true
	_open = true
	_panel.position.y = size.y
	create_tween().tween_property(_panel, "position:y", 0.0, 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func close() -> void:
	if not _open: return
	_open = false
	var t := create_tween()
	t.tween_property(_panel, "position:y", size.y, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)

func _select(tab: String) -> void:
	_tab = tab
	for k in _tab_buttons:
		_tab_buttons[k].add_theme_color_override("font_color", Pal.ACCENT if k == tab else Pal.INK_DIM)
		_tab_underlines[k].visible = (k == tab)
	for c in _body.get_children(): c.queue_free()
	match tab:
		"chars": _render_chars()
		"ach": _render_ach()
		"gal": _render_gal()

# ── Personnages ──
func _render_chars() -> void:
	var met := Data.CHARACTERS.filter(func(c): return c["met"])
	var soon := Data.CHARACTERS.filter(func(c): return not c["met"])
	_body.add_child(_section("RENCONTRÉS · %d" % met.size()))
	_body.add_child(_grid(met))
	_body.add_child(_section("À VENIR · %d" % soon.size()))
	_body.add_child(_grid(soon))

func _grid(list: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in list: g.add_child(_char(c))
	return g

func _char(c: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 7)
	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.resized.connect(func(): if not is_equal_approx(card.custom_minimum_size.y, card.size.x): card.custom_minimum_size.y = card.size.x)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(13)
	sb.bg_color = Data.tone_for(c["id"]) if c["met"] else Color("#10151f")
	card.add_theme_stylebox_override("panel", sb)
	vb.add_child(card)
	if c["met"]:
		var grid := ColorRect.new()
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gm := ShaderMaterial.new()
		gm.shader = HOLO_GRID
		grid.material = gm
		card.add_child(grid)
		grid.resized.connect(func(): gm.set_shader_parameter("rect_size", grid.size))
		var bust := CardBust.new()
		bust.set_anchors_preset(Control.PRESET_FULL_RECT)
		bust.anchor_left = 0.18; bust.anchor_right = 0.82; bust.anchor_top = 0.20
		bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bust)
		bust.set_tone(Data.tone_for(c["id"]))
		bust.set_initials(Data.initials(c["name"]))
	else:
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(cc)
		var q := Label.new()
		q.text = "? ? ?"
		q.add_theme_font_override("font", FONT_MONO)
		q.add_theme_font_size_override("font_size", 22)
		q.add_theme_color_override("font_color", Color("#3a4458"))
		cc.add_child(q)
	if c["key"]:
		var star := Label.new()
		star.text = "★"
		star.add_theme_color_override("font_color", Pal.AMBER)
		star.position = Vector2(8, 6)
		card.add_child(star)
	var nm := Label.new()
	nm.text = c["name"] if c["met"] or c["key"] else "Inconnu"
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", Pal.INK if c["met"] else Color("#5d6b82"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)
	var tg := Label.new()
	tg.text = str(c["tag"]).to_upper()
	tg.add_theme_font_override("font", FONT_MONO)
	tg.add_theme_font_size_override("font_size", 8)
	tg.add_theme_color_override("font_color", Pal.ACCENT if c["met"] else Color("#4d586e"))
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(tg)
	return vb

# ── Succès / Decks ──
func _render_ach() -> void:
	_body.add_child(_section("SUCCÈS"))
	for a in Data.ACHIEVEMENTS: _body.add_child(_ach(a))
	var u := Data.DECKS_META.filter(func(d): return d["unlocked"])
	var l := Data.DECKS_META.filter(func(d): return not d["unlocked"])
	_body.add_child(_section("DECKS DÉBLOQUÉS · %d/%d" % [u.size(), Data.DECKS_META.size()]))
	for d in u: _body.add_child(_chip(d, false))
	_body.add_child(_section("VERROUILLÉS"))
	for d in l: _body.add_child(_chip(d, true))

func _ach(a: Dictionary) -> Control:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.018)
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(1)
	sb.border_color = Pal.LINE
	sb.content_margin_left = 13; sb.content_margin_right = 13
	sb.content_margin_top = 11; sb.content_margin_bottom = 11
	box.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 11)
	box.add_child(hb)
	var chk := Panel.new()
	chk.custom_minimum_size = Vector2(22, 22)
	chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.set_corner_radius_all(11)
	cs.set_border_width_all(1)
	if a["done"]:
		cs.bg_color = Pal.ACCENT; cs.border_color = Pal.ACCENT
	else:
		cs.bg_color = Color(0, 0, 0, 0); cs.border_color = Pal.LINE
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
	nm.add_theme_color_override("font_color", Pal.INK if a["done"] else Pal.INK_DIM)
	vb.add_child(nm)
	var ds := Label.new()
	ds.text = a["desc"]
	ds.add_theme_font_size_override("font_size", 11)
	ds.add_theme_color_override("font_color", Pal.INK_FAINT)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ds)
	hb.add_child(vb)
	return box

func _chip(d: Dictionary, locked: bool) -> Control:
	var box := PanelContainer.new()
	box.modulate.a = 0.4 if locked else 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.012)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = Pal.LINE
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 9; sb.content_margin_bottom = 9
	box.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	box.add_child(hb)
	var nm := Label.new()
	nm.text = d["name"]
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 13)
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	var er := Label.new()
	er.text = d["era"] + (" 🔒" if locked else "")
	er.add_theme_font_override("font", FONT_MONO)
	er.add_theme_font_size_override("font_size", 9)
	er.add_theme_color_override("font_color", Pal.INK_FAINT)
	hb.add_child(er)
	return box

# ── Galaxie ──
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
		l.add_theme_color_override("font_color", Data.state_color(pair[0]))
		legend.add_child(l)
	_body.add_child(legend)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 4)
	_body.add_child(_info)
	_render_info()

func _draw_galaxy() -> void:
	var sz: Vector2 = _galaxy.size
	var side: float = min(sz.x, sz.y)
	if side <= 0.0: return
	var o := Vector2((sz.x - side) / 2.0, 0.0)
	_galaxy.draw_rect(Rect2(o, Vector2(side, side)), Color("#080d16"))
	var c := o + Vector2(side, side) * 0.5
	for f in [0.42, 0.28, 0.14]:
		_galaxy.draw_arc(c, side * f, 0.0, TAU, 64, Color(0.31, 0.839, 0.91, 0.06), 1.0, true)
	_planet_rects.clear()
	for p in Data.PLANETS:
		var pos := o + Vector2(p["x"] / 100.0 * side, p["y"] / 100.0 * side)
		var col := Data.state_color(p["state"])
		var r := 7.0 if p["base"] else 5.5
		if _selected == p["id"]:
			_galaxy.draw_arc(pos, r + 5.0, 0.0, TAU, 32, col, 1.5, true)
		_galaxy.draw_circle(pos, r + 3.0, Color(col.r, col.g, col.b, 0.25))
		_galaxy.draw_circle(pos, r, col)
		_planet_rects.append({"id": p["id"], "pos": pos, "r": r + 6.0})

func _galaxy_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for pr in _planet_rects:
			if e.position.distance_to(pr["pos"]) <= pr["r"]:
				_selected = pr["id"]
				_galaxy.queue_redraw()
				_render_info()
				return

func _render_info() -> void:
	for c in _info.get_children(): c.queue_free()
	var p := {}
	for x in Data.PLANETS:
		if x["id"] == _selected: p = x; break
	if p.is_empty():
		var e := Label.new()
		e.text = "Touchez une planète pour observer son état et sa faction."
		e.add_theme_font_override("font", FONT_SPECTRAL)
		e.add_theme_font_size_override("font_size", 12)
		e.add_theme_color_override("font_color", Pal.INK_FAINT)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(e)
		return
	var head := HBoxContainer.new()
	var nm := Label.new()
	nm.text = p["name"] + (" ◆" if p["base"] else "")
	nm.add_theme_font_override("font", FONT_SPECTRAL)
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var st := Label.new()
	st.text = Data.state_label(p["state"]).to_upper()
	st.add_theme_font_override("font", FONT_MONO)
	st.add_theme_font_size_override("font_size", 9)
	st.add_theme_color_override("font_color", Data.state_color(p["state"]))
	head.add_child(st)
	_info.add_child(head)
	var fc := Label.new()
	fc.text = str(p["faction"]).to_upper() + (" · CACHÉE" if p["hidden"] else "")
	fc.add_theme_font_override("font", FONT_MONO)
	fc.add_theme_font_size_override("font_size", 9)
	fc.add_theme_color_override("font_color", Pal.ACCENT)
	_info.add_child(fc)
	var nt := Label.new()
	nt.text = p["note"]
	nt.add_theme_font_override("font", FONT_SPECTRAL)
	nt.add_theme_font_size_override("font_size", 13)
	nt.add_theme_color_override("font_color", Pal.INK_DIM)
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(nt)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_MONO)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color("#6b768c"))
	return l
