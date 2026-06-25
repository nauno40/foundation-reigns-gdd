@tool
class_name Codex
extends Control

# Panneau « Tableau de bord » coulissant (port de codex.jsx) : 3 onglets.

const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const HOLO_GRID = preload("res://assets/shaders/holo_grid.gdshader")
const CHAR_CARD_SCENE = preload("res://scenes/CharacterCard.tscn")
const TAB_ICONS := {
	"chars": preload("res://assets/icons/tab_chars.svg"),
	"ach": preload("res://assets/icons/tab_ach.svg"),
	"gal": preload("res://assets/icons/tab_gal.svg"),
}

var _open := false
var _tab := "chars"
@onready var _panel: PanelContainer = %Panel
@onready var _body: VBoxContainer = %Body
@onready var _holder: Control = %Holder
@onready var _scroll: ScrollContainer = %Scroll
@onready var _tabs := {"chars": %TabChars, "ach": %TabAch, "gal": %TabGal}
var _galaxy: Control
var _planet_rects := []
var _selected := ""
var _info: VBoxContainer
# carrousel d'onglets (suivi du doigt)
var _gp_start := Vector2.ZERO
var _gp_mode := ""        # "" / "h" / "v"
var _sliding := false
var _ring_phase := 0.0    # pulse de l'anneau planète sélectionnée
var _ring_tween: Tween

func _ready() -> void:
	(%TabChars as CodexTab).setup(TAB_ICONS["chars"], "PERSONNAGES")
	(%TabAch as CodexTab).setup(TAB_ICONS["ach"], "SUCCÈS / DECKS")
	(%TabGal as CodexTab).setup(TAB_ICONS["gal"], "GALAXIE")
	(%TabChars as CodexTab).tab_pressed.connect(func(): _select("chars"))
	(%TabAch as CodexTab).tab_pressed.connect(func(): _select("ach"))
	(%TabGal as CodexTab).tab_pressed.connect(func(): _select("gal"))
	%Grab.pressed.connect(close)
	_holder.resized.connect(func(): _scroll.size = _holder.size)
	if Engine.is_editor_hint():
		visible = get_tree().edited_scene_root == self
		if visible:
			_select("chars")
	else:
		visible = false
		_select("chars")

const TABS := ["chars", "ach", "gal"]

func open(tab := "chars") -> void:
	_select(tab)
	visible = true
	_open = true
	_panel.position.y = size.y
	_animate_to(0.0, false)

func close() -> void:
	if not _open: return
	_open = false
	_animate_to(size.y, true)

func _animate_to(y: float, hide_after: bool) -> void:
	var t := create_tween()
	t.tween_property(_panel, "position:y", y, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if hide_after:
		t.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)

# ── Tirer la poignée (drag) ──
func drag_start() -> void:
	visible = true
	_open = true
	if _tab == "" or _body.get_child_count() == 0:
		_select("chars")
	_panel.position.y = size.y

func drag_move(up: float) -> void:
	_panel.position.y = clampf(size.y - up, 0.0, size.y)

func drag_end(up: float) -> void:
	if up > size.y * 0.22:
		_animate_to(0.0, false)
	else:
		_open = false
		_animate_to(size.y, true)

# ── Carrousel d'onglets : le contenu suit le doigt, ressort si pas assez glissé ──
var _gp_down := false

func _input(event: InputEvent) -> void:
	if not _open or _sliding:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_gp_down = true
			_gp_start = event.position
			_gp_mode = ""
		else:
			if _gp_mode == "h":
				_end_carousel(event.position.x - _gp_start.x)
			_gp_down = false
			_gp_mode = ""
	elif event is InputEventMouseMotion and _gp_down:
		if _gp_mode == "":
			var d: Vector2 = event.position - _gp_start
			if absf(d.x) > 12.0 and absf(d.x) > absf(d.y):
				_gp_mode = "h"
			elif absf(d.y) > 12.0:
				_gp_mode = "v"   # laisse le scroll vertical faire son travail
		if _gp_mode == "h":
			_scroll.position.x = _resist(event.position.x - _gp_start.x)
			get_viewport().set_input_as_handled()

func _resist(dx: float) -> float:
	var i: int = TABS.find(_tab)
	if (dx > 0.0 and i <= 0) or (dx < 0.0 and i >= TABS.size() - 1):
		return dx * 0.3   # bord : résistance élastique
	return dx

func _end_carousel(dx: float) -> void:
	var w: float = _holder.size.x
	var i: int = TABS.find(_tab)
	if dx < -w * 0.28 and i < TABS.size() - 1:
		_slide(1)
	elif dx > w * 0.28 and i > 0:
		_slide(-1)
	else:
		_spring_back()

func _spring_back() -> void:
	var t := create_tween()
	t.tween_property(_scroll, "position:x", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _slide(dir: int) -> void:
	_sliding = true
	var w: float = _holder.size.x
	var i: int = TABS.find(_tab)
	var t := create_tween()
	t.tween_property(_scroll, "position:x", -dir * w, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await t.finished
	_select(TABS[i + dir])
	_scroll.position.x = dir * w
	var t2 := create_tween()
	t2.tween_property(_scroll, "position:x", 0.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await t2.finished
	_sliding = false

func _select(tab: String) -> void:
	_tab = tab
	for k in _tabs:
		(_tabs[k] as CodexTab).set_active(k == tab)
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
	var cc: CharacterCard = CHAR_CARD_SCENE.instantiate()
	cc.setup(c)
	return cc

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
		cs.bg_color = Cfg.accent; cs.border_color = Cfg.accent
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
	# boîte galactique bordée arrondie (template .galaxy)
	var box := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#0a1422")
	bsb.set_corner_radius_all(14)
	bsb.set_border_width_all(1)
	bsb.border_color = Pal.LINE
	box.add_theme_stylebox_override("panel", bsb)
	box.clip_contents = true
	_body.add_child(box)
	_galaxy = Control.new()
	_galaxy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_galaxy.draw.connect(_draw_galaxy)
	_galaxy.gui_input.connect(_galaxy_input)
	_galaxy.resized.connect(func():
		if not is_equal_approx(_galaxy.custom_minimum_size.y, _galaxy.size.x):
			_galaxy.custom_minimum_size.y = _galaxy.size.x
		_galaxy.queue_redraw())
	box.add_child(_galaxy)
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
	# boîte d'info bordée (template .pl-info)
	var ibox := PanelContainer.new()
	ibox.custom_minimum_size = Vector2(0, 84)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(1, 1, 1, 0.02)
	isb.set_corner_radius_all(11)
	isb.set_border_width_all(1)
	isb.border_color = Pal.LINE
	isb.content_margin_left = 15; isb.content_margin_right = 15
	isb.content_margin_top = 13; isb.content_margin_bottom = 13
	ibox.add_theme_stylebox_override("panel", isb)
	_body.add_child(ibox)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 4)
	ibox.add_child(_info)
	_render_info()

func _draw_galaxy() -> void:
	var w: float = _galaxy.size.x
	var h: float = _galaxy.size.y
	if w <= 0.0 or h <= 0.0: return
	# champ d'étoiles (template .stars2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(70):
		var sp := Vector2(rng.randf() * w, rng.randf() * h)
		_galaxy.draw_circle(sp, rng.randf_range(0.5, 1.4), Color(0.82, 0.92, 1.0, rng.randf_range(0.12, 0.5)))
	# bras concentriques
	var c := Vector2(w, h) * 0.5
	var rad: float = min(w, h)
	for f in [0.42, 0.28, 0.14]:
		_galaxy.draw_arc(c, rad * f, 0.0, TAU, 64, Color(0.31, 0.839, 0.91, 0.06), 1.0, true)
	# planètes
	_planet_rects.clear()
	for p in Data.PLANETS:
		var pos := Vector2(p["x"] / 100.0 * w, p["y"] / 100.0 * h)
		var col := Data.state_color(p["state"])
		var r := 7.0 if p["base"] else 5.5
		if _selected == p["id"]:
			# plring : anneau pulsant (scale 1→1.35, alpha 1→.4)
			var tri := sin(_ring_phase * PI)
			var rr := (r + 5.0) * (1.0 + 0.35 * tri)
			_galaxy.draw_arc(pos, rr, 0.0, TAU, 32, Color(col.r, col.g, col.b, 1.0 - 0.6 * tri), 1.5, true)
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
				_start_ring_pulse()
				return

func _start_ring_pulse() -> void:
	if _ring_tween and _ring_tween.is_valid():
		return
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_method(_ring_step, 0.0, 1.0, 1.1)

func _ring_step(v: float) -> void:
	_ring_phase = v
	if is_instance_valid(_galaxy):
		_galaxy.queue_redraw()

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
	fc.add_theme_color_override("font_color", Cfg.accent)
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
	l.add_theme_font_override("font", Pal.mono_spaced(FONT_MONO, 2))
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color("#6b768c"))
	return l
