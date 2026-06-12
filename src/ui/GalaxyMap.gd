class_name GalaxyMap
extends Control

# Carte galactique interactive : 12 points lumineux colorés par l'état de la
# planète (vert alignée / gris neutre / rouge hostile), clic → popup
# (nom, faction, état, bouton VOYAGER si planète ≠ position actuelle).
# Fermeture via ✕. Voyage : émet jump_requested(planet_id).

signal jump_requested(planet_id: String)

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")

const COLOR_ALLIED  = Color("#5fcf8f")
const COLOR_NEUTRAL = Color("#7d8aa3")
const COLOR_HOSTILE = Color("#d96a5a")

# Positions normalisées (0–1) — Terminus à la périphérie, Trantor au centre
const PLANET_POS = {
	"terminus":   Vector2(0.86, 0.16),
	"anacreon":   Vector2(0.74, 0.28),
	"smyrno":     Vector2(0.62, 0.16),
	"santanni":   Vector2(0.80, 0.46),
	"askone":     Vector2(0.60, 0.38),
	"korell":     Vector2(0.66, 0.58),
	"trantor":    Vector2(0.42, 0.46),
	"neotrantor": Vector2(0.50, 0.54),
	"siwenna":    Vector2(0.46, 0.68),
	"kalgan":     Vector2(0.30, 0.56),
	"rossem":     Vector2(0.20, 0.24),
	"sayshell":   Vector2(0.26, 0.78),
}

@onready var _map_area: Control = %MapArea
@onready var _popup: PanelContainer = %PlanetPopup
@onready var _popup_name: Label = %PopupName
@onready var _popup_faction: Label = %PopupFaction
@onready var _popup_state: Label = %PopupState
@onready var _close_btn: Button = %CloseButton
@onready var _popup_close: Button = %PopupClose

var _game_data: FoundationGameData
var _ctx_ref: Context
var _buttons: Dictionary = {}
var _travel_btn: Button
var _popup_planet: String = ""

func _ready() -> void:
	_close_btn.pressed.connect(_on_close)
	_popup_close.pressed.connect(func(): _popup.hide())
	_popup.hide()
	_build_planets()
	_map_area.resized.connect(_position_planets)

	# Bouton de voyage ajouté dynamiquement dans la VBox du popup
	_travel_btn = Button.new()
	_travel_btn.text = "VOYAGER →"
	_travel_btn.focus_mode = Control.FOCUS_NONE
	_travel_btn.add_theme_font_override("font", FONT_MONO)
	_travel_btn.add_theme_font_size_override("font_size", 10)
	_travel_btn.pressed.connect(_on_travel_pressed)
	%PopupState.get_parent().add_child(_travel_btn)

func _on_close() -> void:
	_popup.hide()
	hide()

func setup(game_data: FoundationGameData) -> void:
	_game_data = game_data

func _build_planets() -> void:
	for planet_id in PLANET_POS:
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 4)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(16, 16)
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_planet_pressed.bind(planet_id))
		holder.add_child(btn)

		var lab := Label.new()
		lab.text = planet_id.capitalize()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", FONT_MONO)
		lab.add_theme_font_size_override("font_size", 8)
		lab.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
		holder.add_child(lab)

		_map_area.add_child(holder)
		_buttons[planet_id] = btn
	_position_planets()

func _position_planets() -> void:
	var area: Vector2 = _map_area.size
	for planet_id in PLANET_POS:
		var btn: Button = _buttons[planet_id]
		var holder: Control = btn.get_parent()
		var pos: Vector2 = PLANET_POS[planet_id]
		holder.position = Vector2(pos.x * area.x - 24, pos.y * area.y - 8)

func update(ctx: Context) -> void:
	_ctx_ref = ctx
	for planet_id in _buttons:
		var state: int = ctx.get_var("planet_%s_state" % planet_id, 0)
		_style_planet(_buttons[planet_id], state)

func _on_travel_pressed() -> void:
	_popup.hide()
	hide()
	jump_requested.emit(_popup_planet)

func _style_planet(btn: Button, state: int) -> void:
	var color := COLOR_NEUTRAL
	match state:
		1: color = COLOR_ALLIED
		-1: color = COLOR_HOSTILE
	for style_name in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(99)
		sb.shadow_color = Color(color.r, color.g, color.b, 0.55 if style_name == "hover" else 0.4)
		sb.shadow_size = 8 if style_name == "hover" else 6
		btn.add_theme_stylebox_override(style_name, sb)

func _on_planet_pressed(planet_id: String) -> void:
	if not _game_data or not _ctx_ref:
		return
	var planet: Dictionary = _game_data.get_planet_by_id(planet_id)
	if planet.is_empty():
		return

	var state: int = _ctx_ref.get_var("planet_%s_state" % planet_id, 0)
	var state_text := {1: "Alignée", 0: "Neutre", -1: "Hostile"}
	var state_color := {1: COLOR_ALLIED, 0: COLOR_NEUTRAL, -1: COLOR_HOSTILE}

	_popup_name.text = planet.get("name", planet_id.capitalize())
	_popup_faction.text = "Faction : " + str(planet.get("faction", "—"))
	_popup_state.text = "État : " + state_text.get(state, "?")
	_popup_state.add_theme_color_override("font_color", state_color.get(state, ThemeColors.INK_DIM))
	_popup.show()

	# Mémoriser la planète et afficher le bouton VOYAGER si ce n'est pas
	# la planète actuelle du Speaker
	_popup_planet = planet_id
	var here: String = str(_ctx_ref.get_var("location", "terminus"))
	_travel_btn.visible = planet_id != here
