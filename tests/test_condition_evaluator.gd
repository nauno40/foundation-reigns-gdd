extends GutTest

var ce: ConditionEvaluator

func before_each():
	ce = ConditionEvaluator.new()

func test_equal_true():
	var ctx = {"year": 50}
	var cond = {"variable": "year", "op": "equal", "value": 50}
	assert_true(ce.evaluate(cond, ctx))

func test_equal_false():
	var ctx = {"year": 49}
	var cond = {"variable": "year", "op": "equal", "value": 50}
	assert_false(ce.evaluate(cond, ctx))

func test_above_true():
	var ctx = {"year": 51}
	var cond = {"variable": "year", "op": "above", "value": 50}
	assert_true(ce.evaluate(cond, ctx))

func test_above_false():
	var ctx = {"year": 50}
	var cond = {"variable": "year", "op": "above", "value": 50}
	assert_false(ce.evaluate(cond, ctx))

func test_below_true():
	var ctx = {"military": 20}
	var cond = {"variable": "military", "op": "below", "value": 30}
	assert_true(ce.evaluate(cond, ctx))

func test_not_true():
	var ctx = {"mood": "angry"}
	var cond = {"variable": "mood", "op": "not", "value": "neutral"}
	assert_true(ce.evaluate(cond, ctx))

func test_not_false():
	var ctx = {"mood": "neutral"}
	var cond = {"variable": "mood", "op": "not", "value": "neutral"}
	assert_false(ce.evaluate(cond, ctx))

func test_missing_variable_defaults_zero():
	var ctx = {}
	var cond = {"variable": "military", "op": "above", "value": 0}
	assert_false(ce.evaluate(cond, ctx))

func test_evaluate_all_and_logic():
	var ctx = {"year": 60, "military": 30}
	var conditions = [
		{"variable": "year", "op": "above", "value": 50},
		{"variable": "military", "op": "below", "value": 50}
	]
	assert_true(ce.evaluate_all(conditions, ctx))

func test_evaluate_all_fails_on_one():
	var ctx = {"year": 40, "military": 30}
	var conditions = [
		{"variable": "year", "op": "above", "value": 50},
		{"variable": "military", "op": "below", "value": 50}
	]
	assert_false(ce.evaluate_all(conditions, ctx))

func test_evaluate_all_empty_is_true():
	assert_true(ce.evaluate_all([], {}))

# --- Coercition numérique : le JSON Godot lit tous les nombres en float ---

func test_int_context_vs_float_condition_value():
	# year posé en int par le code, value 50.0 issue de JSON.parse_string
	var cond = {"variable": "year", "op": "below", "value": 50.0}
	assert_true(ce.evaluate(cond, {"year": 30}),
		"int 30 < float 50.0 doit être vrai")

func test_float_context_vs_int_condition_value():
	var cond = {"variable": "year", "op": "above", "value": 29}
	assert_true(ce.evaluate(cond, {"year": 42.0}),
		"float 42.0 > int 29 doit être vrai")

func test_numeric_equality_across_types():
	var cond = {"variable": "flag", "op": "equal", "value": 1.0}
	assert_true(ce.evaluate(cond, {"flag": 1}))
