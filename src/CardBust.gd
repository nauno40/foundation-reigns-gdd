class_name CardBust
extends Control

# Buste plat « sans visage » (port de .bust2) : épaules en dôme + tête + initiales.

const FONT_MONO_BOLD = preload("res://assets/fonts/SpaceMono-Bold.ttf")

var _sh: Color = Color(0.5, 0.55, 0.6)
var _hd: Color = Color(0.6, 0.65, 0.7)
var _ini: String = ""

func set_tone(tone: Color) -> void:
	_sh = Data.lighten(tone, 0.42)
	_hd = Data.lighten(tone, 0.5)
	queue_redraw()

func set_initials(t: String) -> void:
	_ini = t
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0: return
	var sh_h := h * 0.58
	var sh_top := h - sh_h
	var rx := w * 0.5
	var ry := sh_h
	var pts := PackedVector2Array()
	for i in range(41):
		var a := PI + float(i) / 40.0 * PI
		pts.append(Vector2(w * 0.5 + cos(a) * rx, sh_top + ry + sin(a) * ry))
	pts.append(Vector2(w, h))
	pts.append(Vector2(0.0, h))
	var cols := PackedColorArray()
	for _i in range(pts.size()): cols.append(_sh)
	draw_polygon(pts, cols)

	var head_r := w * 0.25
	var head_c := Vector2(w * 0.5, h - h * 0.42 - head_r)
	draw_circle(head_c, head_r, _hd)
	if _ini != "":
		var fs := int(clampf(w * 0.18, 16.0, 26.0))
		var ts := FONT_MONO_BOLD.get_string_size(_ini, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(FONT_MONO_BOLD, head_c + Vector2(-ts.x * 0.5, fs * 0.36), _ini,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.32))
