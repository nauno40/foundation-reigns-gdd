class_name GlowDot
extends Control

# Point coloré avec halo (mood, planètes…)

@export var color: Color = Color("#7d8aa3"):
	set(value):
		color = value
		queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0
	draw_circle(c, r * 2.2, Color(color.r, color.g, color.b, 0.18))
	draw_circle(c, r * 1.5, Color(color.r, color.g, color.b, 0.30))
	draw_circle(c, r, color)
