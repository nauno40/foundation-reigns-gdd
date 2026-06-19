# Notification de déblocage de deck — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Afficher une notification modale « DECK X DÉBLOQUÉ » avec animation d'empilement de cartes, à la première apparition d'un deck « jalon » marqué par l'auteur.

**Architecture:** Un fichier de métadonnées liste les decks jalons (id→nom). Une fonction pure détecte le déblocage à tirer la carte ; `Main._next_card` affiche alors un overlay modal (instancié dynamiquement) avant la carte. Déblocage mémorisé une fois par carrière (flag toKeep). Tout le visuel réutilise le socle `Anim`.

**Tech Stack:** Godot 4.6, GDScript, GUT.

## Global Constraints

- Godot 4.6 ; tests GUT (`extends GutTest`, `before_each`/`before_all`, `test_*`).
- Déclencheur : decks listés dans `data/deck_unlocks.json` uniquement, à la **première apparition** d'une de leurs cartes.
- Persistance : **une fois par carrière**, via flag `toKeep` `deck_unlocked_<id>` (`set_var(key, 1, true)`).
- Interaction : **modale** — empilement puis tap/clic/`ui_accept` → carte déclencheuse.
- Style holographique (`src/ui/ThemeColors.gd`) ; timings via `Anim.settings` (aucune durée d'anim en dur).
- Pas d'édition de `scenes/Main.tscn` (overlay instancié dynamiquement par `Main.gd`).
- Suite GUT complète verte avant chaque commit :
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit`
- Branche : travailler sur `master` (le reste de la session y est).

---

## File Structure

- `data/deck_unlocks.json` *(créer)* — liste des decks jalons (id, name, subtitle).
- `src/core/FoundationGameData.gd` *(modifier)* — charger `deck_unlocks` dans un dict id→entrée.
- `src/core/DeckUnlock.gd` *(créer)* — détection pure (`pending_unlock`).
- `src/ui/AnimSettings.gd` *(modifier)* — groupe `Unlock` (timings).
- `data/anim_settings.tres` — inchangé (les nouveaux `@export` prennent leurs défauts).
- `scenes/DeckUnlockScreen.tscn` + `src/ui/DeckUnlockScreen.gd` *(créer)* — overlay modal + animation.
- `src/main/Main.gd` *(modifier)* — hook dans `_next_card` + `_show_deck_unlock`.
- `src/ui/AnimGallery.gd` *(modifier)* — bouton d'aperçu.
- `tests/test_deck_unlock.gd`, `tests/test_deck_unlocks_data.gd` *(créer)*.

---

## Task 1 : Données + chargement

**Files:**
- Create: `data/deck_unlocks.json`
- Modify: `src/core/FoundationGameData.gd`
- Create: `tests/test_deck_unlocks_data.gd`

**Interfaces:**
- Produces: `FoundationGameData.deck_unlocks : Dictionary` (id → `{id, name, subtitle}`).

- [ ] **Step 1 : Créer `data/deck_unlocks.json`**

```json
[
  { "id": "hardin_era",       "name": "Ère Hardin",            "subtitle": "La religion comme outil" },
  { "id": "merchant_era",     "name": "Ère des Marchands",     "subtitle": "L'expansion commerciale" },
  { "id": "encyclopaedia",    "name": "Projet Encyclopédie",   "subtitle": "Le savoir contre l'oubli" },
  { "id": "mentalic_inquiry", "name": "Enquête mentalique",    "subtitle": "Les pouvoirs de l'esprit" },
  { "id": "anacreon_throne",  "name": "Le Trône d'Anacréon",   "subtitle": "Le royaume militariste" },
  { "id": "church_schism",    "name": "Schisme de l'Église",   "subtitle": "La foi se fracture" },
  { "id": "fall_of_terminus", "name": "La Chute de Terminus",  "subtitle": "Le cœur menacé" },
  { "id": "riose_campaign",   "name": "Campagne de Bel Riose", "subtitle": "Le dernier grand général" },
  { "id": "kalgan_campaign",  "name": "Campagne de Kalgan",    "subtitle": "Le seigneur de guerre" },
  { "id": "bayta_darell",     "name": "Bayta Darell",          "subtitle": "L'intuition qui sauve" },
  { "id": "ebling_mis",       "name": "Ebling Mis",            "subtitle": "Le savant obsédé" },
  { "id": "hidden_speaker",   "name": "L'Orateur caché",       "subtitle": "La Seconde Fondation veille" }
]
```

- [ ] **Step 2 : Ajouter le champ + le chargement dans `FoundationGameData.gd`**

Après `var roles: Dictionary = {}` (ligne 14), ajouter :
```gdscript
var deck_unlocks: Dictionary = {}   # id -> {id, name, subtitle}
```
Dans `load_all()`, après la ligne `ok = ok and _load_dict("res://data/roles.json", roles)` (ligne 30), ajouter (chargement NON fatal : un fichier absent laisse `deck_unlocks` vide sans faire échouer `load_all`) :
```gdscript
	var _du: Array = []
	if _load_array("res://data/deck_unlocks.json", _du):
		for e in _du:
			if e is Dictionary and e.has("id"):
				deck_unlocks[str(e["id"])] = e
```

- [ ] **Step 3 : Écrire le test de données**

```gdscript
extends GutTest

var gd: FoundationGameData

func before_all():
	gd = FoundationGameData.new()
	gd.load_all()

func test_deck_unlocks_loaded():
	assert_gt(gd.deck_unlocks.size(), 0, "deck_unlocks doit être chargé")

func test_deck_unlocks_ids_exist_in_cards():
	var decks := {}
	for c in gd.cards:
		decks[str(c.get("deck", ""))] = true
	for id in gd.deck_unlocks:
		assert_true(decks.has(id), "le deck jalon '%s' doit exister dans les cartes" % id)

func test_deck_unlock_entries_have_name():
	for id in gd.deck_unlocks:
		assert_ne(str(gd.deck_unlocks[id].get("name", "")), "", "%s doit avoir un nom" % id)
```

- [ ] **Step 4 : Lancer le test**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_deck_unlocks_data.gd -gexit`
Expected: 3 tests PASS.

- [ ] **Step 5 : Suite complète + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add data/deck_unlocks.json src/core/FoundationGameData.gd tests/test_deck_unlocks_data.gd
git commit -m "feat(data): deck_unlocks.json + loading (milestone decks)"
```

---

## Task 2 : Détection pure `DeckUnlock`

**Files:**
- Create: `src/core/DeckUnlock.gd`
- Create: `tests/test_deck_unlock.gd`

**Interfaces:**
- Consumes: `Context` (`get_var`), `FoundationGameData.deck_unlocks`.
- Produces: `DeckUnlock.pending_unlock(card: Dictionary, ctx: Context, unlocks: Dictionary) -> Dictionary` (l'entrée `{id,name,subtitle}` ou `{}`).

- [ ] **Step 1 : Écrire le test (TDD)**

```gdscript
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
```

- [ ] **Step 2 : Lancer (échec attendu)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_deck_unlock.gd -gexit`
Expected: FAIL (`DeckUnlock` non défini).

- [ ] **Step 3 : Implémenter `src/core/DeckUnlock.gd`**

```gdscript
class_name DeckUnlock

# Retourne l'entrée du deck à débloquer ({id, name, subtitle}) si la carte
# appartient à un deck jalon (présent dans `unlocks`) pas encore débloqué
# (flag toKeep deck_unlocked_<id> non posé). Sinon {} (cas par défaut).
static func pending_unlock(card: Dictionary, ctx: Context, unlocks: Dictionary) -> Dictionary:
	var deck: String = str(card.get("deck", ""))
	if deck == "" or not unlocks.has(deck):
		return {}
	if int(ctx.get_var("deck_unlocked_" + deck, 0)) != 0:
		return {}
	return unlocks[deck]
```

- [ ] **Step 4 : Lancer (succès attendu)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_deck_unlock.gd -gexit`
Expected: 4 tests PASS.

- [ ] **Step 5 : Suite complète + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/core/DeckUnlock.gd tests/test_deck_unlock.gd
git commit -m "feat(core): DeckUnlock.pending_unlock detection (pure)"
```

---

## Task 3 : Overlay `DeckUnlockScreen` + timings

**Files:**
- Modify: `src/ui/AnimSettings.gd`
- Create: `scenes/DeckUnlockScreen.tscn`
- Create: `src/ui/DeckUnlockScreen.gd`

**Interfaces:**
- Consumes: `Anim.settings.unlock_*`, `Anim.fade_in`, `Anim.reveal_list`, `ThemeColors`.
- Produces: `DeckUnlockScreen.show_unlock(entry: Dictionary) -> void` ; signal `continue_pressed`.

- [ ] **Step 1 : Ajouter le groupe Unlock à `AnimSettings.gd`**

À la fin de `src/ui/AnimSettings.gd`, ajouter :
```gdscript

@export_group("Unlock")
@export var unlock_card_fly := 0.4
@export var unlock_stagger := 0.09
@export var unlock_card_offset := 14.0
@export var unlock_card_tilt := 5.0
@export var unlock_text_in := 0.35
```

- [ ] **Step 2 : Créer `scenes/DeckUnlockScreen.tscn` (racine minimale, UI construite en code)**

```
[gd_scene load_steps=2 format=3 uid="uid://bdeckunlock01"]

[ext_resource type="Script" path="res://src/ui/DeckUnlockScreen.gd" id="1_unlock"]

[node name="DeckUnlockScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_unlock")
```

- [ ] **Step 3 : Implémenter `src/ui/DeckUnlockScreen.gd`**

```gdscript
extends Control

# Overlay modal de déblocage de deck : empilement de cartes holographiques
# + « NOUVEAU DECK / nom / DÉBLOQUÉ », puis tap pour continuer.

const ThemeColors = preload("res://src/ui/ThemeColors.gd")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")

signal continue_pressed

const CARD_COUNT := 5
const CARD_SIZE := Vector2(116, 162)

var _stack: Control
var _name_label: Label
var _sub_label: Label
var _hint: Label
var _cards: Array = []
var _can_continue: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	col.add_child(_mk_label("NOUVEAU DECK", FONT_MONO, 12, ThemeColors.ACCENT))
	_stack = Control.new()
	_stack.custom_minimum_size = CARD_SIZE + Vector2(60, 40)
	col.add_child(_stack)
	_name_label = _mk_label("", FONT_SPECTRAL, 24, ThemeColors.INK)
	col.add_child(_name_label)
	col.add_child(_mk_label("DÉBLOQUÉ", FONT_MONO, 12, ThemeColors.AMBER))
	_sub_label = _mk_label("", FONT_SPECTRAL, 13, ThemeColors.INK_DIM)
	col.add_child(_sub_label)
	_hint = _mk_label("Tap pour continuer", FONT_MONO, 11, ThemeColors.INK_FAINT)
	col.add_child(_hint)

func _mk_label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _mk_card() -> Panel:
	var p := Panel.new()
	p.size = CARD_SIZE
	p.pivot_offset = CARD_SIZE * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.16, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(ThemeColors.ACCENT.r, ThemeColors.ACCENT.g, ThemeColors.ACCENT.b, 0.5)
	sb.shadow_color = Color(ThemeColors.ACCENT.r, ThemeColors.ACCENT.g, ThemeColors.ACCENT.b, 0.22)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	return p

func show_unlock(entry: Dictionary) -> void:
	_name_label.text = "« %s »" % str(entry.get("name", "Deck"))
	_sub_label.text = str(entry.get("subtitle", ""))
	_sub_label.visible = _sub_label.text != ""
	for n in [_name_label, _sub_label, _hint]:
		n.modulate.a = 0.0
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_can_continue = false
	Anim.fade_in(self, 0.2)
	await get_tree().process_frame   # _stack a sa taille
	var s := Anim.settings
	var base := (_stack.size - CARD_SIZE) * 0.5
	var tw := create_tween().set_parallel()
	for i in range(CARD_COUNT):
		var card := _mk_card()
		_stack.add_child(card)
		var fan := (i - (CARD_COUNT - 1) / 2.0)
		var final_pos := base + Vector2(fan * s.unlock_card_offset, 0.0)
		var final_rot := deg_to_rad(fan * s.unlock_card_tilt)
		card.position = base + Vector2(0.0, 420.0)
		card.rotation = 0.0
		var delay := i * s.unlock_stagger
		tw.tween_property(card, "position", final_pos, s.unlock_card_fly) \
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "rotation", final_rot, s.unlock_card_fly) \
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_cards.append(card)
	await get_tree().create_timer(CARD_COUNT * s.unlock_stagger + s.unlock_card_fly).timeout
	Anim.reveal_list([_name_label, _sub_label, _hint], s.unlock_stagger, s.unlock_text_in)
	_can_continue = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _can_continue:
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		continue_pressed.emit()
```

- [ ] **Step 4 : Smoke headless de l'overlay (script jetable)**

```bash
cat > _unlock_smoke.gd <<'GD'
extends SceneTree
func _initialize():
	var s = load("res://scenes/DeckUnlockScreen.tscn").instantiate()
	root.add_child(s)
	await process_frame
	s.show_unlock({"name": "Réseau d'espions", "subtitle": "Vos agents dans l'ombre"})
	await create_timer(1.2).timeout
	s.call("_unhandled_input", InputEventAction.new())  # ne plante pas
	print(">>> UNLOCK_SMOKE_OK")
	quit()
GD
godot --headless -s _unlock_smoke.gd 2>&1 | grep -iE "error|nil|invalid|UNLOCK_SMOKE_OK" | grep -viE "no errors"
rm -f _unlock_smoke.gd
```
Expected: une ligne `>>> UNLOCK_SMOKE_OK`, aucune erreur.

- [ ] **Step 5 : Suite complète + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/ui/AnimSettings.gd scenes/DeckUnlockScreen.tscn src/ui/DeckUnlockScreen.gd
git commit -m "feat(ui): DeckUnlockScreen overlay (card stack animation)"
```

---

## Task 4 : Intégration dans `Main.gd`

**Files:**
- Modify: `src/main/Main.gd`

**Interfaces:**
- Consumes: `DeckUnlock.pending_unlock`, `FoundationGameData.deck_unlocks`, `DeckUnlockScreen`.

- [ ] **Step 1 : Précharger l'overlay**

En tête de `src/main/Main.gd`, près des autres `const`/préchargements, ajouter :
```gdscript
const DECK_UNLOCK_SCENE = preload("res://scenes/DeckUnlockScreen.tscn")
```

- [ ] **Step 2 : Brancher la détection dans `_next_card`**

Dans `_next_card()`, remplacer la ligne finale :
```gdscript
	_card_screen.show_card(_current_card, _ctx)
	_awaiting_reaction = false
```
par :
```gdscript
	# Notification de déblocage de deck (jalon, première apparition).
	var unlock := DeckUnlock.pending_unlock(_current_card, _ctx, _game_data.deck_unlocks)
	if not unlock.is_empty():
		_ctx.set_var("deck_unlocked_" + str(unlock["id"]), 1, true)
		_show_deck_unlock(unlock)
		_awaiting_reaction = false
		return
	_card_screen.show_card(_current_card, _ctx)
	_awaiting_reaction = false
```

- [ ] **Step 3 : Ajouter `_show_deck_unlock`**

Ajouter cette méthode dans `Main.gd` (par exemple juste après `_next_card`) :
```gdscript
# Affiche l'overlay de déblocage ; à la fermeture, montre la carte en attente.
func _show_deck_unlock(entry: Dictionary) -> void:
	var screen = DECK_UNLOCK_SCENE.instantiate()
	add_child(screen)
	screen.continue_pressed.connect(func():
		screen.queue_free()
		_card_screen.show_card(_current_card, _ctx)
	, CONNECT_ONE_SHOT)
	screen.show_unlock(entry)
```

- [ ] **Step 4 : Parse + smoke avec un deck jalon**

```bash
godot --headless --check-only --script src/main/Main.gd 2>&1 | grep -iE "error" | grep -viE "Identifier not found: (Anim|Globals|DeckUnlock)" | grep -viE "no errors" || true
```
(les « Identifier not found » d'autoload/class_name en vérif isolée sont attendus.)
```bash
timeout 12 godot --headless --deck hardin_era 2>&1 | grep -iE "error|script error|nil|invalid|in function" | grep -viE "no errors|0 error"
```
Expected : rien. (`--deck hardin_era` tire une carte du deck jalon `hardin_era` → `_next_card` déclenche l'overlay sans erreur.)

- [ ] **Step 5 : Suite complète + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/main/Main.gd
git commit -m "feat(game): trigger deck-unlock overlay on first milestone-deck card"
```

---

## Task 5 : Bouton d'aperçu dans la galerie

**Files:**
- Modify: `src/ui/AnimGallery.gd`

**Interfaces:**
- Consumes: `DeckUnlockScreen`, `_open_overlay`.

- [ ] **Step 1 : Précharger + ajouter le bouton**

Dans `src/ui/AnimGallery.gd`, près des autres `preload` en tête, ajouter :
```gdscript
const DECK_UNLOCK = preload("res://scenes/DeckUnlockScreen.tscn")
```
Dans `_build_ui()`, dans la section « ÉCRANS (overlay) », après le bouton « Options : sortie » (avant « ← Retour carte »), ajouter :
```gdscript
	_btn(list, "Deck débloqué", _open_unlock)
```

- [ ] **Step 2 : Ajouter le handler**

Ajouter dans `AnimGallery.gd` (près des autres `_open_*`) :
```gdscript
func _open_unlock() -> void:
	var u := DECK_UNLOCK.instantiate()
	_open_overlay(u)
	await get_tree().process_frame
	u.show_unlock({"name": "Réseau d'espions", "subtitle": "Vos agents dans l'ombre"})
	_say("Deck débloqué : empilement de cartes + nom (modal, tap pour fermer)")
```

- [ ] **Step 3 : Smoke de la galerie (le handler ne plante pas)**

```bash
cat > _gal2_smoke.gd <<'GD'
extends SceneTree
func _initialize():
	var g = load("res://scenes/AnimGallery.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	g.call("_open_unlock")
	await create_timer(1.0).timeout
	print(">>> GAL2_OK")
	quit()
GD
godot --headless -s _gal2_smoke.gd 2>&1 | grep -iE "error|nil|invalid|GAL2_OK" | grep -viE "no errors"
rm -f _gal2_smoke.gd
```
Expected : `>>> GAL2_OK`, aucune erreur.

- [ ] **Step 4 : Suite complète + commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
git add src/ui/AnimGallery.gd
git commit -m "feat(dev): deck-unlock preview button in animation gallery"
```

---

## Self-Review (effectué)

- **Couverture spec** : données+loader (T1), détection pure (T2), overlay+animation+timings (T3), intégration `_next_card`/toKeep (T4), bouton galerie (T5). Tests : T1 (données), T2 (détection). Tous les points du spec sont couverts.
- **Placeholders** : aucun ; tout le code est fourni. Les renvois « après la ligne X » pointent du code existant non reproduit, pas du code à inventer.
- **Cohérence des types** : `deck_unlocks: Dictionary` (T1) consommé par `pending_unlock(card, ctx, unlocks)` (T2) et `Main` (T4) ; `DeckUnlockScreen.show_unlock(entry)` + signal `continue_pressed` (T3) consommés par `Main._show_deck_unlock` (T4) et la galerie (T5) ; `Anim.settings.unlock_*` (T3) défini en T3.
