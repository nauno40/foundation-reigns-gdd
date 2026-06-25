class_name ThemeColors

const BG        = Color("#05070d")
const BG_2      = Color("#080c16")
const PANEL     = Color("#0c1322")
const PANEL_2   = Color("#0f1828")
const INK       = Color("#e7edf6")
const INK_DIM   = Color("#93a0b6")
const INK_FAINT = Color("#54607a")
const LINE      = Color(0.471, 0.588, 0.745, 0.14)
const LINE_2    = Color(0.471, 0.588, 0.745, 0.08)
const ACCENT    = Color("#4fd6e8")
const ACCENT_DEEP = Color("#2aa7c4")
const AMBER     = Color("#e8b65a")
const DANGER    = Color("#d96a5a")
# Couleurs de ressources : conversion exacte des oklch du template app.jsx
# (--military oklch(.66 .15 25) etc.) en sRGB.
const MILITARY  = Color("#df6862")
const RELIGION  = Color("#9281e1")
const COMMERCE  = Color("#4cb587")
const POLITICS  = Color("#d3a23b")

static func resource_color(key: String) -> Color:
	match key:
		"military": return MILITARY
		"religion": return RELIGION
		"commerce": return COMMERCE
		"politics": return POLITICS
	return INK_DIM

static func resource_glyph(key: String) -> String:
	match key:
		"military": return "▲"
		"religion": return "✦"
		"commerce": return "●"
		"politics": return "■"
	return "?"

static func resource_label(key: String) -> String:
	match key:
		"military": return "Militaire"
		"religion": return "Religion"
		"commerce": return "Commerce"
		"politics": return "Politique"
	return key

static func mood_color(mood_key: String) -> Color:
	match mood_key:
		"neutral":    return Color("#7d8aa3")
		"suspicious": return Color("#e0a64f")
		"afraid":     return Color("#7fb4d8")
		"angry":      return Color("#d96a5a")
		"flattered":  return Color("#b98ad6")
		"curious":    return Color("#4fd6e8")
		"sad":        return Color("#8693a8")
		"desperate":  return Color("#c8505a")
	return Color("#7d8aa3")

static func mood_label(mood_key: String) -> String:
	match mood_key:
		"neutral":    return "NEUTRE"
		"suspicious": return "MÉFIANT"
		"afraid":     return "APEURÉ"
		"angry":      return "FURIEUX"
		"flattered":  return "FLATTÉ"
		"curious":    return "CURIEUX"
		"sad":        return "TRISTE"
		"desperate":  return "DÉSESPÉRÉ"
	return "NEUTRE"

static func death_message(death_type: String) -> String:
	match death_type:
		"military":    return "Fondation sans défense = bibliothèque attendant l'incendie."
		"military_hi": return "Puissance militaire = redevenu l'Empire."
		"religion":    return "Sans la foi qui voile la science, machines = métal froid."
		"religion_hi": return "La théocratie a dévoré la science."
		"commerce":    return "Isolement économique = siège lent."
		"commerce_hi": return "Monopole a corrompu les marchands."
		"politics":    return "Chaos = aucune institution ne survit."
		"politics_hi": return "Autoritarisme = tyrannie."
		"legitimacy":  return "Orateur exposé met en péril toute la Seconde Fondation."
		"terminus":    return "Terminus est tombée. Le Plan n'a plus d'ancre — mille ans de calculs s'effondrent."
		"natural":     return "Vous avez servi jusqu'à la fin. Le Plan vous remercie."
	return "Le Plan se poursuit, malgré tout."

static func death_label(death_type: String) -> String:
	match death_type:
		"military":    return "Militaire — effondrement"
		"military_hi": return "Militaire — excès fatal"
		"religion":    return "Religion — effondrement"
		"religion_hi": return "Religion — excès fatal"
		"commerce":    return "Commerce — effondrement"
		"commerce_hi": return "Commerce — excès fatal"
		"politics":    return "Politique — effondrement"
		"politics_hi": return "Politique — excès fatal"
		"legitimacy":  return "Orateur démasqué"
		"terminus":    return "Terminus perdue"
		"natural":     return "Mort naturelle"
	return "Cause inconnue"
