extends Node

# Autoload "Anim" : helpers d'animation réutilisables, lisant AnimSettings.
# Porte la chorégraphie Reigns 3K (DOTween) dans le style holographique du projet.

const AnimSettingsScript = preload("res://src/ui/AnimSettings.gd")
const SETTINGS_PATH := "res://data/anim_settings.tres"

var settings: AnimSettingsScript

func _ready() -> void:
	var loaded = load(SETTINGS_PATH)
	settings = loaded if loaded is AnimSettingsScript else AnimSettingsScript.new()

# ── Logique pure (testable sans arbre de scène) ──────────────────────

# Exp-smoothing indépendant du framerate (CardAnimator.DoUpdate).
func smooth(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))

# Formate un compteur interpolé sans jamais dépasser la cible.
func format_count(current: float, target: int) -> String:
	return str(mini(roundi(current), target))

# ── Helpers de tween ─────────────────────────────────────────────────

func fade_in(node: CanvasItem, dur := -1.0, delay := 0.0) -> Tween:
	if dur < 0.0:
		dur = settings.fade_dur
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).set_delay(delay) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tw

func fade_out(node: CanvasItem, dur := -1.0) -> Tween:
	if dur < 0.0:
		dur = settings.fade_dur
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, dur) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	return tw

# Compteur chiffré (année, stats). fmt(current_float, target_int) -> String.
func count_to(label: Label, from_v: int, to_v: int, fmt: Callable, dur := -1.0) -> Tween:
	if dur < 0.0:
		dur = settings.year_count_dur
	var tw := label.create_tween()
	tw.tween_method(func(v: float): label.text = fmt.call(v, to_v),
		float(from_v), float(to_v), dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tw

# Flash bref : applique flash puis revient à la couleur de repos.
# setter(Color) est appelé à chaque frame (ValueAct.flashing / ColorTween).
func color_flash(setter: Callable, flash: Color, dur := -1.0) -> Tween:
	if dur < 0.0:
		dur = settings.bar_flash_dur
	var rest := Color(flash.r, flash.g, flash.b, 0.0)
	var tw := create_tween()
	tw.tween_method(setter, flash, rest, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tw

# Transition de couleur (AnimateTint).
func color_to(setter: Callable, from_c: Color, to_c: Color, dur := -1.0) -> Tween:
	if dur < 0.0:
		dur = settings.map_tint_dur
	var tw := create_tween()
	tw.tween_method(setter, from_c, to_c, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tw

func pulse(setter: Callable, lo: float, hi: float, half_period: float) -> Tween:
	var tw := create_tween().set_loops()
	tw.tween_method(setter, lo, hi, half_period)
	tw.tween_method(setter, hi, lo, half_period)
	return tw

# Révélation en cascade : chaque nœud entre en fondu, décalé de `stagger`.
func reveal_list(nodes: Array, stagger := -1.0, item_dur := -1.0) -> void:
	if stagger < 0.0:
		stagger = settings.menu_stagger
	if item_dur < 0.0:
		item_dur = settings.menu_item_in
	var i := 0
	for node in nodes:
		if node is CanvasItem:
			fade_in(node, item_dur, stagger * i)
			i += 1
