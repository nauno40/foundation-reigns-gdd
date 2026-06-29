# Refactor Godot v2 — Éditeur & Assets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre le projet éditable depuis l'UI Godot (données JSON, StyleBox `.tres`, Theme complet, SFX `@export`, ProjectSettings) **sans changer le comportement du jeu**.

**Architecture :** Refactor incrémental en 5 lots indépendamment lançables, 1 commit par lot, vérification dans l'éditeur Godot entre chaque. Branche `feat/editor-editable-v2`.

**Tech Stack :** Godot 4.7, GDScript, MCP `godot-ai`.

## Global Constraints

- Ne pas casser le jeu ; comportement et rendu identiques. — copié du spec.
- Supprimer le code mort après migration vers les équivalents éditeur. — copié du spec.
- Vérifier dans Godot après chaque étape. — copié du spec.
- Préserver les aperçus `@tool` standalone (décision : theme assigné à chaque sous-scène).
- Accès JSON par clé `d["..."]` (jamais `d.id`).

## Modèle de vérification

Pas de tests unitaires (projet sans GUT). Par tâche : `mcp__godot-ai__project_run`
+ `logs_read` (source `game` + `editor`) → 0 erreur ; le jeu se lance. Pour un
nouveau fichier/`class_name` créé hors éditeur, le **run du jeu** (processus
séparé) fait foi ; demander un reload projet si l'éditeur reste bloqué (cf.
mémoire `godot-mcp-class-name-gotchas`). « Expected: PASS » = 0 erreur + jeu lancé.

---

## LOT 1 — Données JSON (Étape 1)

Risque 🔴. Sortir cards/characters/planets + covers/deck_unlocks/achievements/
seldon_messages de `Data.gd` vers `data/*.json`.

### Task 1.1 : Générer les fichiers JSON (script one-shot)

**Files:**
- Create: `data/` (dossier), `tools/export_data_json.gd` (script jetable)
- Modify: aucun

**Interfaces:**
- Produces: `data/cards.json`, `data/characters.json`, `data/planets.json`,
  `data/covers.json`, `data/deck_unlocks.json`, `data/achievements.json`,
  `data/seldon_messages.json`.

- [ ] **Step 1 : Écrire le script d'export `@tool`**

Créer `tools/export_data_json.gd` :

```gdscript
@tool
extends EditorScript

# Script jetable : exporte les données de Data.gd en JSON (échappement sûr via
# JSON.stringify). Lancer via Fichier → Exécuter (ou la console MCP), puis supprimer.

func _run() -> void:
	_save("res://data/cards.json", Data._DECK_RAW)
	_save("res://data/characters.json", Data._CHARACTERS_RAW)
	_save("res://data/planets.json", Data._PLANETS_RAW)
	_save("res://data/covers.json", Data.COVERS)
	_save("res://data/deck_unlocks.json", Data.DECK_UNLOCKS)
	_save("res://data/achievements.json", Data.ACHIEVEMENTS)
	_save("res://data/seldon_messages.json", Data.SELDON_MESSAGES)
	print("Export JSON terminé.")

func _save(path: String, value) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(value, "\t"))
	f.close()
```

(`Data._DECK_RAW` est accessible car `Data` est un `class_name` ; les `_*_RAW`
sont des `const` privés par convention mais lisibles depuis un autre script.)

- [ ] **Step 2 : Créer le dossier data/ et exécuter le script**

Via MCP : créer `data/` (un `filesystem_manage write_text` d'un fichier temporaire
suffit à créer le dossier, ou créer directement les .json). Exécuter
`tools/export_data_json.gd` via l'`EditorScript` (MCP `script` run ou Fichier →
Exécuter dans l'éditeur). Vérifier que les 7 fichiers existent et sont non vides.

- [ ] **Step 3 : Valider le JSON**

Run: `python3 -c "import json,glob; [json.load(open(p)) for p in glob.glob('data/*.json')]; print('ok')"`
Expected: `ok` (tous les fichiers parsent).

- [ ] **Step 4 : Commit (données + script encore présent)**

```bash
git add data/ tools/export_data_json.gd
git commit -m "data(json): export des données Data.gd en data/*.json (script one-shot)"
```

### Task 1.2 : `Data.gd` charge le JSON et supprime les consts migrées

**Files:**
- Modify: `src/Data.gd`
- Delete (en fin de tâche): `tools/export_data_json.gd`

**Interfaces:**
- Consumes: `data/*.json`.
- Produces: `Data._load_json(path) -> Array`, `Data._load_json_dict(path) ->
  Dictionary` ; `all_cards/all_characters/all_planets` inchangés de signature
  (`Array[CardData]` etc.) ; `COVERS`/`DECK_UNLOCKS`/`ACHIEVEMENTS` deviennent
  `static var Array` ; `SELDON_MESSAGES` devient `static var Dictionary`.

- [ ] **Step 1 : Ajouter les helpers de chargement**

Dans `src/Data.gd`, ajouter (avant les builders) :

```gdscript
static func _load_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : " + path)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Array else []

static func _load_json_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("JSON introuvable : " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
```

- [ ] **Step 2 : Migrer les 4 consts game-design en `static var`**

Remplacer les `const SELDON_MESSAGES := {...}`, `const COVERS := [...]`,
`const DECK_UNLOCKS := [...]`, `const ACHIEVEMENTS := [...]` par :

```gdscript
static var SELDON_MESSAGES: Dictionary = _load_json_dict("res://data/seldon_messages.json")
static var COVERS: Array = _load_json("res://data/covers.json")
static var DECK_UNLOCKS: Array = _load_json("res://data/deck_unlocks.json")
static var ACHIEVEMENTS: Array = _load_json("res://data/achievements.json")
```

(Les `static var` initialisés appellent `_load_json` au chargement de la classe —
`_load_json` doit donc être défini dans le même fichier, ce qui est le cas.)

- [ ] **Step 3 : Brancher les builders sur le JSON et supprimer les `_*_RAW`**

Dans `all_cards()`, remplacer `for d in _DECK_RAW:` par
`for d in _load_json("res://data/cards.json"):`. Idem `all_characters()` →
`"res://data/characters.json"`, `all_planets()` → `"res://data/planets.json"`.
Le corps des boucles (accès `d["..."]`) est déjà correct. Puis **supprimer** les
`const _DECK_RAW := [...]`, `const _CHARACTERS_RAW := [...]`,
`const _PLANETS_RAW := [...]` (gros blocs de dicts).

`RESOURCES`, `MOODS`, `DIFF`, `TONES`, `DECKS_META` **restent en `const`**.

- [ ] **Step 4 : Supprimer le script d'export jetable**

```bash
git rm tools/export_data_json.gd
```

- [ ] **Step 5 : Run + vérif parité données**

Run: `mcp__godot-ai__project_run` puis `logs_read`.
Expected: PASS. Vérifier à l'écran : une carte se charge (bearer/role/question),
le codex personnages liste les bons noms, la galaxie affiche les planètes, l'écran
de mort affiche un message Seldon. Comparer à la parité d'avant.

- [ ] **Step 6 : Commit**

```bash
git add src/Data.gd
git commit -m "refactor(data): Data charge data/*.json (supprime _*_RAW et consts migrées)"
```

### Checkpoint Lot 1

Vérifier : boucle de cartes, codex (personnages + galaxie), mort (message Seldon),
déblocage de deck (deck_unlocks lu du JSON). **Attendre le go.**

---

## LOT 2 — StyleBox `.tres` + `@export` (Étape 2)

Risque 🟠. Extraire les StyleBox **statiques** récurrents en `.tres` + `@export` ;
exposer les fonts/couleurs statiques. Les StyleBox **dynamiques** (couleur
calculée au runtime) restent en code, documentés.

### Task 2.1 : StyleBox statiques → `res://styles/*.tres`

**Files:**
- Create: `res://styles/deck_card_style.tres`, `res://styles/deck_banner_style.tres`,
  `res://styles/galaxy_box_style.tres`

**Interfaces:**
- Produces: 3 ressources `StyleBoxFlat` réutilisables.

- [ ] **Step 1 : Créer les 3 `.tres` (script one-shot ou MCP)**

`deck_card_style.tres` (StyleBoxFlat) : `bg_color=Color(0.102,0.122,0.161)`,
corner_radius_all 16, border_width_all 1, `border_color=Color(0.471,0.784,0.863,0.16)`,
`shadow_color=Color(0,0,0,0.42)`, shadow_size 16, shadow_offset `Vector2(0,16)`.

`deck_banner_style.tres` : `bg_color=Color(0.055,0.094,0.149,0.94)`, corner_radius_all
14, border_width_all 1, `border_color=Color(0.31,0.839,0.91,0.55)`,
`shadow_color=Color(0.31,0.839,0.91,0.35)`, shadow_size 22, content_margin
left/right 30, top/bottom 18.

`galaxy_box_style.tres` : `bg_color=Color("#0a1422")`, corner_radius_all 14,
border_width_all 1, `border_color=Color(0.471,0.588,0.745,0.14)` (Pal.LINE).

Création via `mcp__godot-ai__theme_manage`/`resource` ou un `EditorScript`
jetable qui construit les StyleBoxFlat et `ResourceSaver.save(...)`.

- [ ] **Step 2 : Run + vérif (les .tres se chargent)**

Run: `project_run` + `logs_read`. Expected: PASS (aucune dépendance encore).

- [ ] **Step 3 : Commit**

```bash
git add styles/
git commit -m "feat(styles): deck_card/deck_banner/galaxy_box StyleBox en .tres"
```

### Task 2.2 : `@export` dans Game.gd (deck unlock)

**Files:**
- Modify: `src/Game.gd` (`_play_deck_unlock` ~l.328, `_unlock_banner` ~l.371)

**Interfaces:**
- Consumes: `styles/deck_card_style.tres`, `styles/deck_banner_style.tres`,
  `assets/fonts/SpaceMono-Regular.ttf`, `assets/fonts/Caveat.ttf`.
- Produces: `@export` `deck_card_style`, `banner_style`, `unlock_tag_font`,
  `unlock_name_font`, `unlock_count_font`, `unlock_name_color`, `unlock_count_color`,
  `unlock_tag_color`.

- [ ] **Step 1 : Déclarer les `@export`**

Dans `Game.gd`, après les `@export` existants :

```gdscript
@export var deck_card_style: StyleBox = preload("res://styles/deck_card_style.tres")
@export var banner_style: StyleBox = preload("res://styles/deck_banner_style.tres")
@export var unlock_tag_font: Font = FONT_MONO
@export var unlock_name_font: Font = FONT_CAVEAT
@export var unlock_count_font: Font = FONT_MONO
@export var unlock_tag_color: Color = Color("#4fd6e8")
@export var unlock_name_color: Color = Color(0.933, 0.973, 0.984)
@export var unlock_count_color: Color = Color(0.624, 0.706, 0.769)
```

(`FONT_MONO`/`FONT_CAVEAT` sont les `const preload` existants de `Game.gd`. Le
défaut de `unlock_tag_color` est le littéral de l'accent `#4fd6e8` — un `@export`
ne peut pas utiliser `Cfg.accent` comme défaut, ce n'est pas une expression
constante. L'original posait `Cfg.accent` au moment de la construction du bandeau,
soit la même couleur par défaut.)

- [ ] **Step 2 : Remplacer le StyleBox de la carte qui glisse**

Dans `_play_deck_unlock`, supprimer le bloc `var sb := StyleBoxFlat.new()` … et
remplacer `ac.add_theme_stylebox_override("panel", sb)` par
`ac.add_theme_stylebox_override("panel", deck_card_style)`.

- [ ] **Step 3 : Remplacer le StyleBox + fonts/couleurs du bandeau**

Dans `_unlock_banner`, supprimer le `var sb := StyleBoxFlat.new()` … et utiliser
`banner.add_theme_stylebox_override("panel", banner_style)`. Remplacer les
`add_theme_font_override("font", FONT_MONO/FONT_CAVEAT)` par `unlock_tag_font` /
`unlock_name_font` / `unlock_count_font`, et les `add_theme_color_override(
"font_color", Color(...))` par `unlock_tag_color` / `unlock_name_color` /
`unlock_count_color`. (Le `unlock_tag_color` par défaut = `Cfg.accent` ;
conserver l'override car la valeur par défaut capture l'accent au chargement.)

- [ ] **Step 4 : Run + vérif bannière de deck**

Run + `logs_read`. Expected: PASS, bannière identique. (Déclencher un déblocage en
jouant, ou via test ciblé.)

- [ ] **Step 5 : Commit**

```bash
git add src/Game.gd
git commit -m "refactor(@export): styles/fonts/couleurs du deck-unlock dans Game.gd"
```

### Task 2.3 : `@export` dans Codex.gd (galaxie + section)

**Files:**
- Modify: `src/Codex.gd` (`_render_gal` ~l.218, `_section` ~l.302)

**Interfaces:**
- Consumes: `styles/galaxy_box_style.tres`, `assets/fonts/SpaceMono-Regular.ttf`.
- Produces: `@export` `galaxy_box_style`, `section_font`, `section_font_size`,
  `section_color`.

- [ ] **Step 1 : Déclarer les `@export`**

```gdscript
@export var galaxy_box_style: StyleBox = preload("res://styles/galaxy_box_style.tres")
@export var section_font: Font = preload("res://assets/fonts/SpaceMono-Regular.ttf")
@export var section_font_size: int = 9
@export var section_color: Color = Color("#6b768c")
```

- [ ] **Step 2 : Utiliser galaxy_box_style**

Dans `_render_gal`, supprimer `var bsb := StyleBoxFlat.new()` … et remplacer
`box.add_theme_stylebox_override("panel", bsb)` par
`box.add_theme_stylebox_override("panel", galaxy_box_style)`.

- [ ] **Step 3 : Utiliser section_font/size/color dans `_section`**

`_section(text)` actuel crée un `Label` avec `Pal.mono_spaced(FONT_MONO, 2)` et
couleur `#6b768c`. Le remplacer par `section_font` / `section_font_size` /
`section_color`. **Note :** l'original utilise `Pal.mono_spaced` (FontVariation
spacing 2). Pour la parité exacte, garder la `FontVariation` : exporter
`section_font` comme la `FontVariation` (créée en `.tres`) OU conserver
`Pal.mono_spaced(section_font, 2)` en code. Choix : `Pal.mono_spaced(section_font, 2)`
pour préserver l'espacement.

- [ ] **Step 4 : Run + vérif codex (titres de section, boîte galaxie)**

Run + `logs_read`. Expected: PASS, codex identique.

- [ ] **Step 5 : Commit**

```bash
git add src/Codex.gd
git commit -m "refactor(@export): galaxy_box_style + section font/size/color dans Codex.gd"
```

### Task 2.4 : StyleBox dynamiques — documenter (pas d'extraction)

**Files:**
- Modify: `src/TweaksPanel.gd`, `src/CharacterCard.gd`, `src/AchievementRow.gd`
  (commentaires seulement)

**Interfaces:** aucune.

- [ ] **Step 1 : Documenter les StyleBox restants comme dynamiques**

Ajouter un commentaire au-dessus de chaque StyleBox computé au runtime expliquant
pourquoi il reste en code :
- `TweaksPanel` swatches : `bg_color = Color(hexc)` — une couleur par accent
  (ACCENTS), ne peut pas être un seul `.tres`. Reste en code.
- `TweaksPanel` boutons difficulté : `border_color` dépend de la sélection
  (`Cfg.difficulty`) — état dynamique. La base (bg/corner/margins) sera couverte
  par le Theme au Lot 3 ; la couleur de bordure/texte sélection reste en code.
- `CharacterCard` : `bg_color = Data.tone_for(c.id)` (met) — teinte par
  personnage, dynamique. `Color("#10151f")` (unknown) — statique mais
  appliqué conditionnellement, reste en code.
- `AchievementRow` : `_check` bg/border = `Cfg.accent` si `done` — dynamique.

- [ ] **Step 2 : Run + vérif (aucune régression, commentaires seulement)**

Run + `logs_read`. Expected: PASS.

- [ ] **Step 3 : Commit**

```bash
git add src/TweaksPanel.gd src/CharacterCard.gd src/AchievementRow.gd
git commit -m "docs: StyleBox dynamiques conservés en code (couleurs runtime)"
```

### Checkpoint Lot 2

Vérifier : bannière de deck, boîte galaxie, titres de section codex, swatches/
difficulté/persos/succès inchangés. **Attendre le go.**

---

## LOT 3 — Theme complet (Étape 3)

Risque 🟠. Enrichir `main.tres`, l'assigner à chaque sous-scène, retirer les
overrides redondants (procédure sous-scène par sous-scène).

### Task 3.1 : Enrichir `themes/main.tres`

**Files:**
- Modify: `themes/main.tres`

**Interfaces:**
- Produces: entrées de theme couvrant l'usage réel (Button states, Panel,
  ScrollContainer, HSlider, constantes de containers).

- [ ] **Step 1 : Ajouter les entrées reflétant l'usage réel**

Via `mcp__godot-ai__theme_manage` (`set_stylebox_flat`, `set_constant`,
`set_color`). N'ajouter QUE ce qui correspond au rendu actuel, pour ne rien
changer visuellement :
- `Button` : `normal`/`hover`/`pressed` = StyleBoxEmpty (les boutons du jeu sont
  sans fond par défaut — gear, ✕, onglets) **sauf** là où une instance a son
  propre style (NewReignBtn, difficulté). Vérifier d'abord le rendu par défaut.
- `PanelContainer` : déjà `panel` = PANEL (présent). Conserver.
- `ScrollContainer` : `bg` = StyleBoxEmpty (les scrolls du codex/question sont
  transparents).
- `HSlider` : `slider`/`grabber`/`grabber_highlight` — reproduire l'apparence
  par défaut actuelle des sliders Tweaks (ne pas inventer).
- Constantes de containers (`VBoxContainer`/`HBoxContainer` separation,
  `MarginContainer` margins) : **ne PAS mettre de valeurs globales** — chaque
  instance définit ses propres séparations/marges ; un défaut global casserait
  les layouts. À laisser tel quel.

**Principe :** n'ajouter une entrée que si elle est strictement neutre (= égale au
rendu actuel) OU si elle remplace un override identique présent partout. En cas de
doute, ne pas ajouter.

- [ ] **Step 2 : Run + capture comparée**

Run + `editor_screenshot`. Expected: rendu identique à avant.

- [ ] **Step 3 : Commit**

```bash
git add themes/main.tres
git commit -m "feat(theme): enrichit main.tres (Button/Panel/ScrollContainer/HSlider neutres)"
```

### Task 3.2 : Assigner `main.tres` à chaque sous-scène

**Files:**
- Modify: `scenes/Gauge.tscn`, `scenes/CardView.tscn`, `scenes/Codex.tscn`,
  `scenes/Death.tscn`, `scenes/TweaksPanel.tscn`, `scenes/StatBox.tscn`,
  `scenes/ResSnapshot.tscn`, `scenes/DeckChip.tscn`, `scenes/AchievementRow.tscn`,
  `scenes/PlanetInfo.tscn`, `scenes/CharacterCard.tscn`, `scenes/CodexTab.tscn`

**Interfaces:**
- Consumes: `themes/main.tres`.

- [ ] **Step 1 : Assigner la propriété `theme` sur la racine de chaque sous-scène**

Via `mcp__godot-ai__node_set_property` (`property=theme`,
`value=res://themes/main.tres`) sur le nœud racine de chaque scène listée, puis
`scene_save`. Cela fait hériter le theme aux aperçus `@tool` standalone.

- [ ] **Step 2 : Run + vérif (aucun changement, theme déjà neutre)**

Run + `logs_read` + ouvrir 2-3 sous-scènes en standalone (`scene_open` +
`editor_screenshot`). Expected: rendu identique (le theme est neutre/égal).

- [ ] **Step 3 : Commit**

```bash
git add scenes/
git commit -m "refactor(theme): main.tres assigné à chaque sous-scène (aperçus @tool)"
```

### Task 3.3 : Retirer les overrides redondants (sous-scène par sous-scène)

**Files:**
- Modify: scripts + tscn portant des overrides couverts par le theme

**Interfaces:** suppression seulement.

- [ ] **Step 1 : Établir la liste à conserver (overrides dynamiques)**

**Garder impérativement** (runtime) : tout `add_theme_color_override("font_color",
Cfg.accent)` (bearer_role, tabs `set_active`, swatches), couleurs ressources
(`Pal.res_color`), états jauge crit/warn (Gauge `_refresh`), couleurs
conditionnelles met/unmet (CharacterCard), done/pending (AchievementRow),
state_color (PlanetInfo `_state`). **Retirer** : les overlays statiques égalant le
theme (ex. un `font_color = Pal.INK` sur un Label, un `panel` = PANEL redondant).

- [ ] **Step 2 : Retirer fichier par fichier, run + capture après chacun**

Pour chaque fichier (`Gauge`, `Codex`, `TweaksPanel`, `Death` + tscn, composants),
retirer uniquement les overrides statiques couverts par le theme, puis
`project_run` + `editor_screenshot` (jeu + sous-scène standalone) pour confirmer
0 régression. Si une suppression change le rendu, la rétablir.

- [ ] **Step 3 : Commit (un commit groupé en fin de lot)**

```bash
git add src/ scenes/
git commit -m "refactor(theme): retire les overrides statiques couverts par le theme"
```

### Checkpoint Lot 3

Comparer captures avant/après : jeu, codex (3 onglets), mort, Tweaks, + aperçus
standalone des sous-scènes. **Attendre le go.**

---

## LOT 4 — Réglages éditeur (Étapes 6 + 5)

Risque 🟢. ProjectSettings pour `Cfg` + `@export` du deck-unlock.

### Task 4.1 : `[foundation]` ProjectSettings lus par `Cfg.gd`

**Files:**
- Modify: `project.godot`, `src/Cfg.gd`

**Interfaces:**
- Produces: settings `foundation/difficulty|prose|motion|accent`.

- [ ] **Step 1 : Déclarer les settings**

Via `mcp__godot-ai__project_manage` `settings_set` (4 appels) :
`foundation/difficulty="normal"`, `foundation/prose=17`, `foundation/motion=1.0`,
`foundation/accent=Color(0.30980393,0.8392157,0.9098039,1)`.

- [ ] **Step 2 : Lire les settings dans `Cfg.gd`**

Remplacer les initialiseurs en dur :

```gdscript
var difficulty: String = ProjectSettings.get_setting("foundation/difficulty", "normal")
var prose: int = ProjectSettings.get_setting("foundation/prose", 17)
var motion: float = ProjectSettings.get_setting("foundation/motion", 1.0)
var accent: Color = ProjectSettings.get_setting("foundation/accent", Color("#4fd6e8"))
```

- [ ] **Step 3 : Run + vérif (valeurs par défaut identiques)**

Run + `logs_read`. Expected: PASS, accent/prose/difficulté inchangés au lancement.
Modifier `foundation/prose` dans ProjectSettings → la taille de question par défaut
change (preuve de lecture).

- [ ] **Step 4 : Commit**

```bash
git add project.godot src/Cfg.gd
git commit -m "feat(settings): defaults Cfg via ProjectSettings [foundation]"
```

### Task 4.2 : `@export` du deck-unlock dans `Game.gd`

**Files:**
- Modify: `src/Game.gd` (`_play_deck_unlock`)

**Interfaces:**
- Produces: `@export` `unlock_card_count_min/max`, `unlock_card_start_pos`,
  `unlock_card_start_rotation`, `unlock_card_rotation`, `unlock_fly_duration`.

- [ ] **Step 1 : Déclarer les `@export`**

```gdscript
@export var unlock_card_count_min: int = 3
@export var unlock_card_count_max: int = 6
@export var unlock_card_start_pos: Vector2 = Vector2(140, 150)
@export var unlock_card_start_rotation: float = 16.0
@export var unlock_card_rotation: float = 2.5
@export var unlock_fly_duration: float = 0.5
```

- [ ] **Step 2 : Remplacer les littéraux**

Dans `_play_deck_unlock` : `clampi(u["cards"], 3, 6)` →
`clampi(u["cards"], unlock_card_count_min, unlock_card_count_max)` ;
`Vector2(140, 150)` → `unlock_card_start_pos` ; `deg_to_rad(16)` →
`deg_to_rad(unlock_card_start_rotation)` ; `deg_to_rad(2.5)` (cible rotation) →
`deg_to_rad(unlock_card_rotation)` ; les durées `0.5` du glissement →
`unlock_fly_duration`.

- [ ] **Step 3 : Run + vérif déblocage**

Run + `logs_read`. Expected: PASS, animation identique.

- [ ] **Step 4 : Commit**

```bash
git add src/Game.gd
git commit -m "refactor(@export): valeurs du deck-unlock réglables (Game.gd)"
```

### Checkpoint Lot 4

Vérifier : lancement (defaults Cfg), Tweaks, déblocage de deck. **Attendre le go.**

---

## LOT 5 — Audio assets (Étape 4)

Risque 🟢. `@export` streams + fallback `SfxBank`.

### Task 5.1 : `@export` streams + `play_sfx` fallback

**Files:**
- Modify: `src/AudioManager.gd`

**Interfaces:**
- Produces: `@export` `swipe_sfx/commit_sfx/death_sfx/unlock_sfx/respawn_sfx/
  music_ambient: AudioStream` ; `play_sfx(stream, fallback=null)`.

- [ ] **Step 1 : Déclarer les `@export`**

Dans `AudioManager.gd` :

```gdscript
@export var swipe_sfx: AudioStream
@export var commit_sfx: AudioStream
@export var death_sfx: AudioStream
@export var unlock_sfx: AudioStream
@export var respawn_sfx: AudioStream
@export var music_ambient: AudioStream
```

(AudioManager est un autoload script sans scène ; les `@export` apparaissent dans
ProjectSettings → Autoload n'expose pas l'inspecteur. **Note :** pour qu'ils
soient éditables dans l'inspecteur, AudioManager doit être un autoload **scène**
`.tscn`, sinon les `@export` ne sont pas réglables. Décision : convertir
`AudioManager` en autoload scène `AudioManager.tscn` (Node racine + script) pour
exposer les `@export`.)

- [ ] **Step 2 : Convertir AudioManager en autoload scène**

Créer `scenes/AudioManager.tscn` (Node racine, script `AudioManager.gd`,
3 enfants `AudioStreamPlayer` Music/SFX/UI avec bus assignés). Adapter
`AudioManager.gd._ready` pour utiliser `$Music/$SFX/$UI` (au lieu de les créer en
code). Mettre à jour l'autoload `project.godot` :
`AudioManager="*res://scenes/AudioManager.tscn"`.

- [ ] **Step 3 : `play_sfx` avec fallback**

```gdscript
func play_sfx(stream: AudioStream, fallback: AudioStream = null) -> void:
	var s := stream if stream != null else fallback
	if s == null:
		return
	_sfx.stream = s
	_sfx.play()
```

- [ ] **Step 4 : Run + vérif (autoload scène charge, son fallback joue)**

Run + `logs_read`. Expected: PASS (game_capture_ready). Tester un swipe → son.

- [ ] **Step 5 : Commit**

```bash
git add scenes/AudioManager.tscn src/AudioManager.gd project.godot
git commit -m "feat(audio): AudioManager autoload scène + @export streams + fallback"
```

### Task 5.2 : Sites d'appel passent stream + fallback

**Files:**
- Modify: `src/CardView.gd`, `src/Game.gd`

**Interfaces:**
- Consumes: `play_sfx(stream, fallback)`, `AudioManager.*_sfx`, `SfxBank.*()`.

- [ ] **Step 1 : CardView**

`AudioManager.play_sfx(SfxBank.swipe())` → `AudioManager.play_sfx(
AudioManager.swipe_sfx, SfxBank.swipe())` ; idem commit →
`AudioManager.play_sfx(AudioManager.commit_sfx, SfxBank.commit())`.

- [ ] **Step 2 : Game**

`_play_death` : `AudioManager.play_sfx(AudioManager.death_sfx, SfxBank.death())`.
`_play_deck_unlock` : `AudioManager.play_sfx(AudioManager.unlock_sfx, SfxBank.unlock())`.
`_respawn` : `AudioManager.play_sfx(AudioManager.respawn_sfx, SfxBank.respawn())`.

- [ ] **Step 3 : (Optionnel) musique d'ambiance si fournie**

Dans `Game._ready`, après l'init : `if AudioManager.music_ambient:
AudioManager.play_music(AudioManager.music_ambient, 1.0)`. (Aucun asset par défaut
→ silence, comme avant.)

- [ ] **Step 4 : Run + vérif (SFX jouent via fallback, aucun stream assigné)**

Run + `logs_read`. Expected: PASS, sons identiques (fallback synthétique).

- [ ] **Step 5 : Commit**

```bash
git add src/CardView.gd src/Game.gd
git commit -m "refactor(audio): sites d'appel passent @export stream + fallback SfxBank"
```

### Checkpoint Lot 5

Vérifier : tous les SFX jouent (fallback), pas d'erreur autoload scène, jeu
inchangé. **Attendre le go final.**

---

## Self-Review (couverture du spec)

- Étape 1 (JSON data) → Tasks 1.1, 1.2 ✅
- Étape 2 (StyleBox .tres + @export) → Tasks 2.1–2.4 ✅ (statiques extraits ;
  dynamiques documentés — déviation justifiée : couleurs calculées au runtime)
- Étape 3 (Theme complet + suppression overrides) → Tasks 3.1–3.3 ✅ (+ assignation
  aux sous-scènes, décision actée)
- Étape 4 (audio assets) → Tasks 5.1, 5.2 ✅ (+ conversion autoload scène pour
  exposer les @export — nécessaire, sinon non éditables)
- Étape 5 (deck unlock @export) → Task 4.2 ✅
- Étape 6 (ProjectSettings) → Task 4.1 ✅
- Règle « ne pas casser » → checkpoints + captures ✅
- Règle « supprimer le code mort » → `_*_RAW`/consts (Lot 1), StyleBoxFlat.new()
  statiques (Lot 2), overrides redondants (Lot 3), script export jetable ✅

**Notes de cohérence :** `Data._load_json`/`_load_json_dict` définis avant les
`static var` qui les utilisent (Task 1.2). `play_sfx(stream, fallback)` signature
cohérente entre Task 5.1 (def) et 5.2 (appels). `AudioManager` devient autoload
scène (Task 5.1) — les sites d'appel `AudioManager.x_sfx` (Task 5.2) restent
valides (mêmes propriétés `@export`).

**Déviations explicites du spec (toutes justifiées) :**
1. StyleBox dynamiques (swatches, difficulté, char-tone, ach-done) gardés en code
   — leurs couleurs sont calculées au runtime, non `.tres`-ables.
2. AudioManager converti en autoload **scène** — sinon les `@export` ne sont pas
   éditables dans l'inspecteur (un autoload script pur n'a pas d'inspecteur).
3. Pas de constantes globales de containers dans le theme — casserait les layouts.
