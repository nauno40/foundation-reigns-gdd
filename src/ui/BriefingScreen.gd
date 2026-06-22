class_name BriefingScreen
extends Control

signal dismissed

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const FONT_SPECTRAL_I = preload("res://assets/fonts/Spectral-Italic.ttf")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")

const PAGES := [
	{
		"title": "LE PLAN SELDON",
		"subtitle": "An 1 — Fondation",
		"body": "Hari Seldon, dernier grand psychohistorien de l'Empire, a prédit l'inévitable effondrement de l'Empire Galactique. Mais il a aussi tracé une issue : concentrer le savoir humain sur Terminus pour réduire l'âge des ténèbres de 30 000 ans à seulement 1 000 ans.\n\nC'est le Plan Seldon.",
		"color": ThemeColors.ACCENT,
	},
	{
		"title": "VOTRE RÔLE",
		"subtitle": "Orateur de la Seconde Fondation",
		"body": "Vous êtes un Orateur de la Seconde Fondation — gardien caché du Plan. Votre mission est de guider subtilement la Fondation à travers les crises, sans jamais révéler votre nature.\n\nVotre couverture civile vous protège. Si l'on découvre qui vous êtes, le Plan tout entier est compromis.",
		"color": ThemeColors.AMBER,
	},
	{
		"title": "LES QUATRE PILIERS",
		"subtitle": "Équilibre de la Fondation",
		"body": "La Fondation repose sur quatre piliers — militaire, religion, commerce, politique. Votre rôle est de les maintenir en équilibre.\n\nUn pilier à zéro : la Fondation s'effondre sur ce plan. Un pilier à cent : un déséquilibre tout aussi fatal.\n\nLe but n'est pas de tout maximiser, mais de naviguer entre les extrêmes.",
		"color": ThemeColors.INK,
	},
	{
		"title": "LA LÉGITIMITÉ",
		"subtitle": "Votre couverture",
		"body": "Vous lisez les esprits depuis l'ombre. Mais chaque acte trop omniscient érode votre légitimité.\n\nSi elle tombe à zéro, vous êtes démasqué — votre règne s'achève dans l'infamie.\n\nRestez discret. Jouez votre rôle. Le Plan exige la patience.",
		"color": ThemeColors.DANGER,
	},
	{
		"title": "LES SIX CRISES",
		"subtitle": "Les épreuves du Plan",
		"body": "Seldon a programmé six grandes crises qui jalonnent le chemin de la Fondation vers le Second Empire.\n\nVotre succès dépend de votre capacité à guider la Fondation à travers chacune d'elles. Chaque crise passée vous rapproche du but.\n\nSix crises. Mille ans. Un Plan.",
		"color": ThemeColors.ACCENT,
	},
	{
		"title": "LA MORT N'EST PAS LA FIN",
		"subtitle": "Le Plan continue",
		"body": "Quand votre règne s'achève — par la guerre, l'exposition, la vieillesse ou toute autre cause — un nouvel Orateur prend votre place. La conscience du Plan vous est transmise.\n\nLes acquis stratégiques survivent. Les crises passées restent passées.\n\nLe Plan continue. Toujours.",
		"color": ThemeColors.AMBER,
	},
]

var _page := 0

@onready var _bg: ColorRect = %Bg
@onready var _page_label: Label = %PageLabel
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _body: RichTextLabel = %Body
@onready var _next: Button = %NextBtn
@onready var _prev: Button = %PrevBtn
@onready var _dismiss: Button = %DismissBtn
@onready var _dots: HBoxContainer = %Dots

func _ready() -> void:
	_next.pressed.connect(_on_next)
	_prev.pressed.connect(_on_prev)
	_dismiss.pressed.connect(func(): dismissed.emit())
	_render()
	_bg.modulate.a = 0.0

func show_briefing() -> void:
	show()
	_page = 0
	_render()
	var tw = create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, 0.35)

func _render() -> void:
	var page = PAGES[_page]
	_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	_title.text = page["title"]
	_subtitle.text = page["subtitle"]
	_body.text = page["body"]
	var c = page["color"]
	_title.add_theme_color_override("font_color", c)
	_prev.visible = _page > 0
	_next.visible = _page < PAGES.size() - 1
	_dismiss.text = "COMMENCER →" if _page == PAGES.size() - 1 else "PASSER"
	for d in _dots.get_children():
		d.queue_free()
	for i in range(PAGES.size()):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size = Vector2(6, 6)
		dot.color = c if i == _page else ThemeColors.LINE
		_dots.add_child(dot)

func _on_next() -> void:
	if _page < PAGES.size() - 1:
		_page += 1
		_render()

func _on_prev() -> void:
	if _page > 0:
		_page -= 1
		_render()
