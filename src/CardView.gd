@tool
class_name CardView
extends Control

# Carte (port de app.jsx Card) : suivi direct du doigt, rot=drag*0.055°, scale 1.025
# en saisie, ressort sous-amorti au relâchement, fly-out 150%/18° au commit (seuil 92).

const FACE_SHADER = preload("res://assets/shaders/card_face.gdshader")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_MONO_BOLD = preload("res://assets/fonts/SpaceMono-Bold.ttf")

signal committed(is_left: bool)
signal preview(side: String)   # "left" / "right" / ""

# Réglages de la carte (mêmes valeurs que les const d'origine), exposés à l'inspecteur.
@export var threshold: float = 92.0
@export var reveal_threshold: float = 12.0
@export var rotation_per_drag: float = 0.055
@export var grab_scale: float = 1.025
@export var stiffness: float = 0.16
@export var damping: float = 0.74
@export var flyout_distance: float = 700.0
@export var flyout_duration: float = 0.42

var _base := Vector2.ZERO
var _drag := 0.0
var _drag_y := 0.0
var _grabbing := false
var _releasing := false
var _entering := false
var _vx := 0.0
var _vy := 0.0
var _start := Vector2.ZERO
var _flying := false
var _left_title := ""
var _right_title := ""

@onready var _face: ColorRect = %FaceBg
@onready var _bust: CardBust = %Bust
@onready var _keytag: Label = %KeyTag
@onready var _choice: Label = %CardChoice
var _mat: ShaderMaterial

func _ready() -> void:
	_mat = _face.material
	if Engine.is_editor_hint():
		_editor_preview()
		return
	set_process(true)

func _editor_preview() -> void:
	# Aperçu éditeur : carte teintée + buste + badge, SANS repositionner la carte
	# (on respecte le placement défini dans la scène).
	var s := minf(size.x, size.y)
	if s <= 0.0:
		s = 300.0
	var tone := Data.tone_for("hari")
	_mat.set_shader_parameter("tone_lo", tone)
	_mat.set_shader_parameter("tone_hi", Data.lighten(tone, 0.18))
	_place_children(s)
	_bust.set_tone(tone)
	_bust.set_initials("HS")
	_keytag.visible = true

func layout(base: Vector2, side: float) -> void:
	_base = base
	size = Vector2(side, side)
	pivot_offset = Vector2(side, side) * 0.5
	_place_children(side)
	_apply()

func _place_children(side: float) -> void:
	_bust.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var bw := side * 0.64
	var bh := side * 0.80
	_bust.position = Vector2((side - bw) / 2.0, side - bh)
	_bust.size = Vector2(bw, bh)
	_bust.queue_redraw()
	_keytag.position = Vector2(side - 11 - 110, 11)
	_keytag.size = Vector2(110, 20)
	_choice.position = Vector2(15, 15)
	_choice.size = Vector2(side - 30, 56)
	_mat.set_shader_parameter("rect_size", Vector2(side, side))

func show_card(card: Dictionary) -> void:
	_flying = false
	_releasing = false
	_grabbing = false
	_drag = 0.0
	_drag_y = 0.0
	_vx = 0.0
	_vy = 0.0
	_left_title = card["left"]["title"]
	_right_title = card["right"]["title"]
	_choice.modulate.a = 0.0
	_keytag.visible = bool(card.get("key", false))
	_keytag.modulate.a = 1.0
	var tone := Data.tone_for(card["id"])
	_bust.set_tone(tone)
	_bust.set_initials(Data.initials(card["bearer"]))
	_mat.set_shader_parameter("tone_lo", tone)
	_mat.set_shader_parameter("tone_hi", Data.lighten(tone, 0.12))

func play_entry() -> void:
	_entering = true
	var off := Vector2(8, 12)
	modulate.a = 0.0
	position = _base + off
	rotation = deg_to_rad(2.2)
	scale = Vector2(0.965, 0.965)
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.16)
	# position : lit _base EN DIRECT (résiste aux changements de layout pendant l'entrée)
	t.tween_method(func(p): position = _base + off * (1.0 - p), 0.0, 1.0, 0.36).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "rotation", 0.0, 0.36).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "scale", Vector2.ONE, 0.36).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	get_tree().create_timer(0.38).timeout.connect(func(): _entering = false, CONNECT_ONE_SHOT)

func _gui_input(e: InputEvent) -> void:
	if _flying: return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_grabbing = true
			_releasing = false
			_start = e.position
		else:
			_grabbing = false
			if absf(_drag) >= threshold:
				_fly_out(-1.0 if _drag < 0 else 1.0)
			else:
				_releasing = true
			preview.emit("")
	elif e is InputEventMouseMotion and _grabbing:
		_drag = e.position.x - _start.x
		_drag_y = (e.position.y - _start.y) * 0.4
		_apply()
		_update_choice()
		preview.emit("left" if _drag < -22.0 else ("right" if _drag > 22.0 else ""))

func _process(_dt: float) -> void:
	if _releasing and not _flying:
		_vx = (_vx + (-_drag) * stiffness) * damping
		_drag += _vx
		_vy = (_vy + (-_drag_y) * stiffness) * damping
		_drag_y += _vy
		if absf(_drag) < 0.3 and absf(_vx) < 0.3 and absf(_drag_y) < 0.3:
			_drag = 0.0; _drag_y = 0.0; _releasing = false
		_apply()
		_update_choice()

func _apply() -> void:
	if _flying or _entering: return
	position = _base + Vector2(_drag, _drag_y)
	rotation = deg_to_rad(_drag * rotation_per_drag)
	var s := grab_scale if _grabbing else 1.0
	scale = Vector2(s, s)

func _update_choice() -> void:
	if absf(_drag) > reveal_threshold:
		var right := _drag > 0.0
		_choice.text = _right_title if right else _left_title
		_choice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		_choice.modulate.a = clampf(absf(_drag) / 40.0, 0.0, 1.0)
		_keytag.modulate.a = 0.0
	else:
		_choice.modulate.a = 0.0
		_keytag.modulate.a = 1.0

func _fly_out(dir: float) -> void:
	_flying = true
	_releasing = false
	_grabbing = false
	scale = Vector2.ONE
	preview.emit("")
	var target_x := _base.x + dir * flyout_distance
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:x", target_x, flyout_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "rotation", deg_to_rad(dir * 18.0), flyout_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate:a", 0.0, 0.36).set_delay(0.06)
	await t.finished
	committed.emit(dir < 0)

# Pour le swipe clavier (← / →).
func swipe(is_left: bool) -> void:
	if _flying: return
	_fly_out(-1.0 if is_left else 1.0)
