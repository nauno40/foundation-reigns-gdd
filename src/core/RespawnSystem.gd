class_name RespawnSystem

const ERA_STARTS = [
	{"start": 1,   "era": "hardin"},
	{"start": 80,  "era": "merchants"},
	{"start": 200, "era": "mallow"},
	{"start": 290, "era": "mulet"},
	{"start": 350, "era": "restoration"},
	{"start": 600, "era": "late_empire"},
]

const LEGITIMACY_AFTER_NATURAL  = 100
const LEGITIMACY_AFTER_RESOURCE = 80
const LEGITIMACY_AFTER_EXPOSED  = 50

var _ctx: Context

func _init(ctx: Context) -> void:
	_ctx = ctx

func get_era_start_year(current_year: int) -> int:
	var era_start = 1
	for era in ERA_STARTS:
		if current_year >= era["start"]:
			era_start = era["start"]
		else:
			break
	return era_start

# Ramène les types de mort détaillés (ex: "military_hi", "legitimacy")
# vers les 3 catégories canoniques : natural / resource / exposed.
static func normalize_death_type(death_type: String) -> String:
	match death_type:
		"natural", "resource", "exposed":
			return death_type
		"legitimacy":
			return "exposed"
		_:
			return "resource"

func respawn(death_type: String) -> void:
	death_type = normalize_death_type(death_type)
	var current_year: int = _ctx.get_var("year", 1)
	var era_start: int = get_era_start_year(current_year)

	_ctx.empty_non_keep()

	_ctx.set_var("year", era_start, true)

	for resource in Context.RESOURCES:
		_ctx.set_var(resource, Context.RESOURCE_DEFAULT)

	var legitimacy: int
	match death_type:
		"natural":   legitimacy = LEGITIMACY_AFTER_NATURAL
		"resource":  legitimacy = LEGITIMACY_AFTER_RESOURCE
		"exposed":   legitimacy = LEGITIMACY_AFTER_EXPOSED
		_:           legitimacy = LEGITIMACY_AFTER_RESOURCE
	_ctx.set_var("legitimacy", legitimacy)

	_ctx.set_var("turns", 0)
	_ctx.set_var("mood", "neutral")
	_ctx.set_var("age", 35 + randi() % 6)
