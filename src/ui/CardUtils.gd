class_name CardUtils

# Teintes sourdes (façon Lapse) du nouveau template app.jsx (TONES).
# Le fond de chaque carte est teinté de façon stable selon l'interlocuteur.
const TONES := [
	Color("#1c3a3b"), Color("#22332a"), Color("#3a2731"), Color("#26303f"),
	Color("#33291f"), Color("#2a2740"), Color("#203636"), Color("#352230"),
]

# Teinte stable dérivée de l'id de carte (port de toneFor()).
static func tone_for(id_seed) -> Color:
	var s := str(id_seed)
	var h := 0
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) & 0x7fffffff
	return TONES[h % TONES.size()]

# Éclaircit une couleur vers le blanc (port de lighten()).
static func lighten(c: Color, amt: float) -> Color:
	return c.lerp(Color.WHITE, amt)

# Résolution du porteur d'une carte pour l'affichage du portrait.
# bearer = id canonique (characters.json) → nom/rôle officiels + badge Figure du Plan
# bearer = null → PNJ au nom généré, stable par carte (seed = id de carte)
static func resolve_bearer(card: Dictionary, data: FoundationGameData, ctx: Context = null) -> Dictionary:
	var bearer = card.get("bearer")
	# Rôle institutionnel persistant : bearer = "role:<id>"
	if bearer is String and bearer.begins_with("role:") and ctx != null:
		var role_id: String = bearer.trim_prefix("role:")
		var role: Dictionary = data.roles.get(role_id, {})
		var name_key := "role_%s_name" % role_id
		var name: String = str(ctx.get_var(name_key, ""))
		if name == "":
			name = data.get_random_name()
			ctx.set_var(name_key, name, true)
		return {"name": name, "role": role.get("title", role_id), "key": false}
	if bearer is String and bearer != "":
		var ch: Dictionary = data.characters.get(bearer, {})
		if not ch.is_empty():
			return {
				"name": ch.get("name", bearer),
				"role": str(ch.get("role", "")),
				"key": bool(ch.get("fixed", false)),
			}
		return {"name": bearer, "role": str(card.get("role", "")), "key": false}

	var card_id: int = int(card.get("id", 0))
	var name := ""
	if not data.given_names.is_empty() and not data.family_names.is_empty():
		var given: String = data.given_names[(card_id * 7919) % data.given_names.size()]
		var family: String = data.family_names[(card_id * 104729) % data.family_names.size()]
		name = given + " " + family
	return {"name": name, "role": str(card.get("role", "")), "key": false}

# Ressources touchées par le choix (gauche = yesOutcome) — révèle QUELLES
# barres vont bouger, jamais le sens ni le montant.
static func affected_resources(card: Dictionary, is_left: bool) -> Array:
	var outcomes: Array = card.get("yesOutcome" if is_left else "noOutcome", [])
	var affected: Array = []
	for outcome in outcomes:
		var variable: String = outcome.get("variable", "")
		if variable in Context.RESOURCES and int(outcome.get("intValue", 0)) != 0:
			if not variable in affected:
				affected.append(variable)
	return affected
