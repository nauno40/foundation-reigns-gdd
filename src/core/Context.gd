class_name Context

const RESOURCES = ["military", "religion", "commerce", "politics"]
const RESOURCE_DEFAULT = 50
const LEGITIMACY_DEFAULT = 100

var _vars: Dictionary = {}
var _keep_flags: Dictionary = {}

func get_var(key: String, default = 0) -> Variant:
	return _vars.get(key, default)

func set_var(key: String, value: Variant, to_keep: bool = false) -> void:
	_vars[key] = value
	if to_keep:
		_keep_flags[key] = true

func add_var(key: String, delta: int) -> void:
	_vars[key] = _vars.get(key, 0) + delta

func empty_non_keep() -> void:
	var kept: Dictionary = {}
	for key in _keep_flags:
		if _vars.has(key):
			kept[key] = _vars[key]
	_vars = kept

func initialize_new_reign(legitimacy_start: int = LEGITIMACY_DEFAULT) -> void:
	empty_non_keep()
	for resource in RESOURCES:
		_vars[resource] = RESOURCE_DEFAULT
	_vars["legitimacy"] = legitimacy_start
	_vars["turns"] = 0
	_vars["mood"] = "neutral"

func apply_cover(cover: Dictionary) -> void:
	var resource: String = cover.get("bonus_resource", "")
	var bonus: int = cover.get("bonus_value", 0)
	if resource in RESOURCES and bonus != 0:
		add_var(resource, bonus)

func is_game_over() -> bool:
	for resource in RESOURCES:
		var val = _vars.get(resource, RESOURCE_DEFAULT)
		if val <= 0 or val >= 100:
			return true
	if _vars.get("legitimacy", LEGITIMACY_DEFAULT) <= 0:
		return true
	if _vars.get("planet_terminus_state", 1) <= 0:
		return true
	return false

func get_game_over_reason() -> String:
	for resource in RESOURCES:
		var val = _vars.get(resource, RESOURCE_DEFAULT)
		if val <= 0:
			return "%s reached 0" % resource
		if val >= 100:
			return "%s reached 100" % resource
	if _vars.get("legitimacy", LEGITIMACY_DEFAULT) <= 0:
		return "legitimacy reached 0"
	if _vars.get("planet_terminus_state", 1) <= 0:
		return "terminus lost"
	return ""
