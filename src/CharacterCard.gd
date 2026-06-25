@tool
class_name CharacterCard
extends VBoxContainer

# Cellule personnage du codex (composant). setup(c) peuple depuis les données.

@onready var _card: Panel = %Card
@onready var _grid: ColorRect = %Grid
@onready var _bust: CardBust = %Bust
@onready var _unknown: CenterContainer = %Unknown
@onready var _star: Label = %Star
@onready var _name: Label = %CharName
@onready var _tag: Label = %CharTag

func _ready() -> void:
	_card.resized.connect(_square)
	_grid.resized.connect(func(): (_grid.material as ShaderMaterial).set_shader_parameter("rect_size", _grid.size))
	if Engine.is_editor_hint():
		setup({"id": "hari", "name": "Hari Seldon", "tag": "Fondateur du Plan", "met": true, "key": true})

func _square() -> void:
	if not is_equal_approx(_card.custom_minimum_size.y, _card.size.x):
		_card.custom_minimum_size.y = _card.size.x

func setup(c: Dictionary) -> void:
	if not is_node_ready():
		await ready
	var met: bool = c["met"]
	var key: bool = c.get("key", false)
	(_card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Data.tone_for(c["id"]) if met else Color("#10151f")
	_grid.visible = met
	_bust.visible = met
	_unknown.visible = not met
	_star.visible = key
	if met:
		_bust.set_tone(Data.tone_for(c["id"]))
		_bust.set_initials(Data.initials(c["name"]))
	_name.text = c["name"] if met or key else "Inconnu"
	_name.add_theme_color_override("font_color", Pal.INK if met else Color("#5d6b82"))
	_tag.text = str(c["tag"]).to_upper()
	_tag.add_theme_color_override("font_color", Cfg.accent if met else Color("#4d586e"))
