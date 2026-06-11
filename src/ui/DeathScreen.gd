class_name DeathScreen
extends Control

const ThemeColors = preload("res://src/ui/ThemeColors.gd")

signal continue_pressed

@onready var _cause = $Scroll/MainVBox/Padding/InnerVBox/CauseLabel
@onready var _speaker = $Scroll/MainVBox/Padding/InnerVBox/SpeakerName
@onready var _subtitle = $Scroll/MainVBox/Padding/InnerVBox/Subtitle
@onready var _seldon_text = $Scroll/MainVBox/Padding/InnerVBox/SeldonPanel/SeldonVBox/SeldonText
@onready var _stat_decisions = $Scroll/MainVBox/Padding/InnerVBox/StatsGrid/StatDecisions/StatValue
@onready var _stat_years = $Scroll/MainVBox/Padding/InnerVBox/StatsGrid/StatYears/StatValue2
@onready var _stat_score = $Scroll/MainVBox/Padding/InnerVBox/StatsGrid/StatScore/StatValue3
@onready var _stat_deviation = $Scroll/MainVBox/Padding/InnerVBox/StatsGrid/StatDeviation/StatValue4
@onready var _snap_values = {
	"military": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapMilitary/SnapValue,
	"religion": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapReligion/SnapValue2,
	"commerce": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapCommerce/SnapValue3,
	"politics": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapPolitics/SnapValue4,
}
@onready var _snap_bars = {
	"military": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapMilitary/SnapBar,
	"religion": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapReligion/SnapBar2,
	"commerce": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapCommerce/SnapBar3,
	"politics": $Scroll/MainVBox/Padding/InnerVBox/Snapshot/SnapPolitics/SnapBar4,
}
@onready var _btn = $Scroll/MainVBox/Padding/InnerVBox/RespawnButton

func _ready() -> void:
	_btn.pressed.connect(func(): continue_pressed.emit())

func show_death(ctx: Context, death_type: String, cover_name: String) -> void:
	var year = ctx.get_var("year", 1)
	var y_start = ctx.get_var("y_start", 1)
	var age = ctx.get_var("age", 50)
	var turns = ctx.get_var("turns", 0)
	var speaker = ctx.get_var("speaker_name", "Inconnu")

	var cause_label = ThemeColors.death_label(death_type)
	_cause.text = cause_label
	_speaker.text = "Orateur — " + str(speaker)
	_subtitle.text = "%s · %d ans · Règne couvert An %d → An %d" % [cover_name, age, y_start, year]

	var msg = ThemeColors.death_message(death_type)
	if death_type == "natural":
		msg = "Vous avez servi jusqu'à la fin de vos jours. Le Plan vous remercie."
	_seldon_text.text = msg

	var reign_years = max(year - y_start, 0)
	var score = 60 + turns * 8
	var deviation = "%s%" % str(randf_range(2.0, 8.0)).substr(0, 3)

	_stat_decisions.text = str(turns)
	_stat_years.text = str(reign_years) + " ans"
	_stat_score.text = str(score) + " pts"
	_stat_deviation.text = "dévié de " + deviation

	var resources = ["military", "religion", "commerce", "politics"]
	for r in resources:
		var val = ctx.get_var(r, 50)
		_snap_values[r].text = str(val)
		_snap_bars[r].custom_minimum_size.x = val
		_snap_bars[r].color = ThemeColors.resource_color(r)
