extends GutTest

var ctx: Context
var unlocks: Dictionary

func before_each():
	ctx = Context.new()
	ctx.initialize_new_reign()
	unlocks = {"hardin_era": {"id": "hardin_era", "name": "Ère Hardin", "subtitle": "x"}}

func test_unlock_for_listed_unseen_deck():
	var u = DeckUnlock.pending_unlock({"deck": "hardin_era"}, ctx, unlocks)
	assert_eq(str(u.get("name", "")), "Ère Hardin")

func test_no_unlock_for_unlisted_deck():
	assert_true(DeckUnlock.pending_unlock({"deck": "ambient"}, ctx, unlocks).is_empty())

func test_no_unlock_when_flag_already_set():
	ctx.set_var("deck_unlocked_hardin_era", 1, true)
	assert_true(DeckUnlock.pending_unlock({"deck": "hardin_era"}, ctx, unlocks).is_empty())

func test_no_unlock_for_card_without_deck():
	assert_true(DeckUnlock.pending_unlock({}, ctx, unlocks).is_empty())
