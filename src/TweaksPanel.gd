class_name TweaksPanel
extends Control

# Panneau de réglages (port du Tweaks de app.jsx) : accent, grain, taille texte,
# difficulté. Structure statique dans TweaksPanel.tscn ; ce script ne construit que
# le contenu dynamique (swatches, sliders, boutons). Écrit dans Cfg et émet Cfg.changed.

const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const ACCENTS := ["#4fd6e8", "#e8b65a", "#b98ad6", "#5fcf8f"]

var _open := false
@onready var _panel: PanelContainer = %Panel
@onready var _dynamic: VBoxContainer = %Dynamic

func _ready() -> void:
	visible = false
	%CloseBtn.pressed.connect(close)
	_build_dynamic()

# Construit les réglages dynamiques dans le conteneur %Dynamic.
func _build_dynamic() -> void:
	_dynamic.add_child(_section("ACCENT HOLO"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_dynamic.add_child(row)
	for hexc in ACCENTS:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(34, 26)
		sw.focus_mode = Control.FOCUS_NONE
		# StyleBox dynamique : une couleur par accent (ACCENTS) — non extractible en
		# un seul .tres, reste construit en code.
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(hexc)
		ssb.set_corner_radius_all(6)
		sw.add_theme_stylebox_override("normal", ssb)
		sw.add_theme_stylebox_override("hover", ssb)
		sw.add_theme_stylebox_override("pressed", ssb)
		sw.pressed.connect(func(): Cfg.accent = Color(hexc); Cfg.emit_changed())
		row.add_child(sw)

	_dynamic.add_child(_section("GRAIN / SCANLINES"))
	var grain := HSlider.new()
	grain.min_value = 0.0; grain.max_value = 1.0; grain.step = 0.1
	grain.value = Cfg.motion
	grain.custom_minimum_size = Vector2(0, 18)
	grain.value_changed.connect(func(v): Cfg.motion = v; Cfg.emit_changed())
	_dynamic.add_child(grain)

	_dynamic.add_child(_section("TAILLE DU TEXTE"))
	var prose := HSlider.new()
	prose.min_value = 14; prose.max_value = 22; prose.step = 1
	prose.value = Cfg.prose
	prose.custom_minimum_size = Vector2(0, 18)
	prose.value_changed.connect(func(v): Cfg.prose = int(v); Cfg.emit_changed())
	_dynamic.add_child(prose)

	_dynamic.add_child(_section("DIFFICULTÉ"))
	var diffs := HBoxContainer.new()
	diffs.add_theme_constant_override("separation", 6)
	_dynamic.add_child(diffs)
	for d in ["doux", "normal", "brutal"]:
		var b := Button.new()
		b.text = d.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", FONT_MONO)
		b.add_theme_font_size_override("font_size", 8)
		# StyleBox semi-dynamique : la bordure/couleur dépend de la difficulté
		# sélectionnée (Cfg.difficulty) — reste en code.
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

# Reconstruit uniquement le contenu dynamique (la structure statique reste intacte).
func _rebuild() -> void:
	for c in _dynamic.get_children(): c.queue_free()
	_build_dynamic()

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT_MONO)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color("#6b768c"))
	return l
