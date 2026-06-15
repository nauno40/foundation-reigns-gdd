class_name Context

const RESOURCES = ["military", "religion", "commerce", "politics"]
const RESOURCE_DEFAULT = 50
const LEGITIMACY_DEFAULT = 100

# Multiplicateur de difficulté appliqué aux deltas de jauges (GDD §2.13) :
# doux amortit les variations (plus facile de rester au milieu), brutal les
# amplifie (on atteint 0/100 plus vite). Défaut : normal.
const DIFFICULTY_MULT = {"doux": 0.7, "normal": 1.0, "brutal": 1.45}

# Menace perçue par faction (héritage du système de factions du jeu de base) :
# chaque antagoniste récurrent est rattaché à une faction Fondation ; sa menace
# s'éveille quand cette faction devient hostile.
const RIVAL_FACTION = {
	"cao_cao": "empire", "cao_pi": "empire", "cao_rui": "empire",
	"sima_yi": "empire", "liu_biao": "military_kingdoms",
	"yuan_shao": "military_kingdoms", "gongsun_zan": "military_kingdoms",
	"ma_teng": "military_kingdoms", "lv_bu": "kalgan",
	"zhang_lu": "church_of_science", "yuan_shu": "oligarchs",
	"sun_ce": "oligarchs", "sun_quan": "oligarchs",
	"liu_bei": "autonomous_league", "liu_zhang": "neotrantor",
	"liu_shan": "neotrantor",
}

var _vars: Dictionary = {}
var _keep_flags: Dictionary = {}

func get_var(key: String, default = 0) -> Variant:
	return _vars.get(key, default)

func difficulty_multiplier() -> float:
	return DIFFICULTY_MULT.get(str(get_var("difficulty", "normal")), 1.0)

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

# Une décision = un tour = un an (prototype/Reigns premier du nom).
# L'âge est dérivé du temps écoulé pour rester cohérent même quand une
# carte fait sauter des années via outcome.
func advance_turn() -> void:
	add_var("turns", 1)
	_vars["year"] = int(get_var("year", 1)) + 1
	var age_start: int = int(get_var("age_start", 35))
	var y_start: int = int(get_var("y_start", 1))
	_vars["age"] = age_start + (int(_vars["year"]) - y_start)
	# Mois cyclique 1..12 — alimente les cartes saisonnières (jeu de base)
	_vars["month"] = (int(get_var("turns", 1)) - 1) % 12 + 1

	# Maîtrise mentalique de l'Orateur : jauge cachée qui croît avec
	# l'expérience (+1/tour) et la maîtrise de la couverture (+1 si la
	# légitimité reste haute). Persistante entre règnes (toKeep) — la Seconde
	# Fondation affine son emprise au fil des Orateurs. Plafond 100.
	var gain: int = 1
	if int(get_var("legitimacy", 100)) >= 70:
		gain += 1
	var mentalic: int = min(int(get_var("mentalic", 0)) + gain, 100)
	set_var("mentalic", mentalic, true)
	# Facettes dérivées lues par les cartes (échelles du jeu de base) :
	_vars["synaptic"] = mentalic                  # 0..100 : prouesses rares
	_vars["strength"] = int(mentalic / 10.0)      # 0..10  : échelle des rangs
	_vars["mentalic_strength"] = int(mentalic / 10.0)

	# Menace perçue (jauge dérivée, système de factions du jeu de base).
	# player:threat monte avec la puissance mentalique et l'exposition (faible
	# légitimité = l'Empire vous remarque) — échelle d'avertissements 0..30.
	var threat: int = int(mentalic / 5.0) \
		+ int((100 - int(get_var("legitimacy", 100))) / 12.0)
	_vars["player:threat"] = clampi(threat, 0, 30)
	# Chaque rival devient menaçant (=1) quand sa faction passe hostile.
	for rival in RIVAL_FACTION:
		if int(get_var("relation_" + RIVAL_FACTION[rival], 0)) <= -25:
			_vars[rival + ":threat"] = 1

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
