extends Control

# Overlay modal de déblocage de deck : empilement de cartes holographiques
# + « NOUVEAU DECK / nom / DÉBLOQUÉ », puis tap pour continuer.

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")

signal continue_pressed

const CARD_COUNT := 5
const CARD_SIZE := Vector2(116, 162)

var _stack: Control
var _name_label: Label
var _sub_label: Label
var _hint: Label
var _cards: Array = []
var _stack_tween: Tween
var _can_continue: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	col.add_child(_mk_label("NOUVEAU DECK", FONT_MONO, 12, ThemeColors.ACCENT))
	_stack = Control.new()
	_stack.custom_minimum_size = CARD_SIZE + Vector2(60, 40)
	col.add_child(_stack)
	_name_label = _mk_label("", FONT_SPECTRAL, 24, ThemeColors.INK)
	col.add_child(_name_label)
	col.add_child(_mk_label("DÉBLOQUÉ", FONT_MONO, 12, ThemeColors.AMBER))
	_sub_label = _mk_label("", FONT_SPECTRAL, 13, ThemeColors.INK_DIM)
	col.add_child(_sub_label)
	_hint = _mk_label("Tap pour continuer", FONT_MONO, 11, ThemeColors.INK_FAINT)
	col.add_child(_hint)

func _mk_label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _mk_card() -> Panel:
	var p := Panel.new()
	p.size = CARD_SIZE
	p.pivot_offset = CARD_SIZE * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.16, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(ThemeColors.ACCENT.r, ThemeColors.ACCENT.g, ThemeColors.ACCENT.b, 0.5)
	sb.shadow_color = Color(ThemeColors.ACCENT.r, ThemeColors.ACCENT.g, ThemeColors.ACCENT.b, 0.22)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	return p

func show_unlock(entry: Dictionary) -> void:
	_name_label.text = "« %s »" % str(entry.get("name", "Deck"))
	_sub_label.text = str(entry.get("subtitle", ""))
	_sub_label.visible = _sub_label.text != ""
	for n in [_name_label, _sub_label, _hint]:
		n.modulate.a = 0.0
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_can_continue = false
	Anim.fade_in(self, 0.2)
	await get_tree().process_frame   # _stack a sa taille
	var s := Anim.settings
	var base := (_stack.size - CARD_SIZE) * 0.5
	if _stack_tween and _stack_tween.is_valid():
		_stack_tween.kill()
	var tw := create_tween().set_parallel()
	_stack_tween = tw
	for i in range(CARD_COUNT):
		var card := _mk_card()
		_stack.add_child(card)
		var fan := (i - (CARD_COUNT - 1) / 2.0)
		var final_pos := base + Vector2(fan * s.unlock_card_offset, 0.0)
		var final_rot := deg_to_rad(fan * s.unlock_card_tilt)
		card.position = base + Vector2(0.0, 420.0)
		card.rotation = 0.0
		var delay := i * s.unlock_stagger
		tw.tween_property(card, "position", final_pos, s.unlock_card_fly) \
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "rotation", final_rot, s.unlock_card_fly) \
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_cards.append(card)
	await get_tree().create_timer((CARD_COUNT - 1) * s.unlock_stagger + s.unlock_card_fly).timeout
	Anim.reveal_list([_name_label, _sub_label, _hint], s.unlock_stagger, s.unlock_text_in)
	_can_continue = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _can_continue:
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		continue_pressed.emit()
		get_viewport().set_input_as_handled()
