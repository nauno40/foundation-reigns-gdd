# Phase 1 — Data Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the Godot 4 project skeleton and all 8 JSON data files that drive the Foundation game engine.

**Architecture:** A new Godot 4 project at `~/foundation-reigns/`. All game data lives in `data/` as JSON files loaded at startup. A Python validation script checks schema correctness before the engine ever runs.

**Tech Stack:** Godot 4.x, JSON, Python 3 (validation only)

---

## File Structure

```
~/foundation-reigns/
├── project.godot
├── data/
│   ├── foundation_cards.json       ← cartes narratives (prototype: 30 cartes)
│   ├── given_names.json            ← ~50 prénoms PNJ
│   ├── family_names.json           ← ~30 noms de famille PNJ
│   ├── factions.json               ← 9 factions
│   ├── planets.json                ← 12 planètes
│   ├── characters.json             ← personnages canoniques
│   ├── covers.json                 ← identités de couverture par ère
│   └── moods.json                  ← 8 états émotionnels
├── scripts/
│   └── validate_data.py            ← validation Python (hors Godot)
└── src/
    └── (vide — rempli en Phase 2)
```

---

## Task 1 : Créer le projet Godot 4

**Files:**
- Create: `~/foundation-reigns/project.godot`
- Create: `~/foundation-reigns/data/` (répertoire)
- Create: `~/foundation-reigns/src/` (répertoire)
- Create: `~/foundation-reigns/scenes/` (répertoire)
- Create: `~/foundation-reigns/tests/` (répertoire)

- [ ] **Step 1 : Ouvrir Godot 4 et créer un nouveau projet**

  Dans l'éditeur Godot :
  - Cliquer "New Project"
  - Nom du projet : `foundation-reigns`
  - Chemin : `~/foundation-reigns/`
  - Renderer : Mobile (pour cible mobile + PC)
  - Cliquer "Create & Edit"

- [ ] **Step 2 : Créer les répertoires**

  Dans le terminal (depuis `~/foundation-reigns/`) :
  ```bash
  mkdir -p data src scenes tests scripts
  ```

- [ ] **Step 3 : Vérifier la structure**

  ```bash
  ls ~/foundation-reigns/
  ```
  Attendu : `data/  project.godot  scenes/  scripts/  src/  tests/`

- [ ] **Step 4 : Initialiser git**

  ```bash
  cd ~/foundation-reigns
  git init
  echo "*.import" >> .gitignore
  echo ".godot/" >> .gitignore
  echo "export/" >> .gitignore
  git add .gitignore project.godot
  git commit -m "chore: init Godot 4 project"
  ```

---

## Task 2 : factions.json

**Files:**
- Create: `~/foundation-reigns/data/factions.json`

- [ ] **Step 1 : Créer le fichier**

  ```json
  [
    {
      "id": "empire",
      "name": "Empire Galactique",
      "year_start": 1,
      "year_end": 300,
      "primary_resource": "politics",
      "starting_relation": 0
    },
    {
      "id": "military_kingdoms",
      "name": "Royaumes Militaristes",
      "year_start": 1,
      "year_end": 150,
      "primary_resource": "military",
      "starting_relation": -20
    },
    {
      "id": "merchants",
      "name": "Marchands",
      "year_start": 100,
      "year_end": 400,
      "primary_resource": "commerce",
      "starting_relation": 0
    },
    {
      "id": "oligarchs",
      "name": "Oligarques",
      "year_start": 200,
      "year_end": 400,
      "primary_resource": "commerce",
      "starting_relation": 0
    },
    {
      "id": "autonomous_league",
      "name": "Ligue des Mondes Autonomes",
      "year_start": 250,
      "year_end": 350,
      "primary_resource": "military",
      "starting_relation": -10
    },
    {
      "id": "first_foundation",
      "name": "Première Fondation",
      "year_start": 1,
      "year_end": 1000,
      "primary_resource": "all",
      "starting_relation": 50
    },
    {
      "id": "church_of_science",
      "name": "Église de la Science",
      "year_start": 50,
      "year_end": 200,
      "primary_resource": "religion",
      "starting_relation": 20
    },
    {
      "id": "kalgan",
      "name": "Kalgan",
      "year_start": 350,
      "year_end": 600,
      "primary_resource": "military",
      "starting_relation": -10
    },
    {
      "id": "neotrantor",
      "name": "Neotrantor",
      "year_start": 300,
      "year_end": 500,
      "primary_resource": "politics",
      "starting_relation": 0
    }
  ]
  ```

- [ ] **Step 2 : Valider le JSON**

  ```bash
  python3 -c "import json; data=json.load(open('data/factions.json')); print(f'{len(data)} factions OK')"
  ```
  Attendu : `9 factions OK`

- [ ] **Step 3 : Committer**

  ```bash
  git add data/factions.json
  git commit -m "feat(data): add 9 factions"
  ```

---

## Task 3 : planets.json

**Files:**
- Create: `~/foundation-reigns/data/planets.json`

- [ ] **Step 1 : Créer le fichier**

  ```json
  [
    {
      "id": "terminus",
      "name": "Terminus",
      "faction": "first_foundation",
      "initial_state": 1,
      "game_over_if_lost": true,
      "narrative_role": "Base permanente de la Fondation"
    },
    {
      "id": "trantor",
      "name": "Trantor",
      "faction": "empire",
      "initial_state": 1,
      "game_over_if_lost": false,
      "narrative_role": "Capitale impériale, décline après le sac (an ~300)"
    },
    {
      "id": "anacreon",
      "name": "Anacréon",
      "faction": "military_kingdoms",
      "initial_state": -1,
      "game_over_if_lost": false,
      "narrative_role": "Première grande menace militaire"
    },
    {
      "id": "santanni",
      "name": "Santanni",
      "faction": "military_kingdoms",
      "initial_state": -1,
      "game_over_if_lost": false,
      "narrative_role": "Royaume des Quatre Provinces"
    },
    {
      "id": "smyrno",
      "name": "Smyrno",
      "faction": "military_kingdoms",
      "initial_state": -1,
      "game_over_if_lost": false,
      "narrative_role": "Royaume des Quatre Provinces"
    },
    {
      "id": "askone",
      "name": "Askone",
      "faction": "merchants",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Cible commerciale ère Mallow"
    },
    {
      "id": "korell",
      "name": "Korell",
      "faction": "oligarchs",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Antagoniste ère Mallow"
    },
    {
      "id": "siwenna",
      "name": "Siwenna",
      "faction": "empire",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Illustre la chute de l'Empire"
    },
    {
      "id": "kalgan",
      "name": "Kalgan",
      "faction": "kalgan",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Base du Mulet, seigneurie après sa mort"
    },
    {
      "id": "neotrantor",
      "name": "Neotrantor",
      "faction": "neotrantor",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Vestige impérial post-sac de Trantor"
    },
    {
      "id": "rossem",
      "name": "Rossem",
      "faction": "second_foundation",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Planète cachée, late game"
    },
    {
      "id": "sayshell",
      "name": "Sayshell",
      "faction": "church_of_science",
      "initial_state": 0,
      "game_over_if_lost": false,
      "narrative_role": "Culte de la Fondation"
    }
  ]
  ```

- [ ] **Step 2 : Valider**

  ```bash
  python3 -c "import json; data=json.load(open('data/planets.json')); print(f'{len(data)} planets OK')"
  ```
  Attendu : `12 planets OK`

- [ ] **Step 3 : Committer**

  ```bash
  git add data/planets.json
  git commit -m "feat(data): add 12 planets"
  ```

---

## Task 4 : moods.json

**Files:**
- Create: `~/foundation-reigns/data/moods.json`

- [ ] **Step 1 : Créer le fichier**

  ```json
  {
    "neutral":    {"id": 0, "name": "Neutral",    "FR": "Neutre",     "description": "État normal, aucun effet particulier"},
    "suspicious": {"id": 1, "name": "Suspicious", "FR": "Méfiant",    "description": "Soupçons — les options trop directes sont masquées"},
    "afraid":     {"id": 2, "name": "Afraid",     "FR": "Apeuré",     "description": "Sous pression — les options agressives coûtent moins"},
    "angry":      {"id": 3, "name": "Angry",       "FR": "Furieux",    "description": "Trahison ou perte — la diplomatie est pénalisée"},
    "flattered":  {"id": 4, "name": "Flattered",  "FR": "Flatté",     "description": "Manipulation douce — une option bonus apparaît"},
    "curious":    {"id": 5, "name": "Curious",     "FR": "Curieux",    "description": "Surprise ou découverte — aucun malus"},
    "sad":        {"id": 6, "name": "Sad",         "FR": "Triste",     "description": "Deuil ou défaite — ton des textes plus sombre"},
    "desperate":  {"id": 7, "name": "Desperate",  "FR": "Désespéré",  "description": "Crise grave — dernière chance, tous les choix ont un coût"}
  }
  ```

- [ ] **Step 2 : Valider**

  ```bash
  python3 -c "import json; data=json.load(open('data/moods.json')); print(f'{len(data)} moods OK')"
  ```
  Attendu : `8 moods OK`

- [ ] **Step 3 : Committer**

  ```bash
  git add data/moods.json
  git commit -m "feat(data): add 8 moods"
  ```

---

## Task 5 : given_names.json + family_names.json

**Files:**
- Create: `~/foundation-reigns/data/given_names.json`
- Create: `~/foundation-reigns/data/family_names.json`

- [ ] **Step 1 : Créer given_names.json**

  ```json
  [
    "Hari", "Salvor", "Hober", "Bayta", "Ebling", "Gaal", "Dors",
    "Raych", "Wanda", "Arkady", "Toran", "Magnifico", "Elvett",
    "Jord", "Limmar", "Jorane", "Theo", "Sef", "Quoriana", "Pelleas",
    "Bel", "Ducem", "Onum", "Fran", "Riose", "Brodrig", "Sennett",
    "Callia", "Indbur", "Linge", "Dagobert", "Preem", "Quoriana",
    "Novi", "Sura", "Channis", "Preem", "Elvett", "Jord", "Homir",
    "Anthor", "Kleise", "Munn", "Turbor", "Palver", "Quoriana",
    "Stor", "Alurin", "Quoriana", "Elvett"
  ]
  ```

- [ ] **Step 2 : Créer family_names.json**

  ```json
  [
    "Seldon", "Hardin", "Mallow", "Darell", "Mis", "Dornick",
    "Venabili", "Palver", "Munn", "Turbor", "Anthor", "Kleise",
    "Riose", "Brodrig", "Sennett", "Callia", "Indbur", "Channis",
    "Barr", "Lathan", "Devers", "Sermak", "Sutt", "Lepold",
    "Wienis", "Verisof", "Yohan", "Askonian", "Commdor", "Pritcher"
  ]
  ```

- [ ] **Step 3 : Valider**

  ```bash
  python3 -c "
  import json
  g = json.load(open('data/given_names.json'))
  f = json.load(open('data/family_names.json'))
  print(f'{len(g)} given names, {len(f)} family names OK')
  "
  ```
  Attendu : `50 given names, 30 family names OK`

- [ ] **Step 4 : Committer**

  ```bash
  git add data/given_names.json data/family_names.json
  git commit -m "feat(data): add NPC name pools"
  ```

---

## Task 6 : characters.json

**Files:**
- Create: `~/foundation-reigns/data/characters.json`

- [ ] **Step 1 : Créer le fichier**

  ```json
  {
    "hari_seldon": {
      "name": "Hari Seldon",
      "deck": "seldon_vault",
      "sprite": "hari_seldon",
      "fixed": true,
      "era_start": 1,
      "era_end": 1000,
      "description": "Le fondateur. Apparaît uniquement via les messages enregistrés dans la Crypte."
    },
    "salvor_hardin": {
      "name": "Salvor Hardin",
      "deck": "hardin_legacy",
      "sprite": "salvor_hardin",
      "fixed": true,
      "era_start": 1,
      "era_end": 80,
      "description": "Premier maire de Terminus. Maîtrise la politique et la religion comme outils."
    },
    "hober_mallow": {
      "name": "Hober Mallow",
      "deck": "mallow_legacy",
      "sprite": "hober_mallow",
      "fixed": true,
      "era_start": 200,
      "era_end": 350,
      "description": "Premier Prince Marchand. Commerce comme arme diplomatique."
    },
    "bayta_darell": {
      "name": "Bayta Darell",
      "deck": "bayta_darell",
      "sprite": "bayta_darell",
      "fixed": true,
      "era_start": 290,
      "era_end": 380,
      "description": "Héroïne de l'ère du Mulet. La seule à avoir reconnu le Mulet."
    },
    "ducem_barr": {
      "name": "Ducem Barr",
      "deck": "ducem_barr",
      "sprite": "ducem_barr",
      "fixed": true,
      "era_start": 200,
      "era_end": 300,
      "description": "Érudit siwennien. Témoin de la chute de l'Empire."
    },
    "ebling_mis": {
      "name": "Ebling Mis",
      "deck": "ebling_mis",
      "sprite": "ebling_mis",
      "fixed": true,
      "era_start": 290,
      "era_end": 340,
      "description": "Psychohistorien. A failli localiser la Seconde Fondation."
    }
  }
  ```

- [ ] **Step 2 : Valider**

  ```bash
  python3 -c "import json; data=json.load(open('data/characters.json')); print(f'{len(data)} characters OK')"
  ```
  Attendu : `6 characters OK`

- [ ] **Step 3 : Committer**

  ```bash
  git add data/characters.json
  git commit -m "feat(data): add canonical characters"
  ```

---

## Task 7 : covers.json

**Files:**
- Create: `~/foundation-reigns/data/covers.json`

- [ ] **Step 1 : Créer le fichier**

  ```json
  {
    "hardin": {
      "era_start": 1,
      "era_end": 80,
      "covers": [
        {"id": "imperial_advisor", "name": "Conseiller impérial", "bonus_resource": "politics", "bonus_value": 5},
        {"id": "science_priest",   "name": "Prêtre scientifique", "bonus_resource": "religion", "bonus_value": 5},
        {"id": "local_merchant",   "name": "Marchand local",      "bonus_resource": "commerce", "bonus_value": 5}
      ]
    },
    "merchants": {
      "era_start": 80,
      "era_end": 250,
      "covers": [
        {"id": "interstellar_trader", "name": "Négociant interstellaire", "bonus_resource": "commerce",  "bonus_value": 5},
        {"id": "diplomat",            "name": "Diplomate",                "bonus_resource": "politics",  "bonus_value": 5},
        {"id": "historian",           "name": "Historien",                "bonus_resource": "religion",  "bonus_value": 5}
      ]
    },
    "mallow": {
      "era_start": 200,
      "era_end": 350,
      "covers": [
        {"id": "merchant_prince", "name": "Prince marchand", "bonus_resource": "commerce",  "bonus_value": 5},
        {"id": "ambassador",      "name": "Ambassadeur",     "bonus_resource": "politics",  "bonus_value": 5},
        {"id": "engineer",        "name": "Ingénieur",       "bonus_resource": "military",  "bonus_value": 5}
      ]
    },
    "mulet": {
      "era_start": 290,
      "era_end": 380,
      "covers": [
        {"id": "refugee",        "name": "Réfugié",          "bonus_resource": "commerce", "bonus_value": 5},
        {"id": "spy",            "name": "Espion",           "bonus_resource": "military", "bonus_value": 5},
        {"id": "court_advisor",  "name": "Conseiller de cour","bonus_resource": "politics","bonus_value": 5}
      ]
    },
    "restoration": {
      "era_start": 350,
      "era_end": 600,
      "covers": [
        {"id": "administrator", "name": "Administrateur", "bonus_resource": "politics",  "bonus_value": 5},
        {"id": "judge",         "name": "Juge",           "bonus_resource": "religion",  "bonus_value": 5},
        {"id": "academic",      "name": "Académicien",    "bonus_resource": "commerce",  "bonus_value": 5}
      ]
    },
    "late_empire": {
      "era_start": 600,
      "era_end": 1000,
      "covers": [
        {"id": "archivist",   "name": "Archiviste",  "bonus_resource": "religion",  "bonus_value": 5},
        {"id": "senator",     "name": "Sénateur",    "bonus_resource": "politics",  "bonus_value": 5},
        {"id": "philosopher", "name": "Philosophe",  "bonus_resource": "commerce",  "bonus_value": 5}
      ]
    }
  }
  ```

- [ ] **Step 2 : Valider**

  ```bash
  python3 -c "
  import json
  data = json.load(open('data/covers.json'))
  total = sum(len(era['covers']) for era in data.values())
  print(f'{len(data)} eras, {total} covers total OK')
  "
  ```
  Attendu : `6 eras, 18 covers total OK`

- [ ] **Step 3 : Committer**

  ```bash
  git add data/covers.json
  git commit -m "feat(data): add cover identities per era"
  ```

---

## Task 8 : foundation_cards.json (30 cartes prototype)

**Files:**
- Create: `~/foundation-reigns/data/foundation_cards.json`

Le fichier contient un tableau JSON de cartes. Format de chaque carte :

```json
{
  "id": <int>,
  "label": "<string>",
  "deck": "<string>",
  "weight": <int 1-5>,
  "lockturn": <int>,
  "hidden": false,
  "bearer": "<character_id ou null>",
  "question": {"FR": "<texte>"},
  "conditions": [
    {"variable": "<var>", "op": "equal|below|above|not", "value": <int ou string>}
  ],
  "loadOutcome": [],
  "leftAnswer":  {"title": {"FR": "<texte>"}, "reaction": {"FR": "<texte>"}},
  "rightAnswer": {"title": {"FR": "<texte>"}, "reaction": {"FR": "<texte>"}},
  "yesOutcome": [
    {"variable": "<var>", "intValue": <int>, "addOperation": true, "toKeep": false}
  ],
  "noOutcome": [...],
  "moods": {"default": "<mood>", "yes": "<mood>", "no": "<mood>"}
}
```

- [ ] **Step 1 : Créer 10 cartes `ambient` (vie quotidienne)**

  Créer `data/foundation_cards.json` avec les 10 premières cartes (deck `ambient`) :

  ```json
  [
    {
      "id": 1001,
      "label": "rumeur_terminus",
      "deck": "ambient",
      "weight": 3,
      "lockturn": 10,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Une rumeur circule à Terminus : la Fondation serait en danger de l'intérieur."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Ignorer"}, "reaction": {"FR": "Vous faites confiance au Plan."}},
      "rightAnswer": {"title": {"FR": "Enquêter"}, "reaction": {"FR": "Vous activez votre réseau d'informateurs."}},
      "yesOutcome": [],
      "noOutcome": [
        {"variable": "military", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "neutral", "no": "suspicious"}
    },
    {
      "id": 1002,
      "label": "greve_marchands",
      "deck": "ambient",
      "weight": 2,
      "lockturn": 15,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Les marchands locaux font grève. Ils veulent de meilleures protections commerciales."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Céder à leurs demandes"}, "reaction": {"FR": "La grève s'arrête. Coûteux mais efficace."}},
      "rightAnswer": {"title": {"FR": "Tenir ferme"}, "reaction": {"FR": "La grève dure. Des tensions naissent."}},
      "yesOutcome": [
        {"variable": "commerce",  "intValue": -10, "addOperation": true, "toKeep": false},
        {"variable": "politics",  "intValue": 5,   "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "commerce",  "intValue": -5,  "addOperation": true, "toKeep": false},
        {"variable": "politics",  "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "angry", "yes": "neutral", "no": "angry"}
    },
    {
      "id": 1003,
      "label": "etudiant_fondation",
      "deck": "ambient",
      "weight": 4,
      "lockturn": 8,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un étudiant brillant vous demande de l'aide pour accéder aux archives classifiées de la psychohistoire."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Lui ouvrir les archives"}, "reaction": {"FR": "Son enthousiasme est contagieux."}},
      "rightAnswer": {"title": {"FR": "Refuser — trop tôt"}, "reaction": {"FR": "Il repart, déçu mais compréhensif."}},
      "yesOutcome": [
        {"variable": "religion", "intValue": 5,  "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [],
      "moods": {"default": "curious", "yes": "flattered", "no": "sad"}
    },
    {
      "id": 1004,
      "label": "coupure_energie",
      "deck": "ambient",
      "weight": 3,
      "lockturn": 20,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Une panne d'énergie frappe le secteur ouest de Terminus. Les générateurs nucléaires sont en cause."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Réparer en urgence"}, "reaction": {"FR": "Les techniciens travaillent jour et nuit."}},
      "rightAnswer": {"title": {"FR": "Rationaliser l'énergie"}, "reaction": {"FR": "Des quotas sont imposés — mécontentement garanti."}},
      "yesOutcome": [
        {"variable": "commerce", "intValue": -15, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics", "intValue": -10, "addOperation": true, "toKeep": false},
        {"variable": "commerce", "intValue": -5,  "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "afraid", "yes": "neutral", "no": "angry"}
    },
    {
      "id": 1005,
      "label": "delegation_scientifique",
      "deck": "ambient",
      "weight": 3,
      "lockturn": 12,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Une délégation de scientifiques demande des fonds supplémentaires pour l'Encyclopédie Galactique."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Allouer les fonds"}, "reaction": {"FR": "L'Encyclopédie avance. Le Plan progresse."}},
      "rightAnswer": {"title": {"FR": "Reporter la décision"}, "reaction": {"FR": "Les scientifiques s'impatientent."}},
      "yesOutcome": [
        {"variable": "commerce", "intValue": -10, "addOperation": true, "toKeep": false},
        {"variable": "religion", "intValue": 10,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "religion", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "flattered", "no": "sad"}
    },
    {
      "id": 1006,
      "label": "vieil_amiral",
      "deck": "ambient",
      "weight": 2,
      "lockturn": 25,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un vieil amiral impérial à la retraite vous propose ses services de renseignement. Il n'est pas fiable, mais ses contacts sont précieux."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "L'engager"}, "reaction": {"FR": "Un informateur risqué mais utile."}},
      "rightAnswer": {"title": {"FR": "Décliner poliment"}, "reaction": {"FR": "Il comprend. Ou feint de comprendre."}},
      "yesOutcome": [
        {"variable": "military", "intValue": 10,  "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [],
      "moods": {"default": "suspicious", "yes": "flattered", "no": "neutral"}
    },
    {
      "id": 1007,
      "label": "festival_terminus",
      "deck": "ambient",
      "weight": 4,
      "lockturn": 30,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Le festival annuel de Terminus approche. La population attend de vous un discours public."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Prendre la parole"}, "reaction": {"FR": "Votre couverture est parfaite. La foule applaudit."}},
      "rightAnswer": {"title": {"FR": "Déléguer à un représentant"}, "reaction": {"FR": "Moins visible, mais plus sûr pour votre couverture."}},
      "yesOutcome": [
        {"variable": "politics",   "intValue": 10,  "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": -5,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "flattered", "no": "neutral"}
    },
    {
      "id": 1008,
      "label": "espion_anacreon",
      "deck": "ambient",
      "weight": 2,
      "lockturn": 20,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Vos agents ont capturé un espion anacréonien sur Terminus. Que faire de lui ?"},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "L'emprisonner"}, "reaction": {"FR": "Un signal fort envoyé à Anacréon."}},
      "rightAnswer": {"title": {"FR": "Le relâcher en échange d'informations"}, "reaction": {"FR": "Un échange discret mais pragmatique."}},
      "yesOutcome": [
        {"variable": "military",              "intValue": 10,  "addOperation": true, "toKeep": false},
        {"variable": "relation_military_kingdoms", "intValue": -15, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "military", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "afraid", "yes": "angry", "no": "suspicious"}
    },
    {
      "id": 1009,
      "label": "journaliste_enquete",
      "deck": "ambient",
      "weight": 3,
      "lockturn": 15,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un journaliste de Terminus enquête sur vos activités. Il se rapproche dangereusement de la vérité."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Le discréditer"}, "reaction": {"FR": "Risqué, mais il se tait."}},
      "rightAnswer": {"title": {"FR": "L'inviter à une interview"}, "reaction": {"FR": "Vous le manipulez habilement."}},
      "yesOutcome": [
        {"variable": "politics",   "intValue": -10, "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": 5,   "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics",   "intValue": 10, "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": -10,"addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "suspicious", "yes": "afraid", "no": "flattered"}
    },
    {
      "id": 1010,
      "label": "don_anonyme",
      "deck": "ambient",
      "weight": 2,
      "lockturn": 30,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un don anonyme de 10 000 crédits est déposé pour la Fondation. L'origine est inconnue."},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Accepter sans poser de questions"}, "reaction": {"FR": "L'argent est propre, officiellement."}},
      "rightAnswer": {"title": {"FR": "Enquêter sur l'origine"}, "reaction": {"FR": "Trois semaines plus tard : c'était un test de loyauté."}},
      "yesOutcome": [
        {"variable": "commerce", "intValue": 15, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "commerce",  "intValue": 5,  "addOperation": true, "toKeep": false},
        {"variable": "military",  "intValue": 5,  "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "neutral", "no": "suspicious"}
    }
  ]
  ```

- [ ] **Step 2 : Ajouter 10 cartes `hardin_era` (ère Hardin, ans 1-80)**

  Ajouter ces cartes au tableau JSON existant (à la suite des cartes ambient) :

  ```json
    {
      "id": 2001,
      "label": "pression_anacreon_debut",
      "deck": "hardin_era",
      "weight": 4,
      "lockturn": 10,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Anacréon exige que Terminus cesse de former des techniciens pour ses rivaux."},
      "conditions": [{"variable": "year", "op": "above", "value": 10}],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Accepter"}, "reaction": {"FR": "Anacréon est satisfait. Pour l'instant."}},
      "rightAnswer": {"title": {"FR": "Refuser"}, "reaction": {"FR": "La tension monte entre les deux mondes."}},
      "yesOutcome": [
        {"variable": "relation_military_kingdoms", "intValue": 15,  "addOperation": true, "toKeep": false},
        {"variable": "commerce",                   "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "relation_military_kingdoms", "intValue": -20, "addOperation": true, "toKeep": false},
        {"variable": "military",                   "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "angry", "yes": "neutral", "no": "angry"}
    },
    {
      "id": 2002,
      "label": "pretre_scientifique",
      "deck": "hardin_era",
      "weight": 3,
      "lockturn": 12,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un prêtre de l'Église de la Science vous propose de présenter la technologie comme un miracle divin aux populations locales."},
      "conditions": [{"variable": "year", "op": "above", "value": 5}],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Encourager cette approche"}, "reaction": {"FR": "La religion technologique se répand."}},
      "rightAnswer": {"title": {"FR": "Maintenir la neutralité"}, "reaction": {"FR": "La technologie reste de la science, pas de la magie."}},
      "yesOutcome": [
        {"variable": "religion", "intValue": 15, "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": 5,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "religion", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "flattered", "yes": "flattered", "no": "neutral"}
    },
    {
      "id": 2003,
      "label": "encyclopedie_retard",
      "deck": "hardin_era",
      "weight": 3,
      "lockturn": 20,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Le comité de l'Encyclopédie signale un retard de 5 ans. Les ressources manquent."},
      "conditions": [{"variable": "year", "op": "below", "value": 50}],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Injecter des fonds"}, "reaction": {"FR": "L'Encyclopédie reprend son rythme."}},
      "rightAnswer": {"title": {"FR": "Réduire le périmètre"}, "reaction": {"FR": "Moins ambitieuse, mais plus réalisable."}},
      "yesOutcome": [
        {"variable": "commerce", "intValue": -20, "addOperation": true, "toKeep": false},
        {"variable": "religion", "intValue": 10,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "religion", "intValue": -10, "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": -5,  "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "sad", "yes": "neutral", "no": "sad"}
    },
    {
      "id": 2004,
      "label": "noble_provincial",
      "deck": "hardin_era",
      "weight": 2,
      "lockturn": 15,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un noble de province offre de financer la Fondation en échange d'une place dans le Conseil."},
      "conditions": [{"variable": "year", "op": "above", "value": 15}],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Accepter le deal"}, "reaction": {"FR": "Un allié peu scrupuleux, mais des fonds bienvenus."}},
      "rightAnswer": {"title": {"FR": "Refuser"}, "reaction": {"FR": "Il repart offensé. Ses amis le sauront."}},
      "yesOutcome": [
        {"variable": "commerce", "intValue": 15,  "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": -15, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "flattered", "yes": "flattered", "no": "angry"}
    },
    {
      "id": 2005,
      "label": "rumeur_seldon",
      "deck": "hardin_era",
      "weight": 3,
      "lockturn": 25,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "La Crypte de Seldon s'ouvre pour la première fois. Son message est clair : restez calmes. La crise se résoudra d'elle-même."},
      "conditions": [{"variable": "year", "op": "above", "value": 45}],
      "loadOutcome": [
        {"variable": "seldon_vault_opened", "intValue": 1, "addOperation": false, "toKeep": true}
      ],
      "leftAnswer":  {"title": {"FR": "Suivre les instructions de Seldon"}, "reaction": {"FR": "Vous attendez. La psychohistoire guide vos pas."}},
      "rightAnswer": {"title": {"FR": "Agir malgré tout"}, "reaction": {"FR": "Vous déviez du Plan. Les conséquences restent inconnues."}},
      "yesOutcome": [
        {"variable": "religion",   "intValue": 20,  "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": 10,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics",   "intValue": 10, "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": -15,"addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "flattered", "no": "suspicious"}
    },
    {
      "id": 2006,
      "label": "traite_hardin",
      "deck": "hardin_era",
      "weight": 3,
      "lockturn": 15,
      "hidden": false,
      "bearer": "salvor_hardin",
      "question": {"FR": "Salvor Hardin vous confie que la religion technologique est presque prête à remplacer la dépendance militaire d'Anacréon."},
      "conditions": [
        {"variable": "year", "op": "above", "value": 30},
        {"variable": "religion", "op": "above", "value": 40}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Accélérer le processus"}, "reaction": {"FR": "La stratégie de Hardin se déploie à grande vitesse."}},
      "rightAnswer": {"title": {"FR": "Temporiser encore"}, "reaction": {"FR": "Hardin s'impatiente mais respecte votre décision."}},
      "yesOutcome": [
        {"variable": "religion",                   "intValue": 15, "addOperation": true, "toKeep": false},
        {"variable": "relation_military_kingdoms", "intValue": 5,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "religion", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "flattered", "no": "neutral"}
    },
    {
      "id": 2007,
      "label": "attaque_frontier",
      "deck": "hardin_era",
      "weight": 2,
      "lockturn": 20,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Une flotte de raiders de la frontière attaque un convoi de ravitaillement de Terminus."},
      "conditions": [{"variable": "military", "op": "below", "value": 40}],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Envoyer la défense spatiale"}, "reaction": {"FR": "Coûteux mais le convoi est protégé."}},
      "rightAnswer": {"title": {"FR": "Négocier une rançon"}, "reaction": {"FR": "Humiliant, mais les raiders le diront à leurs amis."}},
      "yesOutcome": [
        {"variable": "military", "intValue": -20, "addOperation": true, "toKeep": false},
        {"variable": "commerce", "intValue": 5,   "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "commerce", "intValue": -15, "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "afraid", "yes": "neutral", "no": "desperate"}
    },
    {
      "id": 2008,
      "label": "conseil_terminus",
      "deck": "hardin_era",
      "weight": 3,
      "lockturn": 10,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Le Conseil de Terminus vote une loi limitant les pouvoirs du maire. C'est une attaque directe contre votre couverture."},
      "conditions": [{"variable": "year", "op": "above", "value": 20}],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Accepter le vote"}, "reaction": {"FR": "Vous semblez raisonnable. Votre couverture est renforcée."}},
      "rightAnswer": {"title": {"FR": "Dissoudre le Conseil"}, "reaction": {"FR": "Efficace, mais vous devenez un autocrate aux yeux de tous."}},
      "yesOutcome": [
        {"variable": "politics",   "intValue": -15, "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": 10,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics",   "intValue": 20,  "addOperation": true, "toKeep": false},
        {"variable": "legitimacy", "intValue": -20, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "angry", "yes": "neutral", "no": "afraid"}
    },
    {
      "id": 2009,
      "label": "missionnaire_frontier",
      "deck": "hardin_era",
      "weight": 3,
      "lockturn": 18,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Un missionnaire de l'Église de la Science revient de la frontière avec des nouvelles inquiétantes : Anacréon forme des techniciens sans supervision religieuse."},
      "conditions": [
        {"variable": "year", "op": "above", "value": 25},
        {"variable": "religion", "op": "below", "value": 60}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Envoyer plus de missionnaires"}, "reaction": {"FR": "La foi technologique gagne du terrain."}},
      "rightAnswer": {"title": {"FR": "Ignorer — c'est prévu dans le Plan"}, "reaction": {"FR": "Vous gardez confiance en la psychohistoire."}},
      "yesOutcome": [
        {"variable": "religion", "intValue": 10, "addOperation": true, "toKeep": false},
        {"variable": "commerce", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "religion",                   "intValue": -5, "addOperation": true, "toKeep": false},
        {"variable": "relation_military_kingdoms", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "afraid", "yes": "curious", "no": "neutral"}
    },
    {
      "id": 2010,
      "label": "crise_approche",
      "deck": "hardin_era",
      "weight": 2,
      "lockturn": 30,
      "hidden": false,
      "bearer": "salvor_hardin",
      "question": {"FR": "Hardin vous avertit en privé : 'La première crise de Seldon approche. Tout doit être en place.'"},
      "conditions": [
        {"variable": "year", "op": "above", "value": 40},
        {"variable": "year", "op": "below", "value": 55}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Renforcer la religion technologique"}, "reaction": {"FR": "Votre atout principal est prêt."}},
      "rightAnswer": {"title": {"FR": "Renforcer les défenses militaires"}, "reaction": {"FR": "Une erreur de lecture du Plan, peut-être."}},
      "yesOutcome": [
        {"variable": "religion", "intValue": 15, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "military", "intValue": 15,  "addOperation": true, "toKeep": false},
        {"variable": "religion", "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "desperate", "yes": "flattered", "no": "afraid"}
    }
  ```

- [ ] **Step 3 : Ajouter 10 cartes `new_speaker` (transition entre règnes)**

  Ajouter ces cartes au tableau JSON (à la suite) :

  ```json
    {
      "id": 3001,
      "label": "nouveau_speaker_debut",
      "deck": "new_speaker",
      "weight": 1,
      "lockturn": 0,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "Un nouveau Speaker prend la relève. Seldon murmure depuis la Crypte : 'Le Plan continue. Votre prédécesseur a bien servi.'"},
      "conditions": [],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Assumer l'héritage"}, "reaction": {"FR": "Vous portez le poids de l'histoire."}},
      "rightAnswer": {"title": {"FR": "Tracer votre propre voie"}, "reaction": {"FR": "Chaque Speaker est unique. Le Plan s'adapte."}},
      "yesOutcome": [
        {"variable": "legitimacy", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "legitimacy", "intValue": -5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "flattered", "no": "curious"}
    },
    {
      "id": 3002,
      "label": "heritage_crisis_reussie",
      "deck": "new_speaker",
      "weight": 3,
      "lockturn": 0,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "Votre prédécesseur a traversé la première crise de Seldon dans le couloir. Le Plan avance comme prévu."},
      "conditions": [
        {"variable": "seldon_crisis_1", "op": "equal", "value": 1}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Construire sur cet acquis"}, "reaction": {"FR": "La psychohistoire est de votre côté."}},
      "rightAnswer": {"title": {"FR": "Rester humble — tout peut basculer"}, "reaction": {"FR": "La prudence est la sagesse du Speaker."}},
      "yesOutcome": [
        {"variable": "religion", "intValue": 10, "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": 5,  "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [],
      "moods": {"default": "flattered", "yes": "flattered", "no": "curious"}
    },
    {
      "id": 3003,
      "label": "heritage_crisis_ratee",
      "deck": "new_speaker",
      "weight": 3,
      "lockturn": 0,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "Votre prédécesseur n'a pas traversé la première crise dans le couloir. Le Plan dévie. Vous devez corriger."},
      "conditions": [
        {"variable": "seldon_crisis_1", "op": "equal", "value": -1}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Corriger en urgence"}, "reaction": {"FR": "Une correction est possible. Difficile, mais possible."}},
      "rightAnswer": {"title": {"FR": "Accepter la déviation et s'adapter"}, "reaction": {"FR": "La psychohistoire a des marges de tolérance."}},
      "yesOutcome": [
        {"variable": "military", "intValue": -10, "addOperation": true, "toKeep": false},
        {"variable": "politics", "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [],
      "moods": {"default": "desperate", "yes": "afraid", "no": "sad"}
    },
    {
      "id": 3004,
      "label": "heritage_natural_death",
      "deck": "new_speaker",
      "weight": 2,
      "lockturn": 0,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "Votre prédécesseur est mort de vieillesse, en pleine sagesse. Son dernier message : 'J'ai servi jusqu'au bout. À vous de continuer.'"},
      "conditions": [
        {"variable": "previous_death_type", "op": "equal", "value": "natural"}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Honorer sa mémoire"}, "reaction": {"FR": "La continuité est la force de la Seconde Fondation."}},
      "rightAnswer": {"title": {"FR": "Regarder vers l'avenir"}, "reaction": {"FR": "Chaque règne efface le précédent dans la mémoire des gens."}},
      "yesOutcome": [
        {"variable": "legitimacy", "intValue": 10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [],
      "moods": {"default": "sad", "yes": "sad", "no": "neutral"}
    },
    {
      "id": 3005,
      "label": "mort_vieillesse_speaker",
      "deck": "new_speaker",
      "weight": 1,
      "lockturn": 0,
      "hidden": true,
      "bearer": null,
      "question": {"FR": "Vos forces déclinent. Vous sentez que votre règne touche à sa fin naturelle. Il est temps de passer le flambeau."},
      "conditions": [
        {"variable": "age", "op": "above", "value": 74}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Transmettre le savoir en paix"}, "reaction": {"FR": "Votre dernier acte de Speaker : former votre successeur."}},
      "rightAnswer": {"title": {"FR": "Continuer jusqu'à la fin"}, "reaction": {"FR": "Quelques semaines de plus. Le Plan attend."}},
      "yesOutcome": [
        {"variable": "death_type", "intValue": 0, "addOperation": false, "toKeep": false}
      ],
      "noOutcome": [],
      "moods": {"default": "sad", "yes": "neutral", "no": "desperate"}
    },
    {
      "id": 3006,
      "label": "contexte_ere_hardin",
      "deck": "new_speaker",
      "weight": 3,
      "lockturn": 0,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Vous prenez vos fonctions à Terminus. Les Royaumes militaristes de la frontière regardent la Fondation avec convoitise."},
      "conditions": [
        {"variable": "year", "op": "below", "value": 80}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Évaluer la menace militaire"}, "reaction": {"FR": "La frontière est votre premier défi."}},
      "rightAnswer": {"title": {"FR": "Renforcer la légitimité civile"}, "reaction": {"FR": "Mieux vaut une bonne couverture qu'une bonne armée."}},
      "yesOutcome": [
        {"variable": "military", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "legitimacy", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "afraid", "yes": "neutral", "no": "curious"}
    },
    {
      "id": 3007,
      "label": "contexte_ere_marchands",
      "deck": "new_speaker",
      "weight": 3,
      "lockturn": 0,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "L'ère commerciale s'ouvre. Les marchands galactiques font de Terminus un nœud incontournable de l'économie."},
      "conditions": [
        {"variable": "year", "op": "above", "value": 79},
        {"variable": "year", "op": "below", "value": 250}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Exploiter l'essor commercial"}, "reaction": {"FR": "Le commerce est une arme plus douce que les canons."}},
      "rightAnswer": {"title": {"FR": "Maintenir une distance prudente"}, "reaction": {"FR": "Trop de richesse attire les convoitises."}},
      "yesOutcome": [
        {"variable": "commerce", "intValue": 10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics", "intValue": 5, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "flattered", "no": "suspicious"}
    },
    {
      "id": 3008,
      "label": "contexte_ere_mulet",
      "deck": "new_speaker",
      "weight": 3,
      "lockturn": 0,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "Le Mulet est en vie. La psychohistoire est aveugle à lui. Seldon ne peut rien vous dire. Vous êtes seul."},
      "conditions": [
        {"variable": "year", "op": "above", "value": 289},
        {"variable": "year", "op": "below", "value": 380}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Chercher le Mulet"}, "reaction": {"FR": "Une quête dangereuse sans la psychohistoire."}},
      "rightAnswer": {"title": {"FR": "Protéger les structures en place"}, "reaction": {"FR": "Résister sans comprendre l'ennemi."}},
      "yesOutcome": [
        {"variable": "military", "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "politics", "intValue": -10, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "desperate", "yes": "afraid", "no": "afraid"}
    },
    {
      "id": 3009,
      "label": "planetes_heritage",
      "deck": "new_speaker",
      "weight": 2,
      "lockturn": 0,
      "hidden": false,
      "bearer": null,
      "question": {"FR": "Votre prédécesseur vous a laissé des planètes alliées. Consolider ou s'étendre ?"},
      "conditions": [
        {"variable": "planet_askone_state", "op": "equal", "value": 1}
      ],
      "loadOutcome": [],
      "leftAnswer":  {"title": {"FR": "Consolider les alliés"}, "reaction": {"FR": "Mieux vaut un empire stable qu'un empire grand."}},
      "rightAnswer": {"title": {"FR": "S'étendre vers de nouvelles planètes"}, "reaction": {"FR": "L'expansion est le moteur du progrès."}},
      "yesOutcome": [
        {"variable": "politics", "intValue": 10, "addOperation": true, "toKeep": false}
      ],
      "noOutcome": [
        {"variable": "military", "intValue": -5, "addOperation": true, "toKeep": false},
        {"variable": "commerce", "intValue": 10, "addOperation": true, "toKeep": false}
      ],
      "moods": {"default": "curious", "yes": "neutral", "no": "curious"}
    },
    {
      "id": 3010,
      "label": "quete_regn_assignee",
      "deck": "new_speaker",
      "weight": 2,
      "lockturn": 0,
      "hidden": false,
      "bearer": "hari_seldon",
      "question": {"FR": "La Seconde Fondation vous assigne une mission secrète pour ce règne. Elle doit rester ignorée de tous, y compris de la Première Fondation."},
      "conditions": [],
      "loadOutcome": [
        {"variable": "quest_reign_1_active", "intValue": 1, "addOperation": false, "toKeep": false}
      ],
      "leftAnswer":  {"title": {"FR": "Accepter la mission"}, "reaction": {"FR": "Vous portez un fardeau invisible."}},
      "rightAnswer": {"title": {"FR": "Demander des précisions"}, "reaction": {"FR": "La Seconde Fondation ne donne jamais de précisions."}},
      "yesOutcome": [],
      "noOutcome": [],
      "moods": {"default": "suspicious", "yes": "curious", "no": "curious"}
    }
  ```

- [ ] **Step 4 : Fermer le tableau JSON et valider**

  S'assurer que le fichier se termine par `]` et valider :

  ```bash
  python3 -c "
  import json
  data = json.load(open('data/foundation_cards.json'))
  from collections import Counter
  decks = Counter(c['deck'] for c in data)
  print(f'{len(data)} cards total')
  for deck, count in sorted(decks.items()):
      print(f'  {deck}: {count} cards')
  "
  ```
  Attendu :
  ```
  30 cards total
    ambient: 10 cards
    hardin_era: 10 cards
    new_speaker: 10 cards
  ```

- [ ] **Step 5 : Committer**

  ```bash
  git add data/foundation_cards.json
  git commit -m "feat(data): add 30 prototype cards (ambient, hardin_era, new_speaker)"
  ```

---

## Task 9 : Script de validation globale

**Files:**
- Create: `~/foundation-reigns/scripts/validate_data.py`

- [ ] **Step 1 : Créer le script**

  ```python
  #!/usr/bin/env python3
  """Validate all Foundation game data files for schema correctness."""
  import json, sys, os
  from pathlib import Path

  DATA_DIR = Path(__file__).parent.parent / "data"
  errors = []

  def load(filename):
      path = DATA_DIR / filename
      if not path.exists():
          errors.append(f"MISSING: {filename}")
          return None
      try:
          return json.loads(path.read_text())
      except json.JSONDecodeError as e:
          errors.append(f"JSON ERROR in {filename}: {e}")
          return None

  def check(condition, message):
      if not condition:
          errors.append(message)

  # --- factions.json ---
  factions = load("factions.json")
  if factions:
      check(len(factions) == 9, f"factions.json: expected 9, got {len(factions)}")
      required = {"id", "name", "year_start", "year_end", "primary_resource", "starting_relation"}
      for f in factions:
          missing = required - set(f.keys())
          check(not missing, f"faction '{f.get('id','?')}' missing fields: {missing}")

  # --- planets.json ---
  planets = load("planets.json")
  if planets:
      check(len(planets) == 12, f"planets.json: expected 12, got {len(planets)}")
      required = {"id", "name", "faction", "initial_state", "game_over_if_lost"}
      for p in planets:
          missing = required - set(p.keys())
          check(not missing, f"planet '{p.get('id','?')}' missing fields: {missing}")
          check(p.get("initial_state") in (-1, 0, 1),
                f"planet '{p.get('id','?')}' initial_state must be -1, 0, or 1")
      terminus = next((p for p in planets if p["id"] == "terminus"), None)
      check(terminus is not None, "planets.json: terminus not found")
      check(terminus and terminus.get("game_over_if_lost"), "terminus must have game_over_if_lost=true")

  # --- moods.json ---
  moods = load("moods.json")
  if moods:
      check(len(moods) == 8, f"moods.json: expected 8 moods, got {len(moods)}")
      expected_moods = {"neutral","suspicious","afraid","angry","flattered","curious","sad","desperate"}
      check(set(moods.keys()) == expected_moods, f"moods.json: unexpected keys: {set(moods.keys()) ^ expected_moods}")

  # --- given_names.json + family_names.json ---
  given = load("given_names.json")
  if given:
      check(len(given) >= 40, f"given_names.json: expected >=40, got {len(given)}")
  family = load("family_names.json")
  if family:
      check(len(family) >= 25, f"family_names.json: expected >=25, got {len(family)}")

  # --- characters.json ---
  characters = load("characters.json")
  if characters:
      required = {"name", "deck", "fixed"}
      for cid, c in characters.items():
          missing = required - set(c.keys())
          check(not missing, f"character '{cid}' missing fields: {missing}")

  # --- covers.json ---
  covers = load("covers.json")
  if covers:
      expected_eras = {"hardin","merchants","mallow","mulet","restoration","late_empire"}
      check(set(covers.keys()) == expected_eras, f"covers.json missing eras: {expected_eras - set(covers.keys())}")

  # --- foundation_cards.json ---
  cards = load("foundation_cards.json")
  if cards:
      check(len(cards) >= 20, f"foundation_cards.json: expected >=20 cards, got {len(cards)}")
      ids = [c.get("id") for c in cards]
      check(len(ids) == len(set(ids)), "foundation_cards.json: duplicate IDs found")
      required = {"id","label","deck","weight","lockturn","question","leftAnswer","rightAnswer"}
      for c in cards:
          missing = required - set(c.keys())
          check(not missing, f"card {c.get('id','?')} missing fields: {missing}")
          check("FR" in c.get("question",{}), f"card {c.get('id','?')} missing FR question")
      # Verify referenced factions exist
      if factions:
          faction_ids = {f["id"] for f in factions}
          for c in cards:
              for outcome in c.get("yesOutcome",[]) + c.get("noOutcome",[]) + c.get("loadOutcome",[]):
                  var = outcome.get("variable","")
                  if var.startswith("relation_"):
                      fid = var[len("relation_"):]
                      check(fid in faction_ids, f"card {c.get('id','?')}: unknown faction '{fid}' in outcome")

  # --- Report ---
  if errors:
      print(f"VALIDATION FAILED — {len(errors)} error(s):")
      for e in errors:
          print(f"  ✗ {e}")
      sys.exit(1)
  else:
      print(f"✓ All data files valid")
  ```

- [ ] **Step 2 : Lancer la validation**

  ```bash
  cd ~/foundation-reigns
  python3 scripts/validate_data.py
  ```
  Attendu : `✓ All data files valid`

- [ ] **Step 3 : Committer**

  ```bash
  git add scripts/validate_data.py
  git commit -m "feat(scripts): add data validation script"
  ```

---

## Livrable Phase 1

À la fin de cette phase :

```bash
python3 scripts/validate_data.py
# ✓ All data files valid
```

```bash
find data/ -name "*.json" | sort
# data/characters.json
# data/covers.json
# data/factions.json
# data/family_names.json
# data/foundation_cards.json
# data/given_names.json
# data/moods.json
# data/planets.json
```

Le projet Godot existe, les données sont validées, les 30 cartes prototype sont prêtes. Phase 2 peut commencer.
