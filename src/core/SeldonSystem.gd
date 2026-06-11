class_name SeldonSystem

# Les 6 Crises de Seldon (GDD §2.8). Chaque couloir est une liste de
# conditions au format des cartes, évaluée par ConditionEvaluator.
# Les cartes de dénouement posent `evaluate_seldon_crisis = N` dans leur
# loadOutcome ; resolve_pending() consomme ce marqueur et fixe
# `seldon_crisis_N` à 1 (couloir respecté) ou -1 (raté), en toKeep.

const CRISIS_COUNT = 6

var _data: FoundationGameData
var _ctx: Context
var _evaluator := ConditionEvaluator.new()

func _init(data: FoundationGameData, ctx: Context) -> void:
	_data = data
	_ctx = ctx

func evaluate_corridor(crisis_num: int) -> bool:
	var crisis: Dictionary = _data.seldon_crises.get("crisis_%d" % crisis_num, {})
	if crisis.is_empty():
		return false
	return _evaluator.evaluate_all(crisis.get("corridor", []), _ctx._vars)

func resolve_pending() -> void:
	var crisis_num: int = int(_ctx.get_var("evaluate_seldon_crisis", 0))
	if crisis_num <= 0:
		return
	_ctx.set_var("evaluate_seldon_crisis", 0)
	var result: int = 1 if evaluate_corridor(crisis_num) else -1
	_ctx.set_var("seldon_crisis_%d" % crisis_num, result, true)

func crises_passed() -> int:
	var passed := 0
	for i in range(1, CRISIS_COUNT + 1):
		if int(_ctx.get_var("seldon_crisis_%d" % i, 0)) == 1:
			passed += 1
	return passed
