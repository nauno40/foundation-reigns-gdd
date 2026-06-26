# Refactor Godot — Foundation Reigns — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactoriser le projet vers des pratiques Godot 4 idiomatiques (signaux modernes, input map, machine à états, scènes/AnimationPlayer, theme, audio, data typée) **sans changer le comportement du jeu**.

**Architecture :** Refactor incrémental en 6 lots indépendamment lançables (A→F), 1 commit par lot, vérification dans l'éditeur Godot entre chaque lot. Chaque lot laisse le jeu jouable à l'identique.

**Tech Stack :** Godot 4.7, GDScript, MCP `godot-ai` (éditeur persistant pour parse-check + run + logs).

## Global Constraints

- Le jeu doit se lancer et se jouer **exactement comme avant** après chaque lot. — copié du spec.
- Ne **pas** modifier les assets (shaders `.gdshader`, polices `.ttf`, icônes/SVG). — copié du spec.
- Supprimer le code mort remplacé (pas d'ancien + nouveau côte à côte). — copié du spec.
- Tous les commentaires en **français**. — copié du spec.
- `@tool` autorisé ; préserver les branches `Engine.is_editor_hint()` (aperçus éditeur de `CardView`, `Death`, `Codex`, `CodexTab`, `CharacterCard`, `Gauge`, `Cfg`).
- Couleurs ressources oklch (`Pal.MILITARY`…) et la conversion `res_color()` ne sont **pas** thématisables — restent dans `Theme.gd`.

## Modèle de vérification (remplace le cycle TDD)

Ce dépôt n'a pas de tests unitaires (pas de GUT) et le but est la **parité de comportement**, pas une nouvelle feature. La « boucle de test » de chaque tâche est donc :

1. **Parse-check** : MCP `editor_reload_plugin` n'est pas requis ; utiliser `mcp__godot-ai__editor_state` puis `mcp__godot-ai__logs_read` pour confirmer 0 erreur de script après réouverture/scan. Alternative CLI : `godot --headless --check-only --script <fichier.gd>` si le binaire est dispo.
2. **Run** : `mcp__godot-ai__project_run` puis `mcp__godot-ai__logs_read` → aucune erreur runtime au démarrage.
3. **Checkpoint utilisateur** (fin de lot uniquement) : l'utilisateur teste à l'œil swipe (clavier+souris), mort+respawn, codex (ouverture/drag/onglets), panneau Tweaks. Go explicite avant le lot suivant.

« Expected: PASS » dans ce plan signifie : **0 erreur** dans `logs_read` et jeu lancé.

---

## LOT A — Fondations sûres (Étapes 1, 8, 4)

Risque 🟢. Signaux modernes nommés, Input Map, `@export`. Aucun changement de comportement attendu.

### Task A1 : Signaux nommés dans Game.gd

**Files:**
- Modify: `src/Game.gd` (connexions `_ready`/`_make_overlays` ~l.61-117, timer ~l.346-349)

**Interfaces:**
- Produces: méthodes privées `_on_gear_pressed()`, `_on_deck_unlock_cleanup(fx, banfx)` consommées par les connexions.

- [ ] **Step 1 : Grouper les connexions de `_ready()`**

Dans `src/Game.gd`, les connexions sont déjà en syntaxe moderne mais éparpillées. Regrouper en un bloc lisible. Remplacer les lignes actuelles (l.61-64) :

```gdscript
	_cardview.committed.connect(_on_committed)
	_cardview.preview.connect(_on_preview)
	_stage.resized.connect(_layout_stage)
	_handle.gui_input.connect(_on_handle_input)
```

par un bloc commenté groupé :

```gdscript
	_connect_signals()
```

et ajouter la méthode (après `_ready`) :

```gdscript
# Branche tous les signaux de la scène en un seul endroit (lisibilité).
func _connect_signals() -> void:
	_cardview.committed.connect(_on_committed)
	_cardview.preview.connect(_on_preview)
	_stage.resized.connect(_layout_stage)
	_handle.gui_input.connect(_on_handle_input)
	_death.respawn_pressed.connect(_respawn)
	Cfg.changed.connect(_on_cfg_changed)
```

Puis **retirer** de `_make_overlays()` les lignes `_death.respawn_pressed.connect(_respawn)` (l.85) et `Cfg.changed.connect(_on_cfg_changed)` (l.117), désormais centralisées.

- [ ] **Step 2 : Remplacer la lambda du gear par une méthode nommée**

Dans `_make_overlays()`, remplacer (l.114) :

```gdscript
	gear.pressed.connect(func(): _tweaks.open())
```

par :

```gdscript
	gear.pressed.connect(_on_gear_pressed)
```

et ajouter la méthode :

```gdscript
func _on_gear_pressed() -> void:
	_tweaks.open()
```

- [ ] **Step 3 : Remplacer la lambda multi-lignes du timer deck-unlock**

Dans `_play_deck_unlock()`, remplacer (l.346-349) :

```gdscript
	get_tree().create_timer(2.4).timeout.connect(func():
		if is_instance_valid(fx): fx.queue_free()
		if is_instance_valid(banfx): banfx.queue_free()
	, CONNECT_ONE_SHOT)
```

par une connexion liée à une méthode nommée (lambda > 3 lignes → méthode `_on_…`) :

```gdscript
	get_tree().create_timer(2.4).timeout.connect(
		_on_deck_unlock_cleanup.bind(fx, banfx), CONNECT_ONE_SHOT)
```

et ajouter :

```gdscript
# Nettoie les nœuds temporaires de la bannière de déblocage de deck.
func _on_deck_unlock_cleanup(fx: Control, banfx: Control) -> void:
	if is_instance_valid(fx): fx.queue_free()
	if is_instance_valid(banfx): banfx.queue_free()
```

- [ ] **Step 4 : Parse-check + run**

Run: MCP `mcp__godot-ai__project_run` puis `mcp__godot-ai__logs_read`.
Expected: PASS (0 erreur ; le gear ouvre Tweaks, la bannière deck disparaît après 2.4 s).

- [ ] **Step 5 : Commit**

```bash
git add src/Game.gd
git commit -m "refactor(signaux): Game.gd — connexions groupées + lambdas → méthodes _on_"
```

### Task A2 : Signaux nommés dans Codex.gd

**Files:**
- Modify: `src/Codex.gd` (l.42-46, 69-73, 222-227)

**Interfaces:**
- Produces: `_on_tab_chars()`, `_on_tab_ach()`, `_on_tab_gal()`, `_on_holder_resized()`, `_on_galaxy_resized()`, `_on_slide_hidden()`.

- [ ] **Step 1 : Onglets + holder (lambdas courtes → méthodes nommées pour cohérence)**

Remplacer (l.42-46) :

```gdscript
	(%TabChars as CodexTab).tab_pressed.connect(func(): _select("chars"))
	(%TabAch as CodexTab).tab_pressed.connect(func(): _select("ach"))
	(%TabGal as CodexTab).tab_pressed.connect(func(): _select("gal"))
	%Grab.pressed.connect(close)
	_holder.resized.connect(func(): _scroll.size = _holder.size)
```

par :

```gdscript
	(%TabChars as CodexTab).tab_pressed.connect(_on_tab_chars)
	(%TabAch as CodexTab).tab_pressed.connect(_on_tab_ach)
	(%TabGal as CodexTab).tab_pressed.connect(_on_tab_gal)
	%Grab.pressed.connect(close)
	_holder.resized.connect(_on_holder_resized)
```

Ajouter les méthodes :

```gdscript
func _on_tab_chars() -> void: _select("chars")
func _on_tab_ach() -> void: _select("ach")
func _on_tab_gal() -> void: _select("gal")
func _on_holder_resized() -> void: _scroll.size = _holder.size
```

- [ ] **Step 2 : Lambda CONNECT_ONE_SHOT de `_animate_to`**

Remplacer (l.73) :

```gdscript
		t.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)
```

par :

```gdscript
		t.finished.connect(_on_slide_hidden, CONNECT_ONE_SHOT)
```

Ajouter :

```gdscript
func _on_slide_hidden() -> void: visible = false
```

- [ ] **Step 3 : Galaxie (lambda resized multi-lignes → méthode)**

Remplacer (l.222-227) :

```gdscript
	_galaxy.draw.connect(_draw_galaxy)
	_galaxy.gui_input.connect(_galaxy_input)
	_galaxy.resized.connect(func():
		if not is_equal_approx(_galaxy.custom_minimum_size.y, _galaxy.size.x):
			_galaxy.custom_minimum_size.y = _galaxy.size.x
		_galaxy.queue_redraw())
```

par :

```gdscript
	_galaxy.draw.connect(_draw_galaxy)
	_galaxy.gui_input.connect(_galaxy_input)
	_galaxy.resized.connect(_on_galaxy_resized)
```

Ajouter :

```gdscript
func _on_galaxy_resized() -> void:
	if not is_equal_approx(_galaxy.custom_minimum_size.y, _galaxy.size.x):
		_galaxy.custom_minimum_size.y = _galaxy.size.x
	_galaxy.queue_redraw()
```

- [ ] **Step 4 : Run + vérif codex**

Run: `mcp__godot-ai__project_run` + `logs_read`.
Expected: PASS (onglets cliquables, carrousel/slide OK, galaxie se redessine).

- [ ] **Step 5 : Commit**

```bash
git add src/Codex.gd
git commit -m "refactor(signaux): Codex.gd — lambdas → méthodes _on_ nommées"
```

### Task A3 : Signaux nommés dans TweaksPanel, Death, CharacterCard, Root

**Files:**
- Modify: `src/TweaksPanel.gd` (l.46, 63, 71, 79, 102, 115), `src/Death.gd` (l.21), `src/CharacterCard.gd` (l.17), `src/Root.gd` (l.9, 24)

**Interfaces:**
- Produces: `Death._on_new_reign_pressed()`, `CharacterCard._on_grid_resized()`. Les lambdas de `TweaksPanel` qui **capturent une variable de boucle** (`hexc`, `dd`) restent des lambdas (≤ 3 lignes, capture nécessaire) — conformes à la règle « > 3 lignes → méthode ».

- [ ] **Step 1 : Death.gd — bouton respawn**

Remplacer (l.21) :

```gdscript
	%NewReignBtn.pressed.connect(func(): respawn_pressed.emit())
```

par :

```gdscript
	%NewReignBtn.pressed.connect(_on_new_reign_pressed)
```

Ajouter :

```gdscript
func _on_new_reign_pressed() -> void:
	respawn_pressed.emit()
```

- [ ] **Step 2 : CharacterCard.gd — grid resized**

Remplacer (l.17) :

```gdscript
	_grid.resized.connect(func(): (_grid.material as ShaderMaterial).set_shader_parameter("rect_size", _grid.size))
```

par :

```gdscript
	_grid.resized.connect(_on_grid_resized)
```

Ajouter :

```gdscript
func _on_grid_resized() -> void:
	(_grid.material as ShaderMaterial).set_shader_parameter("rect_size", _grid.size)
```

- [ ] **Step 3 : TweaksPanel.gd — `close` lambda one-shot**

Remplacer (l.115) :

```gdscript
	t.finished.connect(func(): visible = false, CONNECT_ONE_SHOT)
```

par :

```gdscript
	t.finished.connect(_on_close_hidden, CONNECT_ONE_SHOT)
```

Ajouter :

```gdscript
func _on_close_hidden() -> void: visible = false
```

Les autres connexions de `TweaksPanel` (`sw.pressed`, `grain.value_changed`, `prose.value_changed`, `b.pressed`) capturent une variable de boucle (`hexc`, `v`, `dd`) et font ≤ 3 lignes : **les laisser en lambda** (conforme à la règle). `x.pressed.connect(close)` est déjà idéal.

- [ ] **Step 4 : Root.gd — déjà conforme, vérifier seulement**

`Root.gd` utilise déjà `resized.connect(_on_resized)` et `Cfg.changed.connect(_apply_motion)` (méthodes nommées). **Aucune modification.**

- [ ] **Step 5 : Run + vérif (mort, respawn, codex chars, fond)**

Run: `mcp__godot-ai__project_run` + `logs_read`.
Expected: PASS.

- [ ] **Step 6 : Commit**

```bash
git add src/Death.gd src/CharacterCard.gd src/TweaksPanel.gd
git commit -m "refactor(signaux): Death/CharacterCard/TweaksPanel — lambdas → méthodes _on_"
```

### Task A4 : Input Map (swipe_left, swipe_right, codex_toggle)

**Files:**
- Modify: `project.godot` (ajout section `[input]`), `src/Game.gd` (l.149-150 `_unhandled_input`, ajout toggle codex)

**Interfaces:**
- Consumes: les actions `swipe_left`, `swipe_right`, `codex_toggle` définies dans `project.godot`.

- [ ] **Step 1 : Déclarer les actions dans project.godot**

Préférer le MCP `mcp__godot-ai__input_map_manage` (op `add_action` + `bind_event`) pour écrire un format binaire correct. À défaut, ajouter à la main une section `[input]` dans `project.godot` après `[display]` :

```ini
[input]

swipe_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
swipe_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
codex_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":67,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

(`physical_keycode` 4194319 = flèche gauche, 4194321 = flèche droite, 65 = A, 68 = D, 67 = C.)

- [ ] **Step 2 : Utiliser les nouvelles actions dans `_unhandled_input`**

Dans `src/Game.gd`, remplacer (l.147-150) :

```gdscript
func _unhandled_input(e: InputEvent) -> void:
	if busy or _death.visible or _codex.visible: return
	if e.is_action_pressed("ui_left"): _cardview.swipe(true)
	elif e.is_action_pressed("ui_right"): _cardview.swipe(false)
```

par :

```gdscript
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("codex_toggle"):
		if _codex.visible: _codex.close()
		elif not busy and not _death.visible: _codex.open("chars")
		return
	if busy or _death.visible or _codex.visible: return
	if e.is_action_pressed("swipe_left"): _cardview.swipe(true)
	elif e.is_action_pressed("swipe_right"): _cardview.swipe(false)
```

(Note : le check `busy/_death.visible/_codex.visible` sera remplacé par la machine à états au Lot B ; ici on garde le comportement existant en changeant seulement les noms d'action et en ajoutant le toggle.)

- [ ] **Step 3 : Run + vérif inputs**

Run: `mcp__godot-ai__project_run` + `logs_read`.
Expected: PASS. Flèches gauche/droite **et** A/D font swiper ; C ouvre/ferme le codex.

- [ ] **Step 4 : Commit**

```bash
git add project.godot src/Game.gd
git commit -m "feat(input): actions swipe_left/right + codex_toggle (remplace ui_left/right)"
```

### Task A5 : @export des valeurs magiques

**Files:**
- Modify: `src/Game.gd`, `src/CardView.gd`, `src/Gauge.gd`, `src/Death.gd`

**Interfaces:**
- Produces: propriétés exportées remplaçant des `const`/littéraux ; mêmes valeurs par défaut → comportement identique.

- [ ] **Step 1 : Game.gd**

**Décision DRY :** le spec liste `card_flyout_distance`/`card_flyout_duration` sous `Game.gd`, mais le fly-out est entièrement géré dans `CardView._fly_out()`. Pour éviter de dupliquer la valeur entre deux scripts, ces deux-là vivent **uniquement dans `CardView`** (Step 2). `Game.gd` n'expose que ce qu'il consomme lui-même.

Ajouter après les `const` de `Game.gd` (vers l.17) :

```gdscript
@export var question_fade_duration: float = 0.35
@export var death_fx_duration: float = 0.76
@export var deck_unlock_lifetime: float = 2.4
```

Remplacer les littéraux correspondants :
- l.234 `_refresh_card()` : `..., 0.35).set_ease(...)` → `..., question_fade_duration).set_ease(...)`
- l.248 `_play_death()` : `..., 0.0, 1.0, 0.76)` → `..., 0.0, 1.0, death_fx_duration)`
- `_play_deck_unlock()` : le timer `create_timer(2.4)` → `create_timer(deck_unlock_lifetime)`.

- [ ] **Step 2 : CardView.gd — const → @export**

Remplacer le bloc `const` (l.15-20) :

```gdscript
const THRESHOLD := 92.0
const REVEAL := 12.0
const ROT := 0.055
const GRAB_SCALE := 1.025
const STIFF := 0.16
const DAMP := 0.74
```

par :

```gdscript
@export var threshold: float = 92.0
@export var reveal_threshold: float = 12.0
@export var rotation_per_drag: float = 0.055
@export var grab_scale: float = 1.025
@export var stiffness: float = 0.16
@export var damping: float = 0.74
@export var flyout_distance: float = 700.0
@export var flyout_duration: float = 0.42
```

Remplacer toutes les utilisations : `THRESHOLD`→`threshold` (l.125), `REVEAL`→`reveal_threshold` (l.156), `ROT`→`rotation_per_drag` (l.151), `GRAB_SCALE`→`grab_scale` (l.152), `STIFF`→`stiffness` (l.139,141), `DAMP`→`damping` (l.139,141). Dans `_fly_out()` : `700.0`→`flyout_distance` (l.172), les deux `0.42`→`flyout_duration` (l.174-175).

- [ ] **Step 3 : Gauge.gd**

Ajouter après les `const` (vers l.18) :

```gdscript
@export var tween_duration: float = 0.55
@export var flash_duration: float = 0.2
```

Remplacer : l.78 `..., 0.55)` → `..., tween_duration)` ; dans `_flash_delta` les deux `0.2` d'apparition (l.128-129) → `flash_duration`.

- [ ] **Step 4 : Death.gd**

Ajouter après le signal (vers l.9) :

```gdscript
@export var sweep_duration: float = 0.7
@export var entry_scale: float = 1.035
@export var entry_duration: float = 0.5
```

Remplacer : `_play_sweep()` les `0.7` (l.81-82) → `sweep_duration` ; `show_death()` `Vector2(1.035, 1.035)` (l.51) → `Vector2(entry_scale, entry_scale)` ; les `0.5` du tween d'entrée (l.54-55) → `entry_duration`.

- [ ] **Step 5 : Run + vérif (mort, swipe, jauges, sweep identiques)**

Run: `mcp__godot-ai__project_run` + `logs_read`.
Expected: PASS, animations visuellement inchangées.

- [ ] **Step 6 : Commit**

```bash
git add src/Game.gd src/CardView.gd src/Gauge.gd src/Death.gd
git commit -m "refactor(@export): valeurs magiques réglables dans l'inspecteur (mêmes défauts)"
```

### Checkpoint Lot A

Demander à l'utilisateur de vérifier dans Godot : swipe (flèches + A/D + souris), mort + nouveau règne, codex (C + drag poignée + onglets + galaxie), bouton ⚙ → Tweaks (accent/grain/texte/difficulté), bannière de déblocage de deck. **Attendre le go.**

---

## LOT B — Cœur logique (Étapes 9, 10)

Risque 🟠. Machine à états + groupe `gauges`. Comportement identique.

### Task B1 : Groupe `gauges`

**Files:**
- Modify: `scenes/Game.tscn` (ajouter les 4 `Gauge` au groupe `gauges`), `src/Game.gd`

**Interfaces:**
- Consumes: propriété `Gauge.resource_key` (déjà existante, exportée).
- Produces: `Game._get_gauges() -> Array[Gauge]`, helper `_gauge(key) -> Gauge`.

- [ ] **Step 1 : Ajouter les jauges au groupe (scène)**

Via MCP `mcp__godot-ai__node_manage` op `add_to_group` (`persistent=true`) sur `%BarMilitary`, `%BarReligion`, `%BarCommerce`, `%BarPolitics`, groupe `gauges`. Vérifier aussi que chaque jauge a son `resource_key` correct dans l'inspecteur (military/religion/commerce/politics).

- [ ] **Step 2 : Remplacer le dict `_gauges` par le groupe**

Dans `src/Game.gd`, retirer `var _gauges := {}` (l.50) et l'init (l.55). Ajouter :

```gdscript
# Les jauges sont dans le groupe "gauges" ; on les indexe par resource_key.
func _get_gauges() -> Array:
	return get_tree().get_nodes_in_group("gauges")

func _gauge(key: String) -> Gauge:
	for g in _get_gauges():
		if (g as Gauge).resource_key == key:
			return g
	return null
```

- [ ] **Step 3 : Adapter les usages de `_gauges`**

Remplacer chaque accès :
- `_ready` (l.56-57) :
```gdscript
	for r in Data.RESOURCES:
		_gauge(r["key"]).setup(r["key"], r["label"])
```
- `_on_cfg_changed` (l.131-132) : `for k in _gauges: _gauges[k].refresh()` → `for g in _get_gauges(): (g as Gauge).refresh()`
- `_on_preview` (l.169, 172-173) : `for k in _gauges: _gauges[k].set_affected(...)` → boucle sur `_get_gauges()` avec `g.resource_key` comme clé.
- `_on_committed` (l.178) : `for k in _gauges: _gauges[k].set_affected(false)` → `for g in _get_gauges(): (g as Gauge).set_affected(false)`
- `_refresh_all` (l.218-219) : `_gauges[r["key"]].set_value(...)` → `_gauge(r["key"]).set_value(...)`

Code concret pour `_on_preview` :

```gdscript
func _on_preview(side: String) -> void:
	if side == "":
		for g in _get_gauges(): (g as Gauge).set_affected(false)
		return
	var fx: Dictionary = card[side]["fx"]
	for g in _get_gauges():
		var key: String = (g as Gauge).resource_key
		(g as Gauge).set_affected(fx.has(key) and int(fx[key]) != 0)
```

- [ ] **Step 4 : Run + vérif jauges (valeurs, preview, flash, refresh accent)**

Run + `logs_read`. Expected: PASS, jauges identiques.

- [ ] **Step 5 : Commit**

```bash
git add scenes/Game.tscn src/Game.gd
git commit -m "refactor(groups): jauges via groupe 'gauges' (remplace le dict _gauges)"
```

### Task B2 : Machine à états

**Files:**
- Modify: `src/Game.gd`

**Interfaces:**
- Produces: `enum State { IDLE, DRAGGING, RELEASING, FLYING_OUT, TRANSITIONING, DEATH, CODEX }`, `_state`, `_set_state(s)`. Remplace `busy`, et les checks `.visible`.

- [ ] **Step 1 : Introduire l'enum et l'état**

Remplacer `var busy := false` (l.29) par :

```gdscript
enum State { IDLE, DRAGGING, RELEASING, FLYING_OUT, TRANSITIONING, DEATH, CODEX }
var _state := State.IDLE

# Transition d'état centralisée (un seul point de mutation).
func _set_state(new_state: State) -> void:
	_state = new_state
```

(`_hdrag`/`_hmoved`/`_hstart_y` gèrent un geste tactile local au handle, **distinct** de l'état de la boucle de carte ; on les **garde** tels quels — les intégrer à l'enum compliquerait sans gain. Documenter par un commentaire.)

- [ ] **Step 2 : Remplacer les usages de `busy`**

- `_unhandled_input` : `if busy or _death.visible or _codex.visible:` → `if _state != State.IDLE:` (et pour le toggle codex : `elif _state == State.IDLE:` au lieu de `not busy and not _death.visible`). Quand le codex est ouvert, `_state == State.CODEX` ; gérer la fermeture en conséquence.
- `_on_committed` : `if busy: return` → `if _state != State.IDLE: return` ; `busy = true` → `_set_state(State.TRANSITIONING)` ; les `busy = false` (l.200, 215) → `_set_state(State.IDLE)`.
- `_respawn` : `busy = false` (l.290) → `_set_state(State.IDLE)`.
- `_play_death` : encadrer par `_set_state(State.DEATH)` au début ; le retour à IDLE se fait dans `_respawn`.

- [ ] **Step 3 : Brancher l'état codex sur l'ouverture/fermeture**

Le codex émet déjà via clic/drag. Pour que `_state` reflète le codex, connecter à la visibilité : ajouter dans `_connect_signals()` :

```gdscript
	_codex.visibility_changed.connect(_on_codex_visibility_changed)
```

et :

```gdscript
func _on_codex_visibility_changed() -> void:
	if _codex.visible:
		_set_state(State.CODEX)
	elif _state == State.CODEX:
		_set_state(State.IDLE)
```

Adapter `_unhandled_input` pour le toggle : ouverture si `_state == State.IDLE`, fermeture si `_state == State.CODEX`.

- [ ] **Step 4 : Run + vérif (swipe bloqué pendant transition/mort/codex ; tout rejouable)**

Run + `logs_read`. Expected: PASS. Reproduire : swipe pendant fly-out (ignoré), ouvrir codex puis swipe (ignoré), mort puis respawn (rejouable).

- [ ] **Step 5 : Commit**

```bash
git add src/Game.gd
git commit -m "refactor(state): machine à états (remplace busy + checks .visible)"
```

### Checkpoint Lot B

Vérifier : boucle complète, blocage des inputs pendant transitions/mort/codex, respawn. **Attendre le go.**

---

## LOT C — Scènes & animations (Étapes 5, 2)

Risque 🟠. Déplacer les nœuds créés en code vers les `.tscn` ; AnimationPlayer pour les anims à valeurs fixes.

### Task C1 : DeathFx + gear dans Game.tscn

**Files:**
- Modify: `scenes/Game.tscn`, `src/Game.gd` (`_make_overlays`)

**Interfaces:**
- Consumes: nœuds `%DeathFx` (ColorRect), `%Gear` (Button) ajoutés à la scène.

- [ ] **Step 1 : Ajouter `DeathFx` à Game.tscn**

Via MCP `node_create` : `ColorRect` nommé `DeathFx`, enfant de `Game`, `PRESET_FULL_RECT`, `mouse_filter=IGNORE`, `visible=false`, unique name (`%DeathFx`). Lui assigner un `ShaderMaterial` avec `res://assets/shaders/death_fx.gdshader` (via `material_manage` create + `apply_to_node`).

- [ ] **Step 2 : Ajouter `Gear` à Game.tscn**

`Button` nommé `Gear`, `PRESET_TOP_RIGHT`, mêmes offsets que le code (l.103-108), `text="⚙"`, `focus_mode=NONE`, taille 28×28. Les overrides de couleur/stylebox passeront au theme (Lot D) ; pour l'instant reproduire via l'inspecteur ou laisser en code minimal. Marquer unique (`%Gear`).

- [ ] **Step 3 : Réécrire `_make_overlays()`**

Remplacer la création code de `_deathfx` (l.86-93) et du `gear` (l.99-115) par des `@onready` :

```gdscript
@onready var _deathfx: ColorRect = %DeathFx
@onready var _gear: Button = %Gear
```

`_make_overlays()` ne garde que la création du `TweaksPanel` (déplacé en Task C2) et le branchement. Connecter `_gear.pressed` dans `_connect_signals()` :

```gdscript
	_gear.pressed.connect(_on_gear_pressed)
```

- [ ] **Step 4 : Run + vérif (gear visible/cliquable, death FX joue)**

Run + `logs_read`. Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add scenes/Game.tscn src/Game.gd
git commit -m "refactor(scène): DeathFx + Gear dans Game.tscn (retire la création en code)"
```

### Task C2 : TweaksPanel.tscn (structure statique)

**Files:**
- Create: `scenes/TweaksPanel.tscn`
- Modify: `src/TweaksPanel.gd`, `scenes/Game.tscn` (instancier TweaksPanel), `src/Game.gd`

**Interfaces:**
- Consumes: nœuds statiques `%Panel`, `%Title`, `%CloseBtn`, conteneur `%Dynamic` (VBox où injecter swatches/sliders).
- Produces: `TweaksPanel` lit ses nœuds via `@onready` ; `_build()` ne crée plus que le dynamique dans `%Dynamic`.

- [ ] **Step 1 : Créer TweaksPanel.tscn**

Racine `Control` (script `TweaksPanel.gd`), enfant `PanelContainer %Panel` (preset RIGHT_WIDE, offsets de l.19-22), `VBoxContainer` interne, en-tête `HBoxContainer` avec `Label %Title` ("RÉGLAGES") + `Button %CloseBtn` ("✕"), puis `VBoxContainer %Dynamic` (séparation 14) pour le contenu généré.

- [ ] **Step 2 : Alléger `_build()`**

`TweaksPanel.gd` : remplacer `_panel = PanelContainer.new()` + tout le head statique par des `@onready var _panel := %Panel`, `@onready var _dynamic := %Dynamic`. `_build()` ne construit plus que sections accent/grain/texte/difficulté dans `_dynamic`. `_rebuild()` ne vide/reconstruit que `_dynamic` (au lieu de `_panel.queue_free()`), pour ne pas détruire la structure statique :

```gdscript
func _rebuild() -> void:
	for c in _dynamic.get_children(): c.queue_free()
	_build_dynamic()
```

Connecter `%CloseBtn.pressed` → `close` dans la scène ou `_ready`.

- [ ] **Step 3 : Instancier TweaksPanel dans Game.tscn**

Ajouter une instance de `TweaksPanel.tscn` (nom `Tweaks`, `%Tweaks`, `visible=false`, FULL_RECT) à `Game.tscn`. Dans `Game.gd`, remplacer la création code (`_tweaks = TweaksPanel.new()` l.96-98) par `@onready var _tweaks: TweaksPanel = %Tweaks`.

- [ ] **Step 4 : Run + vérif Tweaks (ouvre, sliders, difficulté rebuild)**

Run + `logs_read`. Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add scenes/TweaksPanel.tscn scenes/Game.tscn src/TweaksPanel.gd src/Game.gd
git commit -m "refactor(scène): TweaksPanel.tscn statique + dynamique en code"
```

### Task C3 : AnimationPlayer — question_fade, death_fx, deck_unlock

**Files:**
- Modify: `scenes/Game.tscn` (AnimationPlayer `Animations`), `src/Game.gd`

**Interfaces:**
- Consumes: `%Animations` (AnimationPlayer) avec animations `question_fade`, `death_fx`.

- [ ] **Step 1 : Ajouter AnimationPlayer `Animations`**

Via MCP `animation_manage` op `player_create` sur `Game`, nom `Animations`, `%Animations`.

- [ ] **Step 2 : `question_fade`**

Créer une animation `question_fade` (0.35 s) qui anime `%QuestionLabel:modulate:a` de 0→1 (ease out cubic). Via MCP `animation_create` / `add_property_track`. Dans `_refresh_card()`, remplacer le `create_tween()` (l.233-234) par :

```gdscript
	_question.modulate.a = 0.0
	%Animations.play("question_fade")
```

- [ ] **Step 3 : `death_fx`**

L'anim pilote `mat.set_shader_parameter("progress", v)` — un param de shader, non animable par property track direct. **Option retenue :** garder un method track appelant une méthode `_set_deathfx_progress(v)` :

```gdscript
func _set_deathfx_progress(v: float) -> void:
	(_deathfx.material as ShaderMaterial).set_shader_parameter("progress", v)
```

Créer `death_fx` (0.76 s) : un method track sur `_set_deathfx_progress` (keys 0→1) + une key sur `%DeathFx:visible` (true au début). Dans `_play_death`, remplacer le tween (l.247-250) par :

```gdscript
	mat.set_shader_parameter("rect_size", _deathfx.size)
	mat.set_shader_parameter("progress", 0.0)
	_deathfx.visible = true
	%Animations.play("death_fx")
	await %Animations.animation_finished
	_deathfx.visible = false
```

- [ ] **Step 4 : deck_unlock (bannière) — méthode hybride**

Le glissement des cartes utilise des positions calculées au runtime → **reste en tween**. Seule l'apparition/scale du **bandeau** (`_unlock_banner`, l.393-403, valeurs fixes) peut devenir une anim `deck_banner` jouée sur le nœud bannière. Vu que la bannière est créée dynamiquement, garder son tween est acceptable et idiomatique (cf. spec). **Décision : laisser `_play_deck_unlock`/`_unlock_banner` en tween** ; documenter pourquoi (nœuds runtime). Aucune modif de code ici — tâche de documentation inline dans le commentaire de `_unlock_banner`.

- [ ] **Step 5 : Run + vérif (fondu question, FX mort, bannière)**

Run + `logs_read`. Expected: PASS, animations identiques.

- [ ] **Step 6 : Commit**

```bash
git add scenes/Game.tscn src/Game.gd
git commit -m "refactor(anim): AnimationPlayer pour question_fade + death_fx"
```

### Task C4 : Death sweep via AnimationPlayer + nœud en scène

**Files:**
- Modify: `scenes/Death.tscn` (bande sweep + AnimationPlayer), `src/Death.gd`

**Interfaces:**
- Consumes: `%Sweep` (TextureRect avec GradientTexture2D), `%DeathAnims` (AnimationPlayer).

- [ ] **Step 1 : Ajouter la bande sweep à Death.tscn**

`TextureRect %Sweep` enfant de `Death`, `mouse_filter=IGNORE`, `stretch_mode=STRETCH_SCALE`, avec un `GradientTexture2D` (gradient cyan 0.16α→0, fill vertical, 4×64) reproduisant l.65-72. `visible=false` par défaut.

- [ ] **Step 2 : Ajouter `DeathAnims` + animation `sweep`**

AnimationPlayer `%DeathAnims`. Animation `sweep` (0.7 s) : `%Sweep:position:y` de `-band_h*0.4`→`size.y*1.2` et `%Sweep:modulate:a` 1→0. Comme `band_h`/`size.y` dépendent de la taille runtime, **paramétrer en début de `_play_sweep` via une méthode** qui pose les bornes puis joue l'anim relative, OU garder un method track. Choix simple : conserver `_play_sweep` en tween (valeurs runtime), mais **déplacer la création du nœud** `Sweep` hors code (réutiliser `%Sweep`). Réécrire `_play_sweep` :

```gdscript
func _play_sweep() -> void:
	var band_h := size.y * 0.34
	%Sweep.size = Vector2(size.x, band_h)
	%Sweep.position = Vector2(0, -band_h * 0.4)
	%Sweep.modulate.a = 1.0
	%Sweep.visible = true
	var t := create_tween().set_parallel()
	t.tween_property(%Sweep, "position:y", size.y * 1.2, sweep_duration).set_ease(Tween.EASE_OUT)
	t.tween_property(%Sweep, "modulate:a", 0.0, sweep_duration)
	t.chain().tween_callback(func(): %Sweep.visible = false)
```

(Le nœud n'est plus créé/free à chaque mort → idiomatique. L'anim reste tween car bornes runtime — conforme spec.)

- [ ] **Step 3 : Run + vérif sweep (balayage cyan à la mort)**

Run + `logs_read`. Expected: PASS.

- [ ] **Step 4 : Commit**

```bash
git add scenes/Death.tscn src/Death.gd
git commit -m "refactor(scène): bande sweep de Death dans la scène (réutilisée, plus recréée)"
```

### Checkpoint Lot C

Vérifier : death FX + sweep, fondu question, gear/Tweaks, bannière deck, aperçus éditeur des scènes (`Death`, `Game`) intacts. **Attendre le go.**

---

## LOT D — Theme (Étape 7)

Risque 🟡. Centraliser couleurs/styles dans un `.theme`, retirer les overrides redondants.

### Task D1 : Créer main.theme et l'appliquer

**Files:**
- Create: `themes/main.theme`
- Modify: `scenes/Main.tscn` (propriété `theme`)

**Interfaces:**
- Produces: theme avec defaults `Label`/`PanelContainer`/`Button`/`RichTextLabel`.

- [ ] **Step 1 : Créer le theme**

Via MCP `theme_manage` (ou créer `themes/main.theme`). Définir :
- `Label` : `font` = SpaceMono-Regular, `font_color` = `Pal.INK` (#e7edf6).
- `RichTextLabel` : `default_color`/`font_color` = `Pal.INK_DIM` (#93a0b6).
- `Button` : `font_color` = `Pal.INK_DIM`.
- `PanelContainer` : `panel` = StyleBoxFlat bg = `Pal.PANEL` (#0c1322).

- [ ] **Step 2 : Appliquer sur Main.tscn**

Propriété `theme` du nœud racine de `Main.tscn` = `res://themes/main.theme`.

- [ ] **Step 3 : Run + vérif (rendu global cohérent, pas de régression majeure)**

Run + `logs_read`. Expected: PASS. Comparer visuellement (capture éditeur `editor_screenshot`).

- [ ] **Step 4 : Commit**

```bash
git add themes/main.theme scenes/Main.tscn
git commit -m "feat(theme): main.theme centralisant fonts/couleurs/styles par défaut"
```

### Task D2 : Retirer les overrides redondants

**Files:**
- Modify: scripts avec `add_theme_*` couverts par le theme (`Game.gd`, `Codex.gd`, `TweaksPanel.gd`, `Death.gd`, composants)

**Interfaces:** aucune nouvelle ; suppression seulement.

- [ ] **Step 1 : Identifier les overrides redondants**

Lister `grep -rn "add_theme_" src/`. Retirer **uniquement** ceux que le theme couvre désormais (couleur INK par défaut sur Label, panel PANEL sur PanelContainer, etc.). **Conserver** les overrides spécifiques à une instance : couleurs d'accent dynamiques (`Cfg.accent`), couleurs ressources (`Pal.res_color`), tailles de police par élément, styleboxes colorées spécifiques (bannière, swatches, jauges crit/warn).

- [ ] **Step 2 : Retirer prudemment, lot par fichier**

Procéder fichier par fichier, run après chacun, pour isoler toute régression visuelle. Exemple : dans `Codex._section()` la couleur `#6b768c` est spécifique → **garder** ; un éventuel `font_color = Pal.INK` redondant → retirer.

- [ ] **Step 3 : Run + capture comparée après chaque fichier**

Run + `editor_screenshot`. Expected: rendu identique.

- [ ] **Step 4 : Commit**

```bash
git add src/
git commit -m "refactor(theme): retire les overrides couverts par main.theme"
```

### Checkpoint Lot D

Comparer captures avant/après sur les écrans clés (jeu, codex, mort, Tweaks). **Attendre le go.**

---

## LOT E — Audio (Étape 3)

Risque 🟢. Système audio + SFX synthétiques. Pur ajout.

### Task E1 : Bus + AudioManager

**Files:**
- Create: `default_bus_layout.tres`, `src/AudioManager.gd`
- Modify: `project.godot` (autoload + bus layout)

**Interfaces:**
- Produces: autoload `AudioManager` avec `play_sfx(stream)`, `play_ui(stream)`, `play_music(stream, fade_in)`, signal `music_finished`.

- [ ] **Step 1 : Bus layout**

Via MCP `audio_manage` ou créer `default_bus_layout.tres` : `Master` → `Music`, `SFX`, `UI` (3 bus enfants routés vers Master). Référencer dans `project.godot` :

```ini
[audio]

buses/default_bus_layout="res://default_bus_layout.tres"
```

- [ ] **Step 2 : AudioManager.gd**

```gdscript
extends Node

# Gère la musique d'ambiance et les SFX. Bus : Master → Music, SFX, UI.

signal music_finished

@onready var _music: AudioStreamPlayer = $Music
@onready var _sfx: AudioStreamPlayer = $SFX
@onready var _ui: AudioStreamPlayer = $UI

func _ready() -> void:
	_music = AudioStreamPlayer.new(); _music.bus = "Music"; add_child(_music)
	_sfx = AudioStreamPlayer.new(); _sfx.bus = "SFX"; add_child(_sfx)
	_ui = AudioStreamPlayer.new(); _ui.bus = "UI"; add_child(_ui)
	_music.finished.connect(func(): music_finished.emit())

func play_music(stream: AudioStream, fade_in: float = 0.0) -> void:
	_music.stream = stream
	_music.volume_db = -80.0 if fade_in > 0.0 else 0.0
	_music.play()
	if fade_in > 0.0:
		create_tween().tween_property(_music, "volume_db", 0.0, fade_in)

func play_sfx(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()

func play_ui(stream: AudioStream) -> void:
	_ui.stream = stream
	_ui.play()
```

Enregistrer l'autoload dans `project.godot` :

```ini
AudioManager="*res://src/AudioManager.gd"
```

- [ ] **Step 3 : Run + vérif (aucune erreur, autoload présent)**

Run + `logs_read`. Expected: PASS.

- [ ] **Step 4 : Commit**

```bash
git add default_bus_layout.tres src/AudioManager.gd project.godot
git commit -m "feat(audio): AudioManager + bus layout (Master/Music/SFX/UI)"
```

### Task E2 : SFX synthétiques + hooks

**Files:**
- Create: `src/SfxBank.gd` (générateur de sons procéduraux)
- Modify: `src/Game.gd`, `src/CardView.gd`, `src/Death.gd`

**Interfaces:**
- Consumes: `AudioManager.play_sfx/play_ui`.
- Produces: `SfxBank.swipe()`, `SfxBank.commit()`, `SfxBank.death()`, `SfxBank.unlock()`, `SfxBank.respawn()` → `AudioStreamWAV`.

- [ ] **Step 1 : SfxBank.gd — sons procéduraux**

Créer un générateur produisant des `AudioStreamWAV` courts (sinus/bruit filtré + enveloppe) :

```gdscript
class_name SfxBank
extends Object

# Génère des SFX simples par code (pas d'asset externe). Buffers PCM 16 bits mono.

const RATE := 22050

static func _tone(freq: float, dur: float, decay: float, noise := 0.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-decay * t)
		var s := sin(TAU * freq * t) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var v := int(clampf(s * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

static func swipe() -> AudioStreamWAV: return _tone(420.0, 0.12, 18.0, 0.35)
static func commit() -> AudioStreamWAV: return _tone(300.0, 0.18, 12.0, 0.1)
static func death() -> AudioStreamWAV: return _tone(90.0, 0.9, 3.0, 0.05)
static func unlock() -> AudioStreamWAV: return _tone(660.0, 0.25, 8.0, 0.0)
static func respawn() -> AudioStreamWAV: return _tone(520.0, 0.3, 6.0, 0.0)
```

Mettre en cache les streams (générer une fois dans `Game._ready`) pour éviter de régénérer à chaque appel.

- [ ] **Step 2 : Hooks Game.gd**

Dans `Game._ready`, pré-générer : `_sfx_commit := SfxBank.commit()`, etc. Appeler :
- `_on_committed` (après le commit) : `AudioManager.play_sfx(_sfx_commit)`.
- `_play_death` (début) : `AudioManager.play_sfx(_sfx_death)`.
- `_play_deck_unlock` : `AudioManager.play_sfx(_sfx_unlock)`.
- `_respawn` : `AudioManager.play_sfx(_sfx_respawn)`.

- [ ] **Step 3 : Hooks CardView.gd**

- Dans `_update_choice` (ou `_gui_input`), au franchissement du seuil `reveal_threshold` (transition false→true), émettre un signal `swiped` ou appeler directement `AudioManager.play_sfx(SfxBank.swipe())` une seule fois par drag (garder un flag `_swipe_sounded`).
- Dans `_fly_out` : `AudioManager.play_sfx(SfxBank.commit())` (le « floup »).

- [ ] **Step 4 : Hook Death.gd**

`show_death()` : `AudioManager.play_sfx(SfxBank.death())` (hors `Engine.is_editor_hint()`).

- [ ] **Step 5 : Run + vérif sons (swipe, commit, mort, unlock, respawn)**

Run + `logs_read` + écoute. Expected: PASS, sons audibles aux bons moments.

- [ ] **Step 6 : Commit**

```bash
git add src/SfxBank.gd src/Game.gd src/CardView.gd src/Death.gd
git commit -m "feat(audio): SFX synthétiques (swipe/commit/mort/unlock/respawn) + hooks"
```

### Checkpoint Lot E

Vérifier sons aux bons moments, pas de saturation, jeu inchangé visuellement. **Attendre le go.**

---

## LOT F — Data typée (Étape 6)

Risque 🔴. Classes `Resource` typées ; `Data.gd` construit les objets en code (pas de `.tres`). Touche `Game`, `CardView`, `Death`, `Codex`.

### Task F1 : Classes de ressources

**Files:**
- Create: `src/resources/AnswerData.gd`, `src/resources/CardData.gd`, `src/resources/CharacterData.gd`, `src/resources/PlanetData.gd`

**Interfaces:**
- Produces: `class_name AnswerData/CardData/CharacterData/PlanetData`.

- [ ] **Step 1 : AnswerData.gd**

```gdscript
class_name AnswerData
extends Resource

@export var title: String
@export_multiline var reaction: String
@export var fx: Dictionary = {}   # {ressource: delta} ; clés legit/legitimacy gérées à part
```

- [ ] **Step 2 : CardData.gd**

```gdscript
class_name CardData
extends Resource

@export var id: String
@export var bearer: String
@export var role: String
@export var mood: String
@export var key: bool = false
@export_multiline var question: String
@export var left_answer: AnswerData
@export var right_answer: AnswerData
```

- [ ] **Step 3 : CharacterData.gd**

```gdscript
class_name CharacterData
extends Resource

@export var id: String
@export var name: String
@export var tag: String
@export var met: bool = false
@export var key: bool = false
```

- [ ] **Step 4 : PlanetData.gd**

```gdscript
class_name PlanetData
extends Resource

@export var id: String
@export var name: String
@export var faction: String
@export var state: int = 0
@export var x: float
@export var y: float
@export_multiline var note: String
@export var base: bool = false
@export var hidden: bool = false
```

- [ ] **Step 5 : Parse-check (les class_name compilent)**

Run `editor_state` + `logs_read`. Expected: PASS (classes reconnues).

- [ ] **Step 6 : Commit**

```bash
git add src/resources/
git commit -m "feat(data): classes Resource typées (Card/Answer/Character/Planet)"
```

### Task F2 : Data.gd construit des objets typés

**Files:**
- Modify: `src/Data.gd`

**Interfaces:**
- Produces: `Data.all_cards() -> Array[CardData]`, `all_characters() -> Array[CharacterData]`, `all_planets() -> Array[PlanetData]`, `pick_card(recent: Array) -> CardData`. `tone_for`, `initials`, `state_color` inchangés.

- [ ] **Step 1 : Builders typés**

Conserver les dicts source en `const` privés (renommés `_DECK_RAW`, etc.) et ajouter des fonctions qui mappent vers les objets :

```gdscript
static func all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for d in _DECK_RAW:
		var c := CardData.new()
		c.id = d["id"]; c.bearer = d["bearer"]; c.role = d["role"]
		c.mood = d["mood"]; c.key = d.get("key", false); c.question = d["question"]
		c.left_answer = _answer(d["left"])
		c.right_answer = _answer(d["right"])
		out.append(c)
	return out

static func _answer(a: Dictionary) -> AnswerData:
	var r := AnswerData.new()
	r.title = a["title"]; r.reaction = a.get("reaction", ""); r.fx = a.get("fx", {})
	return r
```

Idem `all_characters()` / `all_planets()`. Mettre en cache (`static var _cards_cache`) pour ne construire qu'une fois.

- [ ] **Step 2 : Adapter `pick_card`**

`pick_card(recent)` retourne un `CardData` (filtre sur `all_cards()` au lieu de `DECK`). Garder la même logique d'évitement des récents.

- [ ] **Step 3 : Parse-check**

`editor_state` + `logs_read`. Expected: PASS.

- [ ] **Step 4 : Commit**

```bash
git add src/Data.gd
git commit -m "refactor(data): Data construit des objets typés (all_cards/characters/planets)"
```

### Task F3 : Consommateurs (Game, CardView, Death, Codex)

**Files:**
- Modify: `src/Game.gd`, `src/CardView.gd`, `src/Codex.gd`

**Interfaces:**
- Consumes: `CardData`, `AnswerData`, `CharacterData`, `PlanetData`, builders de `Data`.

- [ ] **Step 1 : Game.gd**

- `var card := {}` → `var card: CardData`.
- `card = Data.pick_card([])` inchangé d'appel (retourne CardData).
- `_on_preview` : `var fx: Dictionary = card[side]["fx"]` → `var fx := (card.left_answer if side == "left" else card.right_answer).fx`.
- `_on_committed` : `var ans: Dictionary = card["left" if is_left else "right"]` → `var ans := card.left_answer if is_left else card.right_answer` ; `ans["fx"]` → `ans.fx`.
- `recent` : `card["id"]` → `card.id`.
- `_refresh_card` : `card.get("question","")` → `card.question` ; `card.get("bearer","")` → `card.bearer` ; `card.get("role","")` → `card.role`.
- `_cardview.show_card(card)` : signature change (Step 2).

- [ ] **Step 2 : CardView.gd**

- `show_card(card: Dictionary)` → `show_card(card: CardData)`.
- `card["left"]["title"]` → `card.left_answer.title` ; `card["right"]["title"]` → `card.right_answer.title`.
- `card.get("key", false)` → `card.key` ; `card["id"]` → `card.id` ; `card["bearer"]` → `card.bearer`.

- [ ] **Step 3 : Codex.gd**

- `_render_chars` : `Data.CHARACTERS.filter(func(c): return c["met"])` → `Data.all_characters().filter(func(c): return c.met)`.
- `_char(c)`, `_grid(list)` : typer `c: CharacterData` ; `CharacterCard.setup` accepte un `CharacterData` (adapter `CharacterCard.gd` : `c["met"]`→`c.met`, `c["id"]`→`c.id`, `c["name"]`→`c.name`, `c.get("key",false)`→`c.key`, `c["tag"]`→`c.tag`).
- `_render_gal` / `_draw_galaxy` / `_render_info` : `Data.PLANETS` → `Data.all_planets()` ; `p["x"]`→`p.x`, `p["state"]`→`p.state`, `p["base"]`→`p.base`, `p["id"]`→`p.id`. Adapter `PlanetInfo.setup` au type `PlanetData`.

- [ ] **Step 4 : Adapter CharacterCard.gd + PlanetInfo.gd**

Changer les signatures `setup(c: Dictionary)` → `setup(c: CharacterData)` / `setup(p: PlanetData)` et les accès dict → propriétés. Préserver les branches `Engine.is_editor_hint()` (construire un `CharacterData.new()` d'exemple au lieu d'un dict).

- [ ] **Step 5 : Run + vérif complète (boucle, mort, codex chars/galaxie)**

Run + `logs_read`. Expected: PASS, comportement identique.

- [ ] **Step 6 : Commit**

```bash
git add src/Game.gd src/CardView.gd src/Codex.gd src/CharacterCard.gd src/PlanetInfo.gd
git commit -m "refactor(data): consommateurs utilisent les objets typés (fin dict→objet)"
```

### Checkpoint Lot F

Vérifier la boucle entière, la mort (toutes causes), le codex (personnages rencontrés/à venir, galaxie + sélection planète), aperçus éditeur. **Attendre le go final.**

---

## Self-Review (couverture du spec)

- Étape 1 (signaux) → Tasks A1, A2, A3 ✅
- Étape 8 (input map) → Task A4 ✅
- Étape 4 (@export) → Task A5 ✅
- Étape 9 (state machine) → Task B2 ✅
- Étape 10 (groupes) → Task B1 ✅
- Étape 5 (nœuds en scène) → Tasks C1, C2, C4 ✅
- Étape 2 (AnimationPlayer) → Tasks C3, C4 ✅ (avec décision documentée : tween conservé pour anims à bornes runtime)
- Étape 7 (theme) → Tasks D1, D2 ✅
- Étape 3 (audio) → Tasks E1, E2 ✅
- Étape 6 (resources typées, sans .tres) → Tasks F1, F2, F3 ✅
- Règle « ne pas casser le jeu » → checkpoints utilisateur par lot ✅
- Règle « commentaires en français » → tout le code du plan ✅
- Règle « assets intacts » → aucune tâche ne touche shaders/fonts/icônes ✅

**Notes de cohérence des types :** `card` devient `CardData` partout (Game, CardView) ; `Data.pick_card` retourne `CardData` ; `all_characters()` → `Array[CharacterData]`, consommé par `CharacterCard.setup(c: CharacterData)` ; `all_planets()` → `Array[PlanetData]`, consommé par `PlanetInfo.setup(p: PlanetData)`. `fx` reste `Dictionary` partout (cohérent F1↔F3).
