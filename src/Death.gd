class_name Death
extends Control

# Écran de mort (port de app.jsx Death).

const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const FONT_SPECTRAL_IT = preload("res://assets/fonts/Spectral-Italic.ttf")
const ICONS := {
	"military": preload("res://assets/icons/military.svg"),
	"religion": preload("res://assets/icons/religion.svg"),
	"commerce": preload("res://assets/icons/commerce.svg"),
	"politics": preload("res://assets/icons/politics.svg"),
}

signal respawn_pressed

func _ready() -> void:
	visible = false

func show_death(info: Dictionary) -> void:
	for c in get_children(): c.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.035, 0.055, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 26)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 28)
	m.add_theme_constant_override("margin_bottom", 28)
	add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	m.add_child(vb)

	var cause := _lbl(info["causeLabel"].to_upper(), FONT_MONO, 9, Pal.DANGER)
	cause.add_theme_constant_override("line_spacing", 0)
	vb.add_child(cause)
	vb.add_child(_spacer(7))
	vb.add_child(_lbl(info["bearerName"], FONT_SPECTRAL, 28, Pal.INK))
	vb.add_child(_spacer(3))
	vb.add_child(_lbl(info["sub"], FONT_MONO, 10, Pal.INK_DIM))
	vb.add_child(_spacer(22))

	# transmission Seldon
	var holo := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.91, 0.714, 0.353, 0.06)
	hsb.set_corner_radius_all(12)
	hsb.set_border_width_all(1)
	hsb.border_color = Color(0.91, 0.714, 0.353, 0.32)
	hsb.content_margin_left = 18; hsb.content_margin_right = 18
	hsb.content_margin_top = 17; hsb.content_margin_bottom = 17
	holo.add_theme_stylebox_override("panel", hsb)
	vb.add_child(holo)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	holo.add_child(hv)
	hv.add_child(_lbl("☼ TRANSMISSION — HARI SELDON", FONT_MONO, 8, Pal.AMBER))
	var msg := _lbl(info["message"], FONT_SPECTRAL_IT, 16, Color("#f2e4c4"))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(msg)
	vb.add_child(_spacer(22))

	# grille 2×2 de stats
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 11)
	vb.add_child(grid)
	grid.add_child(_stat("DÉCISIONS PRISES", str(info["turns"])))
	grid.add_child(_stat("ANNÉES COUVERTES", "%d ans" % info["years"]))
	grid.add_child(_stat("SCORE DU RÈGNE", "%d pts" % info["score"]))
	grid.add_child(_stat("PLAN DE SELDON", info["deviation"]))
	vb.add_child(_spacer(22))

	# snapshot 4 ressources (icône + mini-barre)
	var snap := HBoxContainer.new()
	snap.add_theme_constant_override("separation", 9)
	vb.add_child(snap)
	for r in Data.RESOURCES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		var ic_holder := CenterContainer.new()
		ic_holder.custom_minimum_size = Vector2(0, 22)
		var ic := TextureRect.new()
		ic.texture = ICONS[r["key"]]
		ic.custom_minimum_size = Vector2(21, 21)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Pal.res_color(r["key"])
		ic_holder.add_child(ic)
		col.add_child(ic_holder)
		col.add_child(_lbl_c(r["label"].to_upper(), FONT_MONO, 8, Pal.INK_FAINT))
		var track := PanelContainer.new()
		track.custom_minimum_size = Vector2(0, 4)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(1, 1, 1, 0.08)
		tsb.set_corner_radius_all(2)
		track.add_theme_stylebox_override("panel", tsb)
		col.add_child(track)
		var holder := Control.new()
		track.add_child(holder)
		var fill := ColorRect.new()
		fill.color = Pal.res_color(r["key"])
		fill.anchor_bottom = 1.0
		fill.anchor_right = clampf(float(info["res"][r["key"]]) / 100.0, 0.0, 1.0)
		holder.add_child(fill)
		snap.add_child(col)

	vb.add_child(_spacer(0, true))

	var btn := Button.new()
	btn.text = "NOUVEAU RÈGNE →"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_override("font", FONT_MONO)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Pal.ACCENT)
	btn.add_theme_color_override("font_hover_color", Pal.ACCENT)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.31, 0.839, 0.91, 0.08)
	bsb.set_corner_radius_all(10)
	bsb.set_border_width_all(1)
	bsb.border_color = Pal.ACCENT
	btn.add_theme_stylebox_override("normal", bsb)
	var bsbh := bsb.duplicate()
	bsbh.bg_color = Color(0.31, 0.839, 0.91, 0.16)
	btn.add_theme_stylebox_override("hover", bsbh)
	btn.add_theme_stylebox_override("pressed", bsbh)
	btn.pressed.connect(func(): respawn_pressed.emit())
	vb.add_child(btn)

	visible = true
	# deathIn : flash + léger zoom
	pivot_offset = size * 0.5
	scale = Vector2(1.035, 1.035)
	modulate = Color(1.7, 1.7, 1.7)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var fk := create_tween()
	for a in [0.3, 1.0, 0.5, 1.0]:
		fk.tween_property(cause, "modulate:a", a, 0.09)

func _lbl(t: String, f: Font, s: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	return l

func _lbl_c(t: String, f: Font, s: int, c: Color) -> Label:
	var l := _lbl(t, f, s, c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _stat(label: String, value: String) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_top = 1
	sb.border_color = Pal.LINE
	sb.content_margin_top = 8
	box.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	box.add_child(vb)
	vb.add_child(_lbl(label, FONT_MONO, 9, Pal.INK_FAINT))
	vb.add_child(_lbl(value, FONT_SPECTRAL, 15, Pal.INK))
	return box

func _spacer(h: int, expand := false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	if expand: s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s
