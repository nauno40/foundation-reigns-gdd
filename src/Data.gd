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

# Source brute des cartes (dicts). Exposée comme objets typés via all_cards().
# Chaque carte : bearer, role, mood, question, left/right {title, reaction, fx}.
const _DECK_RAW := [
	{"id": "pirenne_base", "bearer": "Lewis Pirenne", "role": "Président du Conseil", "mood": "neutral", "key": false,
		"question": "« Anacréon réclame une base militaire sur Terminus. Le Conseil n'ose ni refuser, ni céder. Que dois-je leur dire, Orateur ? »",
		"left":  {"title": "« Refusez. Fermement. »", "reaction": "Pirenne pâlit. « Et s'ils nous écrasent ? »", "fx": {"military": -8, "politics": 6, "legit": -4}},
		"right": {"title": "« Gagnons du temps. »", "reaction": "« Toujours temporiser… jusqu'à quand ? »", "fx": {"politics": 5, "commerce": -5}}},
	{"id": "anselm_culte", "bearer": "Frère Anselm", "role": "Prêtre de l'Église de la Science", "mood": "flattered", "key": false,
		"question": "« Les peuples d'Anacréon s'agenouillent déjà devant nos réacteurs comme devant des autels. Étendons-nous le culte, Orateur ? »",
		"left":  {"title": "« Répandez la foi. »", "reaction": "« La Galaxie s'illuminera de notre science. »", "fx": {"religion": 12, "politics": -4, "military": 3, "legit": -3}},
		"right": {"title": "« Restez discrets. »", "reaction": "Anselm s'incline, visiblement déçu.", "fx": {"religion": -6, "commerce": 5, "legit": 3}}},
	{"id": "sermak_armer", "bearer": "Sef Sermak", "role": "Chef des Actionnistes", "mood": "angry", "key": false,
		"question": "« Hardin nous endort avec ses prêtres et ses sermons ! Il faut armer Terminus, maintenant — ou périr ! »",
		"left":  {"title": "« Calmez vos partisans. »", "reaction": "Sermak crache à vos pieds. « Lâche. »", "fx": {"politics": 7, "military": -6}},
		"right": {"title": "« Construisez la flotte. »", "reaction": "« Enfin. Un dirigeant qui agit. »", "fx": {"military": 12, "commerce": -10, "religion": -4, "legit": -2}}},
	{"id": "marchand_amulettes", "bearer": "Ponyets de Smyrno", "role": "Négociant en technologie", "mood": "curious", "key": false,
		"question": "« Vos amulettes nucléaires se vendent à prix d'or dans les Quatre Royaumes. On double la production, Orateur ? »",
		"left":  {"title": "« Doublez tout. »", "reaction": "Il se frotte les mains, ravi.", "fx": {"commerce": 12, "religion": 4, "military": -4}},
		"right": {"title": "« Gardez le secret de la technologie. »", "reaction": "« Prudent. Très prudent. »", "fx": {"commerce": -4, "religion": 6, "politics": 3, "legit": 2}}},
	{"id": "hardin_wienis", "bearer": "Salvor Hardin", "role": "Maire de Terminus", "mood": "neutral", "key": true,
		"question": "« La violence est le dernier refuge de l'incompétent. Mais le régent Wienis prépare un coup contre nous. Votre conseil ? »",
		"left":  {"title": "« Laissez-le se pendre seul. »", "reaction": "Hardin sourit. « Vous comprenez le Plan. »", "fx": {"politics": 10, "military": 4, "legit": 4}},
		"right": {"title": "« Frappons les premiers. »", "reaction": "« …Vous me décevez, Orateur. »", "fx": {"military": 8, "politics": -8, "religion": -4, "legit": -6}}},
	{"id": "lefkin_energie", "bearer": "Prince Lefkin", "role": "Régent d'Anacréon", "mood": "afraid", "key": false,
		"question": "« Vos prêtres ont coupé l'énergie de tout mon palais ! La foule gronde aux portes ! Rendez-moi la lumière, je vous en supplie ! »",
		"left":  {"title": "« Soumettez-vous d'abord. »", "reaction": "Lefkin tremble, puis s'agenouille.", "fx": {"religion": 10, "military": 5, "politics": 5, "legit": -4}},
		"right": {"title": "« Rétablissons le courant. »", "reaction": "« Vous… vous êtes clément. »", "fx": {"religion": -4, "commerce": 6, "politics": 2, "legit": 3}}},
	{"id": "lee_dons", "bearer": "Yohan Lee", "role": "Garde du corps du Maire", "mood": "suspicious", "key": false,
		"question": "« Comment savez-vous toujours, à l'avance, ce que l'ennemi va faire ? On jurerait que vous lisez dans les esprits… »",
		"left":  {"title": "« Pure logique politique. »", "reaction": "Lee hoche lentement la tête.", "fx": {"politics": 4, "legit": 5}},
		"right": {"title": "« Disons que j'ai certains dons. »", "reaction": "Le regard de Lee se durcit.", "fx": {"politics": 2, "legit": -12}}},
	{"id": "bort_encyclopedie", "bearer": "Conseillère Bort", "role": "Actionniste modérée", "mood": "neutral", "key": false,
		"question": "« Les Encyclopédistes veulent encore reporter la défense pour financer l'Encyclopédie. Tranchez, Orateur. »",
		"left":  {"title": "« La connaissance d'abord. »", "reaction": "« Espérons que les barbares sachent lire. »", "fx": {"religion": 4, "commerce": 4, "military": -8}},
		"right": {"title": "« La survie d'abord. »", "reaction": "Bort approuve d'un signe sec.", "fx": {"military": 10, "religion": -4}}},
	{"id": "verisof_ambassadeur", "bearer": "Poly Verisof", "role": "Grand Prêtre & Ambassadeur", "mood": "flattered", "key": false,
		"question": "« Je sers à la fois d'ambassadeur et de grand prêtre à Anacréon. Dois-je leur prêcher l'obéissance… ou la révolte contre Wienis ? »",
		"left":  {"title": "« Prêchez l'obéissance. »", "reaction": "« Le troupeau suivra le berger. »", "fx": {"religion": 8, "politics": 5, "military": -3}},
		"right": {"title": "« Préparez les esprits à la révolte. »", "reaction": "« Risqué. Mais habile, Orateur. »", "fx": {"politics": 6, "military": 4, "religion": -2, "legit": -3}}},
	{"id": "haut_pretre_dime", "bearer": "Haut Prêtre Mallow", "role": "Trésorier du Temple", "mood": "desperate", "key": false,
		"question": "« Les caisses du Temple sont vides ! Sans une nouvelle dîme, l'Église de la Science ne tiendra pas l'hiver, Orateur ! »",
		"left":  {"title": "« Levez la dîme. »", "reaction": "« Bénie soit votre sagesse. »", "fx": {"religion": 8, "commerce": -6, "politics": -3}},
		"right": {"title": "« Que le Temple se serre la ceinture. »", "reaction": "Il blêmit. « Vous nous condamnez… »", "fx": {"religion": -8, "commerce": 5, "legit": 2}}},
]

const SELDON_MESSAGES := {
	"military":    "« Une Fondation qui ne sait pas se défendre n'est qu'une bibliothèque attendant l'incendie. Le Plan corrigera ce détour. »",
	"military_hi": "« La puissance des armes vous a grisés. Une Fondation conquérante n'est plus la mienne — elle est l'Empire qu'elle devait remplacer. »",
	"religion":    "« Sans la foi qui voile la science, vos machines ne sont que du métal froid aux yeux des barbares. »",
	"religion_hi": "« La théocratie que vous avez bâtie échappe désormais à tout contrôle. La superstition a dévoré la science. »",
	"commerce":    "« L'isolement économique étrangle la Fondation aussi sûrement qu'un siège. L'or est une arme — vous l'avez laissée rouiller. »",
	"commerce_hi": "« Le monopole a corrompu vos marchands. L'avidité a remplacé le Plan. »",
	"politics":    "« Dans le chaos, aucune institution ne survit. L'anarchie a balayé ce que des siècles devaient construire. »",
	"politics_hi": "« L'autoritarisme a fait de la Fondation une tyrannie. Vous m'avez trahi en croyant me servir. »",
	"legitimacy":  "« On vous a démasqué, Orateur. Un Orateur exposé met en péril toute la Seconde Fondation. Le secret renaîtra ailleurs. »",
}

const COVERS := [
	{"name": "Conseiller impérial", "res": "politics"},
	{"name": "Prêtre scientifique", "res": "religion"},
	{"name": "Marchand local", "res": "commerce"},
]

const DIFF := {"doux": 0.7, "normal": 1.0, "brutal": 1.45}

# decks qui s'activent par progression du règne (ère Hardin)
const DECK_UNLOCKS := [
	{"at": 3,  "name": "Église de la Science", "cards": 4},
	{"at": 8,  "name": "Menace anacréonienne", "cards": 5},
	{"at": 14, "name": "Réseau marchand",       "cards": 4},
	{"at": 21, "name": "Cour impériale",         "cards": 5},
]

const TONES := [
	Color("#1c3a3b"), Color("#22332a"), Color("#3a2731"), Color("#26303f"),
	Color("#33291f"), Color("#2a2740"), Color("#203636"), Color("#352230"),
]

const _CHARACTERS_RAW := [
	{"id": "seldon",  "name": "Hari Seldon",   "tag": "Fondateur du Plan",       "met": true,  "key": true},
	{"id": "hardin",  "name": "Salvor Hardin", "tag": "Maire de Terminus",       "met": true,  "key": true},
	{"id": "pirenne", "name": "Lewis Pirenne", "tag": "Président du Conseil",     "met": true,  "key": false},
	{"id": "sermak",  "name": "Sef Sermak",    "tag": "Chef des Actionnistes",   "met": true,  "key": false},
	{"id": "anselm",  "name": "Frère Anselm",  "tag": "Église de la Science",    "met": true,  "key": false},
	{"id": "verisof", "name": "Poly Verisof",  "tag": "Grand Prêtre & Ambassadeur", "met": true, "key": false},
	{"id": "lefkin",  "name": "Prince Lefkin", "tag": "Régent d'Anacréon",       "met": true,  "key": false},
	{"id": "mallow",  "name": "Hober Mallow",  "tag": "Prince Marchand",         "met": false, "key": true},
	{"id": "barr",    "name": "Ducem Barr",    "tag": "Patricien de Siwenna",    "met": false, "key": false},
	{"id": "bayta",   "name": "Bayta Darell",  "tag": "Résistante",              "met": false, "key": true},
	{"id": "mis",     "name": "Ebling Mis",    "tag": "Psychologue",             "met": false, "key": false},
]

const ACHIEVEMENTS := [
	{"name": "Premier Orateur",   "desc": "Prendre une première couverture.",            "done": true},
	{"name": "Lecteur d'esprits", "desc": "Lire 5 humeurs différentes.",                 "done": true},
	{"name": "Main invisible",    "desc": "Terminer un règne sans être démasqué.",        "done": false},
	{"name": "Crise d'Anacréon",  "desc": "Franchir la 1re Crise de Seldon (ans 50–80).", "done": false},
	{"name": "Vieil Orateur",     "desc": "Mourir de vieillesse (×1.5 score).",           "done": false},
]

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

const _PLANETS_RAW := [
	{"id": "terminus", "name": "Terminus", "faction": "Première Fondation", "state": 1, "x": 18, "y": 64, "note": "Base permanente. La perdre = fin du Plan.", "base": true, "hidden": false},
	{"id": "trantor", "name": "Trantor", "faction": "Empire → Seconde Fondation", "state": 1, "x": 52, "y": 48, "note": "Capitale impériale déclinante. Bascule après le sac (~an 300).", "base": false, "hidden": false},
	{"id": "anacreon", "name": "Anacréon", "faction": "Royaumes militaristes", "state": -1, "x": 30, "y": 30, "note": "Première grande menace. Le royaume voisin le plus agressif.", "base": false, "hidden": false},
	{"id": "santanni", "name": "Santanni", "faction": "Royaumes militaristes", "state": -1, "x": 40, "y": 18, "note": "Royaume des Quatre Provinces.", "base": false, "hidden": false},
	{"id": "smyrno", "name": "Smyrno", "faction": "Royaumes militaristes", "state": -1, "x": 22, "y": 44, "note": "Royaume des Quatre Provinces.", "base": false, "hidden": false},
	{"id": "askone", "name": "Askone", "faction": "Marchands", "state": 0, "x": 64, "y": 30, "note": "Cible commerciale de l'ère Mallow.", "base": false, "hidden": false},
	{"id": "korell", "name": "Korell", "faction": "Oligarques", "state": 0, "x": 76, "y": 42, "note": "République des Princes Marchands. Antagoniste de Mallow.", "base": false, "hidden": false},
	{"id": "siwenna", "name": "Siwenna", "faction": "Empire → Neotrantor", "state": 0, "x": 60, "y": 64, "note": "Province impériale. Chute de l'Empire.", "base": false, "hidden": false},
	{"id": "kalgan", "name": "Kalgan", "faction": "Mulet → Kalgan", "state": 0, "x": 82, "y": 72, "note": "Base du Mulet, puis seigneurie de guerre.", "base": false, "hidden": false},
	{"id": "neotrantor", "name": "Neotrantor", "faction": "Neotrantor", "state": 0, "x": 46, "y": 74, "note": "Vestige impérial après le sac de Trantor.", "base": false, "hidden": false},
	{"id": "rossem", "name": "Rossem", "faction": "Seconde Fondation", "state": 0, "x": 88, "y": 24, "note": "Planète glaciale. Couverture de la Seconde Fondation.", "base": false, "hidden": true},
	{"id": "sayshell", "name": "Sayshell", "faction": "Église de la Science", "state": 0, "x": 34, "y": 82, "note": "Culte de la Fondation, fin de partie.", "base": false, "hidden": false},
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

# ── Builders : construisent (une fois, en cache) les objets typés depuis les dicts. ──
static var _cards: Array[CardData] = []
static var _characters: Array[CharacterData] = []
static var _planets: Array[PlanetData] = []

static func all_cards() -> Array[CardData]:
	if _cards.is_empty():
		for d in _DECK_RAW:
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
		for d in _CHARACTERS_RAW:
			var c := CharacterData.new()
			c.id = d["id"]; c.name = d["name"]; c.tag = d["tag"]
			c.met = d["met"]; c.key = d.get("key", false)
			_characters.append(c)
	return _characters

static func all_planets() -> Array[PlanetData]:
	if _planets.is_empty():
		for d in _PLANETS_RAW:
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
