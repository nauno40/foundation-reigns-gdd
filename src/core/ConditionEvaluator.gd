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

	# Numeric coercion: JSON.parse_string yields floats, Context vars are ints
	if (current is int or current is float) and (expected is int or expected is float):
		current = float(current)
		expected = float(expected)
	elif typeof(current) != typeof(expected):
		# Type mismatch → treat as not-equal
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
