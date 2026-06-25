class_name CardScreen
extends Control

# Écran de jeu principal — nouveau template (reference/UI Nouvelle version) :
# topbar sombre (ère + 4 jauges icône-masque), panneau central (question Space Mono,
# murmure Caveat, carte CARRÉE avec pile de deck derrière, buste teinté, texte du
# choix écrit sur la carte, nom sous la carte), poignée « Tableau de bord »,
# bottombar sombre (année en gros Caveat + âge·couverture).
# Physique : suivi 1:1 du doigt, tilt amorti (Reigns 3K), relâchement en ressort
# sous-amorti (rebond), fly-out 150 % + 22°.

const EraUtils = preload("res://src/ui/EraUtils.gd")
const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_CAVEAT = preload("res://assets/fonts/Caveat-Variable.ttf")

signal choice_made(is_left: bool)
signal dashboard_requested
signal reaction_dismissed

const SWIPE_THRESHOLD := 92.0      # = SwipeDetector.COMMIT_THRESHOLD
const PREVIEW_THRESHOLD := 24.0
const CHOICE_REVEAL := 12.0
const CARD_MAX_W := 300.0
const CARD_FRACTION := 0.76
const QUESTION_MAX_H := 150.0   # au-delà, la question défile (la carte garde sa taille)
const MIN_REACTION_MS := 400       # anti-balayage accidentel de la réaction
const CARD_ROT_FACTOR := 0.055     # rot = drag * 0.055° (app.jsx)
const GRAB_SCALE := 1.025          # carte agrandie pendant la saisie (app.jsx)
# Ressort de relâchement (port app.jsx springBack : STIFF/DAMP par frame ~60fps)
const SPRING_STIFF := 0.16
const SPRING_DAMP := 0.74

@onready var _era_label: RichTextLabel = %EraLabel
@onready var _bars: Dictionary = {
	"military": %BarMilitary,
	"religion": %BarReligion,
	"commerce": %BarCommerce,
	"politics": %BarPolitics,
}
@onready var _question: Label = %QuestionLabel
@onready var _question_scroll: ScrollContainer = %QuestionScroll
@onready var _whisper: Label = %Whisper
@onready var _card_area: Control = %CardArea
@onready var _card_panel: Control = %Card
@onready var _deck_card: Panel = %DeckCard
@onready var _face_bg: ColorRect = %FaceBg
@onready var _bust: CardBust = %Bust
@onready var _keytag: Label = %KeyTag
@onready var _card_choice: Label = %CardChoice
@onready var _bearer_name: Label = %BearerName
@onready var _bearer_role: Label = %BearerRole
@onready var _year: Label = %Year
@onready var _reign: Label = %Reign
@onready var _handle: Button = %Handle
@onready var _swipe_detector = $SwipeDetector

var _game_data: FoundationGameData
var _ctx_ref: Context
var _current_card: Dictionary = {}
var _can_swipe: bool = true
var _current_drag: float = 0.0
var _grabbing: bool = false
var _reaction_visible: bool = false
var _card_base_pos: Vector2 = Vector2.ZERO
var _entry_pending: bool = false
var _reaction_shown_ms: int = 0
var _question_font_regular: Font
var _left_title: String = ""
var _right_title: String = ""
var _card_side: float = 0.0
# ressort de relâchement
var _releasing: bool = false
var _spring_vel: float = 0.0

func setup(game_data: FoundationGameData) -> void:
	_game_data = game_data

func _ready() -> void:
	_swipe_detector.swiped_left.connect(_on_swipe_left)
	_swipe_detector.swiped_right.connect(_on_swipe_right)
	_swipe_detector.swipe_progress.connect(_on_swipe_progress)
	_swipe_detector.drag_released.connect(_on_drag_released)
	_swipe_detector.tapped.connect(_on_tapped)
	_handle.pressed.connect(func(): dashboard_requested.emit())
	_question_font_regular = _question.get_theme_font("font")
	_setup_bars()
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

func _accepts_input() -> bool:
	return is_visible_in_tree() and get_viewport().gui_get_focus_owner() == null

func _setup_bars() -> void:
	var config = [
		["military", "Militaire"],
		["religion", "Religion"],
		["commerce", "Commerce"],
		["politics", "Politique"],
	]
	for c in config:
		_bars[c[0]].setup(c[0], c[1])

# ── Affichage d'une carte ────────────────────────────────────────────

func show_card(card: Dictionary, ctx: Context) -> void:
	_current_card = card
	_ctx_ref = ctx
	_can_swipe = true
	_current_drag = 0.0
	_releasing = false
	_reaction_visible = false
	_reset_anim_state()

	var question = card.get("question", {})
	_question.text = question.get("FR", question.get("EN", "???"))
	_question.add_theme_font_override("font", _question_font_regular)
	_question.add_theme_font_size_override("font_size", 17)
	_question.add_theme_color_override("font_color", Color(0.867, 0.902, 0.949))

	var left_answer = card.get("leftAnswer", {})
	var right_answer = card.get("rightAnswer", {})
	var left_title = left_answer.get("title", {})
	var right_title = right_answer.get("title", {})
	_left_title = left_title.get("FR", left_title.get("EN", ""))
	_right_title = right_title.get("FR", right_title.get("EN", ""))
	_card_choice.modulate.a = 0.0

	_update_card_face(card)
	_update_info(ctx)
	_update_bars(ctx)
	_update_whisper(ctx)
	_clear_affected()

	# entrée de la nouvelle carte : fondu + léger scale
	_entry_pending = true
	_card_panel.modulate.a = 0.0

	_layout_card.call_deferred()
	_fit_question.call_deferred()

func _update_card_face(card: Dictionary) -> void:
	var info := {"name": "", "role": "", "key": false}
	if _game_data:
		info = CardUtils.resolve_bearer(card, _game_data, _ctx_ref)
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
	initials = initials.substr(0, 2)

	# teinte stable par interlocuteur (toneFor) + buste plat teinté
	var tone := CardUtils.tone_for(card.get("id", info["name"]))
	_bust.set_tone(tone)
	_bust.set_initials(initials)
	var mat := _face_bg.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tone_lo", tone)
		mat.set_shader_parameter("tone_hi", CardUtils.lighten(tone, 0.12))

# Ajuste la hauteur de la zone question : naturelle, plafonnée à QUESTION_MAX_H ;
# au-delà, le ScrollContainer permet de faire défiler le texte (texte trop grand).
func _fit_question() -> void:
	if not is_instance_valid(_question_scroll):
		return
	await get_tree().process_frame
	if not is_instance_valid(_question_scroll):
		return
	var h := _question.get_minimum_size().y
	_question_scroll.custom_minimum_size.y = clampf(h, 0.0, QUESTION_MAX_H)
	_question_scroll.scroll_vertical = 0

func _update_info(ctx: Context) -> void:
	var year = ctx.get_var("year", 1)
	var age = ctx.get_var("age", 35)
	var cover = ctx.get_var("cover_name", "Inconnu")
	var era_info = EraUtils.get_era_info(year)
	# « ÈRE … » en accent cyan, comme app.jsx (.era b)
	_era_label.text = "[center]SECONDE FONDATION · [color=#4fd6e8]%s[/color] · %s[/center]" % [
		str(era_info.get("label", "")).to_upper(), str(era_info.get("sub", "")).to_upper()]
	# Année affichée directement (le template n'anime pas le compteur)
	_year.text = "An %d" % year
	_reign.text = "%d ans · %s" % [age, str(cover)]

func _update_bars(ctx: Context) -> void:
	for key in _bars:
		_bars[key].update_value(ctx.get_var(key, 50))

func _update_whisper(ctx: Context) -> void:
	var legitimacy = ctx.get_var("legitimacy", 100)
	var should_show: bool = legitimacy <= LegitimacySystem.THRESHOLD_SUSPICIOUS
	if should_show:
		if _whisper.visible and _whisper.modulate.a >= 1.0:
			return
		_whisper.visible = true
		_whisper.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(_whisper, "modulate:a", 1.0, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		if not _whisper.visible or _whisper.modulate.a <= 0.0:
			return
		var tw = create_tween()
		tw.tween_property(_whisper, "modulate:a", 0.0, 0.25)
		tw.finished.connect(func():
			if is_instance_valid(_whisper):
				_whisper.visible = false
		, CONNECT_ONE_SHOT)

# ── Layout de la carte carrée (côté min(300, 76 %), centrée) ─────────

func _layout_card() -> void:
	var area: Vector2 = _card_area.size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var side: float = min(min(CARD_MAX_W, area.x * CARD_FRACTION), area.y)
	_card_side = side
	_card_panel.size = Vector2(side, side)
	_card_panel.pivot_offset = Vector2(side, side) * 0.5
	_card_base_pos = Vector2((area.x - side) / 2.0, (area.y - side) / 2.0)

	# carte de pile derrière (décalée + légèrement inclinée)
	_deck_card.size = Vector2(side, side)
	_deck_card.pivot_offset = Vector2(side, side) * 0.5
	_deck_card.position = _card_base_pos + Vector2(9, 9)
	_deck_card.rotation = deg_to_rad(2.5)

	# buste plat : 64 % large, 80 % haut, ancré bas-centre
	var bw := side * 0.64
	var bh := side * 0.80
	_bust.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bust.position = Vector2((side - bw) / 2.0, side - bh)
	_bust.size = Vector2(bw, bh)
	_bust.queue_redraw()

	var mat := _face_bg.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", Vector2(side, side))

	_apply_drag()

	if _entry_pending:
		_entry_pending = false
		# cardRise (app.jsx .36s) : translate(8,12) rot2.2° scale.965 opacity0 → repos
		var dur := 0.36
		_card_panel.modulate.a = 0.0
		_card_panel.position = _card_base_pos + Vector2(8, 12)
		_card_panel.rotation = deg_to_rad(2.2)
		_card_panel.scale = Vector2(0.965, 0.965)
		var entry = create_tween().set_parallel()
		entry.tween_property(_card_panel, "modulate:a", 1.0, 0.16)
		entry.tween_property(_card_panel, "position", _card_base_pos, dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		entry.tween_property(_card_panel, "rotation", 0.0, dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		entry.tween_property(_card_panel, "scale", Vector2.ONE, dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		# deckRise (.42s) : la carte de pile remonte derrière
		_deck_card.modulate.a = 0.85
		_deck_card.position = _card_base_pos + Vector2(16, 16)
		_deck_card.rotation = deg_to_rad(4.0)
		_deck_card.scale = Vector2(0.93, 0.93)
		var drise = create_tween().set_parallel()
		drise.tween_property(_deck_card, "modulate:a", 1.0, 0.42)
		drise.tween_property(_deck_card, "position", _card_base_pos + Vector2(9, 9), 0.42) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		drise.tween_property(_deck_card, "rotation", deg_to_rad(2.5), 0.42) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		drise.tween_property(_deck_card, "scale", Vector2.ONE, 0.42) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# Modèle de carte fidèle au template (app.jsx Card) : suivi direct du doigt,
# rotation = drag * 0.055°, scale 1.025 en saisie, ressort sous-amorti au relâchement.
func _process(_delta: float) -> void:
	if not is_instance_valid(_card_panel):
		return
	# ressort sous-amorti : la carte revient au centre en rebondissant (springBack)
	if _releasing and not _reaction_visible:
		_spring_vel = (_spring_vel + (-_current_drag) * SPRING_STIFF) * SPRING_DAMP
		_current_drag += _spring_vel
		if abs(_current_drag) < 0.3 and abs(_spring_vel) < 0.3:
			_current_drag = 0.0
			_spring_vel = 0.0
			_releasing = false
		_set_drag(_current_drag)

func _reset_anim_state() -> void:
	_grabbing = false
	_spring_vel = 0.0

# Transform direct (sans amorti) : position X = drag, rot = drag*0.055°, scale en saisie.
func _apply_drag() -> void:
	_card_panel.position = _card_base_pos + Vector2(_current_drag, 0.0)
	_card_panel.rotation = deg_to_rad(_current_drag * CARD_ROT_FACTOR)
	var sc := GRAB_SCALE if _grabbing else 1.0
	_card_panel.scale = Vector2(sc, sc)

# ── Swipe ────────────────────────────────────────────────────────────

func _on_swipe_progress(drag_px: float, _velocity_px_s: float) -> void:
	if not _can_swipe or _reaction_visible or not _accepts_input():
		return
	_releasing = false
	_spring_vel = 0.0
	_grabbing = true
	_set_drag(drag_px)

func _on_drag_released() -> void:
	_grabbing = false
	if not _can_swipe or _reaction_visible or _current_drag == 0.0:
		_apply_drag()
		return
	# relâchement sous le seuil : ressort sous-amorti vers le centre (rebond)
	_spring_vel = 0.0
	_releasing = true

func _on_tapped() -> void:
	if _reaction_visible and _accepts_input():
		_dismiss_reaction()

func _set_drag(drag_px: float) -> void:
	_current_drag = drag_px

	# texte du choix écrit SUR la carte (apparaît dès |drag| > 12)
	var show_choice := absf(_current_drag) > CHOICE_REVEAL
	if show_choice:
		var right := _current_drag > 0.0
		_card_choice.text = _right_title if right else _left_title
		_card_choice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		_card_choice.modulate.a = clampf(absf(_current_drag) / 40.0, 0.0, 1.0)
		_keytag.modulate.a = 0.0
	else:
		_card_choice.modulate.a = 0.0
		_keytag.modulate.a = 1.0

	# jauges affectées : dès 24px, révèle QUELLES jauges bougeront (pas le sens)
	if _current_drag <= -PREVIEW_THRESHOLD:
		_set_affected(CardUtils.affected_resources(_current_card, true))
	elif _current_drag >= PREVIEW_THRESHOLD:
		_set_affected(CardUtils.affected_resources(_current_card, false))
	else:
		_clear_affected()

	_apply_drag()

func _set_affected(keys: Array) -> void:
	for key in _bars:
		_bars[key].set_affected(key in keys)

func _clear_affected() -> void:
	for key in _bars:
		_bars[key].set_affected(false)

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
	_releasing = false
	_grabbing = false
	_card_panel.scale = Vector2.ONE
	_clear_affected()
	_card_choice.modulate.a = 0.0
	var target_x = _card_base_pos.x + direction * get_viewport_rect().size.x * 1.5
	var target_rot = deg_to_rad(direction * 18.0)
	var tween = create_tween().set_parallel()
	tween.tween_property(_card_panel, "position:x", target_x, 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_card_panel, "rotation", target_rot, 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_card_panel, "modulate:a", 0.0, 0.36).set_delay(0.06)
	await tween.finished
	choice_made.emit(direction < 0)

# ── Réaction après le choix ──────────────────────────────────────────

func show_reaction(card: Dictionary, is_left: bool, ctx: Context) -> bool:
	_update_bars(ctx)
	_update_whisper(ctx)
	_update_info(ctx)

	var answer = card.get("leftAnswer" if is_left else "rightAnswer", {})
	var reaction = answer.get("reaction", {})
	var text: String = str(reaction.get("FR", reaction.get("EN", ""))).strip_edges()
	if text == "":
		return false

	_reaction_visible = true
	_releasing = false
	# réaction = écriture manuscrite (Caveat), remplace la question
	_question.text = text
	_question.add_theme_font_override("font", FONT_CAVEAT)
	_question.add_theme_font_size_override("font_size", 27)
	_question.add_theme_color_override("font_color", Color(0.749, 0.914, 0.945))
	_card_choice.modulate.a = 0.0
	_current_drag = 0.0
	_reset_anim_state()
	_card_panel.rotation = 0.0
	_entry_pending = true
	_card_panel.modulate.a = 0.0
	_reaction_shown_ms = Time.get_ticks_msec()
	_layout_card.call_deferred()
	_fit_question.call_deferred()
	return true

func _dismiss_reaction() -> void:
	if not _reaction_visible:
		return
	if Time.get_ticks_msec() - _reaction_shown_ms < MIN_REACTION_MS:
		return
	_reaction_visible = false
	reaction_dismissed.emit()

# Bannière inline « Nouveau deck » (app.jsx .deck-add + .deck-banner) :
# des cartes glissent dans la pile (addSlide, décalées de 90 ms) + une bannière
# centrée apparaît ~2,2 s. Non bloquant : la carte courante reste jouable.
func play_deck_unlock(entry: Dictionary) -> void:
	var deck_id := str(entry.get("id", ""))
	var deck_name := str(entry.get("name", "Nouveau deck"))
	var count := 0
	if _game_data and ("cards" in _game_data):
		for c in _game_data.cards:
			if str(c.get("deck", "")) == deck_id:
				count += 1
	var n := clampi(count if count > 0 else 4, 3, 6)

	var fx := Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_area.add_child(fx)

	var side: float = _card_side if _card_side > 0.0 else 280.0
	var target := _card_base_pos + Vector2(10, 10)
	for i in range(n):
		var ac := Panel.new()
		ac.size = Vector2(side, side)
		ac.pivot_offset = Vector2(side, side) * 0.5
		ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1b2433")
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.471, 0.784, 0.863, 0.16)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 16
		sb.shadow_offset = Vector2(0, 10)
		ac.add_theme_stylebox_override("panel", sb)
		ac.position = _card_base_pos + Vector2(140, 150)
		ac.rotation = deg_to_rad(16)
		ac.scale = Vector2(0.9, 0.9)
		ac.modulate.a = 0.0
		fx.add_child(ac)
		var delay := i * 0.09
		var t := ac.create_tween().set_parallel()
		t.tween_property(ac, "modulate:a", 1.0, 0.2).set_delay(delay)
		t.tween_property(ac, "position", target, 0.5).set_delay(delay) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(ac, "rotation", deg_to_rad(2.5), 0.5).set_delay(delay) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(ac, "scale", Vector2.ONE, 0.5).set_delay(delay) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_build_unlock_banner(fx, deck_name, n)

	get_tree().create_timer(2.4).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free()
	, CONNECT_ONE_SHOT)

func _build_unlock_banner(parent: Control, deck_name: String, count: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)

	var banner := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.094, 0.149, 0.94)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.31, 0.839, 0.91, 0.55)
	sb.shadow_color = Color(0.31, 0.839, 0.91, 0.35)
	sb.shadow_size = 22
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	banner.add_theme_stylebox_override("panel", sb)
	center.add_child(banner)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 7)
	banner.add_child(vb)

	var tag := Label.new()
	tag.text = "N O U V E A U   D E C K"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", _question_font_regular)
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", ThemeColors.ACCENT)
	vb.add_child(tag)

	var nm := Label.new()
	nm.text = deck_name
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_override("font", FONT_CAVEAT)
	nm.add_theme_font_size_override("font_size", 28)
	nm.add_theme_color_override("font_color", Color(0.933, 0.973, 0.984))
	vb.add_child(nm)

	var cnt := Label.new()
	cnt.text = "+%d cartes" % count
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_override("font", _question_font_regular)
	cnt.add_theme_font_size_override("font_size", 9)
	cnt.add_theme_color_override("font_color", Color(0.624, 0.706, 0.769))
	vb.add_child(cnt)

	# bannerIn : apparition (scale .9→1, fondu) → maintien → disparition
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	banner.set_deferred("pivot_offset", Vector2.ZERO)
	await get_tree().process_frame
	if not is_instance_valid(banner):
		return
	banner.pivot_offset = banner.size * 0.5
	var tw := banner.create_tween()
	tw.set_parallel()
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.2)

# Avant l'écran de mort : simple fondu de la carte (le glitch holographique de
# Main prend le relais — pas de wobble de l'ancien design).
func play_defeat() -> void:
	_can_swipe = false
	_releasing = false
	var tw := create_tween()
	tw.tween_property(_card_panel, "modulate:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
