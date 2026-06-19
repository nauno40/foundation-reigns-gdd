extends Control

const SaveSystem = preload("res://src/core/SaveSystem.gd")
const OPTIONS_SCENE = preload("res://scenes/OptionsScreen.tscn")

@onready var _title: Label = %Title
@onready var _new_btn: Button = %NewGameBtn
@onready var _cont_btn: Button = %ContinueBtn
@onready var _opts_btn: Button = %OptionsBtn
@onready var _quit_btn: Button = %QuitBtn

var _options: Control

func _ready() -> void:
	if Globals.start_mode != Globals.StartMode.NONE:
		_start_game()
		return

	_style_main_btn(_new_btn, true)
	_style_main_btn(_cont_btn, false)
	_style_secondary_btn(_opts_btn)
	_style_secondary_btn(_quit_btn)

	var save = SaveSystem.new()
	if not save.has_save():
		_cont_btn.disabled = true

	_new_btn.pressed.connect(_on_new_game)
	_cont_btn.pressed.connect(_on_continue)
	_opts_btn.pressed.connect(_on_options)
	_quit_btn.pressed.connect(_on_quit)

	_menu_enter()

func _menu_enter() -> void:
	# Cascade : le menu global reste visible ; reveal_list anime chaque nœud séparément
	modulate.a = 1.0
	var s := Anim.settings
	Anim.reveal_list([_title, _new_btn, _cont_btn, _opts_btn, _quit_btn],
		s.menu_stagger, s.menu_item_in)

func _style_main_btn(btn: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.31, 0.839, 0.91, 0.06) if primary else Color(0.31, 0.839, 0.91, 0.0)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.31, 0.839, 0.91, 0.6) if primary else Color(0.31, 0.839, 0.91, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8
	normal.content_margin_left = 12.0
	normal.content_margin_top = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_bottom = 12.0

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.31, 0.839, 0.91, 0.12)
	hover.border_width_left = 1
	hover.border_width_top = 1
	hover.border_width_right = 1
	hover.border_width_bottom = 1
	hover.border_color = Color(0.31, 0.839, 0.91, 1)
	hover.corner_radius_top_left = 8
	hover.corner_radius_top_right = 8
	hover.corner_radius_bottom_right = 8
	hover.corner_radius_bottom_left = 8
	hover.content_margin_left = 12.0
	hover.content_margin_top = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_bottom = 12.0
	hover.shadow_color = Color(0.31, 0.839, 0.91, 0.2)
	hover.shadow_size = 12

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("disabled", normal)

func _style_secondary_btn(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 8.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_bottom = 8.0

	var hover := normal.duplicate()
	hover.bg_color = Color(0.31, 0.839, 0.91, 0.06)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_right = 6
	hover.corner_radius_bottom_left = 6

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)

func _on_new_game() -> void:
	Globals.start_mode = Globals.StartMode.NEW_GAME
	_start_game()

func _on_continue() -> void:
	Globals.start_mode = Globals.StartMode.CONTINUE
	_start_game()

func _on_options() -> void:
	if not _options:
		_options = OPTIONS_SCENE.instantiate()
		add_child(_options)
		_options.back_pressed.connect(_on_options_back)
	_options.show()

func _on_options_back() -> void:
	if _options:
		_options.apply()
		_options.hide()

func _on_quit() -> void:
	get_tree().quit()

func _start_game() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
