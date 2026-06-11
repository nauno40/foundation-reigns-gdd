# Foundation Reigns — Game Design Document

> **Version 2.0 — 11/06/2026**
> Document de référence vivant : source de vérité unique du design **et** de l'état d'avancement.
>
> Ce document absorbe et remplace :
> - `reference/REIGNS_DATA_EXPORT/docs/FOUNDATION_PLAN.md` (plan du 09/06/2026) — archivé
> - `reference/REIGNS_DATA_EXPORT/docs/PROPOSITIONS_SYSTEMES.md` (propositions A–D) — archivé
> - Le prototype React `reference/ui-prototype/` reste la maquette visuelle de référence
>
> **Légende des marqueurs :**
> ✅ implémenté · 🔲 prévu (non implémenté) · ⚠️ écart code↔design (le design fait foi → dette) · 🆕 décision nouvelle (11/06/2026) comblant une zone floue du plan original

---

## Table des matières

- [Partie 1 — Vision & Piliers](#partie-1--vision--piliers)
- [Partie 2 — Systèmes de jeu](#partie-2--systèmes-de-jeu)
- [Partie 3 — Univers & Contenu](#partie-3--univers--contenu)
- [Partie 4 — Interface & UX](#partie-4--interface--ux)
- [Partie 5 — Données & Architecture](#partie-5--données--architecture)
- [Partie 6 — État d'avancement & Roadmap](#partie-6--état-davancement--roadmap)

---

# Partie 1 — Vision & Piliers

## 1.1 Pitch

**Vous êtes l'ombre derrière le Plan de Seldon.**

Foundation Reigns est un jeu narratif mobile de cartes à swipe (Reigns-like) dans l'univers de *Fondation* d'Isaac Asimov. Le joueur incarne une succession de **Speakers de la Seconde Fondation** infiltrés sous couverture civile sur mille ans d'histoire galactique. Chaque carte est une décision ; chaque décision déplace quatre ressources et une légitimité cachée ; chaque mort renvoie un nouveau Speaker dans la même timeline galactique, qui continue sans lui.

Le joueur ne s'attache pas à un personnage — il s'attache à **l'institution** et au **Plan**.

## 1.2 Les quatre piliers d'expérience

1. **Le secret comme tension permanente.** Le Speaker est un Mentalique infiltré. Sa légitimité (jauge cachée, sans barre ni chiffre) s'érode quand il est trop omniscient et se reconstruit quand il joue son rôle de couverture. Le joueur la lit dans le ton des textes, jamais dans l'UI.
2. **La continuité galactique.** Une seule timeline de 1 000 ans, ~20 règnes. La mort n'est pas un échec total : les variables `toKeep` (année, crises de Seldon, planètes, arcs) survivent. Un Speaker plante, le suivant récolte.
3. **L'équilibre, pas la maximisation.** Toute ressource à 0 **ou** à 100 tue. La Fondation ne doit être ni faible ni hégémonique — c'est l'esprit du Plan de Seldon traduit en mécanique.
4. **Lire les esprits comme fantasme.** Le mood de l'interlocuteur est affiché en clair (« vous lisez son esprit ») — un avantage d'information que seul un Mentalique possède, et qui nourrit les choix.

## 1.3 Références

- **Moteur & structure** : *Reigns: Three Kingdoms* (Nerial) — moteur de cartes analysé par rétro-ingénierie (`reference/`), structure Node/Condition/DataElement héritée telle quelle.
- **Univers** : le cycle *Fondation* d'Asimov — ères, crises de Seldon, personnages canoniques, Mulet.
- **Maquette UI** : prototype React/JSX (`reference/ui-prototype/Foundation Reigns Prototype.html`) — l'interface Godot doit la reproduire exactement.

---

# Partie 2 — Systèmes de jeu

## 2.1 Core loop ✅

```
┌──────────────────────────────────────────────────────┐
│ Nouveau règne (nouveau Speaker)                       │
│                        ↓                              │
│ Pioche une carte → Question narrative → 2 choix       │
│                        ↓                              │
│ Effets sur les 4 ressources + Légitimité + Mood       │
│                        ↓                              │
│ Vérification game over ? ──OUI──→ Écran de mort       │
│                        ↓ NON                          │
│ Link forcé ? ──OUI──→ Carte suivante imposée          │
│                        ↓ NON                          │
│ Cycle suivant (turn+1) ───────────────────────────────┘
└──────────────────────────────────────────────────────┘
```

Structure identique à Reigns: Three Kingdoms. Moteur hérité tel quel.

**Déroulé d'un tour (implémenté dans `Main.gd`)** :
1. `NarrativeModel.draw_card()` — link forcé prioritaire, sinon filtre (deck actif + conditions + lockturn) puis tirage pondéré par `weight`
2. `loadOutcome` appliqué au chargement de la carte
3. Le joueur swipe gauche/droite → `yesOutcome` / `noOutcome` appliqués
4. Carte marquée vue (`seen_<id>`), `turns+1`, sauvegarde automatique
5. Vérifications : game over ressource/légitimité → mort naturelle (âge) → carte suivante

## 2.2 Personnage joué & identités de couverture

Le joueur incarne une **succession de Speakers de la Seconde Fondation**, chacun sous une **identité de couverture** civile tirée aléatoirement dans le pool de l'ère active.

- Les interlocuteurs viennent voir le **rôle de couverture**, pas le Speaker
- Chaque Speaker est un **Mentalique** — il lit et influence les émotions
- La continuité entre règnes est assurée par le Plan et les variables `toKeep`

### Couvertures par ère (`data/covers.json`) ✅

| Ère | Couvertures possibles |
|-----|-----------------------|
| Hardin (1–80) | Conseiller impérial, Prêtre scientifique, Marchand local |
| Marchands (80–250) | Négociant interstellaire, Diplomate, Historien |
| Mallow (200–350) | Prince marchand, Ambassadeur, Ingénieur |
| Mulet (290–380) | Réfugié, Espion, Conseiller de cour |
| Restauration (350–600) | Administrateur, Juge, Académicien |
| Late Empire (600–1000) | Archiviste, Sénateur, Philosophe |

Chaque couverture donne un **bonus de départ de +5** sur sa ressource liée (`Context.apply_cover()`, appliqué au premier règne et à chaque respawn ✅) et influence le mood de départ de certains interlocuteurs 🔲.

## 2.3 Temps & ères

### Trois variables temporelles libres

```
year  → avance via outcomes des cartes (ex: +1, +5, +10)  — toKeep   ✅
month → avance via outcomes (ex: +1, +2)                              🔲
day   → avance via outcomes (ex: +1, +3)                              🔲
```

- Entiers **indépendants** — pas de débordement automatique, le moteur ne convertit pas day→month→year (responsabilité des auteurs de cartes)
- 1 tour ≠ 1 unité de temps fixe

### Règne

- Un Speaker commence sa couverture à **35–40 ans** (variable `age`) ✅
- Mort naturelle progressive entre **75 et 83 ans** (voir §2.11)
- ~20 Speakers sur les 1 000 ans du Plan

### Ères — fenêtres temporelles

Les crises et decks s'activent dans des **fenêtres d'années**, pas à des dates exactes. Les fenêtres se chevauchent volontairement (transitions narratives douces).

| Ère | Fenêtre | Thème dominant |
|-----|---------|----------------|
| Hardin | Ans 1–80 | Religion comme outil, menace Anacréon |
| Marchands | Ans 80–250 | Expansion commerciale |
| Mallow | Ans 200–350 | Princes Marchands, Korell |
| Mulet | Ans 290–380 | Chaos, imprévisible |
| Restauration | Ans 350–600 | Reconstruction, Kalgan |
| Late Empire | Ans 600–1000 | Vers le Second Empire |

Pour le **respawn**, l'ère d'une année est déterminée par seuils de début (`ERA_STARTS` : 1, 80, 200, 290, 350, 600) — la dernière ère commencée l'emporte. ✅

## 2.4 Ressources ✅

### 4 barres visibles (0–100, départ 50)

| Ressource | À 0 | À 100 |
|-----------|-----|-------|
| **Militaire** | La Fondation se fait envahir | Puissance militaire agressive — contraire au Plan |
| **Religion** | L'Église de la Science s'effondre | Théocratie incontrôlable |
| **Commerce** | Faillite, isolement économique | Monopole corrupteur |
| **Politique** | Chaos, anarchie | Autoritarisme — la Fondation devient l'Empire |

**Game over immédiat quand une ressource atteint 0 OU 100.** ✅

### Seuils d'affichage

| Zone | Valeur | Affichage UI |
|------|--------|--------------|
| Critique bas | < 15 | Bordure rouge pulsante |
| Danger bas | 15–25 | Label ambre |
| Équilibre | 26–74 | Normal |
| Danger haut | 75–85 | Label ambre |
| Critique haut | > 85 | Bordure rouge pulsante |
| Game over | 0 ou 100 | — |

Aucune valeur numérique affichée — lecture purement visuelle (voir §4.3). Seuils à calibrer pendant les tests — la structure est fixe.

## 2.5 Légitimité ✅ (partiel)

Jauge **cachée** (0–100), séparée des 4 ressources. Pas de barre, pas de chiffre — le joueur lit des signaux textuels.

### Valeurs de départ selon la mort précédente

| Type de mort | Légitimité de départ |
|--------------|---------------------|
| Premier règne | 100 |
| Mort naturelle | 100 |
| Game over ressource | 80 |
| Démasqué | 50 |

Les types de mort détaillés (`military_hi`, `legitimacy`, `terminus`…) sont ramenés aux 3 catégories canoniques par `RespawnSystem.normalize_death_type()` avant application de la pénalité. ✅

### Dynamique

**Baisse quand** : choix trop « omniscients » · manipulation émotionnelle trop ouverte · cartes spéciales de soupçon. **Remonte quand** : laisser passer du temps sans agir · choix « naïfs » conformes à la couverture · cartes de consolidation.

Les deltas de légitimité sont portés par les outcomes des cartes (variable `legitimacy`) — pas de logique moteur dédiée. ✅

### Seuils & signaux

| Seuil | État | Signal joueur |
|-------|------|---------------|
| ≥ 30 | normal | aucun |
| < 30 | suspicious | le ton des textes change, mood `suspicious` plus fréquent ; **murmure UI** sous la ligne de mood (§4.6) ✅ (seuil unifié sur `LegitimacySystem.THRESHOLD_SUSPICIOUS` = 30) |
| < 15 | critical | carte d'avertissement explicite 🔲 |
| 0 | démasqué | fin de règne forcée ✅ |

Pénalité supplémentaire après démasquage : certaines relations de factions démarrent à **-20** au règne suivant. 🔲

## 2.6 Mood — l'état émotionnel de l'interlocuteur

Le mood représente l'état émotionnel de l'interlocuteur, que le Speaker Mentalique lit (affiché en clair dans l'UI, §4.5).

### 8 moods

```
neutral    = 0   (par défaut)
suspicious = 1   (soupçons, méfiance)
afraid     = 2   (pression, menace)
angry      = 3   (trahison, perte)
flattered  = 4   (diplomatie, manipulation douce)
curious    = 5   (découverte, surprise)
sad        = 6   (deuil, défaite)
desperate  = 7   (crise grave, dernière chance)
```

Chaque carte définit `moods.default` (à l'affichage), `moods.yes` et `moods.no` (après le choix). ✅ (affichage et stockage ; le code stocke des chaînes, le design prévoit l'enum 0–7 — convention chaîne acceptée, l'enum reste la référence des données ⚠️ mineur)

### Effets mécaniques — deux maximum par carte

1. **Filtre les options** — ex. `suspicious` → « négocier ouvertement » disparaît ; `flattered` → option bonus
2. **Modifie UN outcome ciblé** — ex. `angry` → la diplomatie donne `politics -5` au lieu de `+10`

**Le mood ne fait PAS** : multiplicateurs globaux, durée multi-tours, cascades.

### 🆕 Règle d'implémentation (11/06/2026)

**Zéro nouvelle mécanique moteur.** Les deux effets passent par des **cartes variantes** conditionnées sur la variable `mood` via le système de conditions existant :

- *Filtre d'options* : la carte « négociation » existe en deux versions — l'une avec `condition: mood not suspicious` (option ouverte présente), l'autre avec `condition: mood equal suspicious` (option remplacée)
- *Outcome modifié* : même principe — la variante `mood equal angry` porte des outcomes différents

Coût : duplication de contenu à l'écriture des cartes. Bénéfice : moteur inchangé et déjà testé, aucune nouvelle structure de données. 🔲 (à appliquer en Phase 4 — contenu)

## 2.7 Système de crises

Remplace le battle system de Reigns par des **défis narratifs** (Propositions A + C retenues du document d'origine).

### Crise mineure (Proposition A) — 1 carte

Une carte pose un défi ; deux options avec coûts/tests différents. Le « test » est réalisé par cartes variantes conditionnées (même technique que le mood).

```
"La flotte d'Anacréon patrouille près de Terminus"
  [Gauche] Payer le tribut        → commerce -15
  [Droite] Bluffer avec la flotte → test military > 30
                                    OUI : relation_anacreon +10
                                    NON : military -25
```

### Crise majeure (Proposition C) — séquence de 2–3 cartes via `link`

```
Carte 1 → link → Carte 2A ou 2B (selon choix)
                      ↓
                  Carte 3 (dénouement)
```

Utilisée pour les quêtes d'arc et les Crises de Seldon. Le `link` (carte suivante forcée) est le cœur du système — 2 157 usages dans Reigns d'origine. Moteur `link` ✅ ; cartes de crises 🔲.

| | Crise mineure | Crise majeure |
|--|--------------|---------------|
| Cartes | 1 | 2–3 via `link` |
| Deck | deck normal | deck `crisis_X` dédié |
| `toKeep` | non | oui si jalon Seldon |
| Quête | optionnelle | toujours |

## 2.8 Les 6 Crises de Seldon — jalons du Plan 🔲

Chaque crise est une séquence majeure (deck `crisis_X`) dont le dénouement évalue un **couloir** — un ensemble de conditions AND testées au `loadOutcome` de la carte finale. Toutes vraies → `seldon_crisis_N = 1` (validé) ; au moins une fausse → `seldon_crisis_N = -1` (raté). Variables `toKeep`.

### 🆕 Couloirs chiffrés (11/06/2026 — première calibration, à affiner en playtest)

| # | Crise | Fenêtre | Couloir | Logique narrative |
|---|-------|---------|---------|-------------------|
| 1 | Anacréon exige la soumission | 50–80 | `religion > 30` · `military < 60` · `relation_anacreon > -30` | La religion scientifique désamorce la menace, pas la flotte |
| 2 | Général Bel Riose attaque | 200–250 | `military < 50` · `commerce > 40` · `relation_empire > -50` | L'inaction calculée : l'Empire dévore ses propres généraux, le commerce tient le siège |
| 3 | Le Mulet — l'imprévisible | 290–320 | `legitimacy > 40` · `military < 70` · `commerce > 20` | Résister en restant caché ; toute résistance frontale est broyée |
| 4 | La chasse à la Seconde Fondation | 350–400 | `legitimacy > 50` · `relation_premiere_fondation > 0` · `politics > 30` | Convaincre la Première Fondation que la Seconde est détruite |
| 5 | Les Princes Marchands renversent l'ordre | 400–450 | `commerce > 30` · `commerce < 70` · `politics > 40` | Ni faillite ni monopole — l'ordre tient par les institutions |
| 6 | Convergence finale | 900–1000 | les 4 ressources entre 30 et 70 · `legitimacy > 60` | L'équilibre parfait du Plan, mille ans de discrétion récompensés |

### Évaluation finale — An 1000

| Jalons validés | Fin |
|----------------|-----|
| 6/6 | **Second Empire** — victoire complète |
| 4–5/6 | **Fondation dominante** — victoire partielle |
| 3/6 | **Équilibre précaire** — fin neutre |
| < 3/6 | **Barbarie prolongée** — échec du Plan |

## 2.9 Le Mulet 🔲

Événement spécial — **pas une faction permanente**.

- Arrive entre **l'an 290 et 320** de façon aléatoire — aucun signal avant
- Carte radicalement différente des autres ; bouleverse simultanément toutes les relations de factions
- Impossible à anticiper (la psychohistoire ne fonctionne pas sur les individus exceptionnels)
- Correspond à la Crise de Seldon n°3
- Après sa mort : active le deck `kalgan_warlord` et la faction Kalgan

## 2.10 Système de quêtes 🔲

### 3 niveaux coexistants

| Niveau | Portée | Persistance |
|--------|--------|-------------|
| **1 — Quête de règne** | Une mission personnelle par Speaker | Perdue à la mort |
| **2 — Quête d'arc** | Une par grande ère, multi-règnes | `arc_X_stage` (toKeep) |
| **3 — Jalons galactiques** | Les 6 Crises de Seldon | `seldon_crisis_N` (toKeep) |

### 🆕 Exemples de référence (11/06/2026 — un par niveau, gabarits pour la Phase 4)

- **Règne — « Asseoir la couverture »** : en Prêtre scientifique, amener `religion ≥ 60` avant 10 tours → +150 pts au score de règne. Décliner une variante par couverture (le Négociant vise `commerce`, le Sénateur `politics`…). Implémentation : carte d'ouverture du deck `new_speaker` pose la quête (`quest_reign = 1`), une carte conditionnée valide (`quest_reign = 2`).
- **Arc (ère Hardin) — « L'Église s'étend »** : `arc_church_stage` 0→3 sur plusieurs règnes — implanter des prêtres sur Anacréon (1), puis Santanni (2), puis Smyrno (3). Chaque étape est une crise mineure dans le deck `church_of_science`. Un Speaker plante, le suivant récolte.
- **Galactique** : les 6 Crises de Seldon (§2.8).

### Deck `new_speaker` ✅ (10 cartes prototype)

Remplace `after_death` de Reigns. S'active au début de chaque règne, lit les `toKeep` et injecte le contexte narratif (héritage du règne précédent).

## 2.11 Cycle de vie / Mort / Respawn ✅ (partiel)

### Mort naturelle — déclencheur mécanique ✅

```
age >= 75 : 5 %   de chance par tour
age >= 77 : 15 %
age >= 79 : 35 %
age >= 81 : 60 %
age >= 83 : 100 % — mort garantie
```

Vers 65–70 ans, les cartes mentionnent la fatigue ; à 75+, certaines options disparaissent. 🔲
La mort arrive via une **carte narrative spéciale** (carte `mort_naturelle` id 9001, deck `new_speaker`, portée par Hari Seldon) : le déclencheur probabiliste force un `link` vers cette carte, dont le `loadOutcome` pose `dying = 1` ; l'écran de mort suit le swipe. ✅

### Respawn — retour au début de l'ère en cours ✅

```
Mort à l'an 60  → repart à l'an 1   (début ère Hardin)
Mort à l'an 120 → repart à l'an 80  (début ère Marchands)
Mort à l'an 280 → repart à l'an 200 (début ère Mallow)
Mort à l'an 320 → repart à l'an 290 (début ère Mulet)
```

### Séquence de fin de règne

```
Mort / Game over
  → Écran de mort (§4.8)
  → Calcul du score, enregistrement Legacy          🔲
  → Sauvegarde automatique                           ✅
  → "Nouveau règne" :
      empty_non_keep()        ← vide tout sauf toKeep   ✅
      year → début de l'ère en cours                    ✅
      Ressources → 50                                    ✅
      Légitimité → 100 / 80 / 50 selon mort             ✅
      age → 35–40                                        ✅
      Couverture → tirée du pool de l'ère + bonus +5    ✅
      Deck new_speaker s'active                          ✅
```

### Variables `toKeep` / réinitialisées

| Survivent (toKeep) | Réinitialisées |
|--------------------|----------------|
| `year` (année galactique) | 4 ressources (→ 50) |
| `seldon_crisis_1..6` (-1/0/1) | Légitimité (→ 100/80/50) |
| `arc_X_stage` (quêtes d'arc) | `age` (→ 35–40), `mood` (→ neutral) |
| `planet_X_state` (états planètes) | Équipage/`party`, variables `custom` temporaires |
| `seen_<id>` si marqué toKeep | `turns` (→ 0) |

La perte de Terminus (`planet_terminus_state ≤ 0`) est un game over (type de mort `terminus`, catégorie `resource` au respawn). ✅

## 2.12 Score & progression méta 🔲

### Système double

- **Score de règne** → contribue à la **progression méta**
- **Rang méta** → persiste entre toutes les parties, débloque du contenu permanent

### Calcul du score de règne

| Action | Points |
|--------|--------|
| Crise de Seldon traversée dans le couloir | +200 |
| Règne sans game over ressource | +100 |
| Quête de règne complétée | +150 |
| Quête d'arc avancée | +100 |
| Légitimité maintenue à la mort naturelle | +50 |
| Découverte d'une nouvelle carte | +10 |
| **Mort naturelle (vieillesse)** | **×1.5 sur tout le règne** |

La durée du règne seule ne rapporte rien.

### 15 rangs — 3 tiers × 5

| Tier | Rangs | Nom | Débloque |
|------|-------|-----|----------|
| 1 | 1–5 | **Initié** | Decks de base, fins standard |
| 2 | 6–10 | **Speaker** | Decks avancés, crises enrichies |
| 3 | 11–15 | **Psychohistorien** | Fins secrètes, decks late game, vrai dénouement an 1000 |

Seuils cumulés : 0 / 500 / 1 200 / 2 000 / 3 000 / 4 500 / 6 500 / 9 000 / 12 000 / 16 000 / 21 000 / 27 000 / 34 000 / 42 000 / 50 000.
Rythme visé : ~3–5 règnes pour rang 5, ~15–20 pour rang 10, ~30–40 pour rang 15.

## 2.13 Difficulté 🔲

Trois niveaux, multiplicateur appliqué aux deltas de ressources des outcomes (hérité du prototype React) :

| Niveau | Multiplicateur |
|--------|---------------|
| Doux | ×0.7 |
| Normal | ×1.0 |
| Brutal | ×1.45 |

### 🆕 Règle d'intégration (11/06/2026)

- S'applique **uniquement aux deltas des 4 ressources** (`military`, `religion`, `commerce`, `politics`) — jamais à la légitimité, aux relations, ni aux variables narratives
- Arrondi à l'entier **le plus éloigné de zéro** (un malus de -3 en brutal donne -5, pas -4)
- Choisi au lancement d'une **nouvelle partie** (pas d'un nouveau règne), stocké **hors `Context`** dans la méta-sauvegarde — il survit aux morts et n'est pas effaçable par `empty_non_keep()`

---

# Partie 3 — Univers & Contenu

## 3.1 Les 6 ères

Voir tableau §2.3. Chaque ère a son pool de couvertures (§2.2), ses decks (§3.5) et ses crises (§2.8).

## 3.2 Les 9 factions (`data/factions.json`) ✅ (données) / 🔲 (relations en jeu)

Relations stockées en `relation_<faction_id>` : -100 à +100, départ 0 sauf exception.

| # | Faction | Période active | Ressource liée |
|---|---------|---------------|----------------|
| 1 | **Empire Galactique** | Ans 1–300 | Politique |
| 2 | **Royaumes militaristes** (Anacréon + voisins) | Ans 1–150 | Militaire |
| 3 | **Marchands** | Ans 100–400 | Commerce |
| 4 | **Oligarques** (Princes Marchands) | Ans 200–400 | Commerce + Politique |
| 5 | **Ligue des Mondes Autonomes** | Ans 250–350 | Militaire + Religion |
| 6 | **Première Fondation** *(interne)* | Ans 1–1000 | Tous |
| 7 | **Église de la Science** | Ans 50–200 | Religion |
| 8 | **Kalgan** | Ans 350–600 | Militaire |
| 9 | **Neotrantor** | Ans 300–500 | Politique |

- Les factions s'effacent via leurs decks qui se vident naturellement hors période
- Les **transitions** (ex. Empire → Neotrantor) sont des cartes narratives, pas de logique moteur
- Faction 6 particulière : trop d'influence sur elle → légitimité en danger
- Le Mulet n'est **pas une faction** (§2.9)
- Relations inter-factions : réservé post-prototype

## 3.3 Les 12 planètes (`data/planets.json`) ✅ (données + carte)

États de faction observés — pas de déplacement physique. `planet_<id>_state` : -1 hostile / 0 neutre / +1 alignée. Entier extensible vers une échelle plus fine sans refactoring. Toutes `toKeep`.

| Planète | Faction liée | État initial | Rôle narratif |
|---------|--------------|--------------|---------------|
| **Terminus** | Première Fondation | +1 | Base permanente — perdre = game over (⚠️ non vérifié, §2.11) |
| **Trantor** | Empire → Seconde Fondation | +1 | Décline, bascule après le sac (~an 300) |
| **Anacréon** | Royaumes militaristes | -1 | Première grande menace |
| **Santanni** | Royaumes militaristes | -1 | Royaume des Quatre Provinces |
| **Smyrno** | Royaumes militaristes | -1 | Royaume des Quatre Provinces |
| **Askone** | Marchands | 0 | Cible commerciale ère Mallow |
| **Korell** | Oligarques | 0 | Antagoniste ère Mallow |
| **Siwenna** | Empire → Neotrantor | 0 | Chute de l'Empire |
| **Kalgan** | Mulet → Kalgan | 0 | Base du Mulet, seigneurie après |
| **Neotrantor** | Neotrantor | 0 | Vestige impérial post-sac |
| **Rossem** | Seconde Fondation | 0 | Planète cachée |
| **Sayshell** | Église de la Science | 0 | Culte de la Fondation, late game |

## 3.4 Personnages & noms ✅ (données)

- **Personnages récurrents canoniques** (`data/characters.json`) : noms fixes, sprites dédiés — Hari Seldon, Salvor Hardin, Hober Mallow, Bayta Darell, Ducem Barr, Ebling Mis, et autres figures des livres. Marqués `key = true` → badge « Figure du Plan » dans l'UI (§4.4).
- **PNJ de remplissage** : prénom tiré de `given_names.json` (~50) + nom de `family_names.json` (~30), genre aléatoire ou contextuel.

## 3.5 Les decks — cible : 41 decks, ~1 160 cartes 🔲 (30 cartes ✅)

### Permanents (~175 cartes)

| Deck | ~Cartes | État |
|------|---------|------|
| `ambient` | 80 | ✅ 10 prototype |
| `new_speaker` | 30 | ✅ 10 prototype |
| `seldon_vault` | 20 | 🔲 |
| `terminus_politics` | 40 | 🔲 |
| `psychohistory_research` | 30 | 🔲 |
| `spy_network` | 25 | 🔲 |

### Par ère (~365 cartes)

| Deck | Fenêtre | ~Cartes | État |
|------|---------|---------|------|
| `encyclopaedia_project` | 1–50 | 20 | 🔲 |
| `hardin_era` | 1–80 | 50 | ✅ 10 prototype |
| `merchant_era` | 80–250 | 50 | 🔲 |
| `religious_missions` | 50–200 | 35 | 🔲 |
| `mallow_era` | 200–350 | 50 | 🔲 |
| `mulet_era` | 290–380 | 40 | 🔲 |
| `sack_of_trantor` | 295–310 | 15 | 🔲 |
| `interregnum` | 350–420 | 25 | 🔲 |
| `restoration` | 350–600 | 40 | 🔲 |
| `late_empire` | 600–1000 | 50 | 🔲 |
| `second_foundation_hunt` | 350–400 | 20 | 🔲 |

### Par faction (~205 cartes) 🔲

`empire_court` (30) · `anacreonian_threat` (25) · `merchant_network` (30) · `trade_routes` (25) · `church_of_science` (30) · `oligarch_conspiracy` (25) · `kalgan_warlord` (20) · `neotrantor_remnant` (15)

### Personnages clés (~60 cartes) 🔲

`hardin_legacy` (15) · `mallow_legacy` (15) · `ducem_barr` (10) · `bayta_darell` (10) · `ebling_mis` (10)

### Crises majeures (~76 cartes) 🔲

| Deck | Déclencheur | ~Cartes |
|------|-------------|---------|
| `crisis_anacreonian_war` | year 50–80 | 10 |
| `crisis_bel_riose` | year 200–250 | 10 |
| `crisis_mulet_arrival` | year 290–320 | 12 |
| `crisis_sf_exposed` | year 350–400 | 10 |
| `crisis_merchant_revolt` | year 400–450 | 10 |
| `crisis_terminus_siege` | military < 20 | 8 |
| `crisis_commercial_collapse` | commerce < 15 | 8 |
| `crisis_religious_schism` | religion > 80 | 8 |

### Planètes (~64 cartes) 🔲

`planet_terminus` (15) · `planet_trantor` (15) · `planet_anacreon` (12) · `planet_kalgan` (12) · `planet_sayshell` (10)

## 3.6 Langue

Cartes écrites en **français** d'abord (clé `"FR"`, fallback `"EN"`). Traduction anglaise après validation du contenu (post-prototype).

---

# Partie 4 — Interface & UX

> Référence absolue : le prototype React (`reference/ui-prototype/Foundation Reigns Prototype.html`). L'implémentation Godot doit le reproduire exactement.

## 4.1 Identité visuelle ✅ (thème de base)

Esthétique **holographique sombre sci-fi**. Palette (variables CSS du prototype, à refléter dans le thème Godot) :

| Variable | Valeur | Usage |
|----------|--------|-------|
| `--bg` | `#05070d` | Fond d'application |
| `--accent` | `#4fd6e8` | Cyan holo — couleur interactive principale |
| `--amber` | `#e8b65a` | Messages Seldon, avertissements, badge |
| `--danger` | `#d96a5a` | État critique, cause de mort |
| `--ink` / `--ink-dim` / `--ink-faint` | clair → très atténué | Texte primaire / secondaire / labels |
| `--line` | subtil | Bordures de cartes |
| `--panel` / `--panel-2` | sombre | Fonds de cartes (dégradé) |
| `--military` | orangé | Couleur de ressource |
| `--religion` | violacé | Couleur de ressource |
| `--commerce` | sarcelle | Couleur de ressource |
| `--politics` | verdâtre | Couleur de ressource |

**Typographie :**
- **Spectral** (serif) — tout le texte narratif : questions, réactions, noms, messages Seldon
- **Space Mono** (mono) — boutons UI, indications footer, raccourcis clavier
- system-ui — labels utilitaires (noms de ressources, méta)

## 4.2 Layout de l'écran principal ✅

```
┌─────────────────────────────────┐
│ TOPBAR                          │
│  ÈRE HARDIN · ANS 1–80   [☼]   │  ← label d'ère (accent) + sceau
│  An 42 · 38 ans  Couverture: X  │  ← année / âge / couverture
│  [▲ MIL] [✦ REL] [● COM] [■ POL]│  ← 4 barres de ressources
│  ◉ MÉFIANT — vous lisez son esprit │ ← point de mood + label
│  « Vous semblez toujours... »   │  ← murmure de légitimité (si bas)
├─────────────────────────────────┤
│ ZONE CARTE (flex:1)             │
│   [indice de swipe au repos]    │
│   ┌──── CARTE ───────────────┐  │
│   │ [portrait holo]          │  │
│   │  Nom · Rôle              │  │
│   │  Question (Spectral)     │  │
│   │  [◄ Gauche] [Droite ►]   │  │
│   └──────────────────────────┘  │
├─────────────────────────────────┤
│ FOOTER  Glissez ◄ ►  [←] [→]   │
└─────────────────────────────────┘
```

## 4.3 Barres de ressources ✅

- Barres verticales, **aucune valeur numérique** — lecture visuelle pure
- Icônes : `▲` Militaire, `✦` Religion, `●` Commerce, `■` Politique
- Trois états : **normal** · **warn** (15–25 ou 75–85 → label ambre) · **crit** (< 15 ou > 85 → bordure rouge pulsante, animation `critpulse`)
- **État « affected »** pendant le drag : bordure cyan pulsante (`affpulse`) + pip cyan — révèle **quelles** barres vont changer, jamais la direction ni l'ampleur 🔲

## 4.4 Composant carte ✅

- Largeur `min(360px, 86%)`, coins arrondis 14 px, fond dégradé sombre, bordure interne subtile
- **Portrait holo** (190 px) : fond sombre + grille cyan masquée radialement, buste abstrait (silhouette + cercle de tête avec initiales), scanlines + flicker périodique, nom du porteur (Spectral 18 px) + rôle (cyan 10 px uppercase), badge ambre **« Figure du Plan »** si `card.key = true`
- **Question** : Spectral ~19 px, interligne 1.46, `#eaf0f8`
- **Chips de choix** au repos : `◄ GAUCHE` / `DROITE ►` ; surbrillance cyan + glow quand le drag dépasse le seuil
- **Labels de bord** : titres des réponses aux bords de l'écran pendant le drag (opacité liée au `lean`)
- **Physique de swipe** : seuil 92 px, inclinaison `drag × 0.045°`, fly-out 150 % + 22° en 0.5 s
- **Réaction** : italique centré Spectral, fade-in (`rise`), remplace les chips après le swipe

## 4.5 Indicateur de mood ✅

Point coloré + label uppercase letterspaced + « — vous lisez son esprit » (atténué).

| Mood | Couleur |
|------|---------|
| neutral | `#7d8aa3` | 
| suspicious | `#e0a64f` |
| afraid | `#7fb4d8` |
| angry | `#d96a5a` |
| flattered | `#b98ad6` |
| curious | `#4fd6e8` |
| sad | `#8693a8` |
| desperate | `#c8505a` |

## 4.6 Murmure de légitimité ✅

Quand la légitimité passe sous le seuil suspicious, texte italique ambre sous la ligne de mood :

> *« Vous semblez toujours avoir la bonne réponse, Orateur… »*

C'est le **signal UI principal** de la légitimité basse — pas de barre, pas de chiffre. Seuil unifié sur `LegitimacySystem.THRESHOLD_SUSPICIOUS` (30). ✅

## 4.7 Carte galactique ✅

Illustration fixe de la galaxie, 12 points lumineux colorés par `planet_<id>_state` : vert = alignée, gris = neutre, rouge = hostile. Clic/tap → popup (nom, faction, état, événements en cours). Accessible via bouton depuis l'écran principal.

## 4.8 Écran de mort ✅ (structure) / 🔲 (stats & héritage complets)

Recouvre tout l'écran (backdrop flouté) :

1. **Cause** (rouge, uppercase, letterspaced) — ex. « Orateur démasqué »
2. **h1** — « Orateur — [nom de couverture] » (Spectral 30 px)
3. **Sous-titre** — couverture · âge · « Règne couvert An X → An Y »
4. **Message holographique de Seldon** (boîte ambre, en-tête `☼ MESSAGE — HARI SELDON`, italique Spectral 16 px)
5. **Grille de stats 2×2** : Décisions prises / Années couvertes / Score du règne 🔲 / Déviation du Plan 🔲
6. **Snapshot des ressources** : 4 colonnes (label, valeur, mini-barre)
7. Bouton **« Nouveau règne → »** (cyan, Space Mono, uppercase)

Éléments du design original encore à intégrer 🔲 : timeline des crises traversées/quêtes/jalons, état de la galaxie (factions + planètes), texte « Contribution au Plan », liste de l'héritage `toKeep` transmis.

## 4.9 Messages de Seldon par cause de mort ✅

| Cause | Message (résumé) |
|-------|------------------|
| `military` | Fondation sans défense = bibliothèque attendant l'incendie |
| `military_hi` | Puissance militaire = redevenu l'Empire |
| `religion` | Sans la foi qui voile la science, machines = métal froid |
| `religion_hi` | La théocratie a dévoré la science |
| `commerce` | Isolement économique = siège lent |
| `commerce_hi` | Le monopole a corrompu les marchands |
| `politics` | Chaos = aucune institution ne survit |
| `politics_hi` | Autoritarisme = tyrannie |
| `legitimacy` | L'Orateur exposé met en péril toute la Seconde Fondation |
| `terminus` | Terminus tombée — le Plan n'a plus d'ancre |
| `natural` | Vous avez servi jusqu'à la fin. Le Plan vous remercie |

Textes complets dans `src/ui/ThemeColors.gd` (`death_message`/`death_label`) ; version longue de référence dans `reference/ui-prototype/data.jsx` (`SELDON_MESSAGES`).

---

# Partie 5 — Données & Architecture

## 5.1 Stack & fichiers de données ✅

- **Moteur** : Godot 4.6 (mobile + PC) · **Données** : JSON parsé au démarrage · **Langue** : FR d'abord · **Sauvegarde** : automatique après chaque carte, slot unique, local (`user://foundation_save.json`)

```
data/
├── foundation_cards.json     ← toutes les cartes (cible 41 decks)
├── given_names.json          ← ~50 prénoms PNJ
├── family_names.json         ← ~30 noms PNJ
├── factions.json             ← 9 factions
├── planets.json              ← 12 planètes
├── characters.json           ← personnages canoniques
├── covers.json               ← couvertures par ère
└── moods.json                ← 8 moods
```

## 5.2 Format des cartes ✅

Chaque carte de `foundation_cards.json` :

```jsonc
{
  "id": 1001,                    // entier unique
  "label": "rumeur_terminus",    // identifiant lisible
  "deck": "ambient",             // deck d'appartenance
  "weight": 3,                   // poids de tirage
  "lockturn": 10,                // tours mini avant re-tirage
  "hidden": false,
  "bearer": null,                // id personnage canonique ou null (PNJ généré)
  "question":    { "FR": "…" },  // localisé, fallback EN
  "conditions": [                // logique AND
    { "variable": "year", "op": "above", "value": 50 }
  ],                             // ops: equal | above | below | not
  "loadOutcome": [],             // appliqué à l'affichage de la carte
  "leftAnswer":  { "title": {"FR":"…"}, "reaction": {"FR":"…"} },
  "rightAnswer": { "title": {"FR":"…"}, "reaction": {"FR":"…"} },
  "yesOutcome": [                // swipe gauche
    { "variable": "military", "intValue": -5,
      "addOperation": true,      // true = +=, false = set
      "toKeep": false }          // survit à la mort
  ],
  "noOutcome": [],               // swipe droite
  "moods": { "default": "curious", "yes": "neutral", "no": "suspicious" }
}
```

## 5.3 Namespace des variables de contexte

`Context._vars` est la source de vérité unique de l'état du jeu.

```
custom     = 0    variables nommées génériques
deck       = 1    deck_<name> (0 = désactivé)
military   = 2    RESSOURCE (0–100)
religion   = 3    RESSOURCE
commerce   = 4    RESSOURCE
politics   = 5    RESSOURCE
turns      = 6    tours écoulés
year       = 7    année galactique (toKeep)
month      = 8    mois (entier libre)          🔲
day        = 9    jour (entier libre)          🔲
quest      = 10   ID quête + état              🔲
link       = 11   enchaînement forcé (next card ID)
seen       = 12   seen_<card_id>
objective  = 13   objectif                     🔲
location   = 14   planète actuelle             🔲
region     = 15   planet_<id>_state (-1/0/1, toKeep)
party      = 16   membre d'équipage présent    🔲
relation   = 17   relation_<faction_id> (-100..100)
mood       = 18   humeur interlocuteur (0–7)
faction    = 19   faction active               🔲
age        = 20   âge du Speaker
legitimacy = 21   légitimité cachée (0–100)
```

Variables additionnelles implémentées : `y_start` (année de début du règne, toKeep), `speaker_name`, `cover_name`, `last_death_type` (toKeep), `seldon_crisis_1..6` (toKeep).

## 5.4 Modules Godot ✅

Toutes les classes cœur sont du GDScript pur (pas de `extends Node`) — instanciées par `Main.gd` et passées par référence.

```
Main.gd (racine de scène)
  ├── FoundationGameData   — charge tous les JSON de data/
  ├── Context              — état mutable (_vars + _keep_flags)
  ├── NarrativeModel       — tirage (conditions, lockturn, weight, link)
  ├── ConditionEvaluator   — évaluation AND des conditions
  ├── LegitimacySystem     — seuils et biais de mood
  ├── RespawnSystem        — mort → reset d'ère avec pénalité
  └── SaveSystem           — sérialisation JSON
```

Scènes UI : `CardScreen` (+`SwipeDetector`) · `DeathScreen` · `GalaxyMap` · `ResourceBars`/`ResourceBar` · `MoodIndicator`. Utilitaires : `EraUtils`, `ThemeColors`.

## 5.5 Boucle de chargement & de jeu ✅

```
1. Charger les JSON → FoundationGameData
2. Charger la sauvegarde existante ou initialiser Context
3. Deck new_speaker → première carte du règne
4. Boucle :
   a. Filtrer cartes (deck actif, conditions, lockturn)
   b. Piocher selon weight (link forcé prioritaire)
   c. Afficher carte + mood
   d. Swipe → loadOutcome / yesOutcome / noOutcome
   e. Vérifier game over (ressource 0/100, légitimité 0, Terminus ⚠️)
   f. Vérifier mort naturelle (age ≥ 75, probabilité)
   g. Sauvegarder → tour suivant
```

## 5.6 Sauvegarde ✅

Automatique après chaque carte. Slot unique, JSON local. Le `lockturn` est stocké dans `Context` (`lockturn_<id>` = tour de dernière vue) et survit donc au rechargement via la sauvegarde normale ; il est purgé au respawn par `empty_non_keep()`, ce qui est le comportement voulu (nouveau règne, `turns` repart à 0). ✅

🔲 Méta-sauvegarde séparée (score cumulé, rang, difficulté, cartes découvertes) — nécessaire pour §2.12 et §2.13.

## 5.7 Tests ✅

GUT v9.6.0 (`addons/gut`), 62 tests sur les modules cœur. Un fichier de test par classe (`tests/test_*.gd`), instanciation directe sans scene tree.

```bash
godot --headless -s tests/gut_runner.gd
```

---

# Partie 6 — État d'avancement & Roadmap

## 6.1 Tableau des systèmes

| Système | État |
|---------|------|
| Core loop (tirage, conditions, link, lockturn, weight) | ✅ |
| Context / toKeep / game over ressources & légitimité | ✅ |
| Respawn par ère + pénalités de légitimité (types normalisés) | ✅ |
| Mort naturelle probabiliste 75–83 ans via carte narrative | ✅ |
| Sauvegarde auto slot unique (lockturn persisté) | ✅ |
| UI : carte, swipe, barres, mood, murmure, mort, galaxie | ✅ (🔲 état « affected », mort enrichie) |
| Couvertures par ère avec bonus +5 | ✅ |
| Game over perte de Terminus | ✅ |
| Effets mécaniques du mood (cartes variantes) | 🔲 |
| Crises mineures / majeures, 6 Crises de Seldon | 🔲 |
| Le Mulet | 🔲 |
| Quêtes (règne / arc / galactique) | 🔲 |
| Score de règne + 15 rangs méta + méta-sauvegarde | 🔲 |
| Difficulté ×0.7/×1.0/×1.45 | 🔲 |
| Pénalité relations -20 après démasquage | 🔲 |
| `month`/`day`, `location`, `party`, `faction` active | 🔲 |
| Localisation EN | 🔲 (post-prototype) |

## 6.2 Écarts code↔design — dette **résolue le 11/06/2026**

| # | Écart | Résolution |
|---|-------|------------|
| 1 | Bug légitimité au respawn (démasqué redémarrait à 80 au lieu de 50) | ✅ `RespawnSystem.normalize_death_type()` ramène les types détaillés aux 3 catégories canoniques |
| 2 | Bonus de couverture +5 non appliqué | ✅ `Context.apply_cover()`, appelé au premier règne et à chaque respawn |
| 3 | Perte de Terminus ≠ game over | ✅ Testé dans `Context.is_game_over()` (défaut +1 si variable absente) ; type de mort `terminus` avec label et message Seldon dédiés |
| 4 | Mort naturelle sans carte narrative | ✅ Carte `mort_naturelle` (id 9001, deck `new_speaker`) forcée par `link` ; son `loadOutcome` pose `dying = 1`, l'écran de mort suit le swipe |
| 5 | Lockturn non persisté | ✅ Stocké dans `Context` (`lockturn_<id>`) — sauvegardé avec le reste, purgé au respawn |
| 6 | Seuil du murmure : 35 (prototype) vs 30 (design) | ✅ Unifié sur `LegitimacySystem.THRESHOLD_SUSPICIOUS` |
| 7 | Mood en chaînes vs enum 0–7 du design | ✅ Convention chaîne actée dans les données ; l'enum reste la référence documentaire (aucun changement de code) |

## 6.3 Contenu

**30 / ~1 160 cartes** (3 decks prototype : `ambient` 10, `hardin_era` 10, `new_speaker` 10). Schéma d'enchaînement actuel : `docs/schema_cartes.md`.

## 6.4 Phases restantes

### Phase 4 — Contenu (5–10 j) 🔲
- 100+ cartes FR (decks `hardin_era`, `merchant_era`, `ambient` complets)
- Crise majeure Anacréon (séquence link, ~10 cartes) avec couloir §2.8
- Deck `new_speaker` enrichi (héritage narratif ; la carte de mort naturelle existe, en écrire des variantes)
- 3 quêtes de règne + 1 quête d'arc sur les gabarits §2.10
- Cartes variantes de mood (règle §2.6)

### Phase 5 — Polish (2–3 j) 🔲
- Calibrage : seuils de danger, mort naturelle, couloirs Seldon, scores et rangs
- Difficulté (§2.13) + méta-sauvegarde
- Musique / SFX
- Tests du cycle complet (naissance → mort → respawn → héritage)

### Post-prototype 🔲
- Relations inter-factions · Cloud save · États planètes au-delà de -1/0/1 · Localisation EN

---

## Annexe — Sources & héritage Reigns

| Source | Contenu |
|--------|---------|
| `reference/REIGNS_DATA_EXPORT/docs/FOUNDATION_PLAN.md` | Plan original (09/06/2026) — absorbé par ce document |
| `reference/REIGNS_DATA_EXPORT/docs/PROPOSITIONS_SYSTEMES.md` | Propositions A–D (crises) et 1–4 (carte) — A + C et carte statique retenues |
| `reference/design-docs/BIBLE_ANALYSE.md` | Analyse de l'architecture du moteur Reigns |
| `reference/REIGNS_DATA_EXPORT/json/cards_fr.json` | 67 decks, 2 454 nœuds de référence Reigns |
| `reference/ui-prototype/` | Maquette React — référence visuelle vivante |
| `reference/design-docs/phase-plans/` | Plans d'implémentation des phases 1–5 |

### Hérité de Reigns inchangé
Structure Node/Condition/DataElement · `link` (cœur des crises majeures) · `weight` · `lockturn` · decks verrouillables · cycle mort/réincarnation · `after_death` → `new_speaker` · quêtes à états entiers · `seen`.

### Supprimé de Reigns
Combat tactique (→ crises narratives A+C) · mood facial (→ mood Mentalique) · unités multijoueur (→ personnages + PNJ) · multijoueur.
