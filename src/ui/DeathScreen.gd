class_name DeathScreen
extends Control

# Écran de mort du prototype : cause, identité de l'Orateur, message
# holographique de Seldon, grille de stats 2×2, snapshot des 4
# ressources avec mini-barres, bouton « Nouveau règne → ».
# Entrée animée : background fade + éléments staggered.

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const RES_ICONS := {
	"military": preload("res://assets/icons/military.svg"),
	"religion": preload("res://assets/icons/religion.svg"),
	"commerce": preload("res://assets/icons/commerce.svg"),
	"politics": preload("res://assets/icons/politics.svg"),
}

signal continue_pressed

@onready var _bg: ColorRect = %Background
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
	_bg.modulate.a = 0.0

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

func show_death(ctx: Context, death_type: String, cover_name: String,
		meta: Dictionary = {}) -> void:
	var year = ctx.get_var("year", 1)
	var y_start = ctx.get_var("y_start", 1)
	var age = ctx.get_var("age", 50)
	var turns = ctx.get_var("turns", 0)

	_cause.text = ThemeColors.death_label(death_type).to_upper()
	_speaker.text = "Orateur — " + str(cover_name)
	# Sous-titre iso au template : « {âge} ans · Règne couvert : An X → An Y ».
	_subtitle.text = "%d ans · Règne couvert : An %d → An %d" % [age, y_start, year]
	_seldon_text.text = "« " + ThemeColors.death_message(death_type) + " »"

	# Stats affichées directement (le template n'anime pas de compteur).
	var reign_score = int(meta.get("score", 0))
	var years = max(year - y_start, 0)
	_stat_values["DÉCISIONS PRISES"].text = str(turns)
	_stat_values["ANNÉES COUVERTES"].text = "%d ans" % years
	_stat_values["SCORE DU RÈGNE"].text = "%d pts" % reign_score
	_stat_values["PLAN DE SELDON"].text = "dévié de %.1f %%" % randf_range(2.0, 8.0)

	for n in [_cause, _speaker, _subtitle, _seldon_text]:
		n.modulate.a = 1.0
	_bg.modulate.a = 1.0
	_build_snapshot(ctx)

	# deathIn (app.jsx) : flash lumineux + léger zoom de tout l'écran.
	pivot_offset = size * 0.5
	scale = Vector2(1.035, 1.035)
	modulate = Color(1.7, 1.7, 1.7)
	var tw = create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# cause : scintillement (dthFlick)
	var fk = create_tween()
	for a in [0.3, 1.0, 0.5, 1.0]:
		fk.tween_property(_cause, "modulate:a", a, 0.09)

func _build_snapshot(ctx: Context) -> void:
	for child in _snapshot.get_children():
		child.queue_free()

	for r in Context.RESOURCES:
		var val: int = ctx.get_var(r, 50)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)

		# icône de ressource (template Death .snap .g), teintée à la couleur ressource
		var icon_holder := CenterContainer.new()
		icon_holder.custom_minimum_size = Vector2(0, 22)
		var icon := TextureRect.new()
		icon.texture = RES_ICONS.get(r)
		icon.custom_minimum_size = Vector2(21, 21)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = ThemeColors.resource_color(r)
		icon_holder.add_child(icon)
		col.add_child(icon_holder)

		var lab := Label.new()
		lab.text = ThemeColors.resource_label(r).to_upper()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", FONT_MONO)
		lab.add_theme_font_size_override("font_size", 8)
		lab.add_theme_color_override("font_color", ThemeColors.INK_FAINT)
		col.add_child(lab)

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
