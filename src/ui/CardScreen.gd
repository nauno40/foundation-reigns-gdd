class_name CardScreen
extends Control

# Écran de jeu principal — fidèle au prototype React :
# topbar (ère/sceau, an/âge/couverture, 4 barres, mood, murmure),
# carte centrale (portrait holo, question, chips), labels de bord,
# réaction, footer. Physique de swipe : seuil 92px, tilt 0.045°/px,
# fly-out 150 % + 22° en 0.5 s.

const EraUtils = preload("res://src/ui/EraUtils.gd")
const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_SPECTRAL_ITALIC = preload("res://assets/fonts/Spectral-Italic.ttf")

signal choice_made(is_left: bool)
signal map_requested
signal reaction_dismissed

const SWIPE_THRESHOLD := 92.0      # = SwipeDetector.COMMIT_THRESHOLD
const PREVIEW_THRESHOLD := 24.0
const CARD_MAX_W := 360.0
const MIN_REACTION_MS := 400       # anti-balayage accidentel de la réaction

@onready var _era_label: Label = %EraLabel
@onready var _seal: Button = %Seal
@onready var _year_age: Label = %YearAge
@onready var _cover_text: Label = %CoverText
@onready var _bars: Dictionary = {
	"military": %BarMilitary,
	"religion": %BarReligion,
	"commerce": %BarCommerce,
	"politics": %BarPolitics,
}
@onready var _mood: MoodIndicator = %MoodIndicator
@onready var _whisper: Label = %Whisper
@onready var _card_area: Control = %CardArea
@onready var _edge_left: Label = %EdgeLeft
@onready var _edge_right: Label = %EdgeRight
@onready var _card_panel: PanelContainer = %CardPanel
@onready var _holo: ColorRect = %Holo
@onready var _initials: Label = %Initials
@onready var _flicker: ColorRect = %Flicker
@onready var _keytag: Label = %KeyTag
@onready var _bearer_name: Label = %BearerName
@onready var _bearer_role: Label = %BearerRole
@onready var _question: Label = %QuestionLabel
@onready var _choices: HBoxContainer = %Choices
@onready var _left_choice: PanelContainer = %LeftChoice
@onready var _left_title: Label = %LeftTitle
@onready var _right_choice: PanelContainer = %RightChoice
@onready var _right_title: Label = %RightTitle
@onready var _reaction_toast: Label = %ReactionToast
@onready var _swipe_detector = $SwipeDetector

var _game_data: FoundationGameData
var _current_card: Dictionary = {}
var _can_swipe: bool = true
var _current_drag: float = 0.0
var _reaction_visible: bool = false
var _card_base_pos: Vector2 = Vector2.ZERO
var _flicker_timer: Timer
var _chip_base_style: StyleBoxFlat
var _snap_tween: Tween
var _entry_pending: bool = false
var _reaction_shown_ms: int = 0
var _question_font_regular: Font

func setup(game_data: FoundationGameData) -> void:
	_game_data = game_data

func _ready() -> void:
	_swipe_detector.swiped_left.connect(_on_swipe_left)
	_swipe_detector.swiped_right.connect(_on_swipe_right)
	_swipe_detector.swipe_progress.connect(_on_swipe_progress)
	_swipe_detector.drag_released.connect(_on_drag_released)
	_swipe_detector.tapped.connect(_on_tapped)
	_seal.pressed.connect(func(): map_requested.emit())
	_chip_base_style = _left_choice.get_theme_stylebox("panel")
	_question_font_regular = _question.get_theme_font("font")
	_setup_bars()
	_setup_flicker()
	_card_area.resized.connect(_layout_card)

func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if _reaction_visible:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
				or event.is_action_pressed("ui_accept"):
			_dismiss_reaction()
		return
	if event.is_action_pressed("ui_left"):
		_on_swipe_left()
	elif event.is_action_pressed("ui_right"):
		_on_swipe_right()

# Ignore les entrées quand l'écran est masqué ou recouvert (carte, mort)
func _accepts_input() -> bool:
	return is_visible_in_tree() and get_viewport().gui_get_focus_owner() == null

func _setup_bars() -> void:
	var config = [
		["military", "▲", "Militaire"],
		["religion", "✦", "Religion"],
		["commerce", "●", "Commerce"],
		["politics", "■", "Politique"],
	]
	for c in config:
		_bars[c[0]].setup(c[0], c[1], c[2])

func _setup_flicker() -> void:
	_flicker_timer = Timer.new()
	_flicker_timer.wait_time = 4.0 + randf() * 3.0
	_flicker_timer.one_shot = true
	_flicker_timer.timeout.connect(_do_flicker)
	add_child(_flicker_timer)
	_flicker_timer.start()

func _do_flicker() -> void:
	var tween = create_tween()
	tween.tween_property(_flicker, "modulate", Color(0.31, 0.839, 0.91, 0.06), 0.02)
	tween.tween_property(_flicker, "modulate", Color(0.31, 0.839, 0.91, 0.01), 0.02)
	tween.tween_property(_flicker, "modulate", Color(0.31, 0.839, 0.91, 0.0), 0.05)
	_flicker_timer.wait_time = 4.0 + randf() * 3.0
	_flicker_timer.start()

# ── Affichage d'une carte ────────────────────────────────────────────

func show_card(card: Dictionary, ctx: Context) -> void:
	_current_card = card
	_can_swipe = true
	_current_drag = 0.0
	_reaction_visible = false

	var question = card.get("question", {})
	_question.text = question.get("FR", question.get("EN", "???"))
	_question.add_theme_font_override("font", _question_font_regular)

	var left_answer = card.get("leftAnswer", {})
	var right_answer = card.get("rightAnswer", {})
	var left_title = left_answer.get("title", {})
	var right_title = right_answer.get("title", {})
	_left_title.text = left_title.get("FR", left_title.get("EN", ""))
	_right_title.text = right_title.get("FR", right_title.get("EN", ""))
	_edge_left.text = _left_title.text
	_edge_right.text = _right_title.text

	_choices.visible = true
	_reaction_toast.visible = false

	_update_portrait(card)
	_update_info(ctx)
	_update_bars(ctx)
	_update_mood(ctx)
	_update_whisper(ctx)
	_reset_choice_styles()
	_clear_affected()

	# entrée de la nouvelle carte : fondu + léger scale (façon Reigns)
	_entry_pending = true
	_card_panel.modulate.a = 0.0

	# le contenu vient de changer : recalcul du layout au prochain frame
	_layout_card.call_deferred()

func _update_portrait(card: Dictionary) -> void:
	var info := {"name": "", "role": "", "key": false}
	if _game_data:
		info = CardUtils.resolve_bearer(card, _game_data)
	else:
		var bearer = card.get("bearer")
		info["name"] = bearer if bearer is String else ""

	_bearer_name.text = info["name"]
	_bearer_role.text = str(info["role"]).to_upper()
	_bearer_role.visible = info["role"] != ""
	_keytag.visible = bool(info["key"])

	var initials := ""
	for w in str(info["name"]).split(" ", false):
		if w.length() > 0:
			initials += w[0].to_upper()
	_initials.text = initials.substr(0, 2)

func _update_info(ctx: Context) -> void:
	var year = ctx.get_var("year", 1)
	var age = ctx.get_var("age", 35)
	var cover = ctx.get_var("cover_name", "Inconnu")
	var era_info = EraUtils.get_era_info(year)
	_era_label.text = (era_info.get("label", "") + " · " + era_info.get("sub", "")).to_upper()
	_year_age.text = "An %d · %d ans" % [year, age]
	_cover_text.text = "Couverture : " + str(cover)

func _update_bars(ctx: Context) -> void:
	for key in _bars:
		_bars[key].update_value(ctx.get_var(key, 50))

func _update_mood(ctx: Context) -> void:
	var mood_key = ctx.get_var("mood", "neutral")
	if typeof(mood_key) != TYPE_STRING:
		mood_key = "neutral"
	_mood.set_mood(mood_key)

func _update_whisper(ctx: Context) -> void:
	var legitimacy = ctx.get_var("legitimacy", 100)
	_whisper.visible = legitimacy <= LegitimacySystem.THRESHOLD_SUSPICIOUS

# ── Layout de la carte (largeur min(360, 86 %), centrée) ─────────────

var _layout_pending: bool = false

func _layout_card() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	var area: Vector2 = _card_area.size
	if area.x <= 0.0:
		_layout_pending = false
		return
	var w: float = min(CARD_MAX_W, area.x * 0.86)
	# 1er passage : fixer la largeur pour que l'autowrap recalcule
	_card_panel.size = Vector2(w, 0)
	await get_tree().process_frame
	_layout_pending = false
	if not is_instance_valid(_card_panel):
		return
	area = _card_area.size
	w = min(CARD_MAX_W, area.x * 0.86)
	# 2e passage : la hauteur min est maintenant correcte
	var ch: float = min(_card_panel.get_combined_minimum_size().y, area.y)
	_card_panel.size = Vector2(w, ch)
	_card_panel.pivot_offset = Vector2(w / 2.0, ch / 2.0)
	_card_base_pos = Vector2((area.x - w) / 2.0, (area.y - ch) / 2.0)
	_apply_drag()

	var holo_mat := _holo.material as ShaderMaterial
	if holo_mat:
		holo_mat.set_shader_parameter("rect_size", Vector2(w, 190.0))

	if _entry_pending:
		_entry_pending = false
		_card_panel.scale = Vector2(0.95, 0.95)
		var entry = create_tween().set_parallel()
		entry.tween_property(_card_panel, "modulate:a", 1.0, 0.18)
		entry.tween_property(_card_panel, "scale", Vector2.ONE, 0.22) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	for edge in [_edge_left, _edge_right]:
		edge.size = Vector2(area.x * 0.42, 0)
	_edge_left.position = Vector2(8, (area.y - _edge_left.size.y) / 2.0)
	_edge_right.position = Vector2(area.x - _edge_right.size.x - 8, (area.y - _edge_right.size.y) / 2.0)

func _apply_drag() -> void:
	_card_panel.position = _card_base_pos + Vector2(_current_drag, 0)
	_card_panel.rotation = deg_to_rad(_current_drag * 0.045)

# ── Swipe ────────────────────────────────────────────────────────────

func _on_swipe_progress(drag_px: float) -> void:
	if not _can_swipe or _reaction_visible or not _accepts_input():
		return
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	_set_drag(drag_px)

# Relâchement sous le seuil : la carte revient au centre (snap-back Reigns)
func _on_drag_released() -> void:
	if not _can_swipe or _reaction_visible or _current_drag == 0.0:
		return
	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()
	_snap_tween = create_tween()
	_snap_tween.tween_method(_set_drag, _current_drag, 0.0, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_tapped() -> void:
	if _reaction_visible and _accepts_input():
		_dismiss_reaction()

func _set_drag(drag_px: float) -> void:
	_current_drag = drag_px
	_apply_drag()

	var lean: float = min(1.0, abs(_current_drag) / SWIPE_THRESHOLD)
	_edge_left.modulate.a = lean if _current_drag < -10.0 else 0.0
	_edge_right.modulate.a = lean if _current_drag > 10.0 else 0.0

	# chips : surbrillance au seuil
	_highlight_choice(_left_choice, _current_drag <= -SWIPE_THRESHOLD)
	_highlight_choice(_right_choice, _current_drag >= SWIPE_THRESHOLD)

	# barres affectées : dès 24px de drag, révèle QUELLES barres bougeront
	if _current_drag <= -PREVIEW_THRESHOLD:
		_set_affected(CardUtils.affected_resources(_current_card, true))
	elif _current_drag >= PREVIEW_THRESHOLD:
		_set_affected(CardUtils.affected_resources(_current_card, false))
	else:
		_clear_affected()

func _set_affected(keys: Array) -> void:
	for key in _bars:
		_bars[key].set_affected(key in keys)

func _clear_affected() -> void:
	for key in _bars:
		_bars[key].set_affected(false)

func _highlight_choice(choice: PanelContainer, lit: bool) -> void:
	var style := _chip_base_style.duplicate() as StyleBoxFlat
	if lit:
		style.bg_color = Color(0.31, 0.839, 0.91, 0.06)
		style.border_color = ThemeColors.ACCENT
		style.shadow_color = Color(0.31, 0.839, 0.91, 0.25)
		style.shadow_size = 10
	choice.add_theme_stylebox_override("panel", style)

func _reset_choice_styles() -> void:
	_highlight_choice(_left_choice, false)
	_highlight_choice(_right_choice, false)

func _on_swipe_left() -> void:
	if not _accepts_input():
		return
	if _reaction_visible:
		_dismiss_reaction()
		return
	if not _can_swipe:
		return
	_can_swipe = false
	_animate_fly_out(-1.0)

func _on_swipe_right() -> void:
	if not _accepts_input():
		return
	if _reaction_visible:
		_dismiss_reaction()
		return
	if not _can_swipe:
		return
	_can_swipe = false
	_animate_fly_out(1.0)

func _animate_fly_out(direction: float) -> void:
	_clear_affected()
	_edge_left.modulate.a = 0.0
	_edge_right.modulate.a = 0.0
	var target_x = _card_base_pos.x + direction * get_viewport_rect().size.x * 1.5
	var target_rot = deg_to_rad(direction * 22.0)
	var tween = create_tween().set_parallel()
	tween.tween_property(_card_panel, "position:x", target_x, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_card_panel, "rotation", target_rot, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_card_panel, "modulate:a", 0.0, 0.4).set_delay(0.1)
	await tween.finished
	choice_made.emit(direction < 0)

# ── Réaction après le choix ──────────────────────────────────────────

# Narration du jeu de base : le même personnage répond, son texte
# remplace la question (italique), pas de choix, un balayage continue.
# Retourne false si la réponse n'a pas de réaction écrite — dans ce cas
# l'enchaînement est direct (84 % des swipes dans Reigns 3K).
func show_reaction(card: Dictionary, is_left: bool, ctx: Context) -> bool:
	# Jauges, mood, date : tout réagit immédiatement au choix (Reigns)
	_update_bars(ctx)
	_update_mood(ctx)
	_update_whisper(ctx)
	_update_info(ctx)

	var answer = card.get("leftAnswer" if is_left else "rightAnswer", {})
	var reaction = answer.get("reaction", {})
	var text: String = str(reaction.get("FR", reaction.get("EN", ""))).strip_edges()
	if text == "":
		return false

	_reaction_visible = true
	_question.text = text
	_question.add_theme_font_override("font", FONT_SPECTRAL_ITALIC)
	_current_drag = 0.0
	_card_panel.rotation = 0.0
	_choices.visible = false
	_entry_pending = true
	_card_panel.modulate.a = 0.0
	_reaction_shown_ms = Time.get_ticks_msec()
	_layout_card.call_deferred()
	return true

# La réaction se balaie comme dans Reigns : tap, swipe ou clavier.
func _dismiss_reaction() -> void:
	if not _reaction_visible:
		return
	if Time.get_ticks_msec() - _reaction_shown_ms < MIN_REACTION_MS:
		return
	_reaction_visible = false
	reaction_dismissed.emit()
