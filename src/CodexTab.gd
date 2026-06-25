@tool
class_name CodexTab
extends VBoxContainer

# Onglet du codex (composant) : icône + label + soulignement, cliquable.

signal tab_pressed

@onready var _icon: TextureRect = %TabIcon
@onready var _label: Label = %TabLabel
@onready var _underline: ColorRect = %TabUnderline

func setup(tex: Texture2D, text: String) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = tex
	_label.text = text

func set_active(on: bool) -> void:
	var col: Color = Cfg.accent if on else Pal.INK_DIM
	_label.add_theme_color_override("font_color", col)
	_icon.modulate = col
	_underline.visible = on
	_underline.color = Cfg.accent

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tab_pressed.emit()

func _ready() -> void:
	if Engine.is_editor_hint():
		setup(preload("res://assets/icons/tab_chars.svg"), "PERSONNAGES")
