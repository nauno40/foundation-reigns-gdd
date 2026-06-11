class_name CardScreen
extends Control

const EraUtils = preload("res://src/ui/EraUtils.gd")
const ResourceBar = preload("res://src/ui/ResourceBar.gd")

signal choice_made(is_left: bool)
signal map_requested

@onready var _topbar_meta_era = $MainVBox/TopBar/MetaRow/EraLabel
@onready var _topbar_meta_seal = $MainVBox/TopBar/MetaRow/Seal
@onready var _topbar_cover_year_age = $MainVBox/TopBar/CoverRow/YearAge
@onready var _topbar_cover_text = $MainVBox/TopBar/CoverRow/CoverText
@onready var _bars = {
	"military": $MainVBox/TopBar/ResourceBars/BarMilitary,
	"religion": $MainVBox/TopBar/ResourceBars/BarReligion,
	"commerce": $MainVBox/TopBar/ResourceBars/BarCommerce,
	"politics": $MainVBox/TopBar/ResourceBars/BarPolitics,
}
@onready var _mood = $MainVBox/TopBar/MoodIndicator
@onready var _whisper = $MainVBox/TopBar/Whisper
@onready var _swipe_hint = $MainVBox/CardArea/SwipeHint
@onready var _edge_left = $MainVBox/CardArea/EdgeLeft
@onready var _edge_right = $MainVBox/CardArea/EdgeRight
@onready var _card_panel = $MainVBox/CardArea/CardPanel
@onready var _portrait = $MainVBox/CardArea/CardPanel/CardVBox/Portrait
@onready var _portrait_grid = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Grid
@onready var _portrait_bust_body = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Bust/Body
@onready var _portrait_bust_head = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Bust/Head
@onready var _portrait_initials = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Bust/Head/Initials
@onready var _portrait_scanlines = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Scanlines
@onready var _portrait_flicker = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Flicker
@onready var _portrait_keytag = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/KeyTag
@onready var _portrait_bearer_name = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Who/BearerName
@onready var _portrait_bearer_role = $MainVBox/CardArea/CardPanel/CardVBox/Portrait/Who/BearerRole
@onready var _question = $MainVBox/CardArea/CardPanel/CardVBox/QuestionLabel
@onready var _choices = $MainVBox/CardArea/CardPanel/CardVBox/Choices
@onready var _left_choice = $MainVBox/CardArea/CardPanel/CardVBox/Choices/LeftChoice
@onready var _left_title = $MainVBox/CardArea/CardPanel/CardVBox/Choices/LeftChoice/ChoiceVBox/TitleLabel
@onready var _right_choice = $MainVBox/CardArea/CardPanel/CardVBox/Choices/RightChoice
@onready var _right_title = $MainVBox/CardArea/CardPanel/CardVBox/Choices/RightChoice/ChoiceVBox2/TitleLabel2
@onready var _reaction_toast = $MainVBox/CardArea/CardPanel/CardVBox/ReactionToast
@onready var _swipe_detector = $SwipeDetector

var _current_card: Dictionary = {}
var _can_swipe: bool = true
var _current_drag: float = 0.0
var _flicker_timer: Timer
var _reaction_visible: bool = false

const SWIPE_THRESHOLD = 92.0

func _ready() -> void:
	_swipe_detector.swiped_left.connect(_on_swipe_left)
	_swipe_detector.swiped_right.connect(_on_swipe_right)
	_swipe_detector.swipe_progress.connect(_on_swipe_progress)
	_setup_bars()
	_setup_flicker()

func _setup_bars() -> void:
	var config = [
		["military", "▲", "Militaire"],
		["religion", "✦", "Religion"],
		["commerce", "●", "Commerce"],
		["politics", "■", "Politique"],
	]
	for c in config:
		var bar: ResourceBar = _bars[c[0]]
		bar.setup(c[0], c[1], c[2])

func _setup_flicker() -> void:
	_flicker_timer = Timer.new()
	_flicker_timer.wait_time = 4.0 + randf() * 3.0
	_flicker_timer.one_shot = true
	_flicker_timer.timeout.connect(_do_flicker)
	add_child(_flicker_timer)
	_flicker_timer.start()

func _do_flicker() -> void:
	var tween = create_tween()
	tween.tween_property(_portrait_flicker, "modulate", Color(0.31, 0.839, 0.91, 0.06), 0.02)
	tween.tween_property(_portrait_flicker, "modulate", Color(0.31, 0.839, 0.91, 0.01), 0.02)
	tween.tween_property(_portrait_flicker, "modulate", Color(0.31, 0.839, 0.91, 0.0), 0.05)
	_flicker_timer.wait_time = 4.0 + randf() * 3.0
	_flicker_timer.start()

func show_card(card: Dictionary, ctx: Context) -> void:
	_current_card = card
	_can_swipe = true
	_current_drag = 0.0
	_reaction_visible = false

	var question = card.get("question", {})
	_question.text = question.get("FR", question.get("EN", "???"))

	var left_answer = card.get("leftAnswer", {})
	var right_answer = card.get("rightAnswer", {})
	var left_title = left_answer.get("title", {})
	var right_title = right_answer.get("title", {})
	_left_title.text = left_title.get("FR", left_title.get("EN", ""))
	_right_title.text = right_title.get("FR", right_title.get("EN", ""))
	_edge_left.text = "◄ " + _left_title.text
	_edge_right.text = _right_title.text + " ►"

	_choices.visible = true
	_reaction_toast.visible = false
	_swipe_hint.modulate.a = 1.0

	_update_portrait(card)
	_update_info(ctx)
	_update_bars(ctx)
	_update_mood(card, ctx)
	_update_whisper(ctx)
	_reset_card_position()

	_reset_choice_styles()

func _update_portrait(card: Dictionary) -> void:
	# bearer vaut null dans le JSON pour les PNJ : la clé existe,
	# donc get() ne retombe pas sur le défaut
	var bearer = card.get("bearer", "")
	if bearer == null:
		bearer = ""
	var role = card.get("role", "")
	if role == null:
		role = ""
	var is_key = card.get("key", false)

	_portrait_bearer_name.text = bearer
	_portrait_bearer_role.text = role

	var words = bearer.split(" ", false)
	var initials = ""
	for w in words:
		if w.length() > 0:
			initials += w[0].to_upper()
	initials = initials.substr(0, 2)
	_portrait_initials.text = initials

	_portrait_keytag.visible = is_key

func _update_info(ctx: Context) -> void:
	var year = ctx.get_var("year", 1)
	var age = ctx.get_var("age", 35)
	var cover = ctx.get_var("cover_name", "Inconnu")
	var era_info = EraUtils.get_era_info(year)
	_topbar_meta_era.text = era_info.get("label", "") + " · " + era_info.get("sub", "")
	_topbar_cover_year_age.text = "An %d · %d ans" % [year, age]
	_topbar_cover_text.text = "Couverture : " + str(cover)

func _update_bars(ctx: Context) -> void:
	for key in _bars:
		var value: int = ctx.get_var(key, 50)
		_bars[key].update_value(value)

func _update_mood(card: Dictionary, ctx: Context) -> void:
	var mood_key = ctx.get_var("mood", "neutral")
	if typeof(mood_key) != TYPE_STRING:
		mood_key = "neutral"
	_mood.set_mood(mood_key)

func _update_whisper(ctx: Context) -> void:
	var legitimacy = ctx.get_var("legitimacy", 100)
	_whisper.visible = legitimacy <= LegitimacySystem.THRESHOLD_SUSPICIOUS

func _reset_card_position() -> void:
	_card_panel.position = Vector2.ZERO
	_card_panel.rotation = 0.0
	_card_panel.modulate.a = 1.0

func _reset_choice_styles() -> void:
	_reset_choice_style(_left_choice)
	_reset_choice_style(_right_choice)

func _reset_choice_style(choice: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.471, 0.588, 0.745, 0.14)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	choice.add_theme_stylebox_override("panel", style)

func _on_swipe_progress(ratio: float) -> void:
	if not _can_swipe or _reaction_visible:
		return
	_current_drag = ratio * SWIPE_THRESHOLD

	var tilt = _current_drag * 0.045
	_card_panel.rotation = deg_to_rad(tilt)
	_card_panel.position.x = _current_drag

	var lean = min(1.0, abs(_current_drag) / SWIPE_THRESHOLD)
	_edge_left.modulate.a = lean if _current_drag < 0 else 0.0
	_edge_right.modulate.a = lean if _current_drag > 0 else 0.0

	if _current_drag <= -SWIPE_THRESHOLD:
		_highlight_choice(_left_choice, true)
		_highlight_choice(_right_choice, false)
		_highlight_bars("left")
	elif _current_drag >= SWIPE_THRESHOLD:
		_highlight_choice(_left_choice, false)
		_highlight_choice(_right_choice, true)
		_highlight_bars("right")
	else:
		_highlight_choice(_left_choice, false)
		_highlight_choice(_right_choice, false)
		_highlight_bars("")

	if abs(_current_drag) > 10.0:
		_swipe_hint.modulate.a = 0.0
	else:
		_swipe_hint.modulate.a = 1.0

func _highlight_choice(choice: PanelContainer, lit: bool) -> void:
	if lit:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.31, 0.839, 0.91, 0.06)
		style.border_color = Color(0.31, 0.839, 0.91, 1)
		style.corner_radius_top_left = 9
		style.corner_radius_top_right = 9
		style.corner_radius_bottom_left = 9
		style.corner_radius_bottom_right = 9
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		choice.add_theme_stylebox_override("panel", style)
	else:
		_reset_choice_style(choice)

func _highlight_bars(side: String) -> void:
	var card = _current_card
	if card.is_empty():
		return
	var answer_key = "leftAnswer" if side == "left" else "rightAnswer"
	var answer = card.get(answer_key, {})
	var fx = answer.get("fx", {})
	for key in _bars:
		var affected = fx.has(key) and fx[key] != 0
		_bars[key].set_affected(affected)

func _on_swipe_left() -> void:
	if not _can_swipe:
		return
	_can_swipe = false
	_animate_fly_out(-1.0)

func _on_swipe_right() -> void:
	if not _can_swipe:
		return
	_can_swipe = false
	_animate_fly_out(1.0)

func _animate_fly_out(direction: float) -> void:
	var target_x = direction * get_viewport_rect().size.x * 1.5
	var target_rot = deg_to_rad(direction * 22.0)

	var tween = create_tween().set_parallel()
	tween.tween_property(_card_panel, "position:x", target_x, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_card_panel, "rotation", target_rot, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_card_panel, "modulate:a", 0.0, 0.4).set_delay(0.1)
	await tween.finished
	choice_made.emit(direction < 0)

func show_reaction(card: Dictionary, is_left: bool) -> void:
	_reaction_visible = true
	var answer_key = "leftAnswer" if is_left else "rightAnswer"
	var answer = card.get(answer_key, {})
	var reaction = answer.get("reaction", {})
	var text = reaction.get("FR", reaction.get("EN", ""))

	_card_panel.position = Vector2.ZERO
	_card_panel.rotation = 0.0
	_card_panel.modulate.a = 1.0

	_choices.visible = false
	_reaction_toast.visible = true
	_reaction_toast.text = text
	_reaction_toast.modulate.a = 0.0

	var rise = create_tween()
	rise.tween_property(_reaction_toast, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(_reaction_toast, "position:y", -10.0, 0.5).set_ease(Tween.EASE_OUT).from_current()

	_edge_left.modulate.a = 0.0
	_edge_right.modulate.a = 0.0
	_swipe_hint.modulate.a = 0.0
