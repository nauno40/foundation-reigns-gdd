extends Node

const EraUtils = preload("res://src/ui/EraUtils.gd")

const NATURAL_DEATH_CARD_ID = 9001

var _game_data: FoundationGameData
var _ctx: Context
var _model: NarrativeModel
var _legitimacy: LegitimacySystem
var _respawn: RespawnSystem
var _save: SaveSystem
var _seldon: SeldonSystem

@onready var _card_screen = %CardScreen
@onready var _death_screen = %DeathScreen
@onready var _galaxy_map = %GalaxyMap

var _current_card: Dictionary = {}
var _awaiting_reaction: bool = false
var _pending_death: String = ""

func _ready() -> void:
	_game_data = FoundationGameData.new()
	if not _game_data.load_all():
		push_error("Main: failed to load game data")
		return

	_ctx = Context.new()
	_save = SaveSystem.new()
	_legitimacy = LegitimacySystem.new(_ctx)
	_respawn = RespawnSystem.new(_ctx)
	_seldon = SeldonSystem.new(_game_data, _ctx)

	if _save.has_save():
		_save.load(_ctx)
	else:
		_initialize_new_reign(100)
		_game_data.seed_planet_states(_ctx)
		_game_data.seed_faction_relations(_ctx)
		_ctx.set_var("location", "terminus", true)

	_dev_parse_args()

	_model = NarrativeModel.new(_game_data, _ctx)
	_card_screen.setup(_game_data)
	_galaxy_map.setup(_game_data)

	_card_screen.choice_made.connect(_on_choice_made)
	_card_screen.reaction_dismissed.connect(_on_reaction_dismissed)
	_card_screen.map_requested.connect(_on_map_pressed)
	_death_screen.continue_pressed.connect(_on_new_reign)
	_galaxy_map.visibility_changed.connect(_on_map_visibility_changed)
	_galaxy_map.jump_requested.connect(_on_jump_requested)

	_generate_equ_watermark()
	_next_card()

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

func _dev_parse_args() -> void:
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		match args[i]:
			"--deck":
				if i + 1 < args.size():
					var deck = args[i + 1]
					_ctx.set_var("dev_deck", deck)
					print("DEV: deck filtré sur '%s'" % deck)

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
	_awaiting_reaction = false

func _on_choice_made(is_left: bool) -> void:
	if _awaiting_reaction:
		return
	_awaiting_reaction = true

	var outcome_key = "yesOutcome" if is_left else "noOutcome"
	var outcomes = _current_card.get(outcome_key, [])
	_model.apply_outcomes(outcomes)

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
	if _ctx.is_game_over():
		if _ctx.get_var("dying", 0) == 1:
			_pending_death = _parse_death_type()
		else:
			# Mort par ressource : la scène narrative du deck deaths joue
			# d'abord (jeu de base) ; son épilogue posera dying = 1.
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
	_death_screen.show_death(_ctx, death_type, cover)
	_death_screen.show()
	_card_screen.hide()

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

func _on_map_pressed() -> void:
	_galaxy_map.update(_ctx)
	_galaxy_map.show()
	_card_screen.hide()

func _on_jump_requested(planet_id: String) -> void:
	_ctx.set_var("link", "_jump_" + planet_id)
	_save.save(_ctx)
	_next_card()

func _on_map_visibility_changed() -> void:
	if not _galaxy_map.visible and not _death_screen.visible:
		_card_screen.show()
