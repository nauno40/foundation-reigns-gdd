class_name ResourceBar
extends Control

# Jauge « icône-masque » du nouveau template (app.jsx) :
# l'icône (épée/atome/pièces/colonnes) se remplit par le bas via le shader
# gauge_fill ; graduations 25/50/75 gravées + ligne de niveau lumineuse.
# États : warn (ambre) / crit (rouge pulsé) / affected (cyan, pendant le drag).
# Flash directionnel ▲ vert / ▼ rouge au changement de valeur.
# API publique conservée : setup(key,label), update_value(int), set_affected(bool).

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const GAUGE_SHADER = preload("res://assets/shaders/gauge_fill.gdshader")

const ICONS := {
	"military": preload("res://assets/icons/military.svg"),
	"religion": preload("res://assets/icons/religion.svg"),
	"commerce": preload("res://assets/icons/commerce.svg"),
	"politics": preload("res://assets/icons/politics.svg"),
}

const CRITICAL_LOW  = 15
const WARNING_LOW   = 25
const WARNING_HIGH  = 75
const CRITICAL_HIGH = 85

const GLYPH_SIZE := 40.0
const BASE_NORMAL := Color(0.235, 0.282, 0.376)   # #3c4860
const BASE_AFF    := Color(0.490, 0.565, 0.659)   # #7d90a8
const FLASH_UP    := Color("#5fcf8f")
const FLASH_DOWN  := Color("#d96a5a")

var resource_key: String = ""
var _label_text: String = ""
var _value: int = 50
var _display_value: float = 50.0
var _affected: bool = false

var _vbox: VBoxContainer
var _delta: Label
var _glyph: Control
var _glow: TextureRect
var _flash_glow: TextureRect
var _icon: TextureRect
var _name_label: Label
var _mat: ShaderMaterial

var _value_tween: Tween
var _glow_tween: Tween
var _delta_tween: Tween
var _flash_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 74)
	_build()

func _build() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)

	# ── delta ▲/▼ ──
	_delta = Label.new()
	_delta.add_theme_font_override("font", FONT_MONO)
	_delta.add_theme_font_size_override("font_size", 11)
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delta.custom_minimum_size = Vector2(0, 13)
	_delta.modulate.a = 0.0
	_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_delta)

	# ── glyphe (glow + flash glow + icône) ──
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(center)

	_glyph = Control.new()
	_glyph.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_glyph)

	var tex: Texture2D = ICONS.get(resource_key)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_glow = _make_layer(tex, add_mat)
	_glow.modulate.a = 0.0
	_flash_glow = _make_layer(tex, add_mat)
	_flash_glow.modulate.a = 0.0

	_icon = TextureRect.new()
	_icon.texture = tex
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = GAUGE_SHADER
	_icon.material = _mat
	_glyph.add_child(_icon)

	# ── label sous l'icône ──
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", FONT_MONO)
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_name_label)

	_apply_shader()
	_refresh_visuals()

func _make_layer(tex: Texture2D, mat: CanvasItemMaterial) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.pivot_offset = Vector2(GLYPH_SIZE, GLYPH_SIZE) * 0.5
	tr.scale = Vector2(1.32, 1.32)
	tr.material = mat
	_glyph.add_child(tr)
	return tr

func setup(key: String, label_text: String) -> void:
	resource_key = key
	_label_text = label_text.to_upper()
	if _icon:
		var tex: Texture2D = ICONS.get(key)
		_icon.texture = tex
		_glow.texture = tex
		_flash_glow.texture = tex
		_apply_shader()
		_refresh_visuals()

func _apply_shader() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("res_color", ThemeColors.resource_color(resource_key))
	_mat.set_shader_parameter("base_color", BASE_NORMAL)
	_mat.set_shader_parameter("fill", _display_value / 100.0)

func update_value(value: int) -> void:
	var target := clampi(value, 0, 100)
	if target != _value and _icon:
		_trigger_flash(signi(target - _value))
	if _value_tween and _value_tween.is_valid():
		_value_tween.kill()
	if is_inside_tree():
		# remplissage : .55s cubic-bezier(.4,0,.2,1) (= ease-in-out) comme app.jsx
		_value_tween = create_tween()
		_value_tween.tween_method(_set_display, _display_value, float(target), 0.55) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_display_value = float(target)
	_value = target
	_refresh_visuals()

func _set_display(v: float) -> void:
	_display_value = v
	if _mat:
		_mat.set_shader_parameter("fill", v / 100.0)

func set_affected(a: bool) -> void:
	if a == _affected:
		return
	_affected = a
	if _mat:
		_mat.set_shader_parameter("base_color", BASE_AFF if a else BASE_NORMAL)
	_refresh_visuals()

func _get_zone() -> String:
	if _value < CRITICAL_LOW or _value > CRITICAL_HIGH:
		return "crit"
	if _value < WARNING_LOW or _value > WARNING_HIGH:
		return "warn"
	return ""

# Met à jour glow d'état (priorité affected > crit > warn) + couleur du label.
func _refresh_visuals() -> void:
	if not _glow:
		return
	var zone := _get_zone()
	var label_color := Color("#aab5c8")
	var glow_color := Color.TRANSPARENT
	var pulse := false
	if _affected:
		glow_color = ThemeColors.ACCENT
		label_color = ThemeColors.ACCENT
	elif zone == "crit":
		glow_color = ThemeColors.DANGER
		label_color = ThemeColors.DANGER
		pulse = true
	elif zone == "warn":
		glow_color = ThemeColors.AMBER
		label_color = ThemeColors.AMBER

	_name_label.text = _label_text
	_name_label.add_theme_color_override("font_color", label_color)

	_stop_glow_pulse()
	if glow_color.a == 0.0 and not _affected and zone == "":
		_glow.modulate = Color(1, 1, 1, 0.0)
		return
	_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, 0.0 if glow_color == Color.TRANSPARENT else 0.55)
	if pulse:
		_start_glow_pulse(glow_color)

func _start_glow_pulse(c: Color) -> void:
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_method(func(a): _glow.modulate = Color(c.r, c.g, c.b, a), 0.32, 0.7, 0.525)
	_glow_tween.tween_method(func(a): _glow.modulate = Color(c.r, c.g, c.b, a), 0.7, 0.32, 0.525)

func _stop_glow_pulse() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null

# Couleur de flash selon le sens du changement (vert hausse / rouge baisse).
func flash_direction(delta_sign: int) -> Color:
	return Anim.settings.bar_flash_up if delta_sign >= 0 else Anim.settings.bar_flash_down

# Flash directionnel : ▲ vert (hausse) / ▼ rouge (baisse) + halo bref.
func _trigger_flash(delta_sign: int) -> void:
	var up := delta_sign >= 0
	var c := flash_direction(delta_sign)
	_delta.text = "▲" if up else "▼"
	_delta.add_theme_color_override("font_color", c)

	if _delta_tween and _delta_tween.is_valid():
		_delta_tween.kill()
	_delta.modulate.a = 0.0
	_delta.position.y = 4.0
	_delta_tween = create_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(_delta, "modulate:a", 1.0, 0.2)
	_delta_tween.tween_property(_delta, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_delta_tween.chain().tween_interval(0.4)
	_delta_tween.chain().tween_property(_delta, "modulate:a", 0.0, 0.3)

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_glow.modulate = Color(c.r, c.g, c.b, 0.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_glow, "modulate:a", 0.85, 0.18)
	_flash_tween.tween_property(_flash_glow, "modulate:a", 0.0, 0.55)
