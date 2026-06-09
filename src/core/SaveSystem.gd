class_name SaveSystem

const SAVE_PATH = "user://foundation_save.json"

func save(ctx: Context) -> bool:
	var data = {
		"vars": ctx._vars.duplicate(),
		"keep_flags": ctx._keep_flags.duplicate(),
		"version": 1
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveSystem: cannot write to %s" % SAVE_PATH)
		return false
	file.store_string(json_string)
	return true

func load(ctx: Context) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	if not data is Dictionary:
		push_error("SaveSystem: corrupt save file")
		return false
	ctx._vars = data.get("vars", {})
	ctx._keep_flags = data.get("keep_flags", {})
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
