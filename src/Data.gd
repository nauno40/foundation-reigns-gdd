class_name Data

# Portage fidèle des données du prototype (reference/UI Nouvelle version/data.jsx
# + constantes de app.jsx). Ère Hardin, mini-moteur de démo.

const RESOURCES := [
	{"key": "military", "label": "Militaire"},
	{"key": "religion", "label": "Religion"},
	{"key": "commerce", "label": "Commerce"},
	{"key": "politics", "label": "Politique"},
]

const MOODS := {
	"neutral":    {"label": "Neutre",     "dot": "#7d8aa3"},
	"suspicious": {"label": "Méfiant",    "dot": "#e0a64f"},
	"afraid":     {"label": "Effrayé",    "dot": "#7fb4d8"},
	"angry":      {"label": "En colère",  "dot": "#d96a5a"},
	"flattered":  {"label": "Flatté",     "dot": "#b98ad6"},
	"curious":    {"label": "Curieux",    "dot": "#4fd6e8"},
	"sad":        {"label": "Affligé",    "dot": "#8693a8"},
	"desperate":  {"label": "Désespéré",  "dot": "#c8505a"},
}

# Messages de Seldon (mort) — éditables dans data/seldon_messages.json.
static var SELDON_MESSAGES: Dictionary = _load_json_dict("res://data/seldon_messages.json")

# Couvertures — éditables dans data/covers.json.
static var COVERS: Array = _load_json("res://data/covers.json")

const DIFF := {"doux": 0.7, "normal": 1.0, "brutal": 1.45}

# Decks qui s'activent par progression du règne — éditables dans data/deck_unlocks.json.
static var DECK_UNLOCKS: Array = _load_json("res://data/deck_unlocks.json")

const TONES := [
	Color("#1c3a3b"), Color("#22332a"), Color("#3a2731"), Color("#26303f"),
	Color("#33291f"), Color("#2a2740"), Color("#203636"), Color("#352230"),
]

# Succès — éditables dans data/achievements.json.
static var ACHIEVEMENTS: Array = _load_json("res://data/achievements.json")

const DECKS_META := [
	{"name": "Ambiant",              "era": "Permanent",  "unlocked": true},
	{"name": "Nouveau Speaker",      "era": "Permanent",  "unlocked": true},
	{"name": "Ère Hardin",           "era": "Ans 1–80",   "unlocked": true},
	{"name": "Église de la Science", "era": "Ans 50–200", "unlocked": true},
	{"name": "Menace Anacréon",      "era": "Ans 1–150",  "unlocked": true},
	{"name": "Ère des Marchands",    "era": "Ans 80–250", "unlocked": false},
	{"name": "Ère Mallow",           "era": "Ans 200–350","unlocked": false},
	{"name": "Le Mulet",             "era": "Ans 290–380","unlocked": false},
	{"name": "Restauration",         "era": "Ans 350–600","unlocked": false},
	{"name": "Second Empire",        "era": "Ans 600+",   "unlocked": false},
]

static func state_color(s: int) -> Color:
	match s:
		1: return Color("#5fcf8f")
		-1: return Color("#d96a5a")
	return Color("#8693a8")

static func state_label(s: int) -> String:
	match s:
		1: return "Alignée"
		-1: return "Hostile"
	return "Neutre"

# ── Chargement JSON (data/*.json éditables hors code). ──
static func _load_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : " + path)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Array else []

static func _load_json_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

# ── Builders : construisent (une fois, en cache) les objets typés depuis le JSON. ──
static var _cards: Array[CardData] = []
static var _characters: Array[CharacterData] = []
static var _planets: Array[PlanetData] = []

static func all_cards() -> Array[CardData]:
	if _cards.is_empty():
		for d in _load_json("res://data/cards.json"):
			var c := CardData.new()
			c.id = d["id"]; c.bearer = d["bearer"]; c.role = d["role"]
			c.mood = d["mood"]; c.key = d.get("key", false); c.question = d["question"]
			c.left_answer = _answer(d["left"])
			c.right_answer = _answer(d["right"])
			_cards.append(c)
	return _cards

static func _answer(a: Dictionary) -> AnswerData:
	var r := AnswerData.new()
	r.title = a["title"]
	r.reaction = a.get("reaction", "")
	r.fx = a.get("fx", {})
	return r

static func all_characters() -> Array[CharacterData]:
	if _characters.is_empty():
		for d in _load_json("res://data/characters.json"):
			var c := CharacterData.new()
			c.id = d["id"]; c.name = d["name"]; c.tag = d["tag"]
			c.met = d["met"]; c.key = d.get("key", false)
			_characters.append(c)
	return _characters

static func all_planets() -> Array[PlanetData]:
	if _planets.is_empty():
		for d in _load_json("res://data/planets.json"):
			var p := PlanetData.new()
			p.id = d["id"]; p.name = d["name"]; p.faction = d["faction"]
			p.state = d["state"]; p.x = d["x"]; p.y = d["y"]
			p.note = d["note"]; p.base = d["base"]; p.hidden = d["hidden"]
			_planets.append(p)
	return _planets

# Tirage : évite la répétition immédiate (port de pickCard).
static func pick_card(recent_ids: Array) -> CardData:
	var cards := all_cards()
	var pool := cards.filter(func(c): return not (c.id in recent_ids))
	var src: Array[CardData] = pool if pool.size() > 0 else cards
	return src[randi() % src.size()]

# Teinte stable par interlocuteur (port de toneFor).
static func tone_for(id_seed: String) -> Color:
	var h := 0
	for i in id_seed.length():
		h = (h * 31 + id_seed.unicode_at(i)) & 0x7fffffff
	return TONES[h % TONES.size()]

static func lighten(c: Color, amt: float) -> Color:
	return c.lerp(Color.WHITE, amt)

static func initials(name: String) -> String:
	var s := ""
	for w in name.split(" ", false):
		if w.length() > 0:
			s += w[0].to_upper()
	return s.substr(0, 2)
