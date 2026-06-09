# Phase 2 — Godot Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all 7 GDScript core modules that power the Foundation game loop — data loading, game state, card selection, legitimacy tracking, death/respawn, and save system.

**Architecture:** Pure GDScript 4 classes, no scene dependencies. Each class is a standalone resource testable with GUT (Godot Unit Testing framework). The game loop runs in `Main.gd` by composing these modules.

**Tech Stack:** Godot 4.x, GDScript 4, GUT addon (unit testing)

**Prerequisite:** Phase 1 complete — all JSON files exist and validate.

---

## File Structure

```
~/foundation-reigns/
├── src/
│   ├── core/
│   │   ├── FoundationGameData.gd    ← charge et indexe tous les JSON
│   │   ├── Context.gd               ← état runtime + toKeep
│   │   ├── ConditionEvaluator.gd    ← évalue les conditions de carte
│   │   ├── NarrativeModel.gd        ← sélection de carte, weight, link
│   │   ├── LegitimacySystem.gd      ← jauge cachée + signaux
│   │   ├── RespawnSystem.gd         ← mort + reset + calcul ère
│   │   └── SaveSystem.gd            ← JSON save/load
│   └── main/
│       └── Main.gd                  ← boucle principale (Phase 3)
├── tests/
│   ├── gut_runner.gd                ← runner GUT
│   ├── test_condition_evaluator.gd
│   ├── test_context.gd
│   ├── test_narrative_model.gd
│   ├── test_legitimacy_system.gd
│   └── test_respawn_system.gd
└── addons/
    └── gut/                         ← addon GUT installé
```

---

## Task 1 : Installer GUT (Godot Unit Testing)

**Files:**
- Create: `~/foundation-reigns/addons/gut/` (via Asset Library)

- [ ] **Step 1 : Installer GUT via l'Asset Library Godot**

  Dans l'éditeur Godot :
  - Menu `AssetLib` (onglet en haut)
  - Chercher `GUT`
  - Installer `GUT - Godot Unit Testing`
  - Cliquer `Install`

  **Alternative (sans éditeur) :**
  ```bash
  cd ~/foundation-reigns
  # Télécharger GUT depuis GitHub
  curl -L https://github.com/bitwes/Gut/releases/latest/download/gut_v9.x.x.zip -o /tmp/gut.zip
  unzip /tmp/gut.zip -d addons/
  ```

- [ ] **Step 2 : Activer le plugin**

  Dans Godot : `Project → Project Settings → Plugins → GUT → Enable`

- [ ] **Step 3 : Créer le runner de test**

  Créer `tests/gut_runner.gd` :
  ```gdscript
  extends GutRunner

  func _init():
      gut.options.dirs = ["res://tests/"]
      gut.options.prefix = "test_"
      gut.options.suffix = ".gd"
  ```

- [ ] **Step 4 : Vérifier que GUT fonctionne**

  Créer `tests/test_sanity.gd` :
  ```gdscript
  extends GutTest

  func test_sanity():
      assert_true(true, "GUT is working")
  ```

  Lancer via terminal :
  ```bash
  cd ~/foundation-reigns
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd
  ```
  Attendu : `1 passed, 0 failed`

- [ ] **Step 5 : Committer**

  ```bash
  git add addons/ tests/
  git commit -m "chore: install GUT testing framework"
  ```

---

## Task 2 : ConditionEvaluator

**Files:**
- Create: `~/foundation-reigns/src/core/ConditionEvaluator.gd`
- Create: `~/foundation-reigns/tests/test_condition_evaluator.gd`

- [ ] **Step 1 : Écrire le test en premier**

  Créer `tests/test_condition_evaluator.gd` :
  ```gdscript
  extends GutTest

  var ce: ConditionEvaluator

  func before_each():
      ce = ConditionEvaluator.new()

  func test_equal_true():
      var ctx = {"year": 50}
      var cond = {"variable": "year", "op": "equal", "value": 50}
      assert_true(ce.evaluate(cond, ctx))

  func test_equal_false():
      var ctx = {"year": 49}
      var cond = {"variable": "year", "op": "equal", "value": 50}
      assert_false(ce.evaluate(cond, ctx))

  func test_above_true():
      var ctx = {"year": 51}
      var cond = {"variable": "year", "op": "above", "value": 50}
      assert_true(ce.evaluate(cond, ctx))

  func test_above_false():
      var ctx = {"year": 50}
      var cond = {"variable": "year", "op": "above", "value": 50}
      assert_false(ce.evaluate(cond, ctx))

  func test_below_true():
      var ctx = {"military": 20}
      var cond = {"variable": "military", "op": "below", "value": 30}
      assert_true(ce.evaluate(cond, ctx))

  func test_not_true():
      var ctx = {"mood": "angry"}
      var cond = {"variable": "mood", "op": "not", "value": "neutral"}
      assert_true(ce.evaluate(cond, ctx))

  func test_not_false():
      var ctx = {"mood": "neutral"}
      var cond = {"variable": "mood", "op": "not", "value": "neutral"}
      assert_false(ce.evaluate(cond, ctx))

  func test_missing_variable_defaults_zero():
      var ctx = {}
      var cond = {"variable": "military", "op": "above", "value": 0}
      # 0 is not above 0
      assert_false(ce.evaluate(cond, ctx))

  func test_evaluate_all_and_logic():
      var ctx = {"year": 60, "military": 30}
      var conditions = [
          {"variable": "year", "op": "above", "value": 50},
          {"variable": "military", "op": "below", "value": 50}
      ]
      assert_true(ce.evaluate_all(conditions, ctx))

  func test_evaluate_all_fails_on_one():
      var ctx = {"year": 40, "military": 30}
      var conditions = [
          {"variable": "year", "op": "above", "value": 50},
          {"variable": "military", "op": "below", "value": 50}
      ]
      assert_false(ce.evaluate_all(conditions, ctx))

  func test_evaluate_all_empty_is_true():
      assert_true(ce.evaluate_all([], {}))
  ```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_condition_evaluator
  ```
  Attendu : erreur `ConditionEvaluator not found`

- [ ] **Step 3 : Implémenter ConditionEvaluator**

  Créer `src/core/ConditionEvaluator.gd` :
  ```gdscript
  class_name ConditionEvaluator

  func evaluate(condition: Dictionary, context: Dictionary) -> bool:
      var variable: String = condition.get("variable", "")
      var op: String = condition.get("op", "equal")
      var expected = condition.get("value", 0)
      var current = context.get(variable, 0)

      match op:
          "equal":  return current == expected
          "above":  return current > expected
          "below":  return current < expected
          "not":    return current != expected
          _:
              push_warning("ConditionEvaluator: unknown op '%s'" % op)
              return false

  func evaluate_all(conditions: Array, context: Dictionary) -> bool:
      for condition in conditions:
          if not evaluate(condition, context):
              return false
      return true
  ```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_condition_evaluator
  ```
  Attendu : `11 passed, 0 failed`

- [ ] **Step 5 : Committer**

  ```bash
  git add src/core/ConditionEvaluator.gd tests/test_condition_evaluator.gd
  git commit -m "feat(core): implement ConditionEvaluator with tests"
  ```

---

## Task 3 : Context

**Files:**
- Create: `~/foundation-reigns/src/core/Context.gd`
- Create: `~/foundation-reigns/tests/test_context.gd`

- [ ] **Step 1 : Écrire le test**

  Créer `tests/test_context.gd` :
  ```gdscript
  extends GutTest

  var ctx: Context

  func before_each():
      ctx = Context.new()

  func test_get_missing_returns_default():
      assert_eq(ctx.get_var("military"), 0)

  func test_set_and_get():
      ctx.set_var("military", 50)
      assert_eq(ctx.get_var("military"), 50)

  func test_add_var():
      ctx.set_var("military", 40)
      ctx.add_var("military", 10)
      assert_eq(ctx.get_var("military"), 50)

  func test_add_var_negative():
      ctx.set_var("military", 40)
      ctx.add_var("military", -15)
      assert_eq(ctx.get_var("military"), 25)

  func test_tokeep_persists_after_empty():
      ctx.set_var("year", 120, true)
      ctx.set_var("military", 60, false)
      ctx.empty_non_keep()
      assert_eq(ctx.get_var("year"), 120)
      assert_eq(ctx.get_var("military"), 0)

  func test_non_tokeep_cleared():
      ctx.set_var("military", 60, false)
      ctx.empty_non_keep()
      assert_eq(ctx.get_var("military"), 0)

  func test_set_overwrite():
      ctx.set_var("politics", 30)
      ctx.set_var("politics", 55)
      assert_eq(ctx.get_var("politics"), 55)

  func test_default_resources_at_50():
      ctx.initialize_new_reign()
      assert_eq(ctx.get_var("military"),  50)
      assert_eq(ctx.get_var("religion"),  50)
      assert_eq(ctx.get_var("commerce"),  50)
      assert_eq(ctx.get_var("politics"),  50)
      assert_eq(ctx.get_var("legitimacy"), 100)

  func test_initialize_keeps_tokeep():
      ctx.set_var("year", 80, true)
      ctx.initialize_new_reign()
      assert_eq(ctx.get_var("year"), 80)

  func test_is_game_over_at_zero():
      ctx.set_var("military", 0)
      assert_true(ctx.is_game_over())

  func test_is_game_over_at_hundred():
      ctx.set_var("religion", 100)
      assert_true(ctx.is_game_over())

  func test_no_game_over_normal():
      ctx.initialize_new_reign()
      assert_false(ctx.is_game_over())
  ```

- [ ] **Step 2 : Lancer le test — vérifier l'échec**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_context
  ```
  Attendu : erreur `Context not found`

- [ ] **Step 3 : Implémenter Context**

  Créer `src/core/Context.gd` :
  ```gdscript
  class_name Context

  const RESOURCES = ["military", "religion", "commerce", "politics"]
  const RESOURCE_DEFAULT = 50
  const LEGITIMACY_DEFAULT = 100

  var _vars: Dictionary = {}
  var _keep_flags: Dictionary = {}

  func get_var(key: String, default = 0) -> Variant:
      return _vars.get(key, default)

  func set_var(key: String, value: Variant, to_keep: bool = false) -> void:
      _vars[key] = value
      if to_keep:
          _keep_flags[key] = true

  func add_var(key: String, delta: int) -> void:
      _vars[key] = _vars.get(key, 0) + delta

  func empty_non_keep() -> void:
      var kept: Dictionary = {}
      for key in _keep_flags:
          if _vars.has(key):
              kept[key] = _vars[key]
      _vars = kept

  func initialize_new_reign(legitimacy_start: int = LEGITIMACY_DEFAULT) -> void:
      empty_non_keep()
      for resource in RESOURCES:
          _vars[resource] = RESOURCE_DEFAULT
      _vars["legitimacy"] = legitimacy_start
      _vars["turns"] = 0
      _vars["mood"] = "neutral"

  func is_game_over() -> bool:
      for resource in RESOURCES:
          var val = _vars.get(resource, RESOURCE_DEFAULT)
          if val <= 0 or val >= 100:
              return true
      if _vars.get("legitimacy", LEGITIMACY_DEFAULT) <= 0:
          return true
      return false

  func get_game_over_reason() -> String:
      for resource in RESOURCES:
          var val = _vars.get(resource, RESOURCE_DEFAULT)
          if val <= 0:
              return "%s reached 0" % resource
          if val >= 100:
              return "%s reached 100" % resource
      if _vars.get("legitimacy", LEGITIMACY_DEFAULT) <= 0:
          return "legitimacy reached 0"
      return ""
  ```

- [ ] **Step 4 : Lancer les tests — vérifier qu'ils passent**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_context
  ```
  Attendu : `12 passed, 0 failed`

- [ ] **Step 5 : Committer**

  ```bash
  git add src/core/Context.gd tests/test_context.gd
  git commit -m "feat(core): implement Context with toKeep and game over detection"
  ```

---

## Task 4 : FoundationGameData

**Files:**
- Create: `~/foundation-reigns/src/core/FoundationGameData.gd`

- [ ] **Step 1 : Implémenter FoundationGameData**

  Créer `src/core/FoundationGameData.gd` :
  ```gdscript
  class_name FoundationGameData

  var cards: Array = []
  var cards_by_deck: Dictionary = {}
  var factions: Array = []
  var planets: Array = []
  var given_names: Array = []
  var family_names: Array = []
  var characters: Dictionary = {}
  var covers: Dictionary = {}
  var moods: Dictionary = {}

  var is_loaded: bool = false

  func load_all() -> bool:
      var ok = true
      ok = ok and _load_array("res://data/foundation_cards.json", cards)
      ok = ok and _load_array("res://data/factions.json", factions)
      ok = ok and _load_array("res://data/planets.json", planets)
      ok = ok and _load_array("res://data/given_names.json", given_names)
      ok = ok and _load_array("res://data/family_names.json", family_names)
      ok = ok and _load_dict("res://data/characters.json", characters)
      ok = ok and _load_dict("res://data/covers.json", covers)
      ok = ok and _load_dict("res://data/moods.json", moods)
      if ok:
          _index_by_deck()
          is_loaded = true
      return ok

  func _load_array(path: String, target: Array) -> bool:
      var text = _read_file(path)
      if text == "":
          return false
      var result = JSON.parse_string(text)
      if not result is Array:
          push_error("FoundationGameData: expected Array in %s" % path)
          return false
      target.assign(result)
      return true

  func _load_dict(path: String, target: Dictionary) -> bool:
      var text = _read_file(path)
      if text == "":
          return false
      var result = JSON.parse_string(text)
      if not result is Dictionary:
          push_error("FoundationGameData: expected Dictionary in %s" % path)
          return false
      target.merge(result)
      return true

  func _read_file(path: String) -> String:
      var file = FileAccess.open(path, FileAccess.READ)
      if not file:
          push_error("FoundationGameData: cannot open %s" % path)
          return ""
      return file.get_as_text()

  func _index_by_deck() -> void:
      cards_by_deck.clear()
      for card in cards:
          var deck: String = card.get("deck", "")
          if not cards_by_deck.has(deck):
              cards_by_deck[deck] = []
          cards_by_deck[deck].append(card)

  func get_card_by_id(id: int) -> Dictionary:
      for card in cards:
          if card.get("id", -1) == id:
              return card
      return {}

  func get_faction_by_id(id: String) -> Dictionary:
      for faction in factions:
          if faction.get("id", "") == id:
              return faction
      return {}

  func get_planet_by_id(id: String) -> Dictionary:
      for planet in planets:
          if planet.get("id", "") == id:
              return planet
      return {}

  func get_random_name() -> String:
      if given_names.is_empty() or family_names.is_empty():
          return "Inconnu"
      var given = given_names[randi() % given_names.size()]
      var family = family_names[randi() % family_names.size()]
      return "%s %s" % [given, family]
  ```

- [ ] **Step 2 : Vérifier manuellement que le chargement fonctionne**

  Créer un script de test rapide `tests/test_game_data_load.gd` :
  ```gdscript
  extends GutTest

  var data: FoundationGameData

  func before_each():
      data = FoundationGameData.new()

  func test_load_all_succeeds():
      var ok = data.load_all()
      assert_true(ok, "load_all should return true")
      assert_true(data.is_loaded)

  func test_cards_loaded():
      data.load_all()
      assert_gte(data.cards.size(), 20)

  func test_factions_loaded():
      data.load_all()
      assert_eq(data.factions.size(), 9)

  func test_planets_loaded():
      data.load_all()
      assert_eq(data.planets.size(), 12)

  func test_decks_indexed():
      data.load_all()
      assert_true(data.cards_by_deck.has("ambient"))
      assert_true(data.cards_by_deck.has("hardin_era"))

  func test_get_card_by_id():
      data.load_all()
      var card = data.get_card_by_id(1001)
      assert_eq(card.get("label", ""), "rumeur_terminus")

  func test_random_name_not_empty():
      data.load_all()
      var name = data.get_random_name()
      assert_ne(name, "")
      assert_ne(name, "Inconnu")
  ```

- [ ] **Step 3 : Lancer les tests**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_game_data_load
  ```
  Attendu : `7 passed, 0 failed`

- [ ] **Step 4 : Committer**

  ```bash
  git add src/core/FoundationGameData.gd tests/test_game_data_load.gd
  git commit -m "feat(core): implement FoundationGameData JSON loader"
  ```

---

## Task 5 : NarrativeModel

**Files:**
- Create: `~/foundation-reigns/src/core/NarrativeModel.gd`
- Create: `~/foundation-reigns/tests/test_narrative_model.gd`

- [ ] **Step 1 : Écrire les tests**

  Créer `tests/test_narrative_model.gd` :
  ```gdscript
  extends GutTest

  var model: NarrativeModel
  var data: FoundationGameData
  var ctx: Context

  func before_each():
      data = FoundationGameData.new()
      data.load_all()
      ctx = Context.new()
      ctx.initialize_new_reign()
      ctx.set_var("year", 1)
      model = NarrativeModel.new(data, ctx)

  func test_draw_returns_card():
      var card = model.draw_card()
      assert_false(card.is_empty(), "Should draw a card")
      assert_true(card.has("id"))

  func test_lockturn_prevents_repeat():
      # Draw a card, record its id, mark it seen
      var card = model.draw_card()
      var id = card.get("id")
      model.mark_card_seen(card)
      # Draw 5 more times — should not see same card within lockturn
      var lockturn = card.get("lockturn", 0)
      if lockturn > 0:
          for i in range(5):
              ctx.add_var("turns", 1)
              var next_card = model.draw_card()
              if ctx.get_var("turns") < lockturn:
                  assert_ne(next_card.get("id"), id,
                      "Card should not repeat within lockturn")

  func test_link_takes_priority():
      ctx.set_var("link", "1002")
      var card = model.draw_card()
      assert_eq(card.get("id"), 1002)
      assert_eq(ctx.get_var("link", ""), "", "link should be cleared after use")

  func test_conditions_filter_cards():
      # Cards with year > 50 should not appear when year = 1
      ctx.set_var("year", 1)
      for i in range(20):
          var card = model.draw_card()
          var conditions = card.get("conditions", [])
          var evaluator = ConditionEvaluator.new()
          assert_true(evaluator.evaluate_all(conditions, ctx._vars),
              "Drawn card must pass conditions")

  func test_apply_yes_outcome():
      ctx.set_var("commerce", 50)
      var outcomes = [
          {"variable": "commerce", "intValue": -10, "addOperation": true, "toKeep": false}
      ]
      model.apply_outcomes(outcomes)
      assert_eq(ctx.get_var("commerce"), 40)

  func test_apply_no_outcome_set():
      var outcomes = [
          {"variable": "politics", "intValue": 30, "addOperation": false, "toKeep": false}
      ]
      model.apply_outcomes(outcomes)
      assert_eq(ctx.get_var("politics"), 30)

  func test_apply_tokeep_outcome():
      var outcomes = [
          {"variable": "year", "intValue": 5, "addOperation": true, "toKeep": true}
      ]
      ctx.set_var("year", 1)
      model.apply_outcomes(outcomes)
      ctx.empty_non_keep()
      assert_eq(ctx.get_var("year"), 6)
  ```

- [ ] **Step 2 : Lancer — vérifier l'échec**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_narrative_model
  ```
  Attendu : erreur `NarrativeModel not found`

- [ ] **Step 3 : Implémenter NarrativeModel**

  Créer `src/core/NarrativeModel.gd` :
  ```gdscript
  class_name NarrativeModel

  var _data: FoundationGameData
  var _ctx: Context
  var _evaluator: ConditionEvaluator
  var _lockturn_tracker: Dictionary = {}  # card_id -> turn_last_seen

  func _init(data: FoundationGameData, ctx: Context) -> void:
      _data = data
      _ctx = ctx
      _evaluator = ConditionEvaluator.new()

  func draw_card() -> Dictionary:
      # Forced link takes absolute priority
      var link = str(_ctx.get_var("link", ""))
      if link != "" and link != "0":
          _ctx.set_var("link", "")
          var linked = _data.get_card_by_id(int(link))
          if not linked.is_empty():
              return linked

      var eligible = _get_eligible_cards()
      if eligible.is_empty():
          push_warning("NarrativeModel: no eligible cards — returning empty")
          return {}

      return _weighted_random(eligible)

  func _get_eligible_cards() -> Array:
      var eligible: Array = []
      var current_turn: int = _ctx.get_var("turns", 0)

      for card in _data.cards:
          # Check deck is active
          var deck: String = card.get("deck", "")
          if _ctx.get_var("deck_" + deck, 1) == 0:
              continue

          # Check conditions
          if not _evaluator.evaluate_all(card.get("conditions", []), _ctx._vars):
              continue

          # Check lockturn
          var card_id: int = card.get("id", 0)
          var last_seen: int = _lockturn_tracker.get(card_id, -9999)
          var lockturn: int = card.get("lockturn", 0)
          if current_turn - last_seen < lockturn:
              continue

          eligible.append(card)

      return eligible

  func _weighted_random(cards: Array) -> Dictionary:
      var total_weight: int = 0
      for card in cards:
          total_weight += card.get("weight", 1)

      var roll: int = randi() % max(total_weight, 1)
      var cumulative: int = 0
      for card in cards:
          cumulative += card.get("weight", 1)
          if roll < cumulative:
              return card

      return cards[-1]

  func mark_card_seen(card: Dictionary) -> void:
      var card_id: int = card.get("id", 0)
      var turn: int = _ctx.get_var("turns", 0)
      _lockturn_tracker[card_id] = turn
      _ctx.set_var("seen_" + str(card_id), 1)

  func apply_outcomes(outcomes: Array) -> void:
      for outcome in outcomes:
          var variable: String = outcome.get("variable", "")
          var int_value: int = outcome.get("intValue", 0)
          var add_op: bool = outcome.get("addOperation", true)
          var to_keep: bool = outcome.get("toKeep", false)

          if variable == "":
              continue

          if add_op:
              _ctx.add_var(variable, int_value)
              if to_keep:
                  _ctx._keep_flags[variable] = true
          else:
              _ctx.set_var(variable, int_value, to_keep)
  ```

- [ ] **Step 4 : Lancer les tests**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_narrative_model
  ```
  Attendu : `7 passed, 0 failed`

- [ ] **Step 5 : Committer**

  ```bash
  git add src/core/NarrativeModel.gd tests/test_narrative_model.gd
  git commit -m "feat(core): implement NarrativeModel (draw, link, weight, outcomes)"
  ```

---

## Task 6 : LegitimacySystem

**Files:**
- Create: `~/foundation-reigns/src/core/LegitimacySystem.gd`
- Create: `~/foundation-reigns/tests/test_legitimacy_system.gd`

- [ ] **Step 1 : Écrire les tests**

  Créer `tests/test_legitimacy_system.gd` :
  ```gdscript
  extends GutTest

  var sys: LegitimacySystem
  var ctx: Context

  func before_each():
      ctx = Context.new()
      ctx.initialize_new_reign()
      sys = LegitimacySystem.new(ctx)

  func test_initial_legitimacy_100():
      assert_eq(ctx.get_var("legitimacy"), 100)

  func test_apply_delta_reduces():
      sys.apply_delta(-15)
      assert_eq(ctx.get_var("legitimacy"), 85)

  func test_apply_delta_clamps_at_zero():
      sys.apply_delta(-200)
      assert_eq(ctx.get_var("legitimacy"), 0)

  func test_apply_delta_clamps_at_hundred():
      sys.apply_delta(200)
      assert_eq(ctx.get_var("legitimacy"), 100)

  func test_is_critical_below_15():
      sys.apply_delta(-90)
      assert_true(sys.is_critical())

  func test_is_not_critical_above_15():
      assert_false(sys.is_critical())

  func test_is_exposed_at_zero():
      sys.apply_delta(-100)
      assert_true(sys.is_exposed())

  func test_get_signal_level_high():
      assert_eq(sys.get_signal_level(), LegitimacySystem.SignalLevel.NORMAL)

  func test_get_signal_level_suspicious():
      sys.apply_delta(-70)
      assert_eq(sys.get_signal_level(), LegitimacySystem.SignalLevel.SUSPICIOUS)

  func test_get_signal_level_critical():
      sys.apply_delta(-90)
      assert_eq(sys.get_signal_level(), LegitimacySystem.SignalLevel.CRITICAL)
  ```

- [ ] **Step 2 : Implémenter LegitimacySystem**

  Créer `src/core/LegitimacySystem.gd` :
  ```gdscript
  class_name LegitimacySystem

  enum SignalLevel { NORMAL, SUSPICIOUS, CRITICAL }

  const THRESHOLD_SUSPICIOUS = 30
  const THRESHOLD_CRITICAL = 15

  var _ctx: Context

  func _init(ctx: Context) -> void:
      _ctx = ctx

  func apply_delta(delta: int) -> void:
      var current: int = _ctx.get_var("legitimacy", 100)
      var new_val: int = clamp(current + delta, 0, 100)
      _ctx.set_var("legitimacy", new_val)

  func is_critical() -> bool:
      return _ctx.get_var("legitimacy", 100) < THRESHOLD_CRITICAL

  func is_exposed() -> bool:
      return _ctx.get_var("legitimacy", 100) <= 0

  func get_signal_level() -> SignalLevel:
      var val: int = _ctx.get_var("legitimacy", 100)
      if val < THRESHOLD_CRITICAL:
          return SignalLevel.CRITICAL
      if val < THRESHOLD_SUSPICIOUS:
          return SignalLevel.SUSPICIOUS
      return SignalLevel.NORMAL

  func get_mood_bias() -> String:
      match get_signal_level():
          SignalLevel.CRITICAL:    return "suspicious"
          SignalLevel.SUSPICIOUS:  return "suspicious"
          _:                       return ""
  ```

- [ ] **Step 3 : Lancer les tests**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_legitimacy_system
  ```
  Attendu : `10 passed, 0 failed`

- [ ] **Step 4 : Committer**

  ```bash
  git add src/core/LegitimacySystem.gd tests/test_legitimacy_system.gd
  git commit -m "feat(core): implement LegitimacySystem with signal levels"
  ```

---

## Task 7 : RespawnSystem

**Files:**
- Create: `~/foundation-reigns/src/core/RespawnSystem.gd`
- Create: `~/foundation-reigns/tests/test_respawn_system.gd`

- [ ] **Step 1 : Écrire les tests**

  Créer `tests/test_respawn_system.gd` :
  ```gdscript
  extends GutTest

  var sys: RespawnSystem
  var ctx: Context

  func before_each():
      ctx = Context.new()
      sys = RespawnSystem.new(ctx)

  func test_era_start_year_hardin():
      assert_eq(sys.get_era_start_year(50), 1)

  func test_era_start_year_merchants():
      assert_eq(sys.get_era_start_year(120), 80)

  func test_era_start_year_mallow():
      assert_eq(sys.get_era_start_year(280), 200)

  func test_era_start_year_mulet():
      assert_eq(sys.get_era_start_year(320), 290)

  func test_era_start_year_restoration():
      assert_eq(sys.get_era_start_year(450), 350)

  func test_era_start_year_late_empire():
      assert_eq(sys.get_era_start_year(700), 600)

  func test_respawn_resets_resources():
      ctx.set_var("year", 60, true)
      ctx.set_var("military", 10)
      sys.respawn("resource")
      assert_eq(ctx.get_var("military"), 50)

  func test_respawn_resets_year_to_era_start():
      ctx.set_var("year", 60, true)
      sys.respawn("resource")
      assert_eq(ctx.get_var("year"), 1)

  func test_respawn_natural_sets_legitimacy_100():
      ctx.set_var("year", 1, true)
      sys.respawn("natural")
      assert_eq(ctx.get_var("legitimacy"), 100)

  func test_respawn_resource_sets_legitimacy_80():
      ctx.set_var("year", 1, true)
      sys.respawn("resource")
      assert_eq(ctx.get_var("legitimacy"), 80)

  func test_respawn_exposed_sets_legitimacy_50():
      ctx.set_var("year", 1, true)
      sys.respawn("exposed")
      assert_eq(ctx.get_var("legitimacy"), 50)

  func test_respawn_preserves_seldon_crises():
      ctx.set_var("year", 60, true)
      ctx.set_var("seldon_crisis_1", 1, true)
      sys.respawn("resource")
      assert_eq(ctx.get_var("seldon_crisis_1"), 1)
  ```

- [ ] **Step 2 : Implémenter RespawnSystem**

  Créer `src/core/RespawnSystem.gd` :
  ```gdscript
  class_name RespawnSystem

  # Era start years matching GDD Section 6
  const ERA_STARTS = [
      {"start": 1,   "era": "hardin"},
      {"start": 80,  "era": "merchants"},
      {"start": 200, "era": "mallow"},
      {"start": 290, "era": "mulet"},
      {"start": 350, "era": "restoration"},
      {"start": 600, "era": "late_empire"},
  ]

  const LEGITIMACY_AFTER_NATURAL  = 100
  const LEGITIMACY_AFTER_RESOURCE = 80
  const LEGITIMACY_AFTER_EXPOSED  = 50

  var _ctx: Context

  func _init(ctx: Context) -> void:
      _ctx = ctx

  func get_era_start_year(current_year: int) -> int:
      var era_start = 1
      for era in ERA_STARTS:
          if current_year >= era["start"]:
              era_start = era["start"]
          else:
              break
      return era_start

  func respawn(death_type: String) -> void:
      var current_year: int = _ctx.get_var("year", 1)
      var era_start: int = get_era_start_year(current_year)

      _ctx.empty_non_keep()

      # Reset year to era start
      _ctx.set_var("year", era_start, true)

      # Reset resources
      for resource in Context.RESOURCES:
          _ctx.set_var(resource, Context.RESOURCE_DEFAULT)

      # Set legitimacy based on death type
      var legitimacy: int
      match death_type:
          "natural":   legitimacy = LEGITIMACY_AFTER_NATURAL
          "resource":  legitimacy = LEGITIMACY_AFTER_RESOURCE
          "exposed":   legitimacy = LEGITIMACY_AFTER_EXPOSED
          _:           legitimacy = LEGITIMACY_AFTER_RESOURCE
      _ctx.set_var("legitimacy", legitimacy)

      # Reset misc
      _ctx.set_var("turns", 0)
      _ctx.set_var("mood", "neutral")
      _ctx.set_var("age", 35 + randi() % 6)  # 35-40
  ```

- [ ] **Step 3 : Lancer les tests**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_respawn_system
  ```
  Attendu : `12 passed, 0 failed`

- [ ] **Step 4 : Committer**

  ```bash
  git add src/core/RespawnSystem.gd tests/test_respawn_system.gd
  git commit -m "feat(core): implement RespawnSystem with era calculation"
  ```

---

## Task 8 : SaveSystem

**Files:**
- Create: `~/foundation-reigns/src/core/SaveSystem.gd`

- [ ] **Step 1 : Implémenter SaveSystem**

  Créer `src/core/SaveSystem.gd` :
  ```gdscript
  class_name SaveSystem

  const SAVE_PATH = "user://foundation_save.json"

  func save(ctx: Context) -> bool:
      var data = {
          "vars": ctx._vars.duplicate(),
          "keep_flags": ctx._keep_flags.duplicate(),
          "version": 1
      }
      var json_string = JSON.stringify(data, "\t")
      var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
      if not file:
          push_error("SaveSystem: cannot write to %s" % SAVE_PATH)
          return false
      file.store_string(json_string)
      return true

  func load(ctx: Context) -> bool:
      if not FileAccess.file_exists(SAVE_PATH):
          return false
      var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
      if not file:
          return false
      var json_string = file.get_as_text()
      var data = JSON.parse_string(json_string)
      if not data is Dictionary:
          push_error("SaveSystem: corrupt save file")
          return false
      ctx._vars = data.get("vars", {})
      ctx._keep_flags = data.get("keep_flags", {})
      return true

  func has_save() -> bool:
      return FileAccess.file_exists(SAVE_PATH)

  func delete_save() -> void:
      if has_save():
          DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
  ```

- [ ] **Step 2 : Test manuel rapide**

  Créer `tests/test_save_system.gd` :
  ```gdscript
  extends GutTest

  var save_sys: SaveSystem
  var ctx: Context

  func before_each():
      save_sys = SaveSystem.new()
      ctx = Context.new()
      ctx.initialize_new_reign()
      save_sys.delete_save()

  func after_each():
      save_sys.delete_save()

  func test_no_save_initially():
      assert_false(save_sys.has_save())

  func test_save_and_load():
      ctx.set_var("military", 65)
      ctx.set_var("year", 42, true)
      save_sys.save(ctx)
      assert_true(save_sys.has_save())

      var ctx2 = Context.new()
      save_sys.load(ctx2)
      assert_eq(ctx2.get_var("military"), 65)
      assert_eq(ctx2.get_var("year"), 42)

  func test_delete_removes_save():
      save_sys.save(ctx)
      save_sys.delete_save()
      assert_false(save_sys.has_save())
  ```

- [ ] **Step 3 : Lancer les tests**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd -gtest=test_save_system
  ```
  Attendu : `3 passed, 0 failed`

- [ ] **Step 4 : Committer**

  ```bash
  git add src/core/SaveSystem.gd tests/test_save_system.gd
  git commit -m "feat(core): implement SaveSystem (JSON, slot unique)"
  ```

---

## Task 9 : Lancer tous les tests

- [ ] **Step 1 : Lancer la suite complète**

  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd
  ```
  Attendu :
  ```
  ConditionEvaluator : 11 passed
  Context            : 12 passed
  FoundationGameData :  7 passed
  NarrativeModel     :  7 passed
  LegitimacySystem   : 10 passed
  RespawnSystem      : 12 passed
  SaveSystem         :  3 passed
  ─────────────────────────────
  Total: 62 passed, 0 failed
  ```

- [ ] **Step 2 : Committer le résultat**

  ```bash
  git add .
  git commit -m "test: all Phase 2 core modules passing (62 tests)"
  ```

---

## Livrable Phase 2

À la fin de cette phase, le moteur est complet et testé :

```
src/core/
├── ConditionEvaluator.gd  ✓ 11 tests
├── Context.gd             ✓ 12 tests
├── FoundationGameData.gd  ✓  7 tests
├── NarrativeModel.gd      ✓  7 tests
├── LegitimacySystem.gd    ✓ 10 tests
├── RespawnSystem.gd       ✓ 12 tests
└── SaveSystem.gd          ✓  3 tests
```

Phase 3 (UI) peut commencer.
