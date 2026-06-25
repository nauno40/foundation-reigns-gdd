extends Node

const EraUtils = preload("res://src/ui/EraUtils.gd")

const NATURAL_DEATH_CARD_ID = 9001

var _game_data: FoundationGameData
var _ctx: Context
var _model: NarrativeModel
var _legitimacy: LegitimacySystem
var _respawn: RespawnSystem
var _meta: MetaProgression
var _save: SaveSystem
var _seldon: SeldonSystem

@onready var _card_screen = %CardScreen
@onready var _death_screen = %DeathScreen
@onready var _codex = %Codex
@onready var _briefing_screen = %BriefingScreen

# Multiplicateur de difficulté appliqué aux deltas de ressources/légitimité
# des choix (nouveau template : doux ×0.7 / normal ×1.0 / brutal ×1.45).
const DIFFICULTY_MULT := {"doux": 0.7, "normal": 1.0, "brutal": 1.45}
var _death_fx: ColorRect = null

var _current_card: Dictionary = {}
var _awaiting_reaction: bool = false
var _pending_death: String = ""
var _loading_tween: Tween
var _loading_pulse: Tween
# Données pré-chargées par LoadingScreen (injection avant add_child) ; si non
# nul, Main saute son propre chargement (sinon fallback auto-chargement).
var preloaded_data: FoundationGameData = null

func _ready() -> void:
	if preloaded_data != null:
		# Données déjà parsées par LoadingScreen → démarrage immédiat.
		_game_data = preloaded_data
	else:
		# Lancement direct de Main : auto-chargement (parse sur un thread pour
		# que l'overlay s'anime au lieu de geler).
		%LoadingOverlay.show()
		_start_loading_visuals()
		await get_tree().process_frame
		var thread := Thread.new()
		thread.start(_load_data_threaded)
		while thread.is_alive():
			await get_tree().process_frame
		if not thread.wait_to_finish():
			push_error("Main: failed to load game data")
			_stop_loading_visuals()
			%LoadingMessage.text = "ÉCHEC DE CHARGEMENT"
			return

	_ctx = Context.new()
	_save = SaveSystem.new()
	_legitimacy = LegitimacySystem.new(_ctx)
	_respawn = RespawnSystem.new(_ctx)
	_seldon = SeldonSystem.new(_game_data, _ctx)
	_meta = MetaProgression.new()
	_meta.load()

	var mode = Globals.start_mode
	if mode == Globals.StartMode.NONE:
		mode = Globals.StartMode.CONTINUE if _save.has_save() else Globals.StartMode.NEW_GAME

	match mode:
		Globals.StartMode.CONTINUE:
			_save.load(_ctx)
		Globals.StartMode.NEW_GAME:
			_initialize_new_reign(100)
			_game_data.seed_planet_states(_ctx)
			_game_data.seed_faction_relations(_ctx)
			_ctx.set_var("location", "terminus", true)

	if Globals.dev_deck:
		_ctx.set_var("dev_deck", Globals.dev_deck)
		print("DEV: deck filtré sur '%s'" % Globals.dev_deck)
	if Globals.difficulty != "normal":
		_ctx.set_var("difficulty", Globals.difficulty, true)
		print("DEV: difficulté '%s'" % Globals.difficulty)

	_model = NarrativeModel.new(_game_data, _ctx)
	_card_screen.setup(_game_data)

	_card_screen.choice_made.connect(_on_choice_made)
	_card_screen.reaction_dismissed.connect(_on_reaction_dismissed)
	_card_screen.dashboard_requested.connect(_on_dashboard_pressed)
	_death_screen.continue_pressed.connect(_on_new_reign)
	_briefing_screen.dismissed.connect(_on_briefing_dismissed)

	_stop_loading_visuals()
	%LoadingOverlay.hide()
	_generate_equ_watermark()
	if mode == Globals.StartMode.NEW_GAME:
		_briefing_screen.show_briefing()
		_card_screen.hide()
	else:
		_next_card()

# Charge les données hors du thread principal : ne touche QUE _game_data
# (FileAccess + JSON), aucun accès à l'arbre de scène → thread-safe.
func _load_data_threaded() -> bool:
	_game_data = FoundationGameData.new()
	return _game_data.load_all()

# Habille l'overlay pendant le chargement : grille holographique de fond +
# points animés « CHARGEMENT… » (tourne sur le thread principal pendant le parse).
func _start_loading_visuals() -> void:
	if not %LoadingOverlay.has_node("HoloGrid"):
		var grid := ColorRect.new()
		grid.name = "HoloGrid"
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/holo_grid.gdshader")
		mat.set_shader_parameter("rect_size", get_viewport().get_visible_rect().size)
		grid.material = mat
		%LoadingOverlay.add_child(grid)
		%LoadingOverlay.move_child(grid, 1)  # au-dessus de Bg, sous le texte
	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()
	_loading_tween = create_tween().set_loops()
	for d in range(4):
		var dots := ".".repeat(d)
		_loading_tween.tween_callback(func(): %LoadingMessage.text = "CHARGEMENT" + dots)
		_loading_tween.tween_interval(0.35)
	# Pulsation du message → mouvement clairement visible.
	if _loading_pulse and _loading_pulse.is_valid():
		_loading_pulse.kill()
	%LoadingMessage.modulate.a = 1.0
	_loading_pulse = create_tween().set_loops()
	_loading_pulse.tween_property(%LoadingMessage, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	_loading_pulse.tween_property(%LoadingMessage, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _stop_loading_visuals() -> void:
	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()
	_loading_tween = null
	if _loading_pulse and _loading_pulse.is_valid():
		_loading_pulse.kill()
	_loading_pulse = null
	if is_instance_valid(%LoadingMessage):
		%LoadingMessage.modulate.a = 1.0
	var grid = %LoadingOverlay.get_node_or_null("HoloGrid")
	if grid:
		grid.queue_free()

func _generate_equ_watermark() -> void:
	var syms = "∫ ∂ Ψ Σ ∇ λ Φ ε δ → ∞ ± ∮ ≈ √ μ Δ ⟨ ⟩ π τ ω".split(" ")
	var s = ""
	for i in range(1400):
		s += syms[randi() % syms.size()] + ("  " if randf() < 0.15 else " ")
	%Equ.text = s

func _initialize_new_reign(legitimacy_start: int) -> void:
	_ctx.initialize_new_reign(legitimacy_start)
	_ctx.set_var("year", 1, true)
	_ctx.set_var("y_start", 1, true)
	_ctx.set_var("age", 35 + randi() % 6)
	_ctx.set_var("age_start", _ctx.get_var("age"))
	_ctx.set_var("speaker_name", _game_data.get_random_name())
	var cover = _pick_cover(1)
	_ctx.set_var("cover_name", cover.get("name", "Inconnu"))
	_ctx.apply_cover(cover)

func _pick_cover(year: int) -> Dictionary:
	var era_id = EraUtils.get_era_for_year(year)
	var era_covers = _game_data.covers.get(era_id, {})
	var list = era_covers.get("covers", [])
	if list.is_empty():
		return {"name": "Inconnu", "bonus_resource": "politics", "bonus_value": 0}
	return list[randi() % list.size()]

func _next_card() -> void:
	_current_card = _model.draw_card()
	if _current_card.is_empty():
		push_error("Main: no card to draw")
		return

	var load_outcomes = _current_card.get("loadOutcome", [])
	_model.apply_outcomes(load_outcomes)
	_seldon.resolve_pending()

	# Mood de l'interlocuteur porté par la carte (héritage Reigns) ;
	# une légitimité basse rend les interlocuteurs méfiants (GDD §2.5)
	var moods = _current_card.get("moods", {})
	var bias = _legitimacy.get_mood_bias()
	_ctx.set_var("mood", bias if bias != "" else moods.get("default", "neutral"))

	_card_screen.show_card(_current_card, _ctx)

	# Déblocage de deck (jalon) : bannière inline non bloquante (app.jsx deck-add).
	var unlock := DeckUnlock.pending_unlock(_current_card, _ctx, _game_data.deck_unlocks)
	if not unlock.is_empty():
		_ctx.set_var("deck_unlocked_" + str(unlock["id"]), 1, true)
		_save.save(_ctx)  # persiste le déblocage tout de suite (survie crash)
		_card_screen.play_deck_unlock(unlock)
	_awaiting_reaction = false

# Applique le multiplicateur de difficulté aux deltas de ressources/légitimité
# (opérations additives) ; les autres outcomes (set, link, deck…) sont intacts.
func _scaled_outcomes(outcomes: Array) -> Array:
	var mult: float = DIFFICULTY_MULT.get(Globals.difficulty, 1.0)
	if is_equal_approx(mult, 1.0):
		return outcomes
	var scaled: Array = []
	for outcome in outcomes:
		var o: Dictionary = outcome.duplicate()
		var variable: String = o.get("variable", "")
		var op: String = o.get("addOperation", "+=")
		if op == "+=" and (variable in Context.RESOURCES or variable == "legitimacy"):
			o["intValue"] = int(round(float(o.get("intValue", 0)) * mult))
		scaled.append(o)
	return scaled

func _on_choice_made(is_left: bool) -> void:
	if _awaiting_reaction:
		return
	_awaiting_reaction = true

	var outcome_key = "yesOutcome" if is_left else "noOutcome"
	var outcomes = _current_card.get(outcome_key, [])
	_model.apply_outcomes(_scaled_outcomes(outcomes))

	# Réaction émotionnelle de l'interlocuteur au choix (visage Reigns)
	var moods = _current_card.get("moods", {})
	_ctx.set_var("mood", moods.get("yes" if is_left else "no", "neutral"))

	_model.mark_card_seen(_current_card)
	_ctx.advance_turn()

	# L'intermède new_speaker ne dure que les premiers tours du règne
	# (provisoire : la carte d'accueil définitive fermera le deck elle-même)
	if int(_ctx.get_var("turns", 0)) >= 4:
		_ctx.set_var("deck_new_speaker", 0)

	# Structure du jeu de base : la narration (réaction) n'existe que si
	# l'auteur a écrit un texte — sinon enchaînement direct (84 % des
	# swipes dans Reigns: Three Kingdoms).
	var has_reaction = _card_screen.show_reaction(_current_card, is_left, _ctx)
	_save.save(_ctx)

	# La suite (mort ou carte suivante) attend que le joueur balaie la
	# réaction — rythme du joueur, comme dans Reigns.
	_pending_death = ""
	var current_link = str(_ctx.get_var("link", ""))
	if _ctx.is_game_over():
		if _ctx.get_var("dying", 0) == 1:
			_pending_death = _parse_death_type()
		elif current_link != "" and current_link != "0":
			pass
		else:
			var death_card = _model.find_death_card()
			if death_card.is_empty():
				_pending_death = _parse_death_type()
			else:
				_ctx.set_var("link", str(int(death_card.get("id", 0))))
	elif _ctx.get_var("dying", 0) == 1:
		# Morts hors ressources : la carte porte son type (défaut : naturelle)
		_pending_death = str(_ctx.get_var("death_type", "natural"))
	else:
		var age = _ctx.get_var("age", 35)
		if _should_die_naturally(age):
			# La mort arrive via une carte narrative (deck new_speaker)
			_ctx.set_var("link", str(NATURAL_DEATH_CARD_ID))

	if not has_reaction:
		_on_reaction_dismissed()

func _on_reaction_dismissed() -> void:
	if _pending_death != "":
		var death_type = _pending_death
		_pending_death = ""
		_show_death_screen(death_type)
		return
	_next_card()

func _parse_death_type() -> String:
	for resource in Context.RESOURCES:
		var val = _ctx.get_var(resource, 50)
		if val <= 0:
			_ctx.set_var("last_death_type", resource, true)
			return resource
		if val >= 100:
			_ctx.set_var("last_death_type", resource + "_hi", true)
			return resource + "_hi"
	if _ctx.get_var("legitimacy", 100) <= 0:
		_ctx.set_var("last_death_type", "legitimacy", true)
		return "legitimacy"
	if _ctx.get_var("planet_terminus_state", 1) <= 0:
		_ctx.set_var("last_death_type", "terminus", true)
		return "terminus"
	return "natural"

func _should_die_naturally(age: int) -> bool:
	var prob = 0.0
	if    age >= 83: prob = 1.0
	elif  age >= 81: prob = 0.60
	elif  age >= 79: prob = 0.35
	elif  age >= 77: prob = 0.15
	elif  age >= 75: prob = 0.05
	else: return false
	return randf() < prob

func _show_death_screen(death_type: String) -> void:
	var cover = _ctx.get_var("cover_name", "Inconnu")
	_ctx.set_var("last_death_type", death_type, true)
	# Méta-progression : on enregistre le règne (score → expérience → rang)
	# avant le respawn, sur le type de mort canonique.
	var meta_result = _meta.record_reign(
		_ctx, RespawnSystem.normalize_death_type(death_type))
	# Wobble + chute de la carte (CardAnimator.TriggerDefeat) avant l'écran de mort.
	await _card_screen.play_defeat()
	# Effondrement holographique (glitch) avant l'overlay de mort.
	await _play_death_fx()
	_death_screen.show_death(_ctx, death_type, cover, meta_result)
	_death_screen.show()
	_card_screen.hide()

# Glitch/collapse holographique (~0.76 s) joué par-dessus le cadre.
func _play_death_fx() -> void:
	if _death_fx == null:
		_death_fx = ColorRect.new()
		_death_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_death_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/death_fx.gdshader")
		_death_fx.material = mat
		_card_screen.get_parent().add_child(_death_fx)
	var mat := _death_fx.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", _death_fx.size)
	mat.set_shader_parameter("progress", 0.0)
	_death_fx.visible = true
	var tw := create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.76)
	await tw.finished
	_death_fx.visible = false

func _on_new_reign() -> void:
	var death_type = _ctx.get_var("last_death_type", "resource")
	_respawn.respawn(death_type)

	var year = _ctx.get_var("year", 1)
	_ctx.set_var("y_start", year, true)
	_ctx.set_var("age_start", _ctx.get_var("age"))
	_ctx.set_var("speaker_name", _game_data.get_random_name())

	var cover = _pick_cover(year)
	_ctx.set_var("cover_name", cover.get("name", "Inconnu"))
	_ctx.apply_cover(cover)

	# Le pont entre règnes s'ouvre (structure du jeu de base : after_death) ;
	# un intermède conditionnel peut être dispatché en première carte
	_ctx.set_var("deck_new_speaker", 1)

	_model = NarrativeModel.new(_game_data, _ctx)
	var interlude = _model.find_interlude_card()
	if not interlude.is_empty():
		_ctx.set_var("link", str(int(interlude.get("id", 0))))
	_death_screen.hide()
	_card_screen.show()
	_next_card()

func _on_dashboard_pressed() -> void:
	# Le « Tableau de bord » est un panneau coulissant en surimpression :
	# la carte reste derrière (le panneau la recouvre).
	_codex.open("chars")

func _on_briefing_dismissed() -> void:
	_briefing_screen.hide()
	_card_screen.show()
	_next_card()
