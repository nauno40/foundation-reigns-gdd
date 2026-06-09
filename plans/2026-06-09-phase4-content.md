# Phase 4 — Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Écrire 100+ cartes narratives en français couvrant les decks principaux, les quêtes de règne, la crise majeure Anacréon, et définir les couloirs des 6 Crises de Seldon.

**Architecture:** Tout le contenu vit dans `data/foundation_cards.json`. Chaque lot de cartes est validé par `scripts/validate_data.py` avant d'être commité. Aucun code Godot n'est modifié dans cette phase.

**Tech Stack:** JSON, Python 3 (validation), éditeur de texte

**Prerequisite:** Phase 3 complete — le jeu est jouable avec les 30 cartes prototype.

---

## Conventions d'écriture des cartes

### Ton et style

- Phrases courtes, vocabulaires galactique (vaisseaux, planètes, crédits, psychohistoire)
- Pas d'ironie moderne, pas d'humour anachronique
- Le Speaker est toujours désigné par "vous" (2e personne)
- Les personnages importants sont toujours nommés
- Les PNJ ont des noms générés (`{given_name} {family_name}`)

### IDs par deck

| Deck | Plage d'IDs |
|------|-------------|
| `ambient`            | 1001–1999 |
| `hardin_era`         | 2001–2999 |
| `new_speaker`        | 3001–3999 |
| `merchant_era`       | 4001–4999 |
| `religious_missions` | 5001–5999 |
| `mallow_era`         | 6001–6999 |
| `terminus_politics`  | 7001–7999 |
| `crisis_anacreonian_war` | 8001–8099 |
| `crisis_bel_riose`   | 8101–8199 |
| `crisis_mulet_arrival` | 8201–8299 |

### Règles de design

- `weight` : 1 (rare) à 5 (très fréquent). Défaut : 3.
- `lockturn` : ≥ 8 pour les cartes importantes. 0 pour les déclencheurs uniques (`hidden: true`).
- Chaque carte doit avoir au moins 1 outcome sur au minimum 1 resource ou relation.
- Les cartes `new_speaker` n'ont pas de conditions ou des conditions très larges.
- Les cartes de crise majeure ont `hidden: true` et `lockturn: 0`.

---

## Task 1 : 30 cartes supplémentaires `ambient`

**Files:**
- Modify: `~/foundation-reigns/data/foundation_cards.json` (ajouter après ID 1010)

- [ ] **Step 1 : Ajouter cartes 1011–1020 — vie quotidienne variée**

  Ajouter les cartes suivantes au tableau JSON (IDs 1011 à 1020). Chaque carte suit exactement le format défini en Phase 1.

  **Carte 1011 — Contrebande de technologie**
  ```json
  {
    "id": 1011, "label": "contrebande_tech", "deck": "ambient",
    "weight": 2, "lockturn": 20, "hidden": false, "bearer": null,
    "question": {"FR": "Des contrebandiers vendent de la technologie nucléaire aux royaumes de la frontière. La loi interdit cela — mais les bénéfices sont réels."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Fermer les yeux"}, "reaction": {"FR": "Votre couverture de marchand local en profite."}},
    "rightAnswer": {"title": {"FR": "Saisir la cargaison"}, "reaction": {"FR": "Vous appliquez la loi. Vos alliés commerçants sont mécontents."}},
    "yesOutcome": [{"variable": "commerce", "intValue": 10, "addOperation": true, "toKeep": false},
                   {"variable": "politics",  "intValue": -10, "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "politics",  "intValue": 10, "addOperation": true, "toKeep": false},
                   {"variable": "commerce",  "intValue": -5,  "addOperation": true, "toKeep": false}],
    "moods": {"default": "suspicious", "yes": "flattered", "no": "angry"}
  }
  ```

  **Carte 1012 — Famine dans un secteur**
  ```json
  {
    "id": 1012, "label": "famine_secteur", "deck": "ambient",
    "weight": 2, "lockturn": 25, "hidden": false, "bearer": null,
    "question": {"FR": "Une famine frappe un secteur de Terminus après une mauvaise récolte. Les gens réclament une aide d'urgence."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Distribuer des vivres"}, "reaction": {"FR": "Votre générosité est remarquée. Coûteux."}},
    "rightAnswer": {"title": {"FR": "Ouvrir les marchés libres"}, "reaction": {"FR": "Les prix montent. Certains s'enrichissent sur la misère."}},
    "yesOutcome": [{"variable": "commerce", "intValue": -15, "addOperation": true, "toKeep": false},
                   {"variable": "politics",  "intValue": 15,  "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "commerce", "intValue": 10, "addOperation": true, "toKeep": false},
                   {"variable": "politics",  "intValue": -15, "addOperation": true, "toKeep": false}],
    "moods": {"default": "desperate", "yes": "sad", "no": "angry"}
  }
  ```

  **Carte 1013 — Académicien dissident**
  ```json
  {
    "id": 1013, "label": "academicien_dissident", "deck": "ambient",
    "weight": 3, "lockturn": 15, "hidden": false, "bearer": null,
    "question": {"FR": "Un académicien réputé publie un traité remettant en question les bases de la psychohistoire. Cela sème le doute."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Réfuter publiquement"}, "reaction": {"FR": "Vous défendez Seldon. Votre légitimité est renforcée — mais vous vous exposez."}},
    "rightAnswer": {"title": {"FR": "Ignorer — le Plan se prouve lui-même"}, "reaction": {"FR": "Le silence est parfois plus sage que la controverse."}},
    "yesOutcome": [{"variable": "religion",   "intValue": 10,  "addOperation": true, "toKeep": false},
                   {"variable": "legitimacy", "intValue": -10, "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "religion", "intValue": -5, "addOperation": true, "toKeep": false}],
    "moods": {"default": "angry", "yes": "suspicious", "no": "neutral"}
  }
  ```

  **Cartes 1014–1020 :** Même format, thèmes : élection locale, déserteur militaire, commerce de reliques, ingénieur corrompu, rapport d'espionnage, mariage diplomatique, révolte d'étudiants.

  *(Écrire ces 7 cartes en suivant exactement le même format JSON — thèmes libres mais cohérents avec l'univers.)*

- [ ] **Step 2 : Ajouter cartes 1021–1030 — vie quotidienne (suite)**

  10 cartes supplémentaires couvrant : missions scientifiques, trahisons mineures, découvertes archéologiques, diplomatie de voisinage, incidents de frontière.

  *(Même format, IDs 1021–1030.)*

- [ ] **Step 3 : Ajouter cartes 1031–1040 — relations factions**

  10 cartes `ambient` axées sur les relations avec les factions actives (selon year). Utiliser des conditions `year` pour limiter leur apparition à la bonne période.

  *(Même format, IDs 1031–1040.)*

- [ ] **Step 4 : Valider**

  ```bash
  python3 scripts/validate_data.py
  ```
  Attendu : `✓ All data files valid`

  Vérifier le compte :
  ```bash
  python3 -c "
  import json
  cards = json.load(open('data/foundation_cards.json'))
  from collections import Counter
  decks = Counter(c['deck'] for c in cards)
  for deck, count in sorted(decks.items()):
      print(f'  {deck}: {count}')
  print(f'Total: {len(cards)}')
  "
  ```

- [ ] **Step 5 : Committer**

  ```bash
  git add data/foundation_cards.json
  git commit -m "feat(content): add 30 ambient cards (1011-1040)"
  ```

---

## Task 2 : 30 cartes `hardin_era` supplémentaires

**Files:**
- Modify: `~/foundation-reigns/data/foundation_cards.json` (ajouter IDs 2011–2040)

- [ ] **Step 1 : Cartes 2011–2020 — religion comme outil (ans 1-50)**

  10 cartes sur la stratégie de Hardin : utiliser la religion technologique pour contrôler Anacréon. Conditions : `year below 50`.

  Thèmes : prêtres envoyés comme techniciens, miracles technologiques mis en scène, conflit entre science et foi, contrôle des réacteurs nucléaires par le clergé.

  *(Format identique, conditions `year below 50`, bearer optionnel `salvor_hardin`.)*

- [ ] **Step 2 : Cartes 2021–2030 — montée en puissance d'Anacréon (ans 30-70)**

  10 cartes sur la tension croissante avec Anacréon. Conditions : `year above 29`.

  Thèmes : ultimatums, visites d'officiers anacréoniens, marchés forcés, espions capturés, préparatifs militaires.

- [ ] **Step 3 : Cartes 2031–2040 — préparation à la Crise 1 (ans 45-75)**

  10 cartes de setup pour la Crise de Seldon 1. Conditions : `year above 44`, `year below 80`.

  Thèmes : consultations secrètes, renforcement de la Crypte, recrutement de la Seconde Fondation, infiltration d'Anacréon.

- [ ] **Step 4 : Valider et committer**

  ```bash
  python3 scripts/validate_data.py
  git add data/foundation_cards.json
  git commit -m "feat(content): add 30 hardin_era cards (2011-2040)"
  ```

---

## Task 3 : 20 cartes `merchant_era`

**Files:**
- Modify: `~/foundation-reigns/data/foundation_cards.json` (ajouter IDs 4001–4020)

- [ ] **Step 1 : Cartes 4001–4010 — expansion commerciale (ans 80-150)**

  10 cartes sur l'ouverture commerciale galactique. Conditions : `year above 79`, `year below 200`.

  Thèmes : routes commerciales, négociations de contrats, pirates de l'espace, monopoles technologiques, ambassadeurs marchands.

- [ ] **Step 2 : Cartes 4011–4020 — consolidation marchande (ans 150-250)**

  10 cartes sur la domination économique. Conditions : `year above 149`, `year below 250`.

  Thèmes : cartels de l'énergie, corruption d'officiels, concurrence entre marchands, traités commerciaux, dépendance technologique.

- [ ] **Step 3 : Valider et committer**

  ```bash
  python3 scripts/validate_data.py
  git add data/foundation_cards.json
  git commit -m "feat(content): add 20 merchant_era cards (4001-4020)"
  ```

---

## Task 4 : Crise majeure Anacréon — séquence `link` complète

**Files:**
- Modify: `~/foundation-reigns/data/foundation_cards.json` (ajouter IDs 8001–8012)

La crise est une séquence de cartes liées. L'issue finale détermine `seldon_crisis_1`.

### Structure de la séquence

```
Carte 8001 (déclencheur)
  → Gauche (négociation) : link → 8003
  → Droite (résistance)  : link → 8004

Carte 8003 (voie négociation)
  → Gauche (accord complet) : link → 8007
  → Droite (accord partiel)  : link → 8008

Carte 8004 (voie résistance)
  → Gauche (défense religieuse) : link → 8009
  → Droite (confrontation militaire) : link → 8010

Carte 8007 → link → 8011 (dénouement favorable)
Carte 8008 → link → 8011
Carte 8009 → link → 8012 (dénouement : validation crise si religion > 30)
Carte 8010 → link → 8012 (dénouement : échec si military > 60)

Carte 8011 (dénouement A — accord)
  loadOutcome: seldon_crisis_1 = 1 si conditions OK, sinon -1

Carte 8012 (dénouement B — confrontation)
  loadOutcome: seldon_crisis_1 = 1 si religion > 30 ET military < 60, sinon -1
```

- [ ] **Step 1 : Créer les cartes 8001–8004 (ouverture de crise)**

  ```json
  {
    "id": 8001,
    "label": "crise_anacreon_debut",
    "deck": "crisis_anacreonian_war",
    "weight": 1,
    "lockturn": 0,
    "hidden": true,
    "bearer": null,
    "question": {"FR": "Anacréon vient d'envoyer un ultimatum : soumission complète de Terminus ou invasion militaire dans 30 jours. La Crypte de Seldon s'est ouverte — mais son message était : 'Gardez la tête froide.'"},
    "conditions": [
      {"variable": "year", "op": "above", "value": 49},
      {"variable": "year", "op": "below", "value": 81},
      {"variable": "seldon_crisis_1", "op": "equal", "value": 0}
    ],
    "loadOutcome": [
      {"variable": "crisis_anacreon_active", "intValue": 1, "addOperation": false, "toKeep": false}
    ],
    "leftAnswer":  {"title": {"FR": "Négocier — trouver une solution politique"}, "reaction": {"FR": "Vous convoquez l'ambassadeur anacréonien."}},
    "rightAnswer": {"title": {"FR": "Résister — montrer notre force"}, "reaction": {"FR": "Terminus se prépare à la confrontation."}},
    "yesOutcome": [{"variable": "link", "intValue": 8003, "addOperation": false, "toKeep": false}],
    "noOutcome":  [{"variable": "link", "intValue": 8004, "addOperation": false, "toKeep": false}],
    "moods": {"default": "desperate", "yes": "afraid", "no": "angry"}
  },
  {
    "id": 8003,
    "label": "crise_anacreon_negoc",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": null,
    "question": {"FR": "L'ambassadeur écoutera vos propositions. Mais il veut soit un tribut annuel en technologie, soit la reconnaissance de la souveraineté d'Anacréon sur Terminus."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Offrir le tribut technologique"}, "reaction": {"FR": "Vous leur donnez de la technologie — mais sous contrôle religieux."}},
    "rightAnswer": {"title": {"FR": "Proposer une alliance commerciale"}, "reaction": {"FR": "Vous détournez leur attention des armes vers le profit."}},
    "yesOutcome": [{"variable": "link", "intValue": 8007, "addOperation": false, "toKeep": false},
                   {"variable": "religion", "intValue": 15, "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "link", "intValue": 8008, "addOperation": false, "toKeep": false},
                   {"variable": "commerce", "intValue": -10, "addOperation": true, "toKeep": false}],
    "moods": {"default": "suspicious", "yes": "neutral", "no": "curious"}
  },
  {
    "id": 8004,
    "label": "crise_anacreon_resist",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": null,
    "question": {"FR": "Terminus se prépare. Deux stratégies s'affrontent au Conseil : utiliser la religion pour paralyser les techniciens militaires anacréoniens, ou préparer une défense directe."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Stratégie religieuse — priver Anacréon de ses techniciens"}, "reaction": {"FR": "Les prêtres-techniciens d'Anacréon refusent d'activer leurs réacteurs."}},
    "rightAnswer": {"title": {"FR": "Défense militaire directe"}, "reaction": {"FR": "Terminus mobilise sa flotte. La confrontation est inévitable."}},
    "yesOutcome": [{"variable": "link",     "intValue": 8009, "addOperation": false, "toKeep": false},
                   {"variable": "religion", "intValue": 10,   "addOperation": true,  "toKeep": false}],
    "noOutcome":  [{"variable": "link",     "intValue": 8010, "addOperation": false, "toKeep": false},
                   {"variable": "military", "intValue": -15,  "addOperation": true,  "toKeep": false}],
    "moods": {"default": "afraid", "yes": "curious", "no": "angry"}
  }
  ```

- [ ] **Step 2 : Créer les cartes 8007–8010 (développement)**

  ```json
  {
    "id": 8007,
    "label": "crise_anacreon_tribut_ok",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": "salvor_hardin",
    "question": {"FR": "Hardin vous souffle : 'Le tribut technologique sous contrôle religieux est parfait. Ils dépendent de nous pour faire fonctionner leurs propres réacteurs.' L'accord est signé."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Consolider l'accord"}, "reaction": {"FR": "La dépendance d'Anacréon est scellée. Pour l'instant."}},
    "rightAnswer": {"title": {"FR": "Rester vigilant"}, "reaction": {"FR": "La paix est une trêve, pas une victoire."}},
    "yesOutcome": [{"variable": "link", "intValue": 8011, "addOperation": false, "toKeep": false},
                   {"variable": "relation_military_kingdoms", "intValue": 10, "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "link", "intValue": 8011, "addOperation": false, "toKeep": false}],
    "moods": {"default": "flattered", "yes": "neutral", "no": "suspicious"}
  },
  {
    "id": 8008,
    "label": "crise_anacreon_alliance_comm",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": null,
    "question": {"FR": "L'alliance commerciale ralentit l'ultimatum — Anacréon hésite entre la guerre et la prospérité. Vous avez 15 jours pour les convaincre définitivement."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Offrir des avantages commerciaux immédiats"}, "reaction": {"FR": "L'or parle plus fort que les canons."}},
    "rightAnswer": {"title": {"FR": "Menacer de couper la technologie"}, "reaction": {"FR": "Un pari risqué — ils peuvent appeler votre bluff."}},
    "yesOutcome": [{"variable": "link",    "intValue": 8011, "addOperation": false, "toKeep": false},
                   {"variable": "commerce","intValue": -15,  "addOperation": true,  "toKeep": false}],
    "noOutcome":  [{"variable": "link",    "intValue": 8012, "addOperation": false, "toKeep": false}],
    "moods": {"default": "afraid", "yes": "flattered", "no": "angry"}
  },
  {
    "id": 8009,
    "label": "crise_anacreon_religion_win",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": "salvor_hardin",
    "question": {"FR": "La stratégie fonctionne : les prêtres-techniciens d'Anacréon refusent de faire la guerre à la 'Terre sacrée de la Science'. L'amiral anacréonien est seul."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Exiger la capitulation d'Anacréon"}, "reaction": {"FR": "Vous poussez l'avantage jusqu'au bout."}},
    "rightAnswer": {"title": {"FR": "Proposer une paix honorable"}, "reaction": {"FR": "Une victoire tranquille vaut mieux qu'une humiliation."}},
    "yesOutcome": [{"variable": "link",    "intValue": 8012, "addOperation": false, "toKeep": false},
                   {"variable": "religion","intValue": 10,   "addOperation": true,  "toKeep": false}],
    "noOutcome":  [{"variable": "link",    "intValue": 8011, "addOperation": false, "toKeep": false},
                   {"variable": "relation_military_kingdoms", "intValue": 20, "addOperation": true, "toKeep": false}],
    "moods": {"default": "curious", "yes": "angry", "no": "flattered"}
  },
  {
    "id": 8010,
    "label": "crise_anacreon_militaire",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": null,
    "question": {"FR": "La flotte d'Anacréon approche de Terminus. Vos défenses sont en place — mais insuffisantes. La bataille aura lieu dans 48 heures."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Combattre"}, "reaction": {"FR": "Terminus se bat. Pertes des deux côtés."}},
    "rightAnswer": {"title": {"FR": "Demander la médiation de l'Empire"}, "reaction": {"FR": "L'Empire est loin et déclinant, mais son nom a encore du poids."}},
    "yesOutcome": [{"variable": "link",    "intValue": 8012, "addOperation": false, "toKeep": false},
                   {"variable": "military","intValue": -20,  "addOperation": true,  "toKeep": false}],
    "noOutcome":  [{"variable": "link",    "intValue": 8012, "addOperation": false, "toKeep": false},
                   {"variable": "relation_empire", "intValue": 10, "addOperation": true, "toKeep": false}],
    "moods": {"default": "desperate", "yes": "angry", "no": "afraid"}
  }
  ```

- [ ] **Step 3 : Créer les cartes 8011–8012 (dénouements)**

  La logique de validation du couloir est encodée dans les `loadOutcome` via des variables intermédiaires. La validation finale est faite dans `Main.gd` ou via des cartes conditionnelles.

  ```json
  {
    "id": 8011,
    "label": "crise_anacreon_fin_accord",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": "hari_seldon",
    "question": {"FR": "La Crypte s'ouvre. Seldon sourit depuis l'enregistrement : 'La première crise est passée. Vous avez compris que la violence est le dernier recours de l'incompétent.'"},
    "conditions": [],
    "loadOutcome": [
      {"variable": "seldon_crisis_1", "intValue": 1, "addOperation": false, "toKeep": true},
      {"variable": "crisis_anacreon_active", "intValue": 0, "addOperation": false, "toKeep": false}
    ],
    "leftAnswer":  {"title": {"FR": "Honorer la mémoire de Seldon"}, "reaction": {"FR": "Le Plan continue. Votre règne restera dans les mémoires."}},
    "rightAnswer": {"title": {"FR": "Regarder vers la prochaine crise"}, "reaction": {"FR": "Une crise de résolue. Cinq à venir."}},
    "yesOutcome": [{"variable": "religion", "intValue": 10, "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "politics", "intValue": 10, "addOperation": true, "toKeep": false}],
    "moods": {"default": "flattered", "yes": "flattered", "no": "curious"}
  },
  {
    "id": 8012,
    "label": "crise_anacreon_fin_conflit",
    "deck": "crisis_anacreonian_war",
    "weight": 1, "lockturn": 0, "hidden": true, "bearer": "hari_seldon",
    "question": {"FR": "La crise est passée — de justesse. Seldon dans la Crypte : 'Le couloir était étroit. Vous l'avez traversé, ou pas.'"},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Analyser ce qui s'est passé"}, "reaction": {"FR": "La psychohistoire enregistre. Qu'avez-vous appris ?"}},
    "rightAnswer": {"title": {"FR": "Passer à autre chose"}, "reaction": {"FR": "Le présent appelle. Le passé est le passé."}},
    "yesOutcome": [],
    "noOutcome":  [],
    "moods": {"default": "sad", "yes": "curious", "no": "neutral"}
  }
  ```

  Note : la validation du couloir `seldon_crisis_1 = 1` est uniquement dans la carte 8011 (dénouement accord). La carte 8012 laisse le résultat indéterminé — `Main.gd` doit évaluer les conditions du couloir pour la carte 8012 et setter `seldon_crisis_1` en conséquence.

  Modifier `Main.gd` pour ajouter après le `apply_outcomes` de la carte 8012 :
  ```gdscript
  # Dans _on_choice_made, après apply_outcomes :
  if _current_card.get("id") == 8012:
      var religion = _ctx.get_var("religion", 50)
      var military = _ctx.get_var("military", 50)
      var result = 1 if (religion > 30 and military < 60) else -1
      _ctx.set_var("seldon_crisis_1", result, true)
  ```

- [ ] **Step 4 : Valider et committer**

  ```bash
  python3 scripts/validate_data.py
  git add data/foundation_cards.json src/main/Main.gd
  git commit -m "feat(content): add Crisis 1 Anacreon sequence (8001-8012) with Seldon validation"
  ```

---

## Task 5 : 3 quêtes de règne complètes

**Files:**
- Modify: `~/foundation-reigns/data/foundation_cards.json`

Chaque quête de règne : 1 carte déclencheur + 2-3 cartes de progression + 1 carte de résolution.

### Quête de règne 1 — "L'Informateur"

Structure : trouver et recruter un informateur dans les rangs d'Anacréon.

- [ ] **Step 1 : Créer les cartes de la quête "L'Informateur" (IDs 9001–9005)**

  ```json
  {
    "id": 9001, "label": "quete_informateur_debut",
    "deck": "ambient", "weight": 1, "lockturn": 0, "hidden": true,
    "bearer": null,
    "question": {"FR": "Un message anonyme arrive : un officier anacréonien veut déserter et vendre des informations. Rencontrer ?"},
    "conditions": [{"variable": "quest_reign_1_active", "op": "equal", "value": 1}],
    "loadOutcome": [{"variable": "quest_informateur_step", "intValue": 1, "addOperation": false, "toKeep": false}],
    "leftAnswer":  {"title": {"FR": "Organiser la rencontre"}, "reaction": {"FR": "Vous envoyez un émissaire discret."}},
    "rightAnswer": {"title": {"FR": "C'est un piège — ignorer"}, "reaction": {"FR": "Vous restez prudent."}},
    "yesOutcome": [{"variable": "link", "intValue": 9002, "addOperation": false, "toKeep": false}],
    "noOutcome":  [{"variable": "quest_reign_1_active", "intValue": 0, "addOperation": false, "toKeep": false}],
    "moods": {"default": "suspicious", "yes": "curious", "no": "afraid"}
  },
  {
    "id": 9002, "label": "quete_informateur_rencontre",
    "deck": "ambient", "weight": 1, "lockturn": 0, "hidden": true, "bearer": null,
    "question": {"FR": "L'officier vous révèle que la flotte d'Anacréon sera en manœuvres dans 3 semaines — fenêtre idéale pour négocier. Il demande en échange une identité de couverture sur Terminus."},
    "conditions": [],
    "loadOutcome": [],
    "leftAnswer":  {"title": {"FR": "Accepter"}, "reaction": {"FR": "Un allié utile, à garder à distance."}},
    "rightAnswer": {"title": {"FR": "Négocier le prix à la baisse"}, "reaction": {"FR": "Il accepte à contrecœur."}},
    "yesOutcome": [{"variable": "link",     "intValue": 9003, "addOperation": false, "toKeep": false},
                   {"variable": "military", "intValue": 10,   "addOperation": true,  "toKeep": false}],
    "noOutcome":  [{"variable": "link",     "intValue": 9003, "addOperation": false, "toKeep": false},
                   {"variable": "military", "intValue": 5,    "addOperation": true,  "toKeep": false}],
    "moods": {"default": "curious", "yes": "flattered", "no": "suspicious"}
  },
  {
    "id": 9003, "label": "quete_informateur_fin",
    "deck": "ambient", "weight": 1, "lockturn": 0, "hidden": true, "bearer": null,
    "question": {"FR": "L'information s'est avérée exacte. Pendant les manœuvres, vous avez pu avancer trois négociations diplomatiques. Quête accomplie."},
    "conditions": [],
    "loadOutcome": [
      {"variable": "quest_reign_1_active",   "intValue": 0, "addOperation": false, "toKeep": false},
      {"variable": "quest_reign_1_completed","intValue": 1, "addOperation": false, "toKeep": false}
    ],
    "leftAnswer":  {"title": {"FR": "Garder l'informateur actif"}, "reaction": {"FR": "Un réseau discret se forme."}},
    "rightAnswer": {"title": {"FR": "Le mettre en veille — trop risqué"}, "reaction": {"FR": "La prudence avant tout."}},
    "yesOutcome": [{"variable": "military", "intValue": 5,  "addOperation": true, "toKeep": false}],
    "noOutcome":  [{"variable": "politics", "intValue": 5,  "addOperation": true, "toKeep": false}],
    "moods": {"default": "flattered", "yes": "neutral", "no": "suspicious"}
  }
  ```

  Quêtes 2 et 3 : mêmes structure, thèmes différents (IDs 9011-9015 et 9021-9025).

- [ ] **Step 2 : Valider et committer**

  ```bash
  python3 scripts/validate_data.py
  git add data/foundation_cards.json
  git commit -m "feat(content): add 3 reign quests (informer, scholar, merchant)"
  ```

---

## Task 6 : Définir les couloirs des 6 Crises de Seldon

**Files:**
- Modify: `~/foundation-reigns/src/main/Main.gd` (ajouter logique de validation)
- Create: `~/foundation-reigns/data/seldon_crises.json` (documentation des couloirs)

- [ ] **Step 1 : Créer seldon_crises.json**

  ```json
  {
    "crisis_1": {
      "name": "Anacréon exige la soumission",
      "year_window": [50, 80],
      "corridor": {
        "religion_above": 30,
        "military_below": 60,
        "relation_military_kingdoms_above": -30
      },
      "description": "La religion technologique doit être établie avant la crise. La confrontation militaire directe est un échec du Plan."
    },
    "crisis_2": {
      "name": "Général Bel Riose attaque",
      "year_window": [200, 250],
      "corridor": {
        "commerce_above": 40,
        "relation_empire_above": -20
      },
      "description": "L'Empire attaque alors qu'il est déjà en déclin. La résistance économique suffit si les relations impériales ne sont pas trop dégradées."
    },
    "crisis_3": {
      "name": "Le Mulet — l'imprévisible",
      "year_window": [290, 320],
      "corridor": {
        "legitimacy_above": 40
      },
      "description": "La psychohistoire est aveugle au Mulet. Seule la légitimité du Speaker protège la Seconde Fondation."
    },
    "crisis_4": {
      "name": "La chasse à la Seconde Fondation",
      "year_window": [350, 400],
      "corridor": {
        "legitimacy_above": 50,
        "relation_first_foundation_below": 60
      },
      "description": "La Première Fondation cherche la Seconde. Il faut être caché (légitimité haute) sans être trop allié (ce qui attirerait les soupçons)."
    },
    "crisis_5": {
      "name": "Les Princes Marchands renversent l'ordre",
      "year_window": [400, 450],
      "corridor": {
        "politics_above": 40,
        "commerce_above": 35
      },
      "description": "Les oligarques prennent le pouvoir. Seule une base politique et commerciale solide permet de survivre à la transition."
    },
    "crisis_6": {
      "name": "Convergence finale",
      "year_window": [900, 1000],
      "corridor": {
        "all_crises_passed": 4
      },
      "description": "La convergence n'est possible que si au moins 4 des 5 premières crises ont été traversées dans le couloir."
    }
  }
  ```

- [ ] **Step 2 : Implémenter la validation des couloirs dans Main.gd**

  Ajouter la méthode `_evaluate_seldon_corridor` à `Main.gd` :
  ```gdscript
  func _evaluate_seldon_corridor(crisis_num: int) -> bool:
      match crisis_num:
          1:
              return (
                  _ctx.get_var("religion", 50) > 30 and
                  _ctx.get_var("military", 50) < 60 and
                  _ctx.get_var("relation_military_kingdoms", 0) > -30
              )
          2:
              return (
                  _ctx.get_var("commerce", 50) > 40 and
                  _ctx.get_var("relation_empire", 0) > -20
              )
          3:
              return _ctx.get_var("legitimacy", 100) > 40
          4:
              return (
                  _ctx.get_var("legitimacy", 100) > 50 and
                  _ctx.get_var("relation_first_foundation", 0) < 60
              )
          5:
              return (
                  _ctx.get_var("politics", 50) > 40 and
                  _ctx.get_var("commerce", 50) > 35
              )
          6:
              var passed = 0
              for i in range(1, 6):
                  if _ctx.get_var("seldon_crisis_%d" % i, 0) == 1:
                      passed += 1
              return passed >= 4
          _:
              return false
  ```

- [ ] **Step 3 : Valider et committer**

  ```bash
  python3 scripts/validate_data.py
  git add data/seldon_crises.json data/foundation_cards.json src/main/Main.gd
  git commit -m "feat(content): define all 6 Seldon crisis corridors"
  ```

---

## Livrable Phase 4

À la fin de cette phase :

```bash
python3 -c "
import json
cards = json.load(open('data/foundation_cards.json'))
from collections import Counter
decks = Counter(c['deck'] for c in cards)
for deck, count in sorted(decks.items()):
    print(f'  {deck}: {count}')
print(f'Total: {len(cards)}')
"
```

Attendu : **≥ 100 cartes** réparties sur les decks principaux.

La crise Anacréon est jouable de bout en bout. Les 3 quêtes de règne fonctionnent. Les 6 couloirs de Seldon sont définis.

Phase 5 (polish + calibrage) peut commencer.
