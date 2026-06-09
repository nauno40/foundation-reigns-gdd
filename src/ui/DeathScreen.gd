class_name DeathScreen
extends Control

signal continue_pressed

@onready var _title        = $Title
@onready var _subtitle     = $SubTitle
@onready var _timeline     = $ScrollContainer/VBoxContainer/TimelineLabel
@onready var _galaxy_state = $ScrollContainer/VBoxContainer/GalaxyStateLabel
@onready var _legacy       = $ScrollContainer/VBoxContainer/LegacyLabel
@onready var _seldon_text  = $SeldonMessage/SeldonText
@onready var _continue_btn = $ContinueButton

func _ready() -> void:
	_continue_btn.pressed.connect(func(): continue_pressed.emit())

func show_death(ctx: Context, death_type: String, cover_name: String) -> void:
	var speaker_name = ctx.get_var("speaker_name", "Inconnu")
	var age = ctx.get_var("age", 50)

	_title.text = "Speaker %s — %d ans" % [speaker_name, age]
	var cause_text = _death_type_to_fr(death_type)
	_subtitle.text = "Couverture : %s  |  Cause : %s" % [cover_name, cause_text]

	var timeline = ""
	for i in range(1, 7):
		var key = "seldon_crisis_%d" % i
		var val = ctx.get_var(key, 0)
		if val == 1:
			timeline += "v Crise de Seldon %d -- traversee\n" % i
		elif val == -1:
			timeline += "x Crise de Seldon %d -- ratee\n" % i
	_timeline.text = timeline if timeline != "" else "Aucune crise de Seldon atteinte ce regne."

	var resources = ["military", "religion", "commerce", "politics"]
	var resource_names = {"military": "Militaire", "religion": "Religion",
						  "commerce": "Commerce",  "politics": "Politique"}
	var galaxy = ""
	for r in resources:
		galaxy += "%s : %d\n" % [resource_names[r], ctx.get_var(r, 50)]
	galaxy += "\nAnnee galactique : %d" % ctx.get_var("year", 1)
	_galaxy_state.text = galaxy

	var legacy = "Variables toKeep transmises :\n"
	for key in ctx._keep_flags:
		legacy += "  * %s = %s\n" % [key, str(ctx.get_var(key))]
	_legacy.text = legacy

	_seldon_text.text = _get_seldon_message(ctx, death_type)

func _death_type_to_fr(death_type: String) -> String:
	match death_type:
		"natural":   return "Mort naturelle"
		"resource":  return "Effondrement d'une ressource"
		"exposed":   return "Couverture demasquee"
		_:           return "Inconnue"

func _get_seldon_message(ctx: Context, death_type: String) -> String:
	var year = ctx.get_var("year", 1)
	var crises_passed = 0
	for i in range(1, 7):
		if ctx.get_var("seldon_crisis_%d" % i, 0) == 1:
			crises_passed += 1

	if death_type == "natural":
		return "Vous avez servi jusqu'a la fin de vos jours. Le Plan vous remercie."
	if crises_passed >= 3:
		return "An %d. Le Plan devie de moins de 2%%. Votre successeur a une bonne marge." % year
	if crises_passed == 0:
		return "An %d. Le Plan devie. La correction sera difficile. Mais pas impossible." % year
	return "An %d. Les fondations tiennent. Continuez." % year
