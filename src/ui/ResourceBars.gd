class_name ResourceBars
extends HBoxContainer

const COLOR_NORMAL   = Color(0.3, 0.7, 0.3)
const COLOR_WARNING  = Color(0.9, 0.6, 0.1)
const COLOR_CRITICAL = Color(0.9, 0.1, 0.1)

const THRESHOLD_CRITICAL_LOW  = 15
const THRESHOLD_WARNING_LOW   = 25
const THRESHOLD_WARNING_HIGH  = 75
const THRESHOLD_CRITICAL_HIGH = 85

@onready var _bars = {
	"military": $MilitaryBar,
	"religion": $ReligionBar,
	"commerce": $CommerceBar,
	"politics": $PoliticsBar,
}

func update(ctx: Context) -> void:
	for resource in _bars:
		var value: int = ctx.get_var(resource, 50)
		_update_bar(_bars[resource], value)

func _update_bar(bar: ProgressBar, value: int) -> void:
	bar.value = value
	var color = _get_color(value)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)

	if value < THRESHOLD_CRITICAL_LOW or value > THRESHOLD_CRITICAL_HIGH:
		_start_blink(bar)
	else:
		_stop_blink(bar)

func _get_color(value: int) -> Color:
	if value < THRESHOLD_CRITICAL_LOW or value > THRESHOLD_CRITICAL_HIGH:
		return COLOR_CRITICAL
	if value < THRESHOLD_WARNING_LOW or value > THRESHOLD_WARNING_HIGH:
		return COLOR_WARNING
	return COLOR_NORMAL

func _start_blink(bar: ProgressBar) -> void:
	if not bar.has_meta("blinking"):
		bar.set_meta("blinking", true)
		var tween = create_tween().set_loops()
		tween.tween_property(bar, "modulate:a", 0.3, 0.4)
		tween.tween_property(bar, "modulate:a", 1.0, 0.4)
		bar.set_meta("tween", tween)

func _stop_blink(bar: ProgressBar) -> void:
	if bar.has_meta("blinking"):
		bar.remove_meta("blinking")
		if bar.has_meta("tween"):
			bar.get_meta("tween").kill()
			bar.remove_meta("tween")
		bar.modulate.a = 1.0
