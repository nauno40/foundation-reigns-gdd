class_name ResourceBar
extends VBoxContainer

const ThemeColors = preload("res://src/ui/ThemeColors.gd")

const CRITICAL_LOW  = 15
const WARNING_LOW   = 25
const WARNING_HIGH  = 75
const CRITICAL_HIGH = 85

var resource_key: String = ""
var _value: int = 50
var _affected: bool = false

var _crit_glow: float = 0.0
var _aff_glow: float = 0.0
var _crit_tween: Tween
var _aff_tween: Tween

@onready var _glyph: Label = $Glyph
@onready var _label: Label = $Label

func setup(key: String, glyph: String, label_text: String) -> void:
	resource_key = key
	_glyph.text = glyph
	_label.text = label_text

func update_value(value: int) -> void:
	_value = clampi(value, 0, 100)
	_update_visual_state()
	queue_redraw()

func set_affected(a: bool) -> void:
	_affected = a
	if a:
		_start_aff_pulse()
	else:
		_stop_aff_pulse()

func _update_visual_state() -> void:
	_label.remove_theme_color_override("font_color")
	if _get_zone() == "crit":
		_label.add_theme_color_override("font_color", ThemeColors.DANGER)
		_start_crit_pulse()
	elif _get_zone() == "warn":
		_label.add_theme_color_override("font_color", ThemeColors.AMBER)
		_stop_crit_pulse()
	else:
		_stop_crit_pulse()

func _get_zone() -> String:
	if _value < CRITICAL_LOW or _value > CRITICAL_HIGH:
		return "crit"
	if _value < WARNING_LOW or _value > WARNING_HIGH:
		return "warn"
	return ""

func _start_crit_pulse() -> void:
	_stop_crit_pulse()
	_crit_tween = create_tween().set_loops()
	_crit_tween.tween_method(func(v): _crit_glow = v; queue_redraw(), 0.0, 1.0, 0.525)
	_crit_tween.tween_method(func(v): _crit_glow = v; queue_redraw(), 1.0, 0.0, 0.525)

func _stop_crit_pulse() -> void:
	if _crit_tween:
		_crit_tween.kill()
		_crit_tween = null
	_crit_glow = 0.0
	queue_redraw()

func _start_aff_pulse() -> void:
	_stop_aff_pulse()
	_aff_tween = create_tween().set_loops()
	_aff_tween.tween_method(func(v): _aff_glow = v; queue_redraw(), 0.0, 1.0, 0.475)
	_aff_tween.tween_method(func(v): _aff_glow = v; queue_redraw(), 1.0, 0.0, 0.475)

func _stop_aff_pulse() -> void:
	if _aff_tween:
		_aff_tween.kill()
		_aff_tween = null
	_aff_glow = 0.0
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var bar_h = 58.0
	var bar_y = 0.0

	var fill_pct = _value / 100.0
	var fill_h = (bar_h - 4.0) * fill_pct
	var fill_color = ThemeColors.resource_color(resource_key)

	# Background
	draw_rect(Rect2(0, bar_y, w, bar_h), Color(0.02, 0.04, 0.08, 0.7))
	# Subtle bg border
	var base_border = Color(0.471, 0.588, 0.745, 0.08)
	draw_rect(Rect2(0, bar_y, w, bar_h), base_border, false, 1.0)

	# Fill
	if fill_h > 0:
		draw_rect(Rect2(2, bar_y + bar_h - 2 - fill_h, w - 4, fill_h), fill_color)
		var highlight = fill_color.lightened(0.3)
		draw_rect(Rect2(2, bar_y + bar_h - 2 - fill_h, w - 4, 2), highlight)

	# Crit pulse (border glow)
	if _crit_glow > 0.0:
		var glow = Color(0.851, 0.416, 0.353, _crit_glow * 0.6)
		var bw = 1.0 + _crit_glow * 2.0
		draw_rect(Rect2(0, bar_y, w, bar_h), glow, false, bw)

	# Aff pulse (border + glyph glow)
	if _aff_glow > 0.0:
		var glow = Color(0.310, 0.839, 0.910, _aff_glow * 0.7)
		var bw = 1.0 + _aff_glow * 2.0
		draw_rect(Rect2(0, bar_y, w, bar_h), glow, false, bw)
		_glyph.modulate = Color(0.922, 0.988, 1.0, 0.5 + _aff_glow * 0.5)
	else:
		_glyph.modulate = Color(1, 1, 1, 0.55)
