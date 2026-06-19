# Suite d'animations Reigns → Godot — Design

Date : 2026-06-19
Statut : validé (brainstorming), prêt pour plan d'implémentation.

## Contexte

Reigns: Three Kingdoms anime son interface **par code (DOTween)**, pas par `AnimationClip`
(269 réfs DOTween dans `reference/raw/il2cpp/il2cpp_dump2/dump.cs` ; voir
`reference/design-docs/card-animation-model.md`). Le swipe narratif de carte a déjà été
porté en Godot (`CardScreen.gd` + `SwipeDetector.gd`, modèle amorti + tilt vélocité).

L'utilisateur veut **porter le reste de la suite d'animations Reigns**, **sauf le minijeu de
combat** (inexistant dans ce jeu). Décisions de cadrage (brainstorming) :

- **Périmètre** : les 8 paquets ci-dessous, par priorité décroissante, un seul spec,
  implémentation incrémentale (un paquet livrable à la fois).
- **Fidélité** : on reproduit la **chorégraphie** Reigns (enchaînements, timings, easings),
  **rendue dans l'identité holographique du projet** (cible visuelle = prototype React
  `reference/ui-prototype/`, pas l'UI de Reigns 3K — cf. `CLAUDE.md`). On construit les
  éléments UI manquants **au style du projet**.
- **Valeurs** : calées au ressenti (les corps de méthodes sont strippés dans le dump ; les
  constantes exactes nécessiteraient AssetRipper — phase ultérieure non bloquante).
- **Architecture** : un helper partagé + une Resource de timings centralisée.

## Architecture

**Autoload `Anim`** (`src/ui/Anim.gd`, même pattern que `Globals`), exposant :

1. **`settings: AnimSettings`** — Resource chargée depuis `data/anim_settings.tres`.
   `AnimSettings` (`src/ui/AnimSettings.gd extends Resource`) regroupe tous les
   timings/easings/couleurs en `@export` par paquet (édition dans l'inspecteur, un seul
   endroit à régler le jour où AssetRipper fournit les vraies valeurs). Groupes : `card`,
   `bars`, `year`, `death`, `map`, `menu`, `options`, `parallax`.

2. **Helpers réutilisables** (lisent `settings`) :
   - `fade_in(node, dur=-1, delay=0.0)` / `fade_out(node, dur=-1)`
   - `count_to(label, from, to, dur, fmt: Callable)` — compteur chiffré (année, stats)
   - `color_flash(node, color, dur=-1)` — flash bref (ValueAct.flashing)
   - `color_to(setter: Callable, from: Color, to: Color, dur)` — transition couleur (ColorTween/AnimateTint)
   - `pulse(node, ...)` — boucle de pulsation
   - `reveal_list(nodes: Array, stagger, item_dur)` — révélation en cascade (listes)
   - `smooth(cur, target, speed, dt)` — exp-smoothing framerate-indépendant (rapatrié de CardScreen)
   - `punch_scale(node, amount, dur)` / `shake(node, amount, dur)`

   Chaque helper retourne le `Tween` créé (pour chaînage/await), et tue proprement tout tween
   antérieur passé en référence si l'appelant le fournit.

**Intégration** : les écrans appellent `Anim.fade_in(...)` etc. Les constantes d'animation
déjà présentes dans `CardScreen.gd` (swipe) **migrent dans `AnimSettings.card`** ; le `_smooth`
local de `CardScreen` est remplacé par `Anim.smooth`. On **enrichit** le code existant, on ne
le réécrit pas.

## Chorégraphie des 8 paquets (ordre d'implémentation)

### Paquet 0 — Socle
`Anim` autoload + `AnimSettings` + `data/anim_settings.tres` ; migration des constantes du
swipe et de `_smooth` depuis `CardScreen.gd`. Aucun changement visuel attendu (non-régression
du swipe).

### Paquet 1 — Carte (`CardScreen.gd`, `CardAnimator`)
- **Entrée/sortie verticale** (`AnimateVertically`) : la carte monte depuis `settings.card.offscreen_height`
  à l'apparition, redescend à la sortie ; enrichit l'actuel fondu+scale d'entrée.
- **Wobble de défaite** (`TriggerDefeat`) : à la mort, tremble puis chute (translation
  `defeat_move_range` + rotation `defeat_rotation_range` après `defeat_anim_delay`) avant la
  transition vers l'écran de mort.
- **Flip recto-verso** (`DoCardFlip`/`FlipRoutine`) : fake 2D (scale X → 0 pour la tranche,
  bascule du contenu à mi-course, scale X → 1). **Déclencheur** : champ carte opt-in
  `flip_intro` (bool, défaut false) ; **par défaut activé pour les cartes du deck
  `seldon_vault`** (messages = révélations). Ajustable par les auteurs de cartes.

### Paquet 2 — Barres de ressources (`ResourceBar.gd`, `ValueAct.flashing`)
- **Flash couleur au changement** : `update_value` déclenche `Anim.color_flash` (couleur =
  sens : vert holo si hausse, rouge si baisse). Le tween de valeur (compteur) et les pulses
  critique/affecté existants sont conservés.

### Paquet 3 — Année qui défile (`CardScreen.gd`, `TweenYearRoutine`)
- Quand `year` change, le label `An X` défile via `Anim.count_to` jusqu'à la nouvelle valeur
  (format `"An %d · %d ans"`). Branché dans `_update_info`.

### Paquet 4 — Écran de mort (`DeathScreen.gd`, `AnimateYouDiedTextIn`/`AnimateObjectivesListIn`)
- **Révélation séquencée** : fondu du fond (existant) → cause de mort + titre « Orateur — X »
  entrent (fade+slide) → grille de stats / objectifs en **cascade** (`Anim.reveal_list`) →
  compteurs animés (existant, via `Anim.count_to`) → message Seldon en fondu. La structure UI
  existe déjà ; on orchestre la séquence au style holographique.

### Paquet 5 — Carte galactique (`GalaxyMap.gd`, `AnimateTint`)
- `update()` ne claque plus la couleur : `_style_planet` **transite** via `Anim.color_to`
  (neutre↔allié↔hostile). Optionnel : léger `Anim.pulse` sur planètes alliées/hostiles.

### Paquet 6 — Menu principal (`MainMenu.gd`, `SplashAnimation`)
- `_menu_enter` remplacé par une **révélation en cascade** (`Anim.reveal_list`) : titre puis
  boutons un par un (fade+slide), au lieu du fondu global actuel.

### Paquet 7 — Dérive de grille holo (`CardScreen.gd`/shader de fond, `AnimateParallax`)
- Réinterprétation de la parallaxe : la **grille holographique du fond dérive** lentement
  (et/ou se décale légèrement au swipe via le drag courant). Pas de décor scrollable (le jeu
  n'en a pas). Plus faible priorité, isolé en dernier.

### Paquet 8 — Écran Options (`OptionsScreen.gd`, `SettingsMenuAnimator`/`SettingsSelectView`)
- **Entrée/sortie d'écran** (`AnimateIn`/`AnimateOut`) : l'overlay Options entre/sort en
  fondu+slide au lieu d'apparaître sec.
- **Icônes d'onglets en cascade** (`AnimateTabIconsIn`) : si l'écran a des onglets/sélecteurs
  (ex: sélecteur de difficulté), leurs éléments se révèlent en cascade (`Anim.reveal_list`).
- Dernière priorité ; réutilise intégralement le socle `Anim`.

## Découpage / isolation

- `Anim` + `AnimSettings` : unité autonome, testable (helpers purs + tweens).
- Chaque paquet ne touche qu'un écran (sauf paquet 0 qui pose le socle), via l'interface
  `Anim.*` — pas de couplage entre écrans.
- `AnimSettings` est la seule source des constantes : changer le ressenti = éditer le `.tres`.

## Tests & vérification

- **GUT** : logique pure de `Anim` — `smooth()` (convergence, indépendance au framerate),
  `count_to` (formatage via un Label factice + await), `color_to`/`color_flash`
  (interpolation de couleur), `reveal_list` (ordre/stagger). Pas de test du rendu visuel.
- **Non-régression** : les 163 tests GUT existants passent ; swipe et écrans existants OK
  (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit`).
- **Playtest fenêtré** par paquet (`godot`) avec checklist de ressenti : entrée/wobble/flip de
  carte lisibles, flash des barres au bon sens, année qui défile, mort en cascade, teintes de
  planètes qui transitent, splash menu en cascade, dérive de grille.

## Hors périmètre (YAGNI)

- Minijeu de combat et ses animations (`BattleCard*`, shields, `DiscCard.attackSequence`,
  `PrebattleUIAnimator`, `BattleTransitionView`) — le jeu n'a pas de combat.
- Extraction AssetRipper des valeurs exactes — phase ultérieure, n'empêche pas la livraison.
