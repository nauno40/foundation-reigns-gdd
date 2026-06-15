class_name MetaProgression

# Méta-progression persistante entre toutes les parties (GDD §Progression) :
# le joueur incarne des Orateurs successifs mais grimpe une échelle de 15 rangs
# (5 Initié → 5 Orateur → 5 Psychohistorien) via l'expérience cumulée. Stockée
# dans un fichier méta SÉPARÉ de la sauvegarde de partie, pour survivre aux
# morts et aux respawns.

const TIERS = ["Initié", "Orateur", "Psychohistorien"]
const ROMAN = ["I", "II", "III", "IV", "V"]

# Seuils d'expérience cumulée (15 paliers, écarts croissants : 250, 350, 450…).
const THRESHOLDS = [0, 250, 600, 1050, 1600, 2250, 3000, 3850, 4800, 5850,
	7000, 8250, 9600, 11050, 12600]

var path: String = "user://foundation_meta.json"
var total_experience: int = 0

# Score d'un règne (barème GDD §Progression) : seuls les accomplissements
# comptent — la durée seule ne rapporte rien. death_type attendu normalisé
# (natural / resource / exposed).
func score_reign(ctx: Context, death_type: String) -> int:
	var base: int = 0
	for i in range(1, 7):
		if int(ctx.get_var("seldon_crisis_%d" % i, 0)) == 1:
			base += 200                       # crise franchie dans son couloir
	if death_type != "resource":
		base += 100                           # pas de mort par ressource
	if int(ctx.get_var("quest_reign", 0)) == 2:
		base += 150                           # quête de règne accomplie
	base += 100 * int(ctx.get_var("arc_advanced", 0))  # avancée d'arc (multi-règnes)
	if death_type == "natural":
		return int(round(base * 1.5))         # mort de vieillesse : ×1.5
	return base

func rank_index_for(experience: int) -> int:
	var idx: int = 0
	for i in range(THRESHOLDS.size()):
		if experience >= THRESHOLDS[i]:
			idx = i
		else:
			break
	return idx

func rank_index() -> int:
	return rank_index_for(total_experience)

func rank_name(index: int) -> String:
	index = clampi(index, 0, TIERS.size() * ROMAN.size() - 1)
	return "%s %s" % [TIERS[index / ROMAN.size()], ROMAN[index % ROMAN.size()]]

# Enregistre un règne : ajoute son score, recalcule le rang, persiste.
# Renvoie {score, total, rank_index, rank_name, ranked_up}.
func record_reign(ctx: Context, death_type: String) -> Dictionary:
	var before: int = rank_index()
	var score: int = score_reign(ctx, death_type)
	total_experience += score
	var after: int = rank_index()
	save()
	return {
		"score": score,
		"total": total_experience,
		"rank_index": after,
		"rank_name": rank_name(after),
		"ranked_up": after > before,
	}

func load() -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		total_experience = int(data.get("total_experience", 0))

func save() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"total_experience": total_experience}))
	return true
