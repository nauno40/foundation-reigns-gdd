class_name LegitimacySystem

enum SignalLevel { NORMAL, SUSPICIOUS, CRITICAL }

const THRESHOLD_SUSPICIOUS = 30
const THRESHOLD_CRITICAL = 15

var _ctx: Context

func _init(ctx: Context) -> void:
	_ctx = ctx

func apply_delta(delta: int) -> void:
	var current: int = _ctx.get_var("legitimacy", 100)
	var new_val: int = clamp(current + delta, 0, 100)
	_ctx.set_var("legitimacy", new_val)

func is_critical() -> bool:
	return _ctx.get_var("legitimacy", 100) < THRESHOLD_CRITICAL

func is_exposed() -> bool:
	return _ctx.get_var("legitimacy", 100) <= 0

func get_signal_level() -> SignalLevel:
	var val: int = _ctx.get_var("legitimacy", 100)
	if val < THRESHOLD_CRITICAL:
		return SignalLevel.CRITICAL
	if val <= THRESHOLD_SUSPICIOUS:
		return SignalLevel.SUSPICIOUS
	return SignalLevel.NORMAL

func get_mood_bias() -> String:
	match get_signal_level():
		SignalLevel.CRITICAL:    return "suspicious"
		SignalLevel.SUSPICIOUS:  return "suspicious"
		_:                       return ""
