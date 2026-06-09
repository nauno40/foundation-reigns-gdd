class_name CardScreen
extends Control

signal choice_made(is_left: bool)

@onready var _background      = $Background
@onready var _portrait        = $Portrait
@onready var _question        = $CardPanel/QuestionLabel
@onready var _left_hint       = $CardPanel/LeftHint
@onready var _right_hint      = $CardPanel/RightHint
@onready var _resource_bars   = $ResourceBars
@onready var _year_label      = $HUDInfo/YearLabel
@onready var _age_label       = $HUDInfo/AgeLabel
@onready var _swipe_detector  = $SwipeDetector

var _current_card: Dictionary = {}
var _can_swipe: bool = true

func _ready() -> void:
	_swipe_detector.swiped_left.connect(_on_swipe_left)
	_swipe_detector.swiped_right.connect(_on_swipe_right)
	_swipe_detector.swipe_progress.connect(_on_swipe_progress)

func show_card(card: Dictionary, ctx: Context) -> void:
	_current_card = card
	_can_swipe = true

	var question = card.get("question", {})
	_question.text = question.get("FR", question.get("EN", "???"))

	var left_answer  = card.get("leftAnswer",  {})
	var right_answer = card.get("rightAnswer", {})
	var left_title   = left_answer.get("title",  {})
	var right_title  = right_answer.get("title", {})
	_left_hint.text  = "← " + left_title.get("FR",  left_title.get("EN",  ""))
	_right_hint.text = right_title.get("FR", right_title.get("EN", "")) + " →"
	_left_hint.visible  = false
	_right_hint.visible = false

	_year_label.text = "An %d" % ctx.get_var("year", 1)
	_age_label.text  = "Âge : %d" % ctx.get_var("age", 35)

	_resource_bars.update(ctx)
	_card_panel_tilt(0.0)

func _on_swipe_left() -> void:
	if not _can_swipe:
		return
	_can_swipe = false
	_animate_swipe_out(-1.0)

func _on_swipe_right() -> void:
	if not _can_swipe:
		return
	_can_swipe = false
	_animate_swipe_out(1.0)

func _on_swipe_progress(ratio: float) -> void:
	_card_panel_tilt(ratio)
	_left_hint.visible  = ratio < -0.3
	_right_hint.visible = ratio > 0.3

func _card_panel_tilt(ratio: float) -> void:
	var card_panel = $CardPanel
	card_panel.rotation = ratio * 0.15
	card_panel.position.x = ratio * 30.0

func _animate_swipe_out(direction: float) -> void:
	var card_panel = $CardPanel
	var tween = create_tween()
	tween.tween_property(card_panel, "position:x", direction * 600.0, 0.25)
	tween.tween_property(card_panel, "modulate:a", 0.0, 0.15)
	await tween.finished
	choice_made.emit(direction < 0)

func show_reaction(card: Dictionary, is_left: bool) -> void:
	var answer_key = "leftAnswer" if is_left else "rightAnswer"
	var answer = card.get(answer_key, {})
	var reaction = answer.get("reaction", {})
	_question.text = reaction.get("FR", reaction.get("EN", ""))
	var card_panel = $CardPanel
	card_panel.position.x = 0
	card_panel.rotation = 0
	card_panel.modulate.a = 1.0
	_left_hint.visible  = false
	_right_hint.visible = false
	_can_swipe = false
