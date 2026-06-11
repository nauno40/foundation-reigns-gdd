class_name FrameFit
extends PanelContainer

# Cadre de jeu portrait du prototype : max 460×920, centré dans la fenêtre.
# Plein écran sur mobile (coins droits) ; détouré avec coins arrondis et
# marge verticale quand la fenêtre est plus large (desktop).

const MAX_W := 460.0
const MAX_H := 920.0
const DESKTOP_MARGIN_V := 36.0

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var bordered: bool = vp.x > MAX_W + 24.0
	var h: float = min(vp.y, MAX_H)
	if bordered:
		h = min(vp.y - DESKTOP_MARGIN_V, MAX_H)
	size = Vector2(min(vp.x, MAX_W), h)
	position = ((vp - size) / 2.0).floor()

	var sb := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb:
		var radius := 18 if bordered else 0
		sb.corner_radius_top_left = radius
		sb.corner_radius_top_right = radius
		sb.corner_radius_bottom_left = radius
		sb.corner_radius_bottom_right = radius
		add_theme_stylebox_override("panel", sb)
