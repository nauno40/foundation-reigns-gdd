extends GutRunner

func _init():
	gut.options.dirs = ["res://tests/"]
	gut.options.prefix = "test_"
	gut.options.suffix = ".gd"
