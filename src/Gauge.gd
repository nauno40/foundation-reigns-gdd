@tool
class_name Gauge
extends Control

# Jauge icône-masque. Structure dans Gauge.tscn ; ce script ne gère que la logique
# (valeur, états warn/crit/affected, flash ▲/▼). setup() fixe l'icône + la couleur.

const ICONS := {
	"military": preload("res://assets/icons/military.svg"),
	"religion": preload("res://assets/icons/religion.svg"),
	"commerce": preload("res://assets/icons/commerce.svg"),
	"politics": preload("res://assets/icons/politics.svg"),
}
const BASE_NORMAL := Color(0.235, 0.282, 0.376)   # #3c4860
const BASE_AFF := Color(0.490, 0.565, 0.659)      # #7d90a8
const UP := Color("#5fcf8f")
const DOWN := Color("#d96a5a")

@onready var _delta: Label = %Delta
@onready var _glow: TextureRect = %Glow
@onready var _flash: TextureRect = %Flash
@onready var _icon: TextureRect = %Icon
@onready var _lab: Label = %Label

var _key := ""
var _value := 50
var _display := 50.0
var _affected := false
var _mat: ShaderMaterial
var _vt: Tween
var _gt: Tween

func _ready() -> void:
	# Aperçu éditeur : icône + remplissage d'exemple (sinon glyphe vide).
	if Engine.is_editor_hint():
		var tex: Texture2D = ICONS["military"]
		_icon.texture = tex
		_glow.texture = tex
		_flash.texture = tex
		_icon.material.set_shader_parameter("res_color", Pal.res_color("military"))
		_icon.material.set_shader_parameter("base_color", BASE_NORMAL)
		_icon.material.set_shader_parameter("fill", 0.5)
		_lab.text = "MILITAIRE"
		_lab.add_theme_color_override("font_color", Color("#aab5c8"))

func setup(key: String, label: String) -> void:
	_key = key
	if not is_node_ready():
		await ready
	var tex: Texture2D = ICONS.get(key)
	_icon.texture = tex
	_glow.texture = tex
	_flash.texture = tex
	_mat = _icon.material
	_mat.set_shader_parameter("res_color", Pal.res_color(key))
	_mat.set_shader_parameter("base_color", BASE_NORMAL)
	_lab.text = label.to_upper()
	_refresh()

func set_value(v: int) -> void:
	var target := clampi(v, 0, 100)
	if target != _value:
		_flash_delta(signi(target - _value))
	if _vt and _vt.is_valid(): _vt.kill()
	_vt = create_tween()
	_vt.tween_method(func(x): _display = x; _mat.set_shader_parameter("fill", x / 100.0),
		_display, float(target), 0.55).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_value = target
	_refresh()

func set_affected(a: bool) -> void:
	if a == _affected: return
	_affected = a
	_mat.set_shader_parameter("base_color", BASE_AFF if a else BASE_NORMAL)
	_refresh()

func _zone() -> String:
	if _value < 15 or _value > 85: return "crit"
	if _value < 25 or _value > 75: return "warn"
	return ""

func refresh() -> void:
	_refresh()

func _refresh() -> void:
	if not _glow: return
	var zone := _zone()
	var lc := Color("#aab5c8")
	var gc := Color.TRANSPARENT
	var pulse := false
	if _affected:
		gc = Cfg.accent; lc = Cfg.accent
	elif zone == "crit":
		gc = Pal.DANGER; lc = Pal.DANGER; pulse = true
	elif zone == "warn":
		gc = Pal.AMBER; lc = Pal.AMBER
	_lab.add_theme_color_override("font_color", lc)
	if _gt and _gt.is_valid(): _gt.kill()
	if gc == Color.TRANSPARENT:
		_glow.modulate = Color(1, 1, 1, 0.0)
		return
	_glow.modulate = Color(gc.r, gc.g, gc.b, 0.55)
	if pulse:
		_gt = create_tween().set_loops()
		_gt.tween_method(func(al): _glow.modulate = Color(gc.r, gc.g, gc.b, al), 0.32, 0.7, 0.525)
		_gt.tween_method(func(al): _glow.modulate = Color(gc.r, gc.g, gc.b, al), 0.7, 0.32, 0.525)

func _flash_delta(sign: int) -> void:
	var up := sign >= 0
	var c := UP if up else DOWN
	_delta.text = "▲" if up else "▼"
	_delta.add_theme_color_override("font_color", c)
	_delta.modulate.a = 0.0
	_delta.offset_top = 1.0
	var t := create_tween()
	t.set_parallel()
	t.tween_property(_delta, "modulate:a", 1.0, 0.2)
	t.tween_property(_delta, "offset_top", -3.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.4)
	t.chain().tween_property(_delta, "modulate:a", 0.0, 0.3)
	_flash.modulate = Color(c.r, c.g, c.b, 0.0)
	var f := create_tween()
	f.tween_property(_flash, "modulate:a", 0.7, 0.18)
	f.tween_property(_flash, "modulate:a", 0.0, 0.55)
