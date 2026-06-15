extends GutTest

var meta: MetaProgression
var ctx: Context

func before_each():
	meta = MetaProgression.new()
	meta.path = "user://test_meta_%d.json" % (randi())
	ctx = Context.new()
	ctx.initialize_new_reign()

func after_each():
	if FileAccess.file_exists(meta.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta.path))

# --- Score de règne (barème GDD) ---

func test_resource_death_no_achievement_scores_zero():
	# Durée seule ne rapporte rien ; mort par ressource = pas de bonus survie.
	ctx.set_var("turns", 40)
	assert_eq(meta.score_reign(ctx, "resource"), 0)

func test_crisis_and_survival_score():
	ctx.set_var("seldon_crisis_1", 1)
	ctx.set_var("seldon_crisis_2", 1)
	# 2 crises ×200 + 100 (pas de mort par ressource)
	assert_eq(meta.score_reign(ctx, "exposed"), 500)

func test_reign_quest_bonus():
	ctx.set_var("quest_reign", 2)
	# 150 (quête) + 100 (pas mort ressource), mort exposed
	assert_eq(meta.score_reign(ctx, "exposed"), 250)

func test_natural_death_multiplier():
	ctx.set_var("seldon_crisis_1", 1)
	# (200 crise + 100 survie) ×1.5 = 450
	assert_eq(meta.score_reign(ctx, "natural"), 450)

# --- Échelle de rangs (15 paliers) ---

func test_rank_index_thresholds():
	assert_eq(meta.rank_index_for(0), 0)
	assert_eq(meta.rank_index_for(249), 0)
	assert_eq(meta.rank_index_for(250), 1)
	assert_eq(meta.rank_index_for(999999), 14, "plafonne au dernier rang")

func test_rank_names():
	assert_eq(meta.rank_name(0), "Initié I")
	assert_eq(meta.rank_name(4), "Initié V")
	assert_eq(meta.rank_name(5), "Orateur I")
	assert_eq(meta.rank_name(14), "Psychohistorien V")

# --- Accumulation + persistance ---

func test_record_reign_accumulates_and_persists():
	ctx.set_var("seldon_crisis_1", 1)  # 200 + 100 survie = 300
	var res = meta.record_reign(ctx, "exposed")
	assert_eq(res["score"], 300)
	assert_eq(meta.total_experience, 300)
	assert_eq(res["rank_index"], 1, "300 xp → rang 1")

	var reloaded = MetaProgression.new()
	reloaded.path = meta.path
	reloaded.load()
	assert_eq(reloaded.total_experience, 300, "l'expérience survit (fichier méta séparé)")

func test_rank_up_flag():
	ctx.set_var("seldon_crisis_1", 1)
	ctx.set_var("seldon_crisis_2", 1)  # 400 + 100 = 500 → rang 1
	var res = meta.record_reign(ctx, "exposed")
	assert_true(res["ranked_up"], "passage de rang 0 à 1 signalé")
