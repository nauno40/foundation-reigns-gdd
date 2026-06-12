extends GutTest

var data: FoundationGameData

func before_each():
	data = FoundationGameData.new()
	data.load_all()

# --- resolve_bearer : porteur canonique / PNJ généré / null ---

func test_canonical_bearer_resolves_name_and_role():
	var info = CardUtils.resolve_bearer({"id": 1, "bearer": "hari_seldon"}, data)
	assert_eq(info["name"], "Hari Seldon")
	assert_true(info["key"], "un personnage canonique est une Figure du Plan")
	assert_ne(info["role"], "", "un personnage canonique doit avoir un rôle court")

func test_null_bearer_generates_stable_npc_name():
	var card = {"id": 1001, "bearer": null}
	var a = CardUtils.resolve_bearer(card, data)
	var b = CardUtils.resolve_bearer(card, data)
	assert_eq(a["name"], b["name"], "le nom de PNJ doit être stable pour une même carte")
	assert_ne(a["name"], "", "un PNJ doit avoir un nom généré")
	assert_false(a["key"])

func test_different_cards_can_have_different_npc_names():
	var a = CardUtils.resolve_bearer({"id": 1001, "bearer": null}, data)
	var b = CardUtils.resolve_bearer({"id": 1002, "bearer": null}, data)
	# pools ~50×30 : deux ids consécutifs ne doivent pas systématiquement coïncider
	assert_ne(a["name"] + "/" + str(1001), b["name"] + "/" + str(1002))

func test_unknown_bearer_id_falls_back_to_raw():
	var info = CardUtils.resolve_bearer({"id": 5, "bearer": "inconnu_x"}, data)
	assert_eq(info["name"], "inconnu_x")
	assert_false(info["key"])

# --- affected_resources : quelles barres vont bouger (jamais le sens) ---

func test_affected_resources_left_outcome():
	var card = {
		"yesOutcome": [
			{"variable": "military", "intValue": -5},
			{"variable": "legitimacy", "intValue": 3},
		],
		"noOutcome": [{"variable": "commerce", "intValue": 10}],
	}
	assert_eq(CardUtils.affected_resources(card, true), ["military"])
	assert_eq(CardUtils.affected_resources(card, false), ["commerce"])

func test_affected_resources_ignores_zero_delta():
	var card = {"yesOutcome": [{"variable": "religion", "intValue": 0}], "noOutcome": []}
	assert_eq(CardUtils.affected_resources(card, true), [])

# --- Rôles institutionnels persistants (bearer "role:<id>") ---

func test_role_bearer_generates_and_persists_name():
	var ctx = Context.new()
	var card = {"bearer": "role:high_priest"}
	var info1 = CardUtils.resolve_bearer(card, data, ctx)
	assert_ne(info1["name"], "", "un nom est généré")
	assert_eq(info1["role"], "Grand Prêtre de l'Esprit Galactique")
	var info2 = CardUtils.resolve_bearer(card, data, ctx)
	assert_eq(info2["name"], info1["name"], "le nom persiste entre les cartes")
	ctx.empty_non_keep()
	var info3 = CardUtils.resolve_bearer(card, data, ctx)
	assert_eq(info3["name"], info1["name"], "le visage du rôle survit à la mort (toKeep)")

func test_role_name_reset_regenerates():
	var ctx = Context.new()
	var card = {"bearer": "role:high_priest"}
	var info1 = CardUtils.resolve_bearer(card, data, ctx)
	ctx.set_var("role_high_priest_name", "")
	var info2 = CardUtils.resolve_bearer(card, data, ctx)
	assert_ne(info2["name"], "", "nom régénéré après reset")
