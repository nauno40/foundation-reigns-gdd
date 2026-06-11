class_name DeathScreen
extends Control

# Écran de mort du prototype : cause, identité de l'Orateur, message
# holographique de Seldon, grille de stats 2×2, snapshot des 4
# ressources avec mini-barres, bouton « Nouveau règne → ».

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")

signal continue_pressed

@onready var _cause: Label = %Cause
@onready var _speaker: Label = %SpeakerName
@onready var _subtitle: Label = %Subtitle
@onready var _seldon_text: Label = %SeldonText
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _snapshot: HBoxContainer = %Snapshot
@onready var _btn: Button = %RespawnButton

var _stat_values: Dictionary = {}

func _ready() -> void:
	_btn.pressed.connect(func(): continue_pressed.emit())
	_build_stats_grid()

func _build_stats_grid() -> void:
	for label in ["DÉCISIONS PRISES", "ANNÉES COUVERTES", "SCORE DU RÈGNE", "PLAN DE SELDON"]:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_width_top = 1
		sb.border_color = ThemeColors.LINE
		sb.content_margin_top = 8.0
		box.add_theme_stylebox_override("panel", sb)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		box.add_child(vb)

		var l := Label.new()
		l.text = label
		l.add_theme_font_override("font", FONT_MONO)
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
		vb.add_child(l)

		var v := Label.new()
		v.text = "—"
		v.add_theme_font_override("font", FONT_SPECTRAL)
		v.add_theme_font_size_override("font_size", 15)
		v.add_theme_color_override("font_color", ThemeColors.INK)
		vb.add_child(v)

		_stat_values[label] = v
		_stats_grid.add_child(box)

func show_death(ctx: Context, death_type: String, cover_name: String) -> void:
	var year = ctx.get_var("year", 1)
	var y_start = ctx.get_var("y_start", 1)
	var age = ctx.get_var("age", 50)
	var turns = ctx.get_var("turns", 0)

	_cause.text = ThemeColors.death_label(death_type).to_upper()
	_speaker.text = "Orateur — " + str(cover_name)
	_subtitle.text = "%s · %d ans · Règne couvert An %d → An %d" % [cover_name, age, y_start, year]
	_seldon_text.text = "« " + ThemeColors.death_message(death_type) + " »"

	_stat_values["DÉCISIONS PRISES"].text = str(turns)
	_stat_values["ANNÉES COUVERTES"].text = "%d ans" % max(year - y_start, 0)
	_stat_values["SCORE DU RÈGNE"].text = "%d pts" % (60 + turns * 8)
	_stat_values["PLAN DE SELDON"].text = "dévié de %.1f %%" % randf_range(2.0, 8.0)

	_build_snapshot(ctx)

func _build_snapshot(ctx: Context) -> void:
	for child in _snapshot.get_children():
		child.queue_free()

	for r in Context.RESOURCES:
		var val: int = ctx.get_var(r, 50)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)

		var lab := Label.new()
		lab.text = ThemeColors.resource_label(r).to_upper()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", FONT_MONO)
		lab.add_theme_font_size_override("font_size", 9)
		lab.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
		col.add_child(lab)

		var value := Label.new()
		value.text = str(val)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_override("font", FONT_MONO)
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", ThemeColors.INK)
		col.add_child(value)

		var track := PanelContainer.new()
		track.custom_minimum_size = Vector2(0, 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.08)
		sb.set_corner_radius_all(2)
		track.add_theme_stylebox_override("panel", sb)
		col.add_child(track)

		var fill_holder := Control.new()
		track.add_child(fill_holder)
		var fill := ColorRect.new()
		fill.color = ThemeColors.resource_color(r)
		fill.anchor_left = 0.0
		fill.anchor_top = 0.0
		fill.anchor_bottom = 1.0
		fill.anchor_right = clampf(val / 100.0, 0.0, 1.0)
		fill_holder.add_child(fill)

		_snapshot.add_child(col)
