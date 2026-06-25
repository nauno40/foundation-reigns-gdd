class_name CardBust
extends Control

# Buste plat « sans visage » du nouveau template (app.jsx .bust2) :
# épaules en dôme + tête circulaire, teintées d'après la couleur de la carte.
# set_tone() fixe les couleurs (lighten(tone,.42) épaules, lighten(tone,.5) tête).

const FONT_MONO_BOLD = preload("res://assets/fonts/SpaceMono-Bold.ttf")

var _sh_color: Color = Color(0.5, 0.55, 0.6)
var _hd_color: Color = Color(0.6, 0.65, 0.7)
var _initials: String = ""

func set_tone(tone: Color) -> void:
	_sh_color = CardUtils.lighten(tone, 0.42)
	_hd_color = CardUtils.lighten(tone, 0.5)
	queue_redraw()

func set_initials(text: String) -> void:
	_initials = text
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# épaules : dôme (demi-ellipse rx=w/2, ry=sh_h) à fond plat, hauteur 58 %
	var sh_h := h * 0.58
	var sh_top := h - sh_h
	var rx := w * 0.5
	var ry := sh_h
	var steps := 40
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var a := PI + float(i) / steps * PI   # demi-tour supérieur
		pts.append(Vector2(w * 0.5 + cos(a) * rx, sh_top + ry + sin(a) * ry))
	pts.append(Vector2(w, h))
	pts.append(Vector2(0.0, h))
	var cols := PackedColorArray()
	for _i in range(pts.size()):
		cols.append(_sh_color)
	draw_polygon(pts, cols)

	# tête : cercle (diamètre 50 % de la largeur), bas de tête à 42 % du bas
	var head_r := w * 0.25
	var head_cy := h - h * 0.42 - head_r
	var head_c := Vector2(w * 0.5, head_cy)
	draw_circle(head_c, head_r, _hd_color)

	# initiales gravées sur la tête (opacité .32)
	if _initials != "":
		var fs := int(clampf(w * 0.18, 16.0, 26.0))
		var ts := FONT_MONO_BOLD.get_string_size(_initials, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos := head_c + Vector2(-ts.x * 0.5, fs * 0.36)
		draw_string(FONT_MONO_BOLD, pos, _initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, 0.32))
