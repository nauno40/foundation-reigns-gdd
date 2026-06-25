@tool
class_name ResSnapshot
extends VBoxContainer

# Colonne ressource du snapshot de mort (composant) : icône + label + mini-barre.

const ICONS := {
	"military": preload("res://assets/icons/military.svg"),
	"religion": preload("res://assets/icons/religion.svg"),
	"commerce": preload("res://assets/icons/commerce.svg"),
	"politics": preload("res://assets/icons/politics.svg"),
}

@onready var _icon: TextureRect = %SnapIcon
@onready var _label: Label = %SnapLabel
@onready var _fill: ColorRect = %SnapFill

func setup(key: String, label: String, value: int) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = ICONS[key]
	_icon.modulate = Pal.res_color(key)
	_label.text = label.to_upper()
	_fill.color = Pal.res_color(key)
	_fill.anchor_right = clampf(float(value) / 100.0, 0.0, 1.0)

func _ready() -> void:
	if Engine.is_editor_hint():
		setup("commerce", "Commerce", 60)
