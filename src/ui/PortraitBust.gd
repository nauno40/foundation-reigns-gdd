class_name PortraitBust
extends Control

# Buste holographique abstrait du prototype : corps en demi-capsule
# (dégradé cyan + liseré) surmonté d'une tête circulaire avec initiales.
# Taille de référence : 118×150, ancré bas-centre du portrait.

const CYAN := Color(0.310, 0.839, 0.910)

func _draw() -> void:
	var w := size.x
	var h := size.y

	# corps : demi-capsule 118×96 en bas (coins hauts arrondis r=60)
	var body_h := 96.0
	var body_top := h - body_h
	var radius := 59.0
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 24
	for i in range(steps + 1):
		var a := PI + float(i) / steps * PI  # arc supérieur gauche → droite
		points.append(Vector2(w / 2.0 + cos(a) * radius, body_top + radius + sin(a) * radius))
	points.append(Vector2(w / 2.0 + radius, h))
	points.append(Vector2(w / 2.0 - radius, h))
	for p in points:
		var t: float = clamp((p.y - body_top) / body_h, 0.0, 1.0)
		colors.append(Color(CYAN.r, CYAN.g, CYAN.b, lerp(0.22, 0.04, t)))
	draw_polygon(points, colors)
	# liseré du corps
	var outline := points.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color(CYAN.r, CYAN.g, CYAN.b, 0.32), 1.0, true)

	# tête : cercle 62px centré, bas de tête à 54px du bas
	var head_r := 31.0
	var head_c := Vector2(w / 2.0, h - 54.0 - head_r)
	draw_circle(head_c, head_r, Color(0.02, 0.035, 0.07, 0.85))
	draw_circle(head_c, head_r, Color(CYAN.r, CYAN.g, CYAN.b, 0.10))
	draw_circle(head_c + Vector2(0, -head_r * 0.30), head_r * 0.55, Color(CYAN.r, CYAN.g, CYAN.b, 0.20))
	draw_arc(head_c, head_r, 0.0, TAU, 48, Color(CYAN.r, CYAN.g, CYAN.b, 0.40), 1.0, true)
