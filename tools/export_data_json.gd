extends SceneTree

# Script jetable (one-shot) : exporte les données de Data.gd en JSON.
# Échappement sûr via JSON.stringify. Lancer en headless :
#   godot --headless -s res://tools/export_data_json.gd
# Puis supprimer ce fichier.

func _init() -> void:
	_save("res://data/cards.json", Data._DECK_RAW)
	_save("res://data/characters.json", Data._CHARACTERS_RAW)
	_save("res://data/planets.json", Data._PLANETS_RAW)
	_save("res://data/covers.json", Data.COVERS)
	_save("res://data/deck_unlocks.json", Data.DECK_UNLOCKS)
	_save("res://data/achievements.json", Data.ACHIEVEMENTS)
	_save("res://data/seldon_messages.json", Data.SELDON_MESSAGES)
	print("Export JSON terminé.")
	quit()

func _save(path: String, value) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Écriture impossible : " + path)
		return
	f.store_string(JSON.stringify(value, "\t"))
	f.close()
	print("écrit ", path)
