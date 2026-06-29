# Refactor Godot — Foundation Reigns (design)

**Date :** 2026-06-26
**Branche :** `feat/ui-refonte-nouvelle-version`
**Source des exigences :** `REFACTOR_PROMPT.md` (10 étapes)

## Objectif

Refactoriser le projet vers des pratiques Godot 4 idiomatiques **sans casser le
jeu**. Le port web React est fonctionnel mais généré par IA : connexions de
signaux incohérentes, `create_tween()` partout, valeurs magiques en dur, nœuds
construits en code, données en dictionnaires non typés, aucun audio.

## Règles non négociables (héritées de `REFACTOR_PROMPT.md`)

- Le jeu doit se lancer et se jouer **exactement comme avant** après chaque lot.
- Ne pas modifier les assets (shaders, polices, icônes, SVG).
- Supprimer le code mort remplacé ; ne pas laisser d'ancien + nouveau côte à côte.
- Tous les commentaires en **français**.
- `@tool` autorisé pour les scripts qui tournent dans l'éditeur (déjà le cas pour
  `CardView`, `Death`, `Cfg`, `Codex`, `CharacterCard`).

## Décisions de cadrage (validées avec l'utilisateur)

1. **Déroulé : par phases + checkpoints.** Étapes regroupées en 6 lots cohérents,
   1 commit par lot. L'utilisateur teste le jeu dans Godot entre chaque lot avant
   qu'on continue.
2. **Audio : système + sons synthétiques.** On construit `AudioManager`, les bus,
   et on génère des SFX simples par code (pas de dépendance externe, libre de
   droits). Pas de vraie musique d'ambiance — placeholder discret seulement.
3. **Data (Étape 6) : objets typés en code, PAS de `.tres` par entrée.** On crée
   les classes `Resource` typées, mais `Data.gd` construit les objets en code via
   `all_cards()` / etc. Moins de churn (≈34 cartes + persos + planètes restent
   dans un fichier), même bénéfice côté typage. Passage aux `.tres` possible plus
   tard si besoin.

## État des lieux (mesuré)

- ~1 770 lignes de GDScript sur 19 scripts, 13 scènes.
- 20 `create_tween()`, 29 `.connect(`, 55 `add_theme_*`.
- Flags booléens dans `Game.gd` : `busy`, `_hdrag`, `_hmoved`, + checks
  `_death.visible` / `_codex.visible`.
- Données 100 % en dictionnaires (`card["left"]["fx"]`, `Data.RESOURCES`, …).
- Autoloads actuels : `Cfg`, `_mcp_game_helper`.

## Découpage en lots

Ordre dérivé du « plan de travail conseillé » du prompt, regroupé pour des
checkpoints utiles.

### Lot A — Fondations sûres (Étapes 1, 8, 4) — risque 🟢

- **Étape 1 — Signaux.** Toutes les connexions en `signal.connect(callable)`
  moderne, groupées et lisibles dans `_ready()`. Toute lambda > 3 lignes devient
  une méthode privée nommée `_on_…`. Conserver `CONNECT_ONE_SHOT` via le param
  `flags`. Fichiers : `Game.gd`, `CardView.gd`, `Gauge.gd`, `Death.gd`,
  `Codex.gd`, `TweaksPanel.gd`, `CodexTab.gd`, `CharacterCard.gd`.
- **Étape 8 — Input Map.** Ajouter `swipe_left`, `swipe_right`, `codex_toggle`
  dans `project.godot`. Dans `Game.gd`, remplacer `ui_left`/`ui_right` par
  `swipe_left`/`swipe_right` ; câbler `codex_toggle` pour ouvrir/fermer le codex.
- **Étape 4 — `@export`.** Convertir les constantes magiques listées dans le
  prompt (`Game.gd`, `CardView.gd`, `Gauge.gd`, `Death.gd`) en `@export`.
  Supprimer les `const` correspondantes sauf si utilisées ailleurs.

### Lot B — Cœur logique (Étapes 9, 10) — risque 🟠

- **Étape 9 — Machine à états.**
  `enum State { IDLE, DRAGGING, RELEASING, FLYING_OUT, TRANSITIONING, DEATH, CODEX }`,
  `var _state := State.IDLE`, fonction `_set_state(new_state)`. Remplacer
  `if busy: return` par `if _state != State.IDLE: return`, et les checks
  `_death.visible` / `_codex.visible` par l'état. `_input()` / `_unhandled_input()`
  consultent `_state` avant d'agir.
- **Étape 10 — Groupes.** Mettre les 4 jauges (`BarMilitary`, `BarReligion`,
  `BarCommerce`, `BarPolitics`) dans le groupe `gauges` (dans `Game.tscn`).
  Remplacer le dict `_gauges` par une lecture du groupe filtrée par `resource_key`
  (propriété exposée sur `Gauge`).

### Lot C — Scènes & animations (Étapes 5, 2) — risque 🟠

- **Étape 5 — Nœuds en code → scènes.** Déplacer dans `Game.tscn` : `DeathFx`
  (`ColorRect`, `visible=false`, `ShaderMaterial` death_fx pré-assigné), le bouton
  gear ⚙ (position/taille/textes), et l'instance `TweaksPanel`. Créer
  `TweaksPanel.tscn` avec la structure statique (titre, bouton ✕) ; ne laisser en
  code que le dynamique (swatch couleurs, sliders). Dans `Death.tscn`, ajouter la
  bande lumineuse sweep. Connecter les signaux dans les scènes quand pertinent.
  `Codex._section()` / `_grid()` restent en code (dynamique, OK).
- **Étape 2 — AnimationPlayer (ciblé).** Ajouter un `AnimationPlayer` `Animations`
  dans `Game.tscn`. Animations à **valeurs fixes** portées en AnimationPlayer :
  `question_fade`, `death_fx` (progress shader), `deck_unlock` (bandeau).
  `Death.tscn` reçoit un AnimationPlayer pour la bande `sweep`.

  **Restent en `create_tween()`** (dépendent de l'état/layout calculé au
  runtime, AnimationPlayer les casserait) : `CardView.play_entry()` (suit `_base`
  en direct), `_fly_out()`, le ressort de drag dans `_process()`, le glissement
  des cartes de deck, `Codex` (`_animate_to`/`_spring_back`/`_slide`). C'est
  l'usage idiomatique : Tween pour le dynamique, AnimationPlayer pour le scripté.

### Lot D — Theme (Étape 7) — risque 🟡

- Créer `res://themes/main.theme`. Centraliser couleurs et styles de `Pal`
  (`Theme.gd`) : `Label` (font SpaceMono, couleur INK), `PanelContainer` (StyleBox
  bg=PANEL), `Button` (couleur INK_DIM), `RichTextLabel` (couleur INK_DIM).
- Retirer les `add_theme_color_override` / `add_theme_stylebox_override`
  redondants ; ne garder que les overrides spécifiques à une instance.
- Appliquer le theme sur le nœud racine de `Main.tscn`.
- `Pal` (`Theme.gd`) reste comme source des couleurs ressources (oklch) utilisées
  par code (`res_color`), non thématisables.

### Lot E — Audio (Étape 3) — risque 🟢

- Nouvel autoload `res://src/AudioManager.gd` (`extends Node`) avec enfants
  `Music` / `SFX` / `UI` (`AudioStreamPlayer`), signal `music_finished`, méthodes
  `play_music(stream, fade_in)`, `play_sfx(stream)`, `play_ui(stream)`.
- `default_bus_layout.tres` avec 4 bus : Master → Music, SFX, UI.
- Enregistrer l'autoload dans `project.godot`.
- SFX **synthétiques** générés par code (petits buffers procéduraux) pour : swipe
  (seuil REVEAL franchi), commit « floup », mort, deck_unlock, respawn.
- Hooks : `Game.gd` (swipe, commit, mort, deck_unlock, respawn + placeholder
  ambiance au `_ready()`), `CardView.gd` (swipe au seuil, floup au commit),
  `Death.gd` (son dramatique à `show_death`).

### Lot F — Data typée (Étape 6) — risque 🔴

- Classes `Resource` : `CardData`, `AnswerData`, `CharacterData`, `PlanetData`
  (champs `@export` selon le prompt ; `fx` reste un `Dictionary` typé valeur).
- `Data.gd` : remplacer `const DECK/CHARACTERS/PLANETS` par
  `static func all_cards() -> Array[CardData]` / `all_characters()` /
  `all_planets()` qui **construisent les objets typés en code** (pas de
  chargement de `.tres`).
- Constantes de config conservées en dur : `RESOURCES`, `MOODS`, `DIFF`,
  `SELDON_MESSAGES`, `DECK_UNLOCKS`, `ACHIEVEMENTS`, `DECKS_META`, `TONES`,
  `COVERS`.
- Adapter tous les consommateurs : `Game.gd` (`card.left_answer.fx`,
  `pick_card`, mort), `CardView.gd` (`show_card(card: CardData)`,
  `card.left_answer.title`), `Death.gd`, `Codex.gd`. Adapter `tone_for`,
  `initials`, `pick_card` aux objets.

## Stratégie de vérification

À chaque checkpoint, **avant** de demander le go utilisateur :

1. MCP Godot : `editor_state` → éditeur prêt, pas d'erreur de parse.
2. `project_run` puis `logs_read` → le jeu se lance sans erreur runtime.
3. L'utilisateur teste à l'œil : swipe (clavier + souris), mort + respawn,
   ouverture/fermeture codex, panneau Tweaks.

Critères d'acceptation par lot : **0 erreur** éditeur/runtime + parité de
comportement confirmée par l'utilisateur.

## Risques & atténuations

- **`@tool` + aperçus éditeur.** `CardView`, `Death`, `Codex`, `CharacterCard`
  ont des branches `Engine.is_editor_hint()`. Le refactor data (Lot F) et signaux
  (Lot A) doivent préserver ces aperçus. Vérifier en ouvrant chaque scène standalone.
- **Lot F le plus invasif.** Fait en dernier, isolé, après que tout le reste soit
  stable. Tout passage dict→objet doit être exhaustif (pas de mix).
- **`fx` spéciaux.** Les clés `legit` / `legitimacy` ne sont pas dans `res` ;
  conserver le traitement spécial existant lors du passage aux objets.
- **Régression localisée.** 1 commit par lot → `git bisect` trivial si un
  comportement casse.

## Hors périmètre (YAGNI)

- Pas de vraie musique / banque de SFX produite (synthétique seulement).
- Pas de `.tres` par entrée de données (objets typés en code suffisent).
- Pas de refactoring non demandé hors des 10 étapes.
