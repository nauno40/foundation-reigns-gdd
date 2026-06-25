class_name Gauge
extends Control

# Jauge icône-masque (port de ResIcon / .ricon dans app.jsx).

const GAUGE_SHADER = preload("res://assets/shaders/gauge_fill.gdshader")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const ICONS := {
	"military": preload("res://assets/icons/military.svg"),
	"religion": preload("res://assets/icons/religion.svg"),
	"commerce": preload("res://assets/icons/commerce.svg"),
	"politics": preload("res://assets/icons/politics.svg"),
}
const GLYPH := 46.0
const BASE_NORMAL := Color(0.235, 0.282, 0.376)   # #3c4860
const BASE_AFF := Color(0.490, 0.565, 0.659)      # #7d90a8
const UP := Color("#5fcf8f")
const DOWN := Color("#d96a5a")

var _key := ""
var _value := 50
var _display := 50.0
var _affected := false
var _delta: Label
var _glow: TextureRect
var _flash: TextureRect
var _icon: TextureRect
var _lab: Label
var _mat: ShaderMaterial
var _vt: Tween
var _gt: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 72)

func setup(key: String, label: String) -> void:
	_key = key
	if get_child_count() == 0:
		_build()
	_lab.text = label.to_upper()
	var tex: Texture2D = ICONS.get(key)
	_icon.texture = tex
	_glow.texture = tex
	_flash.texture = tex
	_mat.set_shader_parameter("res_color", Pal.res_color(key))
	_refresh()

func _build() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	_delta = Label.new()
	_delta.add_theme_font_override("font", FONT_MONO)
	_delta.add_theme_font_size_override("font_size", 11)
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delta.custom_minimum_size = Vector2(0, 13)
	_delta.modulate.a = 0.0
	vb.add_child(_delta)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(center)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(GLYPH, GLYPH)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(glyph)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _layer(glyph, add_mat)
	_glow.modulate.a = 0.0
	_flash = _layer(glyph, add_mat)
	_flash.modulate.a = 0.0
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = GAUGE_SHADER
	_mat.set_shader_parameter("fill", 0.5)
	_mat.set_shader_parameter("base_color", BASE_NORMAL)
	_icon.material = _mat
	glyph.add_child(_icon)

	_lab = Label.new()
	var labf := FontVariation.new()
	labf.base_font = FONT_MONO
	labf.spacing_glyph = 1
	_lab.add_theme_font_override("font", labf)
	_lab.add_theme_font_size_override("font_size", 8)
	_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_lab)

func _layer(glyph: Control, mat: CanvasItemMaterial) -> TextureRect:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.pivot_offset = Vector2(GLYPH, GLYPH) * 0.5
	tr.scale = Vector2(1.32, 1.32)
	tr.material = mat
	glyph.add_child(tr)
	return tr

func set_value(v: int) -> void:
	var target := clampi(v, 0, 100)
	if target != _value:
		_flash_delta(signi(target - _value))
	if _vt and _vt.is_valid(): _vt.kill()
	_vt = create_tween()
	_vt.tween_method(func(x): _display = x; _mat.set_shader_parameter("fill", x / 100.0),
		_display, float(target), 0.55).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_value = target
	_refresh()

func set_affected(a: bool) -> void:
	if a == _affected: return
	_affected = a
	_mat.set_shader_parameter("base_color", BASE_AFF if a else BASE_NORMAL)
	_refresh()

func _zone() -> String:
	if _value < 15 or _value > 85: return "crit"
	if _value < 25 or _value > 75: return "warn"
	return ""

func refresh() -> void:
	_refresh()

func _refresh() -> void:
	if not _glow: return
	var zone := _zone()
	var lc := Color("#aab5c8")
	var gc := Color.TRANSPARENT
	var pulse := false
	if _affected:
		gc = Cfg.accent; lc = Cfg.accent
	elif zone == "crit":
		gc = Pal.DANGER; lc = Pal.DANGER; pulse = true
	elif zone == "warn":
		gc = Pal.AMBER; lc = Pal.AMBER
	_lab.add_theme_color_override("font_color", lc)
	if _gt and _gt.is_valid(): _gt.kill()
	if gc == Color.TRANSPARENT:
		_glow.modulate = Color(1, 1, 1, 0.0)
		return
	_glow.modulate = Color(gc.r, gc.g, gc.b, 0.55)
	if pulse:
		_gt = create_tween().set_loops()
		_gt.tween_method(func(al): _glow.modulate = Color(gc.r, gc.g, gc.b, al), 0.32, 0.7, 0.525)
		_gt.tween_method(func(al): _glow.modulate = Color(gc.r, gc.g, gc.b, al), 0.7, 0.32, 0.525)

func _flash_delta(sign: int) -> void:
	var up := sign >= 0
	var c := UP if up else DOWN
	_delta.text = "▲" if up else "▼"
	_delta.add_theme_color_override("font_color", c)
	_delta.modulate.a = 0.0
	_delta.position.y = 4.0
	var t := create_tween()
	t.set_parallel()
	t.tween_property(_delta, "modulate:a", 1.0, 0.2)
	t.tween_property(_delta, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.4)
	t.chain().tween_property(_delta, "modulate:a", 0.0, 0.3)
	_flash.modulate = Color(c.r, c.g, c.b, 0.0)
	var f := create_tween()
	f.tween_property(_flash, "modulate:a", 0.85, 0.18)
	f.tween_property(_flash, "modulate:a", 0.0, 0.55)
