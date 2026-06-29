@tool
class_name PlanetInfo
extends PanelContainer

# Panneau d'info planète du codex (composant) : placeholder ou détail (nom/état/faction/note).

@onready var _empty: Label = %Empty
@onready var _filled: VBoxContainer = %Filled
@onready var _name: Label = %PName
@onready var _state: Label = %PState
@onready var _faction: Label = %PFaction
@onready var _note: Label = %PNote

func setup(p: PlanetData) -> void:
	if not is_node_ready():
		await ready
	if p == null:
		_empty.visible = true
		_filled.visible = false
		return
	_empty.visible = false
	_filled.visible = true
	_name.text = p.name + (" ◆" if p.base else "")
	_state.text = Data.state_label(p.state).to_upper()
	_state.add_theme_color_override("font_color", Data.state_color(p.state))
	_faction.text = p.faction.to_upper() + (" · CACHÉE" if p.hidden else "")
	_faction.add_theme_color_override("font_color", Cfg.accent)
	_note.text = p.note

func _ready() -> void:
	if Engine.is_editor_hint():
		var demo := PlanetData.new()
		demo.name = "Terminus"; demo.base = true; demo.state = 1
		demo.faction = "Fondation"; demo.hidden = false
		demo.note = "Le cœur du Plan, à la périphérie de la Galaxie."
		setup(demo)
