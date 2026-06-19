# Suite d'animations Reigns → Godot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Porter la chorégraphie d'animation de Reigns 3K (hors combat) dans Godot, via un socle réutilisable, en 9 paquets incrémentaux.

**Architecture:** Un autoload `Anim` expose des helpers de tween (`fade_in`, `count_to`, `color_flash`, `color_to`, `pulse`, `reveal_list`, `smooth`) qui lisent une Resource `AnimSettings` centralisant tous les timings/couleurs. Chaque écran appelle `Anim.*` ; aucun couplage inter-écrans. On enrichit le code existant, on ne le réécrit pas.

**Tech Stack:** Godot 4.6, GDScript, GUT (tests).

## Global Constraints

- Godot 4.6 ; tests GUT (`extends GutTest`, `before_each`, `test_*`).
- Cible visuelle = identité holographique du projet (`src/ui/ThemeColors.gd`), PAS l'UI de Reigns 3K.
- Tous les timings/couleurs d'animation vivent dans `AnimSettings` — aucune constante d'animation en dur ailleurs (sauf migration depuis `CardScreen.gd`).
- Couleurs via `ThemeColors` (`ACCENT #4fd6e8`, `AMBER #e8b65a`, `DANGER #d96a5a`, `COMMERCE #5fcf8f`).
- Valeurs d'animation calées au ressenti (extraction AssetRipper = hors périmètre).
- Commits fréquents ; lancer la suite GUT complète avant chaque commit de paquet :
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit`
- Branche de travail : `feat/reigns-animation-suite` (déjà créée).

---

## File Structure

- `src/ui/AnimSettings.gd` *(créer)* — Resource ; tous les `@export` de timings/couleurs, groupés.
- `data/anim_settings.tres` *(créer)* — instance par défaut de `AnimSettings`.
- `src/ui/Anim.gd` *(créer, autoload "Anim")* — helpers de tween + `smooth`/`format_count` purs.
- `project.godot` *(modifier)* — enregistrer l'autoload `Anim`.
- `tests/test_anim.gd` *(créer)* — tests de la logique pure de `Anim`.
- `src/ui/CardScreen.gd` *(modifier)* — migrer constantes/`_smooth` vers `Anim` ; entrée verticale, wobble, flip, année, dérive de grille.
- `src/ui/ResourceBar.gd` *(modifier)* — flash couleur au changement.
- `src/ui/DeathScreen.gd` *(modifier)* — révélation séquencée.
- `src/ui/GalaxyMap.gd` *(modifier)* — transition de teinte.
- `src/ui/MainMenu.gd` *(modifier)* — splash en cascade.
- `src/ui/OptionsScreen.gd` *(modifier)* — entrée/sortie + onglets.
- `tests/test_resource_bar.gd`, `tests/test_galaxy_map.gd` *(créer)* — logique testable de ces paquets.

---

## Task 0 : Socle `Anim` + `AnimSettings`

**Files:**
- Create: `src/ui/AnimSettings.gd`
- Create: `data/anim_settings.tres`
- Create: `src/ui/Anim.gd`
- Modify: `project.godot` (section `[autoload]`)
- Create: `tests/test_anim.gd`

**Interfaces:**
- Produces (autoload `Anim`, accessible partout) :
  - `Anim.settings : AnimSettings`
  - `Anim.smooth(current: float, target: float, speed: float, delta: float) -> float`
  - `Anim.format_count(current: float, target: int) -> String`
  - `Anim.fade_in(node: CanvasItem, dur := -1.0, delay := 0.0) -> Tween`
  - `Anim.fade_out(node: CanvasItem, dur := -1.0) -> Tween`
  - `Anim.count_to(label: Label, from_v: int, to_v: int, fmt: Callable, dur := -1.0) -> Tween`
  - `Anim.color_flash(setter: Callable, flash: Color, dur := -1.0) -> Tween`
  - `Anim.color_to(setter: Callable, from_c: Color, to_c: Color, dur := -1.0) -> Tween`
  - `Anim.pulse(setter: Callable, lo: float, hi: float, half_period: float) -> Tween`
  - `Anim.reveal_list(nodes: Array, stagger := -1.0, item_dur := -1.0) -> void`

- [ ] **Step 1 : Écrire `AnimSettings.gd`**

```gdscript
class_name AnimSettings
extends Resource

@export_group("Global")
@export var fade_dur := 0.3

@export_group("Card")
@export var card_y_offset_factor := -0.05
@export var card_y_offset_speed := 12.0
@export var card_rot_offset_factor := 0.045
@export var card_rot_offset_speed := 14.0
@export var card_rot_y_factor := 0.0035
@export var card_rot_y_speed := 10.0
@export var card_max_rot_velocity := 8.0
@export var card_entry_dur := 0.22
@export var card_offscreen_height := 60.0
@export var card_flip_dur := 0.45
@export var card_defeat_move := Vector2(40.0, 120.0)
@export var card_defeat_rot := 18.0
@export var card_defeat_delay := 0.15

@export_group("Bars")
@export var bar_flash_dur := 0.4
@export var bar_flash_up := Color("#5fcf8f")
@export var bar_flash_down := Color("#d96a5a")

@export_group("Year")
@export var year_count_dur := 0.6

@export_group("Death")
@export var death_bg_fade := 0.35
@export var death_text_in := 0.4
@export var death_list_stagger := 0.08
@export var death_item_in := 0.3

@export_group("Map")
@export var map_tint_dur := 0.45

@export_group("Menu")
@export var menu_stagger := 0.07
@export var menu_item_in := 0.35

@export_group("Parallax")
@export var parallax_drift_speed := 0.15
@export var parallax_swipe_factor := 0.02

@export_group("Options")
@export var options_in := 0.3
@export var options_out := 0.2
@export var options_tab_stagger := 0.06
```

- [ ] **Step 2 : Créer `data/anim_settings.tres`**

```
[gd_resource type="Resource" script_class="AnimSettings" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/AnimSettings.gd" id="1"]

[resource]
script = ExtResource("1")
```

- [ ] **Step 3 : Écrire `Anim.gd` (helpers + logique pure)**

```gdscript
extends Node

# Autoload "Anim" : helpers d'animation réutilisables, lisant AnimSettings.
# Porte la chorégraphie Reigns 3K (DOTween) dans le style holographique du projet.

const AnimSettingsScript = preload("res://src/ui/AnimSettings.gd")
const SETTINGS_PATH := "res://data/anim_settings.tres"

var settings: AnimSettings

func _ready() -> void:
	var loaded = load(SETTINGS_PATH)
	settings = loaded if loaded is AnimSettings else AnimSettingsScript.new()

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
```

- [ ] **Step 4 : Enregistrer l'autoload dans `project.godot`**

Dans la section `[autoload]`, après la ligne `Globals=...`, ajouter :

```
Anim="*res://src/ui/Anim.gd"
```

- [ ] **Step 5 : Écrire les tests de logique pure**

```gdscript
extends GutTest

# Anim est un autoload : accessible directement via le singleton.

func test_smooth_converges_toward_target():
	var v := 0.0
	for i in range(200):
		v = Anim.smooth(v, 10.0, 12.0, 1.0 / 60.0)
	assert_almost_eq(v, 10.0, 0.01, "smooth doit converger vers la cible")

func test_smooth_is_monotonic_toward_target():
	var v := 0.0
	var prev := v
	for i in range(10):
		v = Anim.smooth(v, 10.0, 12.0, 1.0 / 60.0)
		assert_gt(v, prev, "chaque pas se rapproche de la cible")
		assert_lt(v, 10.0, "sans jamais dépasser")
		prev = v

func test_format_count_clamps_to_target():
	assert_eq(Anim.format_count(7.4, 10), "7")
	assert_eq(Anim.format_count(9.9, 10), "10")
	assert_eq(Anim.format_count(12.0, 10), "10",
		"ne dépasse jamais la cible")

func test_settings_loaded():
	assert_not_null(Anim.settings, "la Resource AnimSettings doit être chargée")
	assert_almost_eq(Anim.settings.card_rot_offset_factor, 0.045, 0.0001)
```

- [ ] **Step 6 : Lancer les tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_anim.gd -gexit`
Expected: 4 tests PASS.

- [ ] **Step 7 : Non-régression complète**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit`
Expected: tous les tests passent (163 existants + 4 nouveaux).

- [ ] **Step 8 : Commit**

```bash
git add src/ui/AnimSettings.gd data/anim_settings.tres src/ui/Anim.gd project.godot tests/test_anim.gd
git commit -m "feat(ui): Anim autoload + AnimSettings resource (socle animation)"
```

---

## Task 1 : Carte — migration vers `Anim` + entrée verticale, wobble, flip

**Files:**
- Modify: `src/ui/CardScreen.gd`

**Interfaces:**
- Consumes: `Anim.smooth`, `Anim.settings.card_*`.
- Produces: `CardScreen.play_defeat() -> void` ; `CardScreen.show_card` joue un flip-in si `card.flip_intro == true` ou si `card.deck == "seldon_vault"`.

- [ ] **Step 1 : Migrer les constantes du swipe vers `AnimSettings`**

Dans `src/ui/CardScreen.gd`, supprimer le bloc de constantes `Y_OFFSET_FACTOR … MAX_ROT_VELOCITY` (ajouté au portage swipe) et la fonction `_smooth`. Remplacer leurs usages dans `_process` :

```gdscript
func _process(delta: float) -> void:
	if not _can_swipe or _reaction_visible or not is_instance_valid(_card_panel):
		return
	var s := Anim.settings
	var target_y := _current_drag * s.card_y_offset_factor
	var target_rot := _current_drag * s.card_rot_offset_factor
	var target_rot_y := clampf(_drag_velocity * s.card_rot_y_factor,
		-s.card_max_rot_velocity, s.card_max_rot_velocity)
	_y_offset = Anim.smooth(_y_offset, target_y, s.card_y_offset_speed, delta)
	_rot_offset = Anim.smooth(_rot_offset, target_rot, s.card_rot_offset_speed, delta)
	_rot_offset_y = Anim.smooth(_rot_offset_y, target_rot_y, s.card_rot_y_speed, delta)
	_apply_drag()
```

Supprimer la fonction locale `_smooth(...)` (remplacée par `Anim.smooth`).

- [ ] **Step 2 : Non-régression du swipe**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_card_screen.gd -gexit`
Expected: tests PASS (le swipe utilise maintenant `Anim.settings`).

- [ ] **Step 3 : Entrée verticale + flip-in dans `_layout_card`**

Dans `_layout_card`, remplacer le bloc d'entrée (`if _entry_pending:`) par une montée depuis `offscreen_height` + flip optionnel :

```gdscript
	if _entry_pending:
		_entry_pending = false
		var s := Anim.settings
		_card_panel.scale = Vector2(0.95, 0.95)
		_card_panel.position.y = _card_base_pos.y + s.card_offscreen_height
		var entry = create_tween().set_parallel()
		entry.tween_property(_card_panel, "modulate:a", 1.0, 0.18)
		entry.tween_property(_card_panel, "scale", Vector2.ONE, s.card_entry_dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		entry.tween_property(_card_panel, "position:y", _card_base_pos.y, s.card_entry_dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if _flip_pending:
			_flip_pending = false
			_play_flip_in()
```

- [ ] **Step 4 : Décider du flip-in dans `show_card`**

Dans `show_card`, après `_current_card = card`, déterminer si on joue le flip :

```gdscript
	_flip_pending = bool(card.get("flip_intro", false)) \
		or card.get("deck", "") == "seldon_vault"
```

Déclarer la variable près des autres états : `var _flip_pending: bool = false`.

- [ ] **Step 5 : Implémenter `_play_flip_in` et `play_defeat`**

Ajouter à la fin de `CardScreen.gd` :

```gdscript
# Flip-in 2D : la carte démarre « sur la tranche » (scale X 0) et s'ouvre.
func _play_flip_in() -> void:
	var dur := Anim.settings.card_flip_dur
	_card_panel.scale.x = 0.0
	var tw := create_tween()
	tw.tween_property(_card_panel, "scale:x", 1.0, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# Wobble + chute de la carte (CardAnimator.TriggerDefeat), avant l'écran de mort.
func play_defeat() -> void:
	_can_swipe = false
	var s := Anim.settings
	var tw := create_tween()
	tw.tween_interval(s.card_defeat_delay)
	# tremblement
	tw.tween_property(_card_panel, "rotation", deg_to_rad(s.card_defeat_rot * 0.3), 0.06)
	tw.tween_property(_card_panel, "rotation", deg_to_rad(-s.card_defeat_rot * 0.3), 0.06)
	# chute
	tw.set_parallel()
	tw.tween_property(_card_panel, "position",
		_card_panel.position + Vector2(s.card_defeat_move.x, s.card_defeat_move.y), 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_card_panel, "rotation", deg_to_rad(s.card_defeat_rot), 0.5)
	tw.tween_property(_card_panel, "modulate:a", 0.0, 0.4).set_delay(0.1)
```

- [ ] **Step 6 : Vérification fenêtrée (manuelle)**

Run: `godot --deck seldon_vault`
Attendu : à l'apparition, la carte **monte** depuis le bas et **s'ouvre en flip** (scale X). Sur un deck normal (`godot --deck ambient`), la carte monte sans flip.

- [ ] **Step 7 : Commit**

```bash
git add src/ui/CardScreen.gd src/ui/AnimSettings.gd
git commit -m "feat(ui): card vertical entry, defeat wobble, flip-in (seldon_vault)"
```

---

## Task 2 : Barres de ressources — flash couleur au changement

**Files:**
- Modify: `src/ui/ResourceBar.gd`
- Create: `tests/test_resource_bar.gd`

**Interfaces:**
- Consumes: `Anim.color_flash`, `Anim.settings.bar_flash_up/down/dur`.
- Produces: `ResourceBar._flash_color : Color` (état du flash, lu par `_draw`) ; `ResourceBar.flash_direction(delta_sign: int) -> Color` (pure, testable).

- [ ] **Step 1 : Écrire le test de sélection de couleur**

```gdscript
extends GutTest

const BAR = preload("res://scenes/ResourceBar.tscn")
var bar

func before_each():
	bar = BAR.instantiate()
	add_child_autofree(bar)
	bar.setup("commerce", "Commerce")

func test_flash_direction_up_is_green():
	assert_eq(bar.flash_direction(1), Anim.settings.bar_flash_up,
		"une hausse flashe en vert")

func test_flash_direction_down_is_red():
	assert_eq(bar.flash_direction(-1), Anim.settings.bar_flash_down,
		"une baisse flashe en rouge")

func test_no_flash_when_value_unchanged():
	bar.update_value(50)
	bar._flash_color = Color(1, 1, 1, 0.0)
	bar.update_value(50)
	assert_almost_eq(bar._flash_color.a, 0.0, 0.001,
		"valeur inchangée : pas de flash")
```

- [ ] **Step 2 : Lancer le test (échec attendu)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_resource_bar.gd -gexit`
Expected: FAIL (`flash_direction` / `_flash_color` non définis).

- [ ] **Step 3 : Ajouter le flash dans `ResourceBar.gd`**

Ajouter l'état près des autres tweens (vers la ligne 37) :

```gdscript
var _flash_color: Color = Color(1, 1, 1, 0.0)
var _flash_tween: Tween
```

Ajouter la fonction pure et brancher `update_value`. Au début de `update_value`, avant le `clampi`, capturer l'ancienne valeur et déclencher le flash :

```gdscript
func update_value(value: int) -> void:
	var target := clampi(value, 0, 100)
	if target != _value:
		_trigger_flash(signi(target - _value))
	# … (reste inchangé : kill _value_tween, tween_method, etc.)
```

Ajouter :

```gdscript
# Couleur de flash selon le sens du changement (vert hausse / rouge baisse).
func flash_direction(delta_sign: int) -> Color:
	return Anim.settings.bar_flash_up if delta_sign >= 0 else Anim.settings.bar_flash_down

func _trigger_flash(delta_sign: int) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = Anim.color_flash(_set_flash, flash_direction(delta_sign))

func _set_flash(c: Color) -> void:
	_flash_color = c
	queue_redraw()
```

- [ ] **Step 4 : Rendre le flash dans `_draw`**

Dans `_draw`, après le dessin du `StyleBoxFlat` (`sb.draw(...)`, vers la ligne 141), ajouter un voile coloré sur la colonne :

```gdscript
	if _flash_color.a > 0.001:
		draw_rect(col_rect, _flash_color)
```

- [ ] **Step 5 : Lancer le test (succès attendu)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_resource_bar.gd -gexit`
Expected: 3 tests PASS.

- [ ] **Step 6 : Non-régression + vérification fenêtrée**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit` (tout passe).
Run: `godot --deck ambient` — glisser une carte : la/les barre(s) qui change(nt) **clignotent** brièvement en vert (hausse) ou rouge (baisse).

- [ ] **Step 7 : Commit**

```bash
git add src/ui/ResourceBar.gd tests/test_resource_bar.gd
git commit -m "feat(ui): resource bar colour flash on change (ValueAct)"
```

---

## Task 3 : Année qui défile (topbar)

**Files:**
- Modify: `src/ui/CardScreen.gd`

**Interfaces:**
- Consumes: `Anim.count_to`, `Anim.settings.year_count_dur`.
- Produces: aucun (effet visuel interne à `_update_info`).

- [ ] **Step 1 : Mémoriser l'année affichée**

Déclarer près des autres états de `CardScreen.gd` : `var _shown_year: int = -1`.

- [ ] **Step 2 : Animer le défilé dans `_update_info`**

Remplacer la ligne `_year_age.text = "An %d · %d ans" % [year, age]` par :

```gdscript
	if _shown_year < 0 or _shown_year == year:
		_year_age.text = "An %d · %d ans" % [year, age]
	else:
		Anim.count_to(_year_age, _shown_year, year,
			func(v: float, _t: int): return "An %s · %d ans" % [Anim.format_count(v, year), age])
	_shown_year = year
```

- [ ] **Step 3 : Vérification fenêtrée (manuelle)**

Run: `godot --deck ambient` — jouer jusqu'à un changement d'année (ou un respawn) : le nombre **défile** jusqu'à la nouvelle année au lieu de sauter.

- [ ] **Step 4 : Non-régression**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_card_screen.gd -gexit`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add src/ui/CardScreen.gd
git commit -m "feat(ui): animate year counter in topbar (TweenYearRoutine)"
```

---

## Task 4 : Écran de mort — révélation séquencée

**Files:**
- Modify: `src/ui/DeathScreen.gd`

**Interfaces:**
- Consumes: `Anim.fade_in`, `Anim.reveal_list`, `Anim.settings.death_*`.
- Produces: aucun (chorégraphie interne à `show_death`).

- [ ] **Step 1 : Identifier les nœuds à révéler**

En tête de `show_death`, juste avant la construction du tween d'entrée existant, masquer cause/titre/sous-titre/Seldon pour les révéler ensuite. Ajouter :

```gdscript
	var s := Anim.settings
	for n in [_cause, _speaker, _subtitle]:
		n.modulate.a = 0.0
	_seldon_text.modulate.a = 0.0
```

- [ ] **Step 2 : Séquencer la révélation**

Après `_build_snapshot(ctx)` et le tween de fond/compteurs existant, ajouter la cascade :

```gdscript
	# Révélation séquencée : cause+titre → sous-titre → snapshot → message Seldon.
	Anim.reveal_list([_cause, _speaker, _subtitle],
		s.death_list_stagger, s.death_text_in)
	var snap_items: Array = _snapshot.get_children()
	Anim.reveal_list(snap_items, s.death_list_stagger, s.death_item_in)
	Anim.fade_in(_seldon_text, s.death_text_in,
		s.death_list_stagger * (3 + snap_items.size()))
```

- [ ] **Step 3 : Vérifier que `_build_snapshot` initialise les enfants à `modulate.a = 0`**

Dans `_build_snapshot`, après avoir créé chaque colonne enfant et avant de l'ajouter, poser `col.modulate.a = 0.0` (sinon `reveal_list` part de l'opacité par défaut). Repérer la création de colonne dans la boucle `for r in Context.RESOURCES:` et ajouter `column.modulate.a = 0.0` juste avant `_snapshot.add_child(column)` (adapter au nom de variable local réel : lire les lignes 115-159 de `DeathScreen.gd`).

- [ ] **Step 4 : Vérification fenêtrée (manuelle)**

Run: provoquer une mort en jouant (`godot`) — l'écran de mort **révèle en cascade** : cause/titre, puis sous-titre, puis les 4 colonnes de ressources une à une, puis le message Seldon ; les compteurs s'animent comme avant.

- [ ] **Step 5 : Non-régression**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit`
Expected: tous PASS.

- [ ] **Step 6 : Commit**

```bash
git add src/ui/DeathScreen.gd
git commit -m "feat(ui): staggered reveal on death screen (AnimateObjectivesListIn)"
```

---

## Task 5 : Carte galactique — transition de teinte

**Files:**
- Modify: `src/ui/GalaxyMap.gd`
- Create: `tests/test_galaxy_map.gd`

**Interfaces:**
- Consumes: `Anim.color_to`, `Anim.settings.map_tint_dur`.
- Produces: `GalaxyMap.state_color(state: int) -> Color` (pure, testable).

- [ ] **Step 1 : Écrire le test de mapping état→couleur**

```gdscript
extends GutTest

const MAP = preload("res://scenes/GalaxyMap.tscn")
var map

func before_each():
	map = MAP.instantiate()
	add_child_autofree(map)

func test_state_color_allied():
	assert_eq(map.state_color(1), map.COLOR_ALLIED)

func test_state_color_hostile():
	assert_eq(map.state_color(-1), map.COLOR_HOSTILE)

func test_state_color_neutral():
	assert_eq(map.state_color(0), map.COLOR_NEUTRAL)
```

- [ ] **Step 2 : Lancer le test (échec attendu)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_galaxy_map.gd -gexit`
Expected: FAIL (`state_color` non définie).

- [ ] **Step 3 : Extraire `state_color` et animer la teinte**

Dans `GalaxyMap.gd`, remplacer le `match state` interne de `_style_planet` par un appel à une fonction pure, et mémoriser la couleur courante par bouton pour pouvoir interpoler. Ajouter :

```gdscript
var _planet_color: Dictionary = {}  # planet_id -> Color courante

func state_color(state: int) -> Color:
	match state:
		1: return COLOR_ALLIED
		-1: return COLOR_HOSTILE
		_: return COLOR_NEUTRAL
```

Dans `update(ctx)`, animer la transition au lieu d'appeler directement `_style_planet` avec couleur instantanée :

```gdscript
func update(ctx: Context) -> void:
	_ctx_ref = ctx
	for planet_id in _buttons:
		var state: int = ctx.get_var("planet_%s_state" % planet_id, 0)
		var to_c := state_color(state)
		var from_c: Color = _planet_color.get(planet_id, to_c)
		if from_c == to_c:
			_style_planet(_buttons[planet_id], to_c)
		else:
			Anim.color_to(func(c: Color): _style_planet(_buttons[planet_id], c),
				from_c, to_c, Anim.settings.map_tint_dur)
		_planet_color[planet_id] = to_c
```

Adapter la signature de `_style_planet` pour accepter une **couleur** au lieu d'un `state` :

```gdscript
func _style_planet(btn: Button, color: Color) -> void:
	for style_name in ["normal", "hover"]:
		var sb := btn.get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
		sb.bg_color = color
		sb.shadow_color = Color(color.r, color.g, color.b, 0.55 if style_name == "hover" else 0.4)
		btn.add_theme_stylebox_override(style_name, sb)
```

> Note : lire les lignes 118-141 de `GalaxyMap.gd` pour préserver les détails exacts du stylebox (rayons, bordures) lors de l'adaptation.

- [ ] **Step 4 : Lancer le test (succès attendu)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_galaxy_map.gd -gexit`
Expected: 3 tests PASS.

- [ ] **Step 5 : Vérification fenêtrée (manuelle)**

Run: `godot` — ouvrir la carte galactique (sceau topbar) après un changement d'état d'une planète : la couleur **transite** au lieu de claquer.

- [ ] **Step 6 : Non-régression + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/ui/GalaxyMap.gd tests/test_galaxy_map.gd
git commit -m "feat(ui): galaxy map tint transition (AnimateTint)"
```

---

## Task 6 : Menu principal — splash en cascade

**Files:**
- Modify: `src/ui/MainMenu.gd`

**Interfaces:**
- Consumes: `Anim.reveal_list`, `Anim.settings.menu_*`.
- Produces: aucun.

- [ ] **Step 1 : Remplacer `_menu_enter` par une cascade**

Dans `MainMenu.gd`, remplacer le corps de `_menu_enter` :

```gdscript
func _menu_enter() -> void:
	modulate.a = 1.0
	var s := Anim.settings
	Anim.reveal_list([_new_btn, _cont_btn, _opts_btn, _quit_btn],
		s.menu_stagger, s.menu_item_in)
```

> Si la scène a un nœud titre référencé, le placer en tête de la liste. Lire `scenes/MainMenu.tscn` pour confirmer la présence d'un `%Title` ; si présent, ajouter `@onready var _title := %Title` et le mettre en première position de `reveal_list`.

- [ ] **Step 2 : Vérification fenêtrée (manuelle)**

Run: `godot` — au lancement, le titre puis les boutons **apparaissent un par un** au lieu d'un fondu global.

- [ ] **Step 3 : Non-régression + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/ui/MainMenu.gd
git commit -m "feat(ui): main menu staggered splash (SplashAnimation)"
```

---

## Task 7 : Dérive de grille holographique

**Files:**
- Modify: `src/ui/CardScreen.gd`

**Interfaces:**
- Consumes: `Anim.settings.parallax_drift_speed`, `parallax_swipe_factor`.
- Produces: aucun (le shader holo du fond reçoit un offset).

- [ ] **Step 1 : Repérer le matériau de grille holo**

Lire `scenes/CardScreen.tscn` et `CardScreen.gd` (`_holo`, `ShaderMaterial`, paramètre `rect_size`) pour identifier le `ShaderMaterial` de la grille de fond et vérifier qu'il accepte un paramètre d'offset. Si le shader n'expose pas d'offset, ajouter un uniform `grid_offset : vec2` au shader (`.gdshader` référencé) et l'appliquer au sample de la grille.

- [ ] **Step 2 : Dériver l'offset dans `_process`**

Dans `_process` de `CardScreen.gd`, après `_apply_drag()`, faire dériver lentement la grille + réagir au drag :

```gdscript
	var holo_mat := _holo.material as ShaderMaterial
	if holo_mat:
		var s := Anim.settings
		var t := float(Time.get_ticks_msec()) / 1000.0
		var off := Vector2(t * s.parallax_drift_speed,
			_current_drag * s.parallax_swipe_factor)
		holo_mat.set_shader_parameter("grid_offset", off)
```

> Note : si l'ajout de l'uniform shader s'avère trop invasif, réinterpréter en décalant légèrement la **position** du `ColorRect` `_holo` (`_holo.position.x = _current_drag * parallax_swipe_factor`) — effet de parallaxe minimal sans toucher au shader. Choisir cette voie de repli si le shader n'a pas d'offset.

- [ ] **Step 3 : Vérification fenêtrée (manuelle)**

Run: `godot --deck ambient` — la grille de fond **dérive** lentement et se décale légèrement quand on glisse la carte.

- [ ] **Step 4 : Non-régression + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/ui/CardScreen.gd
git commit -m "feat(ui): holographic grid drift (parallax reinterpretation)"
```

---

## Task 8 : Écran Options — entrée/sortie + onglets

**Files:**
- Modify: `src/ui/OptionsScreen.gd`

**Interfaces:**
- Consumes: `Anim.fade_in`, `Anim.fade_out`, `Anim.reveal_list`, `Anim.settings.options_*`.
- Produces: `OptionsScreen.animate_out(on_done: Callable) -> void`.

- [ ] **Step 1 : Lire la structure de `OptionsScreen.gd`**

Lire `src/ui/OptionsScreen.gd` et `scenes/OptionsScreen.tscn` pour identifier le nœud racine, le moment d'apparition (`_ready` / `_enter`), les éléments d'onglet/sélecteur (ex: boutons de difficulté) et le bouton retour.

- [ ] **Step 2 : Animer l'entrée**

Dans `_ready` (ou la fonction d'entrée) de `OptionsScreen.gd`, après le câblage des boutons, ajouter :

```gdscript
	var s := Anim.settings
	Anim.fade_in(self, s.options_in)
	# Révèle les sélecteurs/onglets en cascade (adapter la liste aux nœuds réels).
	Anim.reveal_list(_tab_items(), s.options_tab_stagger, s.options_in)
```

Ajouter un accesseur retournant les éléments à révéler (à adapter aux nœuds réels lus au Step 1) :

```gdscript
# Éléments d'onglet/sélecteur révélés en cascade (ex: boutons de difficulté).
func _tab_items() -> Array:
	return [%DouxBtn, %NormalBtn, %BrutalBtn]
```

- [ ] **Step 3 : Animer la sortie**

Ajouter une sortie animée, et l'appeler depuis le handler du bouton retour (remplacer la fermeture immédiate) :

```gdscript
func animate_out(on_done: Callable) -> void:
	var tw := Anim.fade_out(self, Anim.settings.options_out)
	tw.finished.connect(on_done, CONNECT_ONE_SHOT)
```

Dans le handler de retour existant, remplacer la fermeture directe (`queue_free()` / `hide()` / `emit`) par :

```gdscript
	animate_out(func(): <fermeture existante>)
```

(remplacer `<fermeture existante>` par l'action de fermeture réellement présente, repérée au Step 1.)

- [ ] **Step 4 : Vérification fenêtrée (manuelle)**

Run: `godot` → menu → Options : l'écran **entre en fondu**, les sélecteurs de difficulté se révèlent **en cascade**, et le retour **sort en fondu**.

- [ ] **Step 5 : Non-régression + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/ui/OptionsScreen.gd
git commit -m "feat(ui): options screen in/out + tab icons cascade"
```

---

## Branchement du wobble de défaite (intégration)

`CardScreen.play_defeat()` (Task 1) doit être appelé avant l'affichage de l'écran de mort.

- [ ] **Step 1 : Trouver le point de bascule mort**

Dans `src/main/Main.gd`, repérer où la mort est détectée (après `apply_outcomes`/game-over check) et où `DeathScreen.show_death(...)` est invoqué.

- [ ] **Step 2 : Jouer le wobble avant l'écran de mort**

Avant d'afficher la `DeathScreen`, appeler `await card_screen.play_defeat()` (ou connecter la fin du tween) pour que la carte tremble et chute, puis enchaîner sur `show_death`. Adapter au flux réel de `Main.gd` (lire la zone de détection de mort).

- [ ] **Step 3 : Vérification fenêtrée + commit**

Run: `godot` — à la mort, la carte **tremble puis chute** avant l'apparition de l'écran de mort.

```bash
git add src/main/Main.gd
git commit -m "feat(ui): trigger card defeat wobble before death screen"
```

---

## Self-Review (effectué)

- **Couverture spec** : socle (Task 0), Carte entrée/wobble/flip (Task 1 + intégration), Barres (Task 2), Année (Task 3), Mort (Task 4), Carte galactique (Task 5), Menu (Task 6), Dérive grille (Task 7), Options (Task 8). Les 8 paquets + socle sont couverts.
- **Placeholders** : les seuls renvois « lire les lignes X » concernent l'adaptation à du code existant non reproduit ici (stylebox planète, fermeture Options, nœuds de scène) — ce sont des instructions de lecture, pas du code à inventer ; le code à écrire est fourni en entier.
- **Cohérence des types** : `Anim.smooth/format_count/fade_in/count_to/color_flash/color_to/pulse/reveal_list` définis en Task 0 et consommés tels quels ensuite ; `state_color`/`flash_direction`/`play_defeat` définis là où produits.
