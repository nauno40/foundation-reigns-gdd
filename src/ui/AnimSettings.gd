class_name AnimSettings
extends Resource

@export_group("Global")
@export var fade_dur := 0.3

@export_group("Card")
@export var card_y_offset_factor := -0.05
@export var card_y_offset_speed := 12.0
@export var card_rot_offset_factor := 0.045
@export var card_rot_offset_speed := 14.0
@export var card_rot_y_factor := 0.0035
@export var card_rot_y_speed := 10.0
@export var card_max_rot_velocity := 8.0
@export var card_entry_dur := 0.22
@export var card_offscreen_height := 60.0
@export var card_flip_dur := 0.45
@export var card_defeat_move := Vector2(40.0, 120.0)
@export var card_defeat_rot := 18.0
@export var card_defeat_delay := 0.15

@export_group("Bars")
@export var bar_flash_dur := 0.4
@export var bar_flash_up := Color("#5fcf8f")
@export var bar_flash_down := Color("#d96a5a")

@export_group("Year")
@export var year_count_dur := 0.6

@export_group("Death")
@export var death_bg_fade := 0.35
@export var death_text_in := 0.4
@export var death_list_stagger := 0.08
@export var death_item_in := 0.3
@export var death_stat_dur := 0.7
@export var death_stat_delay := 0.15
@export var death_stat_step := 0.1

@export_group("Map")
@export var map_tint_dur := 0.45

@export_group("Menu")
@export var menu_stagger := 0.07
@export var menu_item_in := 0.35

@export_group("Parallax")
@export var parallax_drift_speed := 0.15
@export var parallax_swipe_factor := 0.02

@export_group("Options")
@export var options_in := 0.3
@export var options_out := 0.2
@export var options_tab_stagger := 0.06

@export_group("Unlock")
@export var unlock_card_fly := 0.4
@export var unlock_stagger := 0.09
@export var unlock_card_offset := 14.0
@export var unlock_card_tilt := 5.0
@export var unlock_text_in := 0.35
