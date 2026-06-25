extends Control

# Écran de chargement léger : s'instancie instantanément (donc s'affiche tout
# de suite, pas de gel), puis charge Main.tscn EN ARRIÈRE-PLAN (ResourceLoader
# threadé) + les données de jeu sur un thread, avec une barre de progression.
# Quand tout est prêt, instancie Main, lui injecte les données, et bascule.

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const MAIN_PATH := "res://scenes/Main.tscn"
const BAR_W := 280.0

var _msg: Label
var _bar_fill: ColorRect
var _pulse: Tween
var _data_thread: Thread
var _swapping := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# Parse de la scène lourde (textures, sous-scènes, scripts) sur un thread.
	ResourceLoader.load_threaded_request(MAIN_PATH)
	# Données de jeu (2586 cartes) en parallèle sur un thread.
	_data_thread = Thread.new()
	_data_thread.start(_load_data)
	# Pré-chauffage APRÈS que l'écran se soit affiché (sinon la 1re frame gèle
	# en gris avant d'apparaître). On laisse 2 frames se dessiner d'abord.
	await get_tree().process_frame
	await get_tree().process_frame
	_prewarm()

func _load_data() -> FoundationGameData:
	var gd := FoundationGameData.new()
	gd.load_all()
	return gd

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.027, 0.051, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Grille holographique de fond.
	var grid := ColorRect.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/holo_grid.gdshader")
	mat.set_shader_parameter("rect_size", get_viewport().get_visible_rect().size)
	grid.material = mat
	add_child(grid)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	col.add_child(_label("FOUNDATION REIGNS", 18, Color(0.31, 0.839, 0.91, 0.6)))
	_msg = _label("CHARGEMENT", 12, Color(0.576, 0.631, 0.714))
	col.add_child(_msg)

	# Barre de progression (track + remplissage cyan).
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 4)
	var track := ColorRect.new()
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.color = Color(0.31, 0.839, 0.91, 0.12)
	bar.add_child(track)
	_bar_fill = ColorRect.new()
	_bar_fill.color = ThemeColors.ACCENT
	_bar_fill.size = Vector2(0, 4)
	bar.add_child(_bar_fill)
	col.add_child(bar)

	# Pulsation du message → mouvement clairement visible.
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_msg, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_msg, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

# Pré-chauffage : pendant que le chargement tourne (écran animé), on REND une
# fois les shaders et les polices que Main affichera, pour que la compilation
# des shaders + la rastérisation des glyphes (le coût du « premier rendu » de
# CardScreen, ~1,2 s) se fasse ici plutôt qu'en gelant au swap. Les caches
# (programme shader + atlas de glyphes) sont globaux → réutilisés par Main.
# Les nœuds sont placés DERRIÈRE le fond opaque (dessinés mais invisibles).
func _prewarm() -> void:
	var warm := Control.new()
	warm.name = "Prewarm"
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(warm)
	move_child(warm, 0)   # derrière le Bg opaque (jamais visible)

	# Un élément par frame : chaque frame ne paie qu'UN shader ou UNE police,
	# donc aucun à-coup visible (l'écran continue de s'animer entre chaque).
	for path in [
			"res://assets/shaders/portrait_holo.gdshader",
			"res://assets/shaders/holo_grid.gdshader",
			"res://assets/shaders/space_bg.gdshader",
			"res://assets/shaders/scanline_veil.gdshader",
			"res://assets/shaders/gauge_fill.gdshader",
			"res://assets/shaders/card_face.gdshader",
			"res://assets/shaders/death_fx.gdshader"]:
		if _swapping:
			return
		var shader := load(path)
		if shader != null:
			var r := ColorRect.new()
			r.size = Vector2(8, 8)
			var m := ShaderMaterial.new()
			m.shader = shader
			r.material = m
			warm.add_child(r)
		await get_tree().process_frame

	var glyphs := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 àâäéèêëîïôöùûüçÀÂÉÈÊ,.;:!?«»—'’…•▲✦●■◄►☼◉"
	for font_path in [
			"res://assets/fonts/Spectral-Regular.ttf",
			"res://assets/fonts/Spectral-Italic.ttf",
			"res://assets/fonts/Spectral-Bold.ttf",
			"res://assets/fonts/SpaceMono-Regular.ttf",
			"res://assets/fonts/SpaceMono-Bold.ttf",
			"res://assets/fonts/Caveat-Variable.ttf"]:
		var f := load(font_path)
		if f == null:
			continue
		for sz in [9, 10, 11, 12, 13, 15, 18, 19]:
			if _swapping:
				return
			var l := Label.new()
			l.text = glyphs
			l.add_theme_font_override("font", f)
			l.add_theme_font_size_override("font_size", sz)
			warm.add_child(l)
			await get_tree().process_frame

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_MONO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _process(_dt: float) -> void:
	if _swapping:
		return
	var prog := []
	var status := ResourceLoader.load_threaded_get_status(MAIN_PATH, prog)
	var p: float = prog[0] if prog.size() > 0 else 0.0
	_bar_fill.size.x = BAR_W * p
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_msg.text = "ÉCHEC DE CHARGEMENT"
		set_process(false)
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED and not _data_thread.is_alive():
		_swapping = true
		_swap()

func _swap() -> void:
	_bar_fill.size.x = BAR_W
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	var gd: FoundationGameData = _data_thread.wait_to_finish()
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN_PATH)
	var main = packed.instantiate()
	main.preloaded_data = gd          # injection avant l'entrée dans l'arbre
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	queue_free()
