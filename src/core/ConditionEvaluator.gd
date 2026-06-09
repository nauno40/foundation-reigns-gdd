class_name ConditionEvaluator

func evaluate(condition: Dictionary, context: Dictionary) -> bool:
	var variable: String = condition.get("variable", "")
	var op: String = condition.get("op", "equal")
	var expected = condition.get("value", 0)
	var current = context.get(variable, null)

	# Variable missing: default 0 for numeric, false-match for string
	if current == null:
		if expected is int or expected is float:
			current = 0
		else:
			return op == "not"

	# Type mismatch → treat as not-equal
	if typeof(current) != typeof(expected):
		return op == "not"

	match op:
		"equal":  return current == expected
		"above":  return current > expected
		"below":  return current < expected
		"not":    return current != expected
		_:
			push_warning("ConditionEvaluator: unknown op '%s'" % op)
			return false

func evaluate_all(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		if not evaluate(condition, context):
			return false
	return true
