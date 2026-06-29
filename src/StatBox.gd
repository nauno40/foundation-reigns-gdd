@tool
class_name StatBox
extends PanelContainer

# Case statistique de l'écran de mort (composant) : titre + valeur.

@onready var _title: Label = %StatTitle
@onready var _value: Label = %StatValue

func setup(title: String, value: String) -> void:
	if not is_node_ready():
		await ready
	_title.text = title
	_value.text = value

func _ready() -> void:
	if Engine.is_editor_hint():
		setup("SCORE DU RÈGNE", "108 pts")
