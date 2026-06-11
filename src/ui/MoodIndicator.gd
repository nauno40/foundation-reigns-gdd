class_name MoodIndicator
extends HBoxContainer

const ThemeColors = preload("res://src/ui/ThemeColors.gd")

@onready var _dot: ColorRect = $Dot
@onready var _label: Label = $Label
@onready var _read_label: Label = $ReadLabel

func set_mood(mood_key: String) -> void:
	var c = ThemeColors.mood_color(mood_key)
	_dot.color = c
	_label.text = ThemeColors.mood_label(mood_key)
