@tool
class_name DeckChip
extends PanelContainer

# Puce de deck du codex (composant) : nom + ère (grisée si verrouillé).

@onready var _name: Label = %DeckName
@onready var _era: Label = %DeckEra

func setup(d: Dictionary, locked: bool) -> void:
	if not is_node_ready():
		await ready
	modulate.a = 0.4 if locked else 1.0
	_name.text = d["name"]
	_era.text = d["era"] + (" 🔒" if locked else "")

func _ready() -> void:
	if Engine.is_editor_hint():
		setup({"name": "Église de la Science", "era": "Ère Hardin"}, false)
