class_name ResourceBar
extends Control

# Barre de ressource verticale du prototype :
# colonne 58px (fond, remplissage dégradé, liseré lumineux en crête, glyphe,
# pip) + label 9px en dessous. Aucune valeur numérique affichée.
# États : normal / warn (label ambre) / crit (pulse rouge) / affected
# (bordure cyan pulsée + pip + glyphe brillant).

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")

const CRITICAL_LOW  = 15
const WARNING_LOW   = 25
const WARNING_HIGH  = 75
const CRITICAL_HIGH = 85

const COL_H := 58.0
const LABEL_GAP := 6.0
const LABEL_H := 12.0

var resource_key: String = ""
var _glyph_text: String = "?"
var _label_text: String = ""
var _value: int = 50
var _affected: bool = false

var _crit_glow: float = 0.0
var _aff_glow: float = 0.0
var _crit_tween: Tween
var _aff_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(0, COL_H + LABEL_GAP + LABEL_H)

func setup(key: String, glyph: String, label_text: String) -> void:
	resource_key = key
	_glyph_text = glyph
	_label_text = label_text.to_upper()
	queue_redraw()

func update_value(value: int) -> void:
	_value = clampi(value, 0, 100)
	if _get_zone() == "crit":
		_start_crit_pulse()
	else:
		_stop_crit_pulse()
	queue_redraw()

func set_affected(a: bool) -> void:
	if a == _affected:
		return
	_affected = a
	if a:
		_start_aff_pulse()
	else:
		_stop_aff_pulse()
	queue_redraw()

func _get_zone() -> String:
	if _value < CRITICAL_LOW or _value > CRITICAL_HIGH:
		return "crit"
	if _value < WARNING_LOW or _value > WARNING_HIGH:
		return "warn"
	return ""

func _start_crit_pulse() -> void:
	if _crit_tween and _crit_tween.is_valid():
		return
	_crit_tween = create_tween().set_loops()
	_crit_tween.tween_method(_set_crit_glow, 0.0, 1.0, 0.525)
	_crit_tween.tween_method(_set_crit_glow, 1.0, 0.0, 0.525)

func _set_crit_glow(v: float) -> void:
	_crit_glow = v
	queue_redraw()

func _stop_crit_pulse() -> void:
	if _crit_tween:
		_crit_tween.kill()
		_crit_tween = null
	_crit_glow = 0.0

func _start_aff_pulse() -> void:
	_stop_aff_pulse()
	_aff_tween = create_tween().set_loops()
	_aff_tween.tween_method(_set_aff_glow, 0.35, 1.0, 0.475)
	_aff_tween.tween_method(_set_aff_glow, 1.0, 0.35, 0.475)

func _set_aff_glow(v: float) -> void:
	_aff_glow = v
	queue_redraw()

func _stop_aff_pulse() -> void:
	if _aff_tween:
		_aff_tween.kill()
		_aff_tween = null
	_aff_glow = 0.0

func _draw() -> void:
	var w := size.x
	var col_rect := Rect2(0, 0, w, COL_H)
	var fill_color := ThemeColors.resource_color(resource_key)

	# conteneur : fond + bordure (couleur selon état), coins arrondis 7
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(1)
	sb.border_color = ThemeColors.LINE_2
	if _crit_glow > 0.0:
		sb.border_color = Color(ThemeColors.DANGER.r, ThemeColors.DANGER.g, ThemeColors.DANGER.b, 0.6 * _crit_glow)
		sb.shadow_color = Color(ThemeColors.DANGER.r, ThemeColors.DANGER.g, ThemeColors.DANGER.b, 0.45 * _crit_glow)
		sb.shadow_size = int(14 * _crit_glow)
	elif _affected:
		sb.border_color = ThemeColors.ACCENT
		sb.shadow_color = Color(ThemeColors.ACCENT.r, ThemeColors.ACCENT.g, ThemeColors.ACCENT.b, 0.35 * _aff_glow)
		sb.shadow_size = int(4 + 10 * _aff_glow)
	sb.draw(get_canvas_item(), col_rect)

	# remplissage depuis le bas (dégradé couleur → 35 %)
	var pct := _value / 100.0
	var fill_h := (COL_H - 2.0) * pct
	if fill_h > 1.0:
		var top_y := COL_H - 1.0 - fill_h
		var pts := PackedVector2Array([
			Vector2(1, top_y), Vector2(w - 1, top_y),
			Vector2(w - 1, COL_H - 1), Vector2(1, COL_H - 1),
		])
		var c_top := fill_color
		var c_bot := Color(fill_color.r, fill_color.g, fill_color.b, 0.35)
		draw_polygon(pts, PackedColorArray([c_top, c_top, c_bot, c_bot]))
		# crête lumineuse 2px
		draw_rect(Rect2(1, top_y, w - 2, 2.0), fill_color.lightened(0.25))
		draw_rect(Rect2(1, top_y - 1.5, w - 2, 1.5),
			Color(fill_color.r, fill_color.g, fill_color.b, 0.35))

	# glyphe centré en haut de colonne
	var font: Font = FONT_MONO
	var glyph_color := Color(1, 1, 1, 0.55)
	if _affected:
		glyph_color = Color(0.918, 0.988, 1.0, 1.0)
	var gw := font.get_string_size(_glyph_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
	draw_string(font, Vector2((w - gw) / 2.0, 16), _glyph_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, glyph_color)

	# pip cyan (affected)
	if _affected:
		draw_circle(Vector2(w - 7.5, 6.5), 2.5, ThemeColors.ACCENT)
		draw_circle(Vector2(w - 7.5, 6.5), 4.0,
			Color(ThemeColors.ACCENT.r, ThemeColors.ACCENT.g, ThemeColors.ACCENT.b, 0.25 + 0.25 * _aff_glow))

	# label sous la colonne
	var label_color := ThemeColors.INK_FAINT
	match _get_zone():
		"crit": label_color = ThemeColors.DANGER
		"warn": label_color = ThemeColors.AMBER
	if _affected:
		label_color = ThemeColors.ACCENT
	var lw := font.get_string_size(_label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9).x
	draw_string(font, Vector2((w - lw) / 2.0, COL_H + LABEL_GAP + 9.0), _label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, label_color)
