extends Node

var _game_data: FoundationGameData
var _ctx: Context
var _model: NarrativeModel
var _legitimacy: LegitimacySystem
var _respawn: RespawnSystem
var _save: SaveSystem

@onready var _card_screen  = $CardScreen
@onready var _death_screen = $DeathScreen
@onready var _galaxy_map   = $GalaxyMap
@onready var _map_button   = $MapButton

var _current_card: Dictionary = {}
var _awaiting_reaction: bool = false

func _ready() -> void:
	_game_data = FoundationGameData.new()
	if not _game_data.load_all():
		push_error("Main: failed to load game data")
		return

	_ctx        = Context.new()
	_save       = SaveSystem.new()
	_legitimacy = LegitimacySystem.new(_ctx)
	_respawn    = RespawnSystem.new(_ctx)

	if _save.has_save():
		_save.load(_ctx)
	else:
		_ctx.initialize_new_reign()
		_ctx.set_var("year", 1, true)
		_ctx.set_var("age", 35 + randi() % 6)
		_ctx.set_var("speaker_name", _game_data.get_random_name())
		_ctx.set_var("cover_name", "Conseiller impérial")

	_model = NarrativeModel.new(_game_data, _ctx)
	_galaxy_map.setup(_game_data)

	_card_screen.choice_made.connect(_on_choice_made)
	_death_screen.continue_pressed.connect(_on_new_reign)
	_map_button.pressed.connect(_on_map_pressed)

	_next_card()

func _next_card() -> void:
	_current_card = _model.draw_card()
	if _current_card.is_empty():
		push_error("Main: no card to draw")
		return

	var load_outcomes = _current_card.get("loadOutcome", [])
	_model.apply_outcomes(load_outcomes)

	_card_screen.show_card(_current_card, _ctx)
	_awaiting_reaction = false

func _on_choice_made(is_left: bool) -> void:
	if _awaiting_reaction:
		return
	_awaiting_reaction = true

	var outcome_key = "yesOutcome" if is_left else "noOutcome"
	var outcomes = _current_card.get(outcome_key, [])
	_model.apply_outcomes(outcomes)

	_card_screen.show_reaction(_current_card, is_left)
	_model.mark_card_seen(_current_card)

	_ctx.add_var("turns", 1)
	_save.save(_ctx)

	if _ctx.is_game_over():
		await get_tree().create_timer(1.5).timeout
		_show_death_screen(_ctx.get_game_over_reason())
		return

	if _legitimacy.is_exposed():
		await get_tree().create_timer(1.5).timeout
		_show_death_screen("exposed")
		return

	var age = _ctx.get_var("age", 35)
	if _should_die_naturally(age):
		await get_tree().create_timer(1.5).timeout
		_show_death_screen("natural")
		return

	await get_tree().create_timer(1.2).timeout
	_next_card()

func _should_die_naturally(age: int) -> bool:
	var prob = 0.0
	if    age >= 83: prob = 1.0
	elif  age >= 81: prob = 0.60
	elif  age >= 79: prob = 0.35
	elif  age >= 77: prob = 0.15
	elif  age >= 75: prob = 0.05
	else: return false
	return randf() < prob

func _show_death_screen(cause: String) -> void:
	var cover = _ctx.get_var("cover_name", "Inconnu")
	_death_screen.show_death(_ctx, cause, cover)
	_death_screen.show()
	_card_screen.hide()

func _on_new_reign() -> void:
	var death_type = _ctx.get_var("last_death_type", "resource")
	_respawn.respawn(death_type)
	_ctx.set_var("speaker_name", _game_data.get_random_name())
	_model = NarrativeModel.new(_game_data, _ctx)
	_death_screen.hide()
	_card_screen.show()
	_next_card()

func _on_map_pressed() -> void:
	_galaxy_map.update(_ctx)
	_galaxy_map.show()
