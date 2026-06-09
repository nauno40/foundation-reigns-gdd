# Phase 5 — Polish & Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Calibrer les seuils de gameplay, vérifier l'équilibre sur 3 cycles complets, ajouter musique et SFX, et préparer le build final.

**Architecture:** Aucun nouveau module — on ajuste des constantes dans les fichiers existants et on ajoute les assets audio. Le calibrage se base sur des sessions de jeu documentées.

**Tech Stack:** Godot 4.x, GDScript 4, Audacity (SFX), assets audio libre de droits

**Prerequisite:** Phase 4 complete — ≥ 100 cartes, crise Anacréon jouable, quêtes fonctionnelles.

---

## Task 1 : Tests du cycle complet — 3 règnes

Jouer 3 règnes de bout en bout et documenter les problèmes.

- [ ] **Step 1 : Jouer règne 1 — mourir d'une ressource à 0**

  Lancer le jeu depuis le début. Prendre volontairement de mauvaises décisions pour faire descendre `military` à 0.

  Vérifier :
  - [ ] La barre `military` devient rouge clignotante avant 15
  - [ ] Le game over se déclenche à 0
  - [ ] L'écran de mort s'affiche avec les bonnes informations
  - [ ] `seldon_crisis_1 = 0` (pas encore atteinte)
  - [ ] Légitimité de départ du règne 2 = 80

- [ ] **Step 2 : Jouer règne 2 — mourir d'une ressource à 100**

  Favoriser systématiquement la religion → la faire monter à 100.

  Vérifier :
  - [ ] La barre `religion` devient rouge clignotante après 85
  - [ ] Game over à 100
  - [ ] L'écran de mort mentionne "Religion reached 100"
  - [ ] Légitimité de départ du règne 3 = 80
  - [ ] `year` a bien avancé (> 1) et est conservé entre règnes

- [ ] **Step 3 : Jouer règne 3 — traverser la Crise de Seldon 1**

  Jouer correctement pour maintenir `religion > 30` et `military < 60`. Vérifier que la séquence de crise Anacréon se déclenche entre l'an 50 et 80.

  Vérifier :
  - [ ] Carte 8001 apparaît dans la bonne fenêtre d'années
  - [ ] La séquence de 4-6 cartes s'enchaîne via `link`
  - [ ] `seldon_crisis_1 = 1` après la carte 8011
  - [ ] L'écran de mort (si mort) affiche "Crise de Seldon 1 — traversée ✓"
  - [ ] Le message de Seldon correspond au résultat

- [ ] **Step 4 : Documenter les problèmes trouvés**

  Créer `docs/playtesting_notes.md` avec les observations :
  ```markdown
  # Notes de Playtest — Phase 5

  ## Règne 1
  - [OK/KO] ...

  ## Règne 2
  - [OK/KO] ...

  ## Règne 3
  - [OK/KO] ...

  ## Problèmes à corriger
  - [ ] ...
  ```

- [ ] **Step 5 : Corriger les bugs critiques trouvés**

  Pour chaque bug noté, corriger dans le fichier approprié et committer séparément :
  ```bash
  git add <fichier_corrige>
  git commit -m "fix: <description du bug>"
  ```

---

## Task 2 : Calibrage des seuils de danger

Ajuster les seuils dans `ResourceBars.gd` et `Context.gd` si le ressenti n'est pas bon.

- [ ] **Step 1 : Évaluer le ressenti des seuils actuels**

  Seuils actuels dans `ResourceBars.gd` :
  ```
  THRESHOLD_CRITICAL_LOW  = 15   → rouge clignotant
  THRESHOLD_WARNING_LOW   = 25   → orange
  THRESHOLD_WARNING_HIGH  = 75   → orange
  THRESHOLD_CRITICAL_HIGH = 85   → rouge clignotant
  ```

  Questions de calibrage :
  - Le joueur voit-il venir le game over à temps ?
  - Les barres orange sont-elles assez visibles ?
  - Le clignotement est-il trop agressif ou pas assez visible ?

- [ ] **Step 2 : Ajuster si nécessaire**

  Si le joueur meurt "par surprise" (game over trop rapide), augmenter `THRESHOLD_WARNING_LOW` à 30 :

  Dans `ResourceBars.gd` :
  ```gdscript
  const THRESHOLD_CRITICAL_LOW  = 15  # rouge clignotant
  const THRESHOLD_WARNING_LOW   = 30  # orange — augmenté de 25 à 30
  const THRESHOLD_WARNING_HIGH  = 70  # orange — réduit de 75 à 70
  const THRESHOLD_CRITICAL_HIGH = 85  # rouge clignotant
  ```

- [ ] **Step 3 : Calibrer la mort naturelle**

  Seuils actuels dans `Main.gd` `_should_die_naturally()` :
  ```gdscript
  if    age >= 83: prob = 1.0
  elif  age >= 81: prob = 0.60
  elif  age >= 79: prob = 0.35
  elif  age >= 77: prob = 0.15
  elif  age >= 75: prob = 0.05
  ```

  Un règne dure ~50-80 ans de jeu (age 35-40 au début). Vérifier que la mort naturelle arrive bien entre 75 et 83 dans la majorité des parties. Si les morts naturelles sont trop rares, augmenter la probabilité à 75 ans.

  Si le joueur ne survit jamais jusqu'à 75 (mort par ressource avant), c'est normal — pas de changement.

- [ ] **Step 4 : Committer les ajustements**

  ```bash
  git add src/ui/ResourceBars.gd src/main/Main.gd
  git commit -m "calibrate: adjust danger thresholds based on playtesting"
  ```

---

## Task 3 : Calibrage des couloirs de Seldon

- [ ] **Step 1 : Tester le couloir de la Crise 1 sur 5 tentatives**

  Jouer 5 fois en visant spécifiquement la Crise 1. Compter combien de fois le couloir est réussi.

  Cible : 2-3 succès sur 5 pour un joueur qui essaie activement.

- [ ] **Step 2 : Ajuster si trop facile ou trop difficile**

  **Trop facile** (>4/5 succès) — durcir le couloir dans `Main.gd` :
  ```gdscript
  # Crise 1 — version durcie
  1:
      return (
          _ctx.get_var("religion", 50) > 40 and  # augmenté de 30 à 40
          _ctx.get_var("military", 50) < 50 and  # réduit de 60 à 50
          _ctx.get_var("relation_military_kingdoms", 0) > -20  # durci
      )
  ```

  **Trop difficile** (<1/5 succès) — assouplir :
  ```gdscript
  1:
      return (
          _ctx.get_var("religion", 50) > 20 and  # réduit de 30 à 20
          _ctx.get_var("military", 50) < 70       # augmenté de 60 à 70
      )
  ```

- [ ] **Step 3 : Vérifier que `seldon_crises.json` reflète les changements**

  Mettre à jour les valeurs dans `data/seldon_crises.json` pour correspondre au code.

- [ ] **Step 4 : Committer**

  ```bash
  git add src/main/Main.gd data/seldon_crises.json
  git commit -m "calibrate: adjust Seldon crisis 1 corridor based on playtesting"
  ```

---

## Task 4 : Calibrage des scores et rangs

- [ ] **Step 1 : Jouer 3 règnes complets et calculer les scores obtenus**

  Scores actuels (GDD Section 16) :
  ```
  Crise Seldon traversée  : +200
  Règne sans game over    : +100
  Quête de règne complétée: +150
  Quête d'arc avancée     : +100
  Légitimité maintenue    : +50
  Nouvelle carte vue      : +10
  Mort naturelle          : ×1.5
  ```

  Calculer manuellement le score d'un règne typique.

- [ ] **Step 2 : Vérifier la courbe de progression**

  Objectif : atteindre le rang 5 (3 000 points) en 3-5 règnes.
  
  Si un règne typique donne ~400-600 points, alors 3-5 règnes = 1 200-3 000 pts → rang 5. ✓
  
  Sinon, ajuster les valeurs dans `Main.gd` :
  ```gdscript
  # Dans _calculate_reign_score() — à créer dans Main.gd
  const SCORE_CRISIS_PASSED    = 200
  const SCORE_NO_GAME_OVER     = 100
  const SCORE_QUEST_COMPLETED  = 150
  const SCORE_NEW_CARD_SEEN    = 10
  const MULTIPLIER_NATURAL_DEATH = 1.5
  ```

- [ ] **Step 3 : Implémenter le calcul de score dans Main.gd**

  Ajouter `_calculate_reign_score()` à `Main.gd` :
  ```gdscript
  func _calculate_reign_score(death_type: String) -> int:
      var score = 0

      # Crises de Seldon traversées ce règne
      for i in range(1, 7):
          if _ctx.get_var("seldon_crisis_%d_this_reign" % i, 0) == 1:
              score += SCORE_CRISIS_PASSED

      # Règne sans game over resource
      if death_type == "natural" or death_type == "exposed":
          score += SCORE_NO_GAME_OVER

      # Quêtes de règne complétées
      if _ctx.get_var("quest_reign_1_completed", 0) == 1:
          score += SCORE_QUEST_COMPLETED

      # Cartes vues ce règne
      var cards_seen = _ctx.get_var("cards_seen_this_reign", 0)
      score += cards_seen * SCORE_NEW_CARD_SEEN

      # Multiplicateur mort naturelle
      if death_type == "natural":
          score = int(score * MULTIPLIER_NATURAL_DEATH)

      return score
  ```

- [ ] **Step 4 : Committer**

  ```bash
  git add src/main/Main.gd
  git commit -m "feat(progression): implement reign score calculation"
  ```

---

## Task 5 : Musique et SFX

- [ ] **Step 1 : Préparer les assets audio (libres de droits)**

  Sources recommandées :
  - **Freesound.org** — SFX gratuits
  - **OpenGameArt.org** — musiques de jeu libres
  - **Pixabay Music** — musiques libres commerciales

  Fichiers à obtenir :
  ```
  assets/audio/
  ├── music/
  │   ├── hardin_era.ogg        ← musique ambiante ère Hardin (tons impériaux)
  │   ├── merchant_era.ogg      ← musique commerciale, animée
  │   ├── mulet_era.ogg         ← musique inquiétante, dissonante
  │   └── death_screen.ogg      ← musique triste pour l'écran de mort
  └── sfx/
      ├── swipe_left.wav        ← son discret lors du swipe gauche
      ├── swipe_right.wav       ← son discret lors du swipe droite
      ├── game_over.wav         ← son grave pour le game over
      └── seldon_appear.wav     ← son holographique pour Seldon
  ```

  Critères de sélection :
  - Musiques : ~2-3 minutes, en boucle propre, cohérentes avec SF des années 1950
  - SFX : courts (<1s), discrets, pas agressifs

- [ ] **Step 2 : Créer le gestionnaire audio dans Main.gd**

  Ajouter à `Main.gd` :
  ```gdscript
  @onready var _music_player = $MusicPlayer  # AudioStreamPlayer
  @onready var _sfx_player   = $SFXPlayer    # AudioStreamPlayer

  const MUSIC_BY_ERA = {
      "hardin":      preload("res://assets/audio/music/hardin_era.ogg"),
      "merchants":   preload("res://assets/audio/music/merchant_era.ogg"),
      "mallow":      preload("res://assets/audio/music/merchant_era.ogg"),
      "mulet":       preload("res://assets/audio/music/mulet_era.ogg"),
      "restoration": preload("res://assets/audio/music/hardin_era.ogg"),
      "late_empire": preload("res://assets/audio/music/hardin_era.ogg"),
  }

  func _play_era_music() -> void:
      var year = _ctx.get_var("year", 1)
      var era = _respawn._get_era_name(year)
      if MUSIC_BY_ERA.has(era):
          var stream = MUSIC_BY_ERA[era]
          if _music_player.stream != stream:
              _music_player.stream = stream
              _music_player.play()

  func _play_sfx(name: String) -> void:
      var path = "res://assets/audio/sfx/%s.wav" % name
      if ResourceLoader.exists(path):
          _sfx_player.stream = load(path)
          _sfx_player.play()
  ```

  Ajouter à `RespawnSystem.gd` une méthode `_get_era_name(year)` :
  ```gdscript
  func _get_era_name(year: int) -> String:
      for era in ERA_STARTS:
          if year >= era["start"]:
              continue
          break
      # Return last matched era
      for i in range(ERA_STARTS.size() - 1, -1, -1):
          if year >= ERA_STARTS[i]["start"]:
              return ERA_STARTS[i]["era"]
      return "hardin"
  ```

- [ ] **Step 3 : Intégrer les SFX dans SwipeDetector.gd et CardScreen.gd**

  Dans `CardScreen.gd`, ajouter le signal et appel :
  ```gdscript
  signal play_sfx(sfx_name: String)

  func _on_swipe_left() -> void:
      if not _can_swipe:
          return
      play_sfx.emit("swipe_left")
      # ... reste du code
  ```

  Dans `Main.gd`, connecter :
  ```gdscript
  _card_screen.play_sfx.connect(_play_sfx)
  ```

- [ ] **Step 4 : Ajouter AudioStreamPlayer à la scène Main.tscn**

  Dans l'éditeur Godot, ajouter à `Main.tscn` :
  - `MusicPlayer` (AudioStreamPlayer, `autoplay: false`, `volume_db: -10`)
  - `SFXPlayer` (AudioStreamPlayer, `autoplay: false`, `volume_db: -5`)

- [ ] **Step 5 : Committer**

  ```bash
  git add assets/audio/ src/main/Main.gd src/ui/CardScreen.gd src/core/RespawnSystem.gd scenes/Main.tscn
  git commit -m "feat(audio): add era music and swipe SFX"
  ```

---

## Task 6 : Tests d'intégration finaux

- [ ] **Step 1 : Test cycle complet × 3 règnes (version finale)**

  Jouer 3 règnes complets sans interruption. Checklist :

  **Règne 1 :**
  - [ ] Deck `new_speaker` s'active au démarrage
  - [ ] Cartes `ambient` et `hardin_era` apparaissent selon les conditions
  - [ ] `lockturn` empêche les répétitions immédiates
  - [ ] La musique joue selon l'ère
  - [ ] Les SFX se déclenchent au swipe
  - [ ] Mort par ressource → Death Screen correct → Nouveau règne

  **Règne 2 :**
  - [ ] `year` continue depuis la fin du règne 1 (toKeep)
  - [ ] Légitimité de départ = 80 (mort resource règne 1)
  - [ ] Nouveau Speaker avec nouvelle couverture
  - [ ] Deck `new_speaker` lit l'héritage du règne précédent
  - [ ] La Crise 1 se déclenche si on est dans l'ère Hardin (year 50-80)

  **Règne 3 :**
  - [ ] Les jalons des règnes 1 et 2 sont visibles dans `new_speaker`
  - [ ] L'écran de mort affiche les 3 règnes cumulés correctement
  - [ ] Le score total est calculé et affiché

- [ ] **Step 2 : Corriger les bugs restants**

  ```bash
  git add <fichiers>
  git commit -m "fix: <description>"
  ```

- [ ] **Step 3 : Test sur mobile (si disponible)**

  Exporter en APK Android (ou utiliser l'émulateur Android dans Godot) :
  - `Project → Export → Android`
  - Vérifier que le swipe tactile fonctionne
  - Vérifier que les barres de ressources s'affichent correctement sur petit écran
  - Vérifier les performances (pas de lag au chargement des JSON)

- [ ] **Step 4 : Commit final de la phase**

  ```bash
  git add .
  git commit -m "chore: Phase 5 polish complete — prototype playable"
  git tag v0.1.0-prototype
  ```

---

## Livrable Phase 5 — Prototype Jouable

À la fin de cette phase, le jeu est un **prototype jouable de bout en bout** :

```
✓ Données : 8 fichiers JSON validés, 100+ cartes
✓ Moteur  : 7 modules GDScript, 62+ tests passants
✓ UI      : Swipe, barres, écran de mort, carte galactique
✓ Contenu : Crise 1 Anacréon, 3 quêtes de règne, 6 couloirs Seldon
✓ Audio   : Musique par ère, SFX swipe/game over
✓ Cycles  : 3 règnes testés et calibrés

Tag git : v0.1.0-prototype
```

Prêt pour une première session de playtest externe.
