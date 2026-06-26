class_name TweaksPanel
extends Control

# Panneau de réglages (port du Tweaks de app.jsx) : accent, grain, taille texte,
# difficulté. Écrit dans Cfg et émet Cfg.changed.

const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const ACCENTS := ["#4fd6e8", "#e8b65a", "#b98ad6", "#5fcf8f"]

var _open := false
var _panel: PanelContainer

func _ready() -> void:
	visible = false
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.anchor_left = 1.0
	_panel.offset_left = -230.0
	_panel.offset_right = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.063, 0.098, 0.97)
	sb.border_width_left = 1
	sb.border_color = Pal.LINE
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 16; sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := _lbl("RÉGLAGES", 10, Pal.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	x.add_theme_color_override("font_color", Pal.INK_DIM)
	x.pressed.connect(close)
	head.add_child(x)

	vb.add_child(_section("ACCENT HOLO"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	for hexc in ACCENTS:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(34, 26)
		sw.focus_mode = Control.FOCUS_NONE
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(hexc)
		ssb.set_corner_radius_all(6)
		sw.add_theme_stylebox_override("normal", ssb)
		sw.add_theme_stylebox_override("hover", ssb)
		sw.add_theme_stylebox_override("pressed", ssb)
		sw.pressed.connect(func(): Cfg.accent = Color(hexc); Cfg.emit_changed())
		row.add_child(sw)

	vb.add_child(_section("GRAIN / SCANLINES"))
	var grain := HSlider.new()
	grain.min_value = 0.0; grain.max_value = 1.0; grain.step = 0.1
	grain.value = Cfg.motion
	grain.custom_minimum_size = Vector2(0, 18)
	grain.value_changed.connect(func(v): Cfg.motion = v; Cfg.emit_changed())
	vb.add_child(grain)

	vb.add_child(_section("TAILLE DU TEXTE"))
	var prose := HSlider.new()
	prose.min_value = 14; prose.max_value = 22; prose.step = 1
	prose.value = Cfg.prose
	prose.custom_minimum_size = Vector2(0, 18)
	prose.value_changed.connect(func(v): Cfg.prose = int(v); Cfg.emit_changed())
	vb.add_child(prose)

	vb.add_child(_section("DIFFICULTÉ"))
	var diffs := HBoxContainer.new()
	diffs.add_theme_constant_override("separation", 6)
	vb.add_child(diffs)
	for d in ["doux", "normal", "brutal"]:
		var b := Button.new()
		b.text = d.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", FONT_MONO)
		b.add_theme_font_size_override("font_size", 8)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(1, 1, 1, 0.03)
		bsb.set_corner_radius_all(6)
		bsb.set_border_width_all(1)
		bsb.border_color = Pal.ACCENT if Cfg.difficulty == d else Pal.LINE
		bsb.content_margin_top = 6; bsb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", bsb)
		b.add_theme_color_override("font_color", Pal.ACCENT if Cfg.difficulty == d else Pal.INK_DIM)
		var dd: String = d
		b.pressed.connect(func(): Cfg.difficulty = dd; Cfg.emit_changed(); _rebuild())
		diffs.add_child(b)

func open() -> void:
	visible = true
	_open = true
	_panel.position.x = 230
	create_tween().tween_property(_panel, "position:x", 0.0, 0.28).set_ease(Tween.EASE_OUT)

func close() -> void:
	_open = false
	var t := create_tween()
	t.tween_property(_panel, "position:x", 230.0, 0.22).set_ease(Tween.EASE_IN)
	t.finished.connect(_on_close_hidden, CONNECT_ONE_SHOT)

func _on_close_hidden() -> void: visible = false

func _rebuild() -> void:
	_panel.queue_free()
	_build()

func _lbl(t: String, s: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT_MONO)
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	return l

func _section(t: String) -> Label:
	return _lbl(t, 8, Color("#6b768c"))
