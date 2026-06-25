# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Foundation Reigns** is a Godot 4.6 mobile narrative card game set in Asimov's Foundation universe, inspired by the *Reigns* series. The player is a secret Second Foundation Speaker making choices by swiping cards left/right, managing 4 resources (military, religion, commerce, politics) and a legitimacy score. Death triggers a respawn into the same galactic timeline.

The `reference/` directory is a separate reverse-engineering workspace (Unity IL2CPP analysis of *Reigns: Three Kingdoms*) used as design reference; it is not part of the Godot project. The canonical design document is `docs/GDD.md` (it absorbs and replaces the former `FOUNDATION_PLAN.md`, archived in `reference/REIGNS_DATA_EXPORT/docs/`).

## Running the Project

Open in Godot 4.6. The entry scene is `scenes/MainMenu.tscn`. Tests run via the GUT plugin (enabled in `project.godot`).

**Run all tests** from the Godot editor: enable the GUT panel and click Run, or run headless:
```bash
godot --headless -s tests/gut_runner.gd
```

**Run a single test file:**
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gtest=res://tests/test_narrative_model.gd
```

## Architecture

The game follows a strict separation between data, core logic, and UI. All core classes are plain GDScript (no `extends Node`) — they are instantiated by `Main.gd` and passed by reference. The game entry point is `MainMenu.tscn`; `Globals.gd` is an autoload that parses CLI args (`--deck`, `--difficulty`) and controls `start_mode` (NEW_GAME / CONTINUE) for the transition to `Main.tscn`.

```
Globals.gd (autoload)   — CLI args, start_mode, difficulty
MainMenu.tscn (entry)   — main menu with Nouvelle Partie / Continuer / Options / Quitter
  └── OptionsScreen.tscn — difficulty selector overlay
Main.gd (scene root)
  ├── FoundationGameData   — loads all JSON from data/ into typed arrays/dicts
  ├── Context              — mutable game state (_vars dict + _keep_flags)
  ├── NarrativeModel       — card draw logic (conditions, lockturn, weighted random)
  ├── LegitimacySystem     — legitimacy thresholds and mood bias
  ├── RespawnSystem        — death → era reset with legitimacy penalty by death type
  └── SaveSystem           — JSON serialization to user://foundation_save.json
```

**Data flow on each turn:**
1. `NarrativeModel.draw_card()` — filters eligible cards (deck active + conditions + lockturn), picks via weighted random; `link` context var forces a specific card ID
2. `CardScreen.show_card()` — renders question/hints, tilts card on swipe progress
3. On swipe: `apply_outcomes()` → `add_var("turns", 1)` → `save()` → game-over check → next card

## Card Data Format (`data/foundation_cards.json`)

Each card is a Dictionary with these keys:
- `id`, `label`, `deck`, `weight`, `lockturn`, `hidden`, `bearer`
- `conditions[]` — AND logic; each: `{variable, op ("equal"|"above"|"below"|"not"), value}`
- `loadOutcome[]`, `yesOutcome[]`, `noOutcome[]` — each outcome: `{variable, intValue, addOperation (+=|set), toKeep}`
- `question`, `leftAnswer.title`, `leftAnswer.reaction`, `rightAnswer.title`, `rightAnswer.reaction` — localized dicts with `"FR"` key (fallback to `"EN"`)
- `moods` — `{default, yes, no}` strings
- `link` outcomes accept node IDs or string aliases (`_enddispatch`, `_jump_<planet>`,
  see `data/link_aliases.json`); `weight: -1` = link-only card; `bearer` accepts
  `"role:<id>"` (persistent institutional roles, `data/roles.json`); `planet_<id>`
  decks are gated by the `location` context variable.
- Production pipeline: `tools/extract_skeletons.py` → fill `data/skeletons/<deck>.json`
  → `tools/check_structure.py` (structural 1:1 clone of the base game, see
  `docs/superpowers/specs/2026-06-12-clone-structurel-reigns-design.md`).

## Context Variables

`Context._vars` is the single source of truth for all game state. Key variables:
- Resources: `military`, `religion`, `commerce`, `politics` (0–100, default 50; 0 or 100 = death)
- `legitimacy` (0–100; 0 = "exposed" death)
- `turns`, `year`, `age`, `mood`, `link` (forced next card ID)
- `deck_<name>` — set to 0 to disable a deck
- `seen_<card_id>` — set after card is seen
- `planet_<id>_state` — -1/0/1 (hostile/neutral/allied) for the codex galaxy tab
- `seldon_crisis_<1-6>` — 1=passed, -1=failed (shown on DeathScreen timeline)
- `toKeep` variables survive death/respawn via `Context._keep_flags`

## Death Types & Respawn

Three death types with different legitimacy penalties on respawn:
- `"natural"` — age-based probability (≥75), full legitimacy (100)
- `"resource"` — any resource hits 0 or 100, legitimacy 80
- `"exposed"` — legitimacy reaches 0, legitimacy 50

`RespawnSystem.respawn()` resets to the era start year (6 eras mapped to Foundation years 1–600+), clears non-keep vars, randomizes starting age (35–40).

## UI Scenes

- `CardScreen.tscn` / `CardScreen.gd` — swipe via `SwipeDetector`, square card + icon-mask gauges, inline deck-unlock banner (`play_deck_unlock`); emits `choice_made(is_left)`, `dashboard_requested`
- `DeathScreen.tscn` / `DeathScreen.gd` — cause, Seldon transmission, 2×2 stats, resource snapshot (icons); emits `continue_pressed`
- `Codex.tscn` / `Codex.gd` — sliding « Tableau de bord » panel, 3 tabs (Personnages, Succès/Decks, Galaxie). Replaces the former standalone `GalaxyMap`.
- `ResourceBar.tscn` / `ResourceBar.gd` — single icon-mask gauge (fill bottom-up, ▲/▼ delta flash); 4 instances in `CardScreen`

## Tests

Test files in `tests/` follow GUT conventions (`extends GutTest`, `before_each`, `test_*` methods). Each test file covers one core class. Tests instantiate core classes directly without the scene tree.

## UI Design Reference

The **current** target interface is the redesign in `reference/UI Nouvelle version/`
(`app.jsx`, `codex.jsx`, `data.jsx`, `Foundation Reigns Prototype.html`). The older
`reference/ui-prototype/` is superseded. When implementing or modifying UI, match the
new template. Key differences from the old prototype, **already ported to Godot**:

- **Resource gauges** are icon-shaped masks that fill bottom-up (sword/atom/coins/columns),
  with engraved graduations (25/50/75), a bright waterline, and a ▲/▼ green/red delta flash
  on change. Implemented in `src/ui/ResourceBar.gd` + `assets/shaders/gauge_fill.gdshader`
  (icons `assets/icons/*.svg`). No numbers shown.
- **Card is square** (1:1) with a deck-pile card behind it, a per-bearer tinted background
  (`CardUtils.tone_for`, `assets/shaders/card_face.gdshader`), a faceless flat bust
  (`src/ui/CardBust.gd`), the chosen answer's title written **on the card** during the swipe,
  and the bearer name **below** the card. Release uses a sub-damped **spring** (bounce).
- **Layout**: dark top bar (era + 4 gauges only — the mood indicator is removed), light
  central panel (question in Space Mono, low-legitimacy whisper in **Caveat** cursive), dark
  bottom bar (year in large Caveat + age·cover). See `scenes/CardScreen.tscn` /
  `src/ui/CardScreen.gd`.
- **Dashboard codex** (`scenes/Codex.tscn` / `src/ui/Codex.gd`): a panel sliding up from the
  bottom bar handle, 3 tabs — Personnages, Succès/Decks, Galaxie. The standalone
  `GalaxyMap.tscn` is no longer in the flow (the galaxy is now the codex's 3rd tab). Codex
  data is currently a **static placeholder** (real wiring to `seen_*`/`deck_*`/MetaSystem
  is deferred).
- **Death**: a holographic glitch/collapse (`assets/shaders/death_fx.gdshader`, played by
  `Main._play_death_fx`) precedes the death overlay; the Seldon box header reads
  `☼ TRANSMISSION — HARI SELDON`.
- **Caveat** font added at `assets/fonts/Caveat-Variable.ttf` (reactions, whisper, year).
- **Difficulty multiplier** (doux ×0.7 / normal ×1.0 / brutal ×1.45) is applied to additive
  resource/legitimacy outcome deltas in `Main._scaled_outcomes`.

### Visual Identity

Dark holographic sci-fi aesthetic. CSS variable palette (to be mirrored in Godot theme):

| Variable | Value | Usage |
|----------|-------|-------|
| `--bg` | `#05070d` | App background |
| `--accent` | `#4fd6e8` | Cyan holo — primary interactive color |
| `--amber` | `#e8b65a` | Seldon messages, warnings, keytag |
| `--danger` | `#d96a5a` | Critical state, death cause |
| `--ink` | light | Primary text |
| `--ink-dim` | dimmed | Secondary text |
| `--ink-faint` | very dim | Labels, hints |
| `--line` | subtle | Card borders |
| `--panel` / `--panel-2` | dark | Card backgrounds (gradient) |
| `--military` | orange-ish | Resource color |
| `--religion` | purple-ish | Resource color |
| `--commerce` | teal-ish | Resource color |
| `--politics` | green-ish | Resource color |

**Typography:**
- `"Spectral"` (serif) — all narrative text: questions, reactions, character names, Seldon messages
- `"Space Mono"` (monospace) — UI buttons, footer hints, keyboard shortcuts
- system-ui — utility labels (resource names, meta info)

### Screen Layout (top to bottom)

```
┌─────────────────────────────────┐
│ TOPBAR                          │
│  ÈRE HARDIN · ANS 1–80   [☼]   │  ← era label (accent) + seal
│  An 42 · 38 ans  Couverture: X  │  ← year / age / cover
│  [▲ MIL] [✦ REL] [● COM] [■ POL]  ← 4 resource bars
│  ◉ MÉFIANT — vous lisez son esprit │  ← mood dot + label
│  « Vous semblez toujours... »   │  ← legitimacy whisper (< 35)
├─────────────────────────────────┤
│ CARD AREA (flex:1)              │
│   [swipe hint when idle]        │
│   ┌──── CARD ────────────────┐  │
│   │ [holo portrait]          │  │
│   │  Name · Role             │  │
│   │  Question text (Spectral)│  │
│   │  [◄ Left] [Right ►]      │  │
│   └──────────────────────────┘  │
├─────────────────────────────────┤
│ FOOTER  Glissez ◄ ►  [←] [→]  │
└─────────────────────────────────┘
```

### Resource Bars

- Vertical bars, **no numeric values displayed** — the player reads the level visually only
- Icons: `▲` Military, `✦` Religion, `●` Commerce, `■` Politique
- Three states:
  - **normal**: default
  - **warn**: value 15–25 or 75–85 → label turns amber
  - **crit**: value < 15 or > 85 → border pulses red (`critpulse` animation)
- **Affected state** (during drag): bar border turns cyan + pulses (`affpulse`) + small cyan dot pip appears. Reveals WHICH bars will change, never the direction or amount.

### Card Component

- Width: `min(360px, 86%)`, border-radius 14px
- Dark gradient background with subtle inner border
- **Holo portrait** (190px tall):
  - Dark background with cyan grid overlay (masked radially)
  - Abstract bust silhouette (body shape + head circle with initials)
  - Scanlines overlay + periodic flicker animation
  - Bearer name (Spectral 18px) + role (cyan 10px uppercase) at bottom-left
  - `"Figure du Plan"` amber badge (top-right) for key narrative characters (`card.key = true`)
- **Question** (Spectral ~19px, line-height 1.46, `#eaf0f8`)
- **Choice chips** (shown at rest): left chip `◄ GAUCHE` / right chip `DROITE ►`; chip highlights with cyan border + glow when drag passes threshold
- **Edge labels**: left/right answer titles appear at screen edges while dragging (fade in with `lean` opacity)
- **Swipe physics**: threshold 92px, tilt `drag * 0.045°`, fly-out 150% + 22° rotation over 0.5s
- **Reaction text**: italic centered Spectral, fades in (`rise` animation) after swipe, replaces choice chips

### Legitimacy Whisper

When `legitimacy < 35`, display italicized amber text below the mood row:
> *« Vous semblez toujours avoir la bonne réponse, Orateur… »*

This is the primary UI signal for low legitimacy — no bar, no number.

### Mood Indicator

Small colored dot + mood label (uppercase, letterspaced) + `"— vous lisez son esprit"` (faint).

| Mood | Dot color |
|------|-----------|
| neutral | `#7d8aa3` (grey-blue) |
| suspicious | `#e0a64f` (amber) |
| afraid | `#7fb4d8` (light blue) |
| angry | `#d96a5a` (red) |
| flattered | `#b98ad6` (purple) |
| curious | `#4fd6e8` (cyan) |
| sad | `#8693a8` (muted blue-grey) |
| desperate | `#c8505a` (dark red) |

### Death Screen

Overlays the full screen (`z-index:40`, blurred backdrop):
1. Cause label (red, uppercase, letterspaced) — e.g. "Orateur démasqué"
2. `h1` Speaker identifier — "Orateur — [cover name]" (Spectral 30px)
3. Subtitle — cover · age · "Règne couvert An X → An Y"
4. **Holographic Seldon message** (amber box, `"☼ MESSAGE — HARI SELDON"` header, italic Spectral 16px, `#f2e4c4`)
5. 2×2 stat grid: Décisions prises / Années couvertes / Score du règne / Plan de Seldon deviation
6. Resource snapshot: 4 columns with label, numeric value, mini horizontal bar
7. `"Nouveau règne →"` button (cyan, Space Mono, uppercase)

### Seldon Messages by Death Cause (`data.jsx` → `SELDON_MESSAGES`)

| Cause key | Message |
|-----------|---------|
| `military` | Fondation sans défense = bibliothèque attendant l'incendie |
| `military_hi` | Puissance militaire = redevenu l'Empire |
| `religion` | Sans la foi qui voile la science, machines = métal froid |
| `religion_hi` | La théocratie a dévoré la science |
| `commerce` | Isolement économique = siège lent |
| `commerce_hi` | Monopole a corrompu les marchands |
| `politics` | Chaos = aucune institution ne survit |
| `politics_hi` | Autoritarisme = tyrannie |
| `legitimacy` | Orateur exposé met en péril toute la Seconde Fondation |

### Difficulty Multiplier

Applied to all outcome `fx` deltas: doux ×0.7 / normal ×1.0 / brutal ×1.45. Not yet in Godot — planned feature.

---

## Game Design Reference

The sections below summarize the full design from `docs/GDD.md`. Consult that file for complete detail.

### Eras & Respawn Windows

| Ère | Fenêtre | Thème |
|-----|---------|-------|
| Hardin | Ans 1–80 | Religion comme outil, menace Anacréon |
| Marchands | Ans 80–250 | Expansion commerciale |
| Mallow | Ans 200–350 | Princes Marchands, Korell |
| Mulet | Ans 290–380 | Chaos, imprévisible |
| Restauration | Ans 350–600 | Reconstruction, Kalgan |
| Late Empire | Ans 600–1000 | Vers le Second Empire |

On death, `RespawnSystem` resets `year` to the era start year of the current year (already implemented — see `ERA_STARTS` in `RespawnSystem.gd`).

### Cover Identities (`data/covers.json`)

Each Speaker starts with a random civilian cover identity from their era's pool, granting a minor +5 bonus on the linked resource. The cover name is stored in `ctx.cover_name`.

| Ère | Couvertures possibles |
|-----|-----------------------|
| Hardin (1–80) | Conseiller impérial, Prêtre scientifique, Marchand local |
| Marchands (80–250) | Négociant interstellaire, Diplomate, Historien |
| Mallow (200–350) | Prince marchand, Ambassadeur, Ingénieur |
| Mulet (290–380) | Réfugié, Espion, Conseiller de cour |
| Restauration (350–600) | Administrateur, Juge, Académicien |
| Late Empire (600–1000) | Archiviste, Sénateur, Philosophe |

### Resources

| Ressource | À 0 | À 100 |
|-----------|-----|-------|
| `military` | La Fondation se fait envahir | Puissance militaire agressive |
| `religion` | L'Église de la Science s'effondre | Théocratie incontrôlable |
| `commerce` | Faillite, isolement | Monopole corrupteur |
| `politics` | Chaos, anarchie | Autoritarisme |

UI danger thresholds (implemented in `ResourceBar.gd`): < 15 = critical low (red blink), 15–25 = orange, 75–85 = orange, > 85 = critical high (red blink).

### Legitimacy (hidden gauge)

`LegitimacySystem` tracks a hidden 0–100 value. No bar shown — the player reads textual signals. Thresholds: suspicious < 30, critical < 15. Falls to 0 → "exposed" death. Design intent: decreases when choices are too "omniscient"; increases by playing the cover role naturally.

### 9 Factions (`data/factions.json`)

| # | Faction | Période active | Ressource liée |
|---|---------|---------------|----------------|
| 1 | Empire Galactique | Ans 1–300 | Politique |
| 2 | Royaumes militaristes (Anacréon…) | Ans 1–150 | Militaire |
| 3 | Marchands | Ans 100–400 | Commerce |
| 4 | Oligarques (Princes Marchands) | Ans 200–400 | Commerce + Politique |
| 5 | Ligue des Mondes Autonomes | Ans 250–350 | Militaire + Religion |
| 6 | Première Fondation *(interne)* | Ans 1–1000 | Tous |
| 7 | Église de la Science | Ans 50–200 | Religion |
| 8 | Kalgan | Ans 350–600 | Militaire |
| 9 | Neotrantor | Ans 300–500 | Politique |

Faction relations stored as `relation_<faction_id>` in Context (-100 to +100, default 0). The Mulet is not a faction — it's a one-time special event (Crisis 3, years 290–320).

### 12 Planets (`data/planets.json`)

Planet states stored as `planet_<id>_state` in Context (-1 hostile / 0 neutral / +1 allied). All are `toKeep`.

| Planète | Faction liée | État initial | Note |
|---------|-------------|-------------|------|
| terminus | Première Fondation | +1 | Perdre = game over |
| trantor | Empire → Seconde Fondation | +1 | Décline ~an 300 |
| anacreon | Royaumes militaristes | -1 | Première grande menace |
| santanni | Royaumes militaristes | -1 | — |
| smyrno | Royaumes militaristes | -1 | — |
| askone | Marchands | 0 | Cible ère Mallow |
| korell | Oligarques | 0 | Antagoniste ère Mallow |
| siwenna | Empire → Neotrantor | 0 | — |
| kalgan | Mulet → Kalgan | 0 | Base du Mulet |
| neotrantor | Neotrantor | 0 | Vestige impérial |
| rossem | Seconde Fondation | 0 | Planète cachée |
| sayshell | Église de la Science | 0 | Late game |

### 6 Seldon Crises

Each crisis is a card sequence (deck `crisis_X`). `seldon_crisis_N` is set to 1 (passed) or -1 (failed) via `loadOutcome` when conditions in a "corridor" are all met. All are `toKeep`.

| # | Crise | Fenêtre |
|---|-------|---------|
| 1 | Anacréon exige la soumission | Ans 50–80 |
| 2 | Général Bel Riose attaque | Ans 200–250 |
| 3 | Le Mulet — l'imprévisible | Ans 290–320 |
| 4 | La chasse à la Seconde Fondation | Ans 350–400 |
| 5 | Les Princes Marchands renversent l'ordre | Ans 400–450 |
| 6 | Convergence finale | Ans 900–1000 |

Final score at year 1000: 6/6 = Second Empire (win), 4–5 = partial win, 3 = neutral, < 3 = failure.

### 8 Moods

Stored as `mood` in Context. Set per card via the `moods` field (`default`, `yes`, `no`). Affects available options and outcome weights (designed, not yet fully implemented):

| Valeur | Mood |
|--------|------|
| neutral | 0 (par défaut) |
| suspicious | 1 |
| afraid | 2 |
| angry | 3 |
| flattered | 4 |
| curious | 5 |
| sad | 6 |
| desperate | 7 |

### Planned Deck Structure (~41 decks, ~1 160 cards)

**Permanents:** `ambient` (80), `new_speaker` (30), `seldon_vault` (20), `terminus_politics` (40), `psychohistory_research` (30), `spy_network` (25)

**Par ère:** `encyclopaedia_project`, `hardin_era`, `merchant_era`, `religious_missions`, `mallow_era`, `mulet_era`, `sack_of_trantor`, `interregnum`, `restoration`, `late_empire`, `second_foundation_hunt`

**Par faction:** `empire_court`, `anacreonian_threat`, `merchant_network`, `trade_routes`, `church_of_science`, `oligarch_conspiracy`, `kalgan_warlord`, `neotrantor_remnant`

**Personnages clés:** `hardin_legacy`, `mallow_legacy`, `ducem_barr`, `bayta_darell`, `ebling_mis`

**Crises majeures:** `crisis_anacreonian_war`, `crisis_bel_riose`, `crisis_mulet_arrival`, `crisis_sf_exposed`, `crisis_merchant_revolt`, `crisis_terminus_siege`, `crisis_commercial_collapse`, `crisis_religious_schism`

**Planètes:** `planet_terminus`, `planet_trantor`, `planet_anacreon`, `planet_kalgan`, `planet_sayshell`

### Crisis System

Two types (Proposition A + C from `PROPOSITIONS_SYSTEMES.md`):
- **Minor (A):** Single card with resource test. Right choice: condition check → different outcomes.
- **Major (C):** 2–3 card sequence via `link`. Used for Seldon Crises and arc quests.

### Quest System

Three levels of persistence:
- **Règne** — one personal quest per Speaker; lost on death
- **Arc** — multi-reign quests via `arc_X_stage` (toKeep)
- **Galactiques** — the 6 Seldon Crises (toKeep)

Deck `new_speaker` bridges reigns: activated at reign start, reads `toKeep` to inject narrative context.

### Progression & Rankings

15 meta-ranks (5 Initié → 5 Speaker → 5 Psychohistorien), persistent across all runs. Score per reign: crisis traversed in corridor (+200), no resource death (+100), reign quest (+150), arc quest advance (+100), natural death → ×1.5 multiplier. Reign duration alone scores nothing.

## Dev Tools

### Capture d'écran UI (`tools/Shot.tscn`)

Rend une scène UI isolée (avec autoloads + données chargées) et sauvegarde un PNG
dans `/tmp/shot_<mode>.png`, pour comparer le rendu Godot au template de référence
(`reference/UI Nouvelle version/`). Nécessite un affichage (`DISPLAY`).

```bash
godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- card      # écran de jeu
godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- death     # écran de mort
godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- codex     # tableau de bord (Personnages)
godot --display-driver x11 --rendering-driver opengl3 res://tools/Shot.tscn -- codexgal  # tableau de bord (Galaxie)
```

### Mode `--deck` (filtrage CLI)

Lance le jeu en ne tirant que les cartes d'un deck spécifique. Ignore `hidden`, `weight`, `conditions` et `lockturn` pour les tests.

```bash
godot --deck hyperjumps
godot --deck ambient
godot --deck hardin_era
godot --deck crisis_anacreonian_war
```

Implementé dans `Globals.gd` (autoload, parse les arguments CLI) et `Main.gd:51` (applique `dev_deck` dans Context) et `NarrativeModel.gd:63` (filtre les cartes éligibles si `dev_deck` est défini). `--deck` bypasses le menu principal (saute directement vers `Main.tscn`).

### Narrative Explorer (`tools/narrative_explorer.py`)

Outil web de visualisation et d'édition des cartes et decks.

```bash
python3 tools/narrative_explorer.py
```

Ouvre `http://localhost:8080` avec une interface à 3 panneaux :
- **Sidebar** — liste des decks avec compteurs et flags (cachées, weight négatif)
- **Liste de cartes** — cartes du deck sélectionné avec flags visibles
- **Éditeur de carte** — modifie tous les champs (ID, label, deck, weight, lockturn, hidden, bearer, question FR/EN, réponses, conditions, outcomes, moods)
- **Graphe narratif** — force-directed graph des liens entre cartes (load/yes/no outcomes avec `variable: "link"`)

Auto-save 500ms après chaque modification + backup automatique de `foundation_cards.json` avant la première sauvegarde. Ctrl+S pour sauvegarde globale.

### Full Variable Namespace

```
custom     = 0    variables nommées génériques
deck       = 1    deck_<name> activation (0 = disabled)
military   = 2    RESSOURCE
religion   = 3    RESSOURCE
commerce   = 4    RESSOURCE
politics   = 5    RESSOURCE
turns      = 6    tours écoulés
year       = 7    année galactique (toKeep)
month      = 8    mois (entier libre, auteurs de cartes)
day        = 9    jour (entier libre, auteurs de cartes)
quest      = 10   ID quête + état
link       = 11   enchaînement forcé (next card ID)
seen       = 12   seen_<card_id>
objective  = 13   objectif
location   = 14   planète actuelle
region     = 15   planet_<id>_state (-1/0/1, toKeep)
party      = 16   membre d'équipage présent
relation   = 17   relation_<faction_id> (-100..100)
mood       = 18   humeur de l'interlocuteur (0–7)
faction    = 19   faction active
age        = 20   âge du Speaker
legitimacy = 21   légitimité cachée (0–100)
```
