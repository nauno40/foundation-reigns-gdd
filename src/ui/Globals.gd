extends Node

enum StartMode { NONE, NEW_GAME, CONTINUE }

var start_mode = StartMode.NONE
var dev_deck = ""
var difficulty = "normal"
var anim_gallery = false  # --anim : ouvre la galerie d'animations (outil de dev)
var music_vol: float = 0.7
var sfx_vol: float = 0.7

const CONFIG_PATH = "user://foundation_config.json"

func _ready() -> void:
	_load_config()
	var args = OS.get_cmdline_args()
	var i = 0
	while i < args.size():
		match args[i]:
			"--deck":
				if i + 1 < args.size():
					dev_deck = args[i + 1]
					start_mode = StartMode.NEW_GAME
					i += 1
			"--difficulty":
				if i + 1 < args.size():
					var d = args[i + 1]
					if d in ["doux", "normal", "brutal"]:
						difficulty = d
					i += 1
			"--anim":
				anim_gallery = true
		i += 1

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	if data.has("difficulty") and data.difficulty in ["doux", "normal", "brutal"]:
		difficulty = data.difficulty
	music_vol = data.get("music_vol", music_vol)
	sfx_vol = data.get("sfx_vol", sfx_vol)

func save_config() -> void:
	var data = {
		"difficulty": difficulty,
		"music_vol": music_vol,
		"sfx_vol": sfx_vol,
	}
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
