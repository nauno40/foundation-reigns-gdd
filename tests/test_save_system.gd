extends GutTest

var save_sys: SaveSystem
var ctx: Context

func before_each():
	save_sys = SaveSystem.new()
	ctx = Context.new()
	ctx.initialize_new_reign()
	save_sys.delete_save()

func after_each():
	save_sys.delete_save()

func test_no_save_initially():
	assert_false(save_sys.has_save())

func test_save_and_load():
	ctx.set_var("military", 65)
	ctx.set_var("year", 42, true)
	save_sys.save(ctx)
	assert_true(save_sys.has_save())

	var ctx2 = Context.new()
	save_sys.load(ctx2)
	assert_eq(ctx2.get_var("military"), 65)
	assert_eq(ctx2.get_var("year"), 42)

func test_delete_removes_save():
	save_sys.save(ctx)
	save_sys.delete_save()
	assert_false(save_sys.has_save())
