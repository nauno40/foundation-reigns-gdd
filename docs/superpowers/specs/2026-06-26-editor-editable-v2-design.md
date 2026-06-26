# Refactor Godot v2 — Éditeur & Assets (design)

**Date :** 2026-06-26
**Branche :** `feat/editor-editable-v2`
**Source des exigences :** `EDITOR_PROMPT.md` (6 étapes)
**Pré-requis :** le refactor v1 (code idiomatique Godot 4) est mergé sur `master`.

## Objectif

Rendre le projet **éditable depuis l'interface de Godot sans toucher au code** :
données en JSON, StyleBox en `.tres`, Theme complet, SFX en assets `@export`,
réglages par défaut dans ProjectSettings. **Sans casser le jeu.**

## Règles (héritées de `EDITOR_PROMPT.md`)

- Ne pas casser le fonctionnement du jeu.
- Supprimer le code mort après migration vers les équivalents éditeur.
- Vérifier dans Godot après chaque étape.

## Décisions de cadrage (validées)

1. **Déroulé : phases + checkpoints.** 5 lots, 1 commit par lot, vérification
   utilisateur dans Godot entre chaque.
2. **Theme + aperçus `@tool` (Étape 3) : assigner `main.tres` à CHAQUE
   sous-scène**, pas seulement `Main.tscn`. Cela permet de retirer les overrides
   redondants tout en gardant les aperçus standalone corrects (workflow
   `codexscene`/`deathscene` de l'utilisateur).
3. **Audio (Étape 4) : inclus.** `@export` streams dans `AudioManager` +
   `play_sfx(stream, fallback)` ; `SfxBank` reste le fallback zéro-asset.

## Notes techniques actées

- **Génération JSON one-shot.** Les textes FR (« », apostrophes, accents) sont
  écrits via un script `@tool` jetable qui lit les `_*_RAW` et sérialise avec
  `JSON.stringify`, puis est supprimé. Pas d'écriture JSON manuelle.
- **Accès JSON par clé.** `d["id"]` / `d.get(...)` (l'accès point `d.id` sur un
  `Dictionary` JSON n'est pas valide en GDScript). Le spec d'`EDITOR_PROMPT`
  utilise `d.id` à titre illustratif uniquement.
- **`Cfg` ↔ ProjectSettings.** `accent: Color` stockée dans `[foundation]`
  (Godot sérialise les `Color`), lue via `ProjectSettings.get_setting(key, def)`.
  `Cfg` reste `@tool`.
- **Vérification.** MCP Godot (parse-check + `project_run` + `logs_read`) par
  tâche ; checkpoint visuel utilisateur par lot. Pour tout nouveau fichier/script
  créé hors éditeur : run du jeu = source de vérité ; demander un reload projet
  si le cache éditeur se bloque.

## État des lieux (mesuré, post-v1)

- `Data.gd` : `_DECK_RAW`, `_CHARACTERS_RAW`, `_PLANETS_RAW` (consts) + builders
  `all_cards/all_characters/all_planets` (objets typés en cache). Autres consts :
  `RESOURCES`, `MOODS`, `DIFF`, `TONES`, `DECKS_META`, `SELDON_MESSAGES`,
  `COVERS`, `DECK_UNLOCKS`, `ACHIEVEMENTS`.
- **5** `StyleBoxFlat.new()` (Game.gd, TweaksPanel.gd, Codex.gd).
- **46** `add_theme_*_override` : PlanetInfo 2, AchievementRow 1, CharacterCard 2,
  TweaksPanel 12, Game 15, CodexTab 1, Codex 10, Gauge 3.
- `Cfg.gd` : `difficulty`/`prose`/`motion`/`accent` en dur.
- `AudioManager.gd` : `play_sfx/play_ui/play_music` ; `SfxBank` (preload) génère
  les SFX synthétiques.
- `themes/main.tres` : minimal (Label/Button/RichTextLabel colors + PanelContainer
  panel), appliqué à `Main` seulement.

## Découpage en lots

### Lot 1 — Données JSON (Étape 1) — risque 🔴

- Créer `data/` à la racine.
- Script `@tool` one-shot : exporte `_DECK_RAW` → `data/cards.json`,
  `_CHARACTERS_RAW` → `data/characters.json`, `_PLANETS_RAW` →
  `data/planets.json`, et `COVERS`/`DECK_UNLOCKS`/`ACHIEVEMENTS` (tableaux) +
  `SELDON_MESSAGES` (dict) vers leurs `.json`. Exécuté une fois, puis supprimé.
- `Data.gd` : ajouter `_load_json(path) -> Array` et `_load_json_dict(path) ->
  Dictionary`. Les builders `all_cards/all_characters/all_planets` lisent les
  `.json` (via `d["..."]`). `COVERS`/`DECK_UNLOCKS`/`ACHIEVEMENTS`/
  `SELDON_MESSAGES` deviennent des `static var` chargées du JSON.
- Supprimer `_DECK_RAW`, `_CHARACTERS_RAW`, `_PLANETS_RAW` et les 4 consts
  migrées. **Conservées en const** (hors périmètre JSON du spec) : `RESOURCES`,
  `MOODS`, `DIFF`, `TONES`, `DECKS_META`.
- Adapter `DECKS_META` consommé par Codex (reste const) ; vérifier que rien ne
  référence les noms supprimés.

### Lot 2 — StyleBox `.tres` + `@export` (Étape 2) — risque 🟠

- Créer `res://styles/`. Un `.tres` par StyleBox récurrent (générés via script
  one-shot ou `material/resource` MCP) :
  - `deck_card_style.tres`, `deck_banner_style.tres` (Game `_play_deck_unlock` /
    `_unlock_banner`).
  - `galaxy_box_style.tres` (Codex `_render_gal`).
  - `char_met_style` / `char_unknown_style` (CharacterCard) — ou via Theme.
  - `ach_done_style` / `ach_pending_style` (AchievementRow) — styles de la case.
  - styles des swatches / boutons difficulté (TweaksPanel) — via Theme ou `.tres`.
- `@export var` correspondants (`StyleBox`, `Font`, `Color`, `int`) dans
  Game.gd (deck unlock : `deck_card_style`, `banner_style`, `unlock_tag_font`,
  `unlock_name_font`, `unlock_name_color`, `unlock_count_color`), Codex.gd
  (`galaxy_box_style`, `section_font`, `section_font_size`, `section_color`),
  TweaksPanel.gd (`difficulty_button_style`), CharacterCard.gd, AchievementRow.gd.
- Remplacer les `StyleBoxFlat.new()` + littéraux par les `@export`. Assigner les
  `.tres`/fonts par défaut sur les instances dans les `.tscn`.

### Lot 3 — Theme complet (Étape 3) — risque 🟠

- Enrichir `themes/main.tres` : `Button` hover/pressed/disabled,
  `Panel/styles/panel`, `ScrollContainer/styles/bg`, `HSlider`
  (grabber/grabber_area/grabber_highlight), constantes de containers
  (`VBoxContainer`/`HBoxContainer`/`MarginContainer`), ombre de `Label` si
  pertinent. Uniquement ce qui reflète l'usage réel du jeu (pas de styles
  inventés qui changeraient le rendu).
- **Assigner `main.tres` à la racine de chaque sous-scène** : `Gauge`,
  `CardView`, `Codex`, `Death`, `TweaksPanel`, `StatBox`, `ResSnapshot`,
  `DeckChip`, `AchievementRow`, `PlanetInfo`, `CharacterCard`, `CodexTab`.
- Retirer les `add_theme_*_override` désormais couverts par le theme. **Garder**
  les overrides dynamiques runtime : `Cfg.accent` (bearer_role, tabs, swatches…),
  couleurs ressources (`Pal.res_color`), états crit/warn des jauges, couleurs
  conditionnelles (met/unmet, done/pending).
- Vérifier chaque sous-scène en standalone (aperçu `@tool`) + au runtime.

### Lot 4 — Réglages éditeur (Étapes 6 + 5) — risque 🟢

- **Étape 6 :** ajouter dans `project.godot` une section `[foundation]` :
  `difficulty="normal"`, `prose=17`, `motion=1.0`, `accent=Color(...)`. Dans
  `Cfg.gd`, initialiser les variables via `ProjectSettings.get_setting(
  "foundation/<clé>", <défaut>)`.
- **Étape 5 :** `@export var` dans `Game.gd` pour les valeurs du deck-unlock :
  `unlock_card_count_min/max`, `unlock_card_start_pos`,
  `unlock_card_start_rotation`, `unlock_card_rotation`, `unlock_fly_duration`.
  Remplacer les littéraux de `_play_deck_unlock` par ces `@export`.

### Lot 5 — Audio assets (Étape 4) — risque 🟢

- `@export var swipe_sfx/commit_sfx/death_sfx/unlock_sfx/respawn_sfx/
  music_ambient: AudioStream` dans `AudioManager.gd`.
- `play_sfx(stream: AudioStream, fallback: AudioStream = null)` : joue
  `stream` sinon `fallback`, ignore si les deux sont null.
- Sites d'appel : `AudioManager.play_sfx(AudioManager.swipe_sfx, SfxBank.swipe())`
  etc. (CardView, Game). `SfxBank` conservé comme fallback.
- Aucun asset fourni par défaut → le fallback synthétique reste actif (parité).

## Stratégie de vérification

Par tâche : parse-check MCP + `project_run` + `logs_read` (0 erreur). Par lot :
checkpoint utilisateur (run + interactions concernées + aperçus `@tool` des
sous-scènes touchées). Critère : 0 erreur + parité visuelle/comportementale.

## Risques & atténuations

- **Lot 1 (JSON) le plus invasif.** Génération via `JSON.stringify` (échappement
  sûr). Vérifier que `all_cards()` etc. produisent des objets identiques (mêmes
  ids, fx, textes) — comparer un tirage avant/après.
- **`static var` + chargement JSON au class-load.** `_load_json` doit être
  défini et fonctionner en éditeur (`@tool` Cfg, scènes `@tool`). `res://` packé
  en export → OK.
- **Lot 3 retrait d'overrides.** Risque de régression visuelle ; procéder
  sous-scène par sous-scène avec captures avant/après.
- **Cache éditeur (class_name/nouveaux fichiers).** Run du jeu = source de
  vérité ; reload projet si blocage (cf. mémoire `godot-mcp-class-name-gotchas`).

## Hors périmètre (YAGNI)

- Pas de migration JSON de `RESOURCES`/`MOODS`/`DIFF`/`TONES`/`DECKS_META`
  (config moteur, non listée par le spec).
- Pas d'assets audio réels fournis (le fallback synthétique suffit).
- Pas de styles de Theme inventés au-delà de l'usage réel du jeu.
