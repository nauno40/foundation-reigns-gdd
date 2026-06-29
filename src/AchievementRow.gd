@tool
class_name AchievementRow
extends PanelContainer

# Ligne de succès du codex (composant) : case cochée + nom + description.

@onready var _check: Panel = %Check
@onready var _checkmark: Label = %Checkmark
@onready var _name: Label = %AchName
@onready var _desc: Label = %AchDesc

func setup(a: Dictionary) -> void:
	if not is_node_ready():
		await ready
	var done: bool = a["done"]
	# Couleur de la case dépend de l'état done + Cfg.accent — dynamique, reste en code.
	var cs := _check.get_theme_stylebox("panel") as StyleBoxFlat
	if done:
		cs.bg_color = Cfg.accent
		cs.border_color = Cfg.accent
	else:
		cs.bg_color = Color(0, 0, 0, 0)
		cs.border_color = Pal.LINE
	_checkmark.visible = done
	_name.text = a["name"]
	_name.add_theme_color_override("font_color", Pal.INK if done else Pal.INK_DIM)
	_desc.text = a["desc"]

func _ready() -> void:
	if Engine.is_editor_hint():
		setup({"name": "Premier règne", "desc": "Survivez à votre première décision.", "done": true})
