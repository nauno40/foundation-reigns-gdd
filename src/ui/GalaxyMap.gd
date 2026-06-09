class_name GalaxyMap
extends Control

const COLOR_ALLIED  = Color(0.2, 0.8, 0.2)
const COLOR_NEUTRAL = Color(0.6, 0.6, 0.6)
const COLOR_HOSTILE = Color(0.8, 0.2, 0.2)

const PLANET_IDS = [
	"terminus", "trantor", "anacreon", "santanni", "smyrno",
	"askone", "korell", "siwenna", "kalgan", "neotrantor",
	"rossem", "sayshell"
]

@onready var _planets_container = $PlanetsContainer
@onready var _popup         = $PlanetPopup
@onready var _popup_name    = $PlanetPopup/PopupName
@onready var _popup_faction = $PlanetPopup/PopupFaction
@onready var _popup_state   = $PlanetPopup/PopupState
@onready var _close_btn     = $PlanetPopup/CloseButton

var _game_data: FoundationGameData
var _ctx_ref: Context

func _ready() -> void:
	_close_btn.pressed.connect(func(): _popup.hide())
	_popup.hide()

func setup(game_data: FoundationGameData) -> void:
	_game_data = game_data

func update(ctx: Context) -> void:
	_ctx_ref = ctx
	for planet_id in PLANET_IDS:
		var btn = _planets_container.get_node_or_null(planet_id.capitalize())
		if not btn:
			continue
		var state = ctx.get_var("planet_%s_state" % planet_id, 0)
		_set_planet_color(btn, state)
		if not btn.pressed.is_connected(_on_planet_pressed.bind(planet_id)):
			btn.pressed.connect(_on_planet_pressed.bind(planet_id))

func _set_planet_color(btn: Button, state: int) -> void:
	var color = COLOR_NEUTRAL
	match state:
		1: color = COLOR_ALLIED
		-1: color = COLOR_HOSTILE
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

func _on_planet_pressed(planet_id: String) -> void:
	if not _game_data or not _ctx_ref:
		return
	var planet = _game_data.get_planet_by_id(planet_id)
	if planet.is_empty():
		return

	var state = _ctx_ref.get_var("planet_%s_state" % planet_id, 0)
	var state_text = {1: "Alignee", 0: "Neutre", -1: "Hostile"}

	_popup_name.text    = planet.get("name", planet_id)
	_popup_faction.text = "Faction : " + planet.get("faction", "?")
	_popup_state.text   = "Etat : " + state_text.get(state, "?")
	_popup.show()
