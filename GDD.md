# Game Design Document — Foundation × Reigns

> **Titre provisoire :** Foundation  
> **Genre :** Narrative card game (swipe)  
> **Moteur :** Godot (mobile + PC)  
> **Univers :** *Foundation* d'Isaac Asimov  
> **Inspiration mécanique :** *Reigns: Three Kingdoms*  
> **Langue principale :** Français (traduction EN post-prototype)  
> **Version GDD :** 1.0 — 09/06/2026  

---

## Table des matières

1. [Vision et Concept](#1-vision-et-concept)
2. [Core Loop](#2-core-loop)
3. [Le Personnage — Speaker de la Seconde Fondation](#3-le-personnage--speaker-de-la-seconde-fondation)
4. [Ressources](#4-ressources)
5. [Légitimité — la jauge cachée](#5-légitimité--la-jauge-cachée)
6. [Le Temps](#6-le-temps)
7. [Factions](#7-factions)
8. [Planètes](#8-planètes)
9. [Système de Quêtes](#9-système-de-quêtes)
10. [Crises de Seldon — jalons narratifs](#10-crises-de-seldon--jalons-narratifs)
11. [Système de Crises (mécanique)](#11-système-de-crises-mécanique)
12. [Système de Mood](#12-système-de-mood)
13. [Le Mulet — événement spécial](#13-le-mulet--événement-spécial)
14. [Decks et Contenu](#14-decks-et-contenu)
15. [Cycle de Vie, Mort et Respawn](#15-cycle-de-vie-mort-et-respawn)
16. [Progression et Rankings](#16-progression-et-rankings)
17. [Personnages](#17-personnages)
18. [Structure des Données](#18-structure-des-données)
19. [Architecture Technique](#19-architecture-technique)
20. [Ce qu'on garde / adapte / supprime de Reigns](#20-ce-quon-garde--adapte--supprime-de-reigns)
21. [Phases de Développement](#21-phases-de-développement)

---

## 1. Vision et Concept

### Elevator pitch

*Foundation* est un jeu de cartes narratif à swipe dans l'univers d'Asimov. Le joueur incarne une succession de **Speakers de la Seconde Fondation** sur 1 000 ans d'histoire galactique. Chaque règne est une partie roguelike : les décisions façonnent l'histoire, la mort est inévitable, mais le **Plan de Seldon** continue.

### Pourquoi Foundation × Reigns ?

*Reigns: Three Kingdoms* a démontré que la mécanique swipe gauche/droite peut porter une narration politique complexe. L'univers Foundation est idéalement adapté :

- **Pas de combat épique** — tout est diplomatie, manipulation, information
- **La psychohistoire** = conditions et probabilités → parfaitement traduisible en système de cartes
- **La mort est une transition** — les Speakers se succèdent, la Fondation perdure
- **Les factions** remplacent naturellement les royaumes de Reigns

### Piliers de design

| Pilier | Description |
|--------|-------------|
| **Décisions lourdes** | Chaque swipe a des conséquences sur les ressources et les relations |
| **Tension permanente** | Les 4 barres peuvent atteindre 0 ou 100 — il n'y a pas de zone de confort |
| **Narration stratifiée** | Règne individuel + arcs multi-règnes + jalons galactiques |
| **Fidélité thématique** | Asimov avant le gameplay — pas de combat, pas de héros solitaire |
| **Rejouabilité** | Roguelike avec progression méta — chaque partie enrichit la suivante |

---

## 2. Core Loop

```
┌──────────────────────────────────────────────────────────┐
│  Nouveau règne — nouveau Speaker                          │
│                          ↓                                │
│  Deck new_speaker → contexte narratif (héritage)          │
│                          ↓                                │
│  Pioche une carte → Question → 2 choix (swipe L/R)        │
│                          ↓                                │
│  Effets : 4 ressources + Légitimité + Mood + Variables    │
│                          ↓                                │
│  Game over ? ────OUI────→ Écran de mort → Nouveau règne   │
│                ↓ NON                                      │
│  Link forcé ? ──OUI──→ Carte imposée (crise majeure)      │
│               ↓ NON                                       │
│  Mort naturelle ? (probabilité si age ≥ 75)               │
│               ↓                                           │
│  Tour suivant ────────────────────────────────────────────┘
└──────────────────────────────────────────────────────────┘
```

Structure héritée de *Reigns: Three Kingdoms* — moteur data-driven, aucune modification du core.

---

## 3. Le Personnage — Speaker de la Seconde Fondation

### Concept

Le joueur n'est jamais le même personnage, mais toujours la même **institution**. Chaque Speaker :

- Est un **Mentalique** (lit et influence les émotions des autres)
- Opère sous une **identité de couverture civile** (personne ne sait qu'il est Speaker)
- Vit entre **35 et 83 ans** selon son règne
- Laisse un **héritage** (variables `toKeep`) au Speaker suivant

### Identités de couverture par ère

L'identité est tirée aléatoirement dans un pool selon l'année galactique active.

| Ère | Fenêtre | Couvertures disponibles |
|-----|---------|------------------------|
| Hardin | Ans 1–80 | Conseiller impérial, Prêtre scientifique, Marchand local |
| Marchands | Ans 80–250 | Négociant interstellaire, Diplomate, Historien |
| Mallow | Ans 200–350 | Prince marchand, Ambassadeur, Ingénieur |
| Mulet | Ans 290–380 | Réfugié, Espion, Conseiller de cour |
| Restauration | Ans 350–600 | Administrateur, Juge, Académicien |
| Late Empire | Ans 600–1000 | Archiviste, Sénateur, Philosophe |

Chaque couverture donne un **bonus de départ +5** sur la ressource liée et influence le mood de certains interlocuteurs.

---

## 4. Ressources

### 4 barres visibles (0–100) — game over à 0 ET à 100

| Ressource | Game over à 0 | Game over à 100 |
|-----------|---------------|-----------------|
| **Militaire** | La Fondation est envahie | Puissance militaire agressive — trahit le Plan |
| **Religion** | L'Église de la Science s'effondre | Théocratie incontrôlable |
| **Commerce** | Faillite et isolement | Monopole corrupteur |
| **Politique** | Anarchie et chaos | Autoritarisme — la Fondation devient l'Empire |

### Seuils d'affichage UI

| Zone | Valeur | Indicateur |
|------|--------|------------|
| Critique bas | < 15 | Rouge clignotant |
| Danger bas | 15–25 | Orange |
| Équilibre | 26–74 | Normal |
| Danger haut | 75–85 | Orange |
| Critique haut | > 85 | Rouge clignotant |

Seuils exacts à calibrer lors des tests de prototype.

---

## 5. Légitimité — la jauge cachée

Variable `legitimacy` (0–100), **jamais affichée directement** au joueur.

### Valeur de départ selon la mort précédente

| Cause de la mort précédente | Légitimité de départ |
|------------------------------|----------------------|
| Premier règne | 100 |
| Mort naturelle | 100 |
| Game over ressource | 80 |
| Démasqué (légitimité à 0) | 50 |

### Ce qui la fait bouger

**↓ Baisser :**
- Choix trop "omniscients" (le Speaker semble tout savoir)
- Manipulation émotionnelle trop visible
- Cartes de suspicion (un PNJ commence à soupçonner)

**↑ Monter :**
- Laisser passer du temps sans agir
- Jouer parfaitement le rôle de couverture
- Cartes de consolidation de couverture

### Quand elle tombe à 0

→ Le Speaker est **démasqué** → fin de règne forcée  
→ Certaines relations de factions démarrent à **-20** au règne suivant

### Signaux textuels (pas de barre)

- Ton des interlocuteurs change progressivement ("vous semblez toujours avoir les bonnes réponses...")
- Mood `suspicious` plus fréquent dans les cartes
- À légitimité critique (< 15) : carte d'avertissement explicite

---

## 6. Le Temps

### 3 variables temporelles — entiers libres

```
year  → avance via outcomes (ex: +1, +5, +10)  — toKeep=true
month → avance via outcomes (ex: +1, +2)
day   → avance via outcomes (ex: +1, +3)
```

- **Pas de débordement automatique** — day ne passe pas automatiquement à month
- 1 tour ≠ 1 unité de temps fixe — les auteurs de cartes gèrent l'avancement

### Durée d'un règne

- Démarrage : ~35–40 ans (`age`)
- Mort naturelle progressive entre 75 et 83 ans
- ~20 Speakers couvrent les 1 000 ans du Plan de Seldon

### Ères narratives

Les decks s'activent selon des **fenêtres d'années** (conditions `year`).

| Ère | Fenêtre | Thème |
|-----|---------|-------|
| Hardin | Ans 1–80 | Religion comme outil politique, menace Anacréon |
| Marchands | Ans 80–250 | Expansion commerciale galactique |
| Mallow | Ans 200–350 | Princes Marchands, confrontation Korell |
| Mulet | Ans 290–380 | Chaos — la psychohistoire échoue |
| Restauration | Ans 350–600 | Reconstruction, rivalités post-Mulet |
| Late Empire | Ans 600–1000 | Convergence vers le Second Empire |

---

## 7. Factions

9 factions actives selon les périodes. Relations de **-100 à +100**, démarrent à 0 par défaut.

| # | Faction | Période | Ressource liée |
|---|---------|---------|----------------|
| 1 | **Empire Galactique** | Ans 1–300 | Politique |
| 2 | **Royaumes Militaristes** (Anacréon + voisins) | Ans 1–150 | Militaire |
| 3 | **Marchands** | Ans 100–400 | Commerce |
| 4 | **Oligarques** (Princes Marchands) | Ans 200–400 | Commerce + Politique |
| 5 | **Ligue des Mondes Autonomes** | Ans 250–350 | Militaire + Religion |
| 6 | **Première Fondation** *(relation interne)* | Ans 1–1000 | Tous |
| 7 | **Église de la Science** | Ans 50–200 | Religion |
| 8 | **Kalgan** | Ans 350–600 | Militaire |
| 9 | **Neotrantor** | Ans 300–500 | Politique |

**Notes de design :**
- Les factions disparaissent progressivement hors de leur période — leurs decks se vident
- Les transitions (Empire → Neotrantor) sont des **cartes narratives**, pas de la logique moteur
- La faction 6 est particulière : trop d'influence sur elle → Légitimité en danger
- Le Mulet n'est **pas une faction** — voir Section 13
- Relations inter-factions (entre factions entre elles) : réservé post-prototype

---

## 8. Planètes

12 planètes comme **états observables** — pas de déplacement physique du joueur.

| # | Planète | Faction liée | État initial | Rôle |
|---|---------|-------------|-------------|------|
| 1 | **Terminus** | Première Fondation | +1 | Base permanente — perdre = game over |
| 2 | **Trantor** | Empire → Seconde Fondation | +1 | Décline, bascule après le sac (~an 300) |
| 3 | **Anacréon** | Royaumes militaristes | -1 | Première grande menace |
| 4 | **Santanni** | Royaumes militaristes | -1 | Royaume des Quatre Provinces |
| 5 | **Smyrno** | Royaumes militaristes | -1 | Royaume des Quatre Provinces |
| 6 | **Askone** | Marchands | 0 | Cible commerciale ère Mallow |
| 7 | **Korell** | Oligarques | 0 | Antagoniste ère Mallow |
| 8 | **Siwenna** | Empire → Neotrantor | 0 | Chute de l'Empire illustrée |
| 9 | **Kalgan** | Mulet → Kalgan | 0 | Base du Mulet, seigneurie après |
| 10 | **Neotrantor** | Neotrantor | 0 | Vestige impérial post-sac de Trantor |
| 11 | **Rossem** | Seconde Fondation | 0 | Planète cachée, late game |
| 12 | **Sayshell** | Église de la Science | 0 | Culte de la Fondation |

### États planètes

```
-1 = hostile    (contre la Fondation)
 0 = neutre
+1 = alignée    (sous influence de la Fondation)
```

Variable `region_X` = entier. Convention -1/0/1 pour le prototype, **extensible** vers une échelle plus fine sans refactoring.

**Règle spéciale :** Terminus ne peut jamais passer à 0 ou -1 — cela déclenche un game over immédiat.

### UI Carte Galactique

Illustration fixe de la galaxie, 12 points lumineux :
- **Vert** = alignée · **Gris** = neutre · **Rouge** = hostile
- Clic/tap → popup : nom, faction, état, événements en cours
- Accessible via bouton depuis l'écran principal

---

## 9. Système de Quêtes

### 3 niveaux coexistants

**Niveau 1 — Quêtes de règne**
- Une par Speaker, active dès le début du règne
- Si non complétée à la mort → disparaît définitivement

**Niveau 2 — Quêtes d'arc**
- Durent plusieurs règnes, progressent via `toKeep`
- Un Speaker plante, le suivant récolte

**Niveau 3 — Jalons galactiques**
- Les 6 Crises de Seldon (Section 10)
- Stockés en `toKeep`, persistent sur toute la partie

### Variables persistantes (toKeep)

```
year                 → année galactique continue
seldon_crisis_1 à 6  → -1 raté / 0 non atteint / 1 validé
arc_X_stage          → progression des quêtes d'arc
planet_X_state       → états des 12 planètes
```

### Deck `new_speaker`

Remplace le deck `after_death` de Reigns. S'active en début de chaque règne, lit les `toKeep` et injecte le contexte narratif (ce que le Speaker précédent a laissé).

---

## 10. Crises de Seldon — jalons narratifs

### Les 6 Crises

| # | Crise | Fenêtre | Ère |
|---|-------|---------|-----|
| 1 | Anacréon exige la soumission de Terminus | Ans 50–80 | Hardin |
| 2 | Le général Bel Riose attaque la Fondation | Ans 200–250 | Mallow |
| 3 | Le Mulet — l'imprévisible | Ans 290–320 | Mulet |
| 4 | La chasse à la Seconde Fondation | Ans 350–400 | Restauration |
| 5 | Les Princes Marchands renversent l'ordre | Ans 400–450 | Restauration |
| 6 | Convergence finale vers le Second Empire | Ans 900–1000 | Late Empire |

### Mécanique du couloir

Chaque crise vérifie des **conditions au loadOutcome** de la carte de crise principale.

```
Exemple — Crise 1 (Anacréon) :
  religion > 30   (religion scientifique établie)
  military < 60   (pas de confrontation directe)
  relation_anacreon > -30

→ Toutes vraies  : seldon_crisis_1 = 1  (jalon validé)
→ Une seule fausse : seldon_crisis_1 = -1 (jalon raté)
```

Les couloirs exacts sont définis lors de l'écriture du contenu, pas dans le moteur.

### Évaluation finale — An 1000

| Jalons validés | Fin |
|---------------|-----|
| 6/6 | **Second Empire** — victoire complète |
| 4–5/6 | **Fondation dominante** — victoire partielle |
| 3/6 | **Équilibre précaire** — fin neutre |
| < 3/6 | **Barbarie prolongée** — échec du Plan |

---

## 11. Système de Crises (mécanique)

### Crise mineure — Proposition A (1 carte)

Pour les menaces courantes, résolution en une carte.

```
"La flotte d'Anacréon patrouille près de Terminus"
  [Gauche] Payer le tribut       → commerce -15
  [Droite] Bluffer avec la flotte → test military > 30
                                    OUI : relation_anacreon +10
                                    NON : military -25
```

### Crise majeure — Proposition C (2–3 cartes via `link`)

Pour les quêtes d'arc et les Crises de Seldon.

```
Carte 1 → choix → link → Carte 2A ou 2B (selon choix précédent)
                               ↓
                          Carte 3 (dénouement narratif)
```

### Tableau comparatif

| | Crise mineure | Crise majeure |
|--|--------------|--------------|
| Cartes | 1 | 2–3 via `link` |
| Deck | Deck normal | Deck `crisis_X` dédié |
| `toKeep` | Non | Oui si jalon Seldon |
| Quête associée | Optionnelle | Toujours |

---

## 12. Système de Mood

Le mood représente l'**état émotionnel de l'interlocuteur** — le Speaker Mentalique le perçoit.

### 8 états

```
neutral    = 0   (défaut)
suspicious = 1   (méfiance, soupçons)
afraid     = 2   (pression, menace)
angry      = 3   (trahison, perte)
flattered  = 4   (manipulation douce, diplomatie)
curious    = 5   (découverte, surprise)
sad        = 6   (deuil, défaite)
desperate  = 7   (crise grave, dernière chance)
```

### 2 effets maximum par carte

**1. Filtre les options disponibles**
```
suspicious → "négocier ouvertement" disparaît du choix
flattered  → option bonus supplémentaire apparaît
afraid     → option agressive coûte moins cher
```

**2. Modifie UN outcome ciblé**
```
angry → la carte de diplomatie donne politics -5 au lieu de +10
```

### Ce que le mood ne fait PAS

- Pas de multiplicateurs globaux sur toutes les ressources
- Pas de durée persistante sur plusieurs tours
- Pas d'effets en cascade entre moods

---

## 13. Le Mulet — événement spécial

Le Mulet n'est **pas une faction** — c'est un événement qui brise la psychohistoire.

- Arrive entre **l'an 290 et 320** de façon aléatoire
- Carte radicalement différente — aucun signal préalable
- Bouleverse **simultanément toutes les relations de factions**
- Correspond à la Crise de Seldon n°3
- Après sa mort (résolution narrative) : active le deck `kalgan_warlord` et la faction Kalgan

---

## 14. Decks et Contenu

**41 decks — ~1 160 cartes** (moyenne ~25 cartes/deck)

### Permanents (~175 cartes)

| Deck | Rôle | ~Cartes |
|------|------|--------|
| `ambient` | Vie quotidienne galactique | 80 |
| `new_speaker` | Transition entre règnes | 30 |
| `seldon_vault` | Messages d'Hari Seldon | 20 |
| `terminus_politics` | Politique interne Terminus | 40 |
| `psychohistory_research` | Recherches psychohistoriques | 30 |
| `spy_network` | Réseau d'information Speaker | 25 |

### Par ère (~365 cartes)

| Deck | Fenêtre | ~Cartes |
|------|---------|--------|
| `encyclopaedia_project` | Ans 1–50 | 20 |
| `hardin_era` | Ans 1–80 | 50 |
| `merchant_era` | Ans 80–250 | 50 |
| `religious_missions` | Ans 50–200 | 35 |
| `mallow_era` | Ans 200–350 | 50 |
| `mulet_era` | Ans 290–380 | 40 |
| `sack_of_trantor` | Ans 295–310 | 15 |
| `interregnum` | Ans 350–420 | 25 |
| `restoration` | Ans 350–600 | 40 |
| `late_empire` | Ans 600–1000 | 50 |
| `second_foundation_hunt` | Ans 350–400 | 20 |

### Par faction (~205 cartes)

| Deck | Faction | ~Cartes |
|------|---------|--------|
| `empire_court` | Empire Galactique | 30 |
| `anacreonian_threat` | Royaumes Militaristes | 25 |
| `merchant_network` | Marchands | 30 |
| `trade_routes` | Marchands | 25 |
| `church_of_science` | Église de la Science | 30 |
| `oligarch_conspiracy` | Oligarques | 25 |
| `kalgan_warlord` | Kalgan | 20 |
| `neotrantor_remnant` | Neotrantor | 15 |

### Personnages clés (~60 cartes)

| Deck | Personnage | ~Cartes |
|------|-----------|--------|
| `hardin_legacy` | Salvor Hardin | 15 |
| `mallow_legacy` | Hober Mallow | 15 |
| `ducem_barr` | Ducem Barr | 10 |
| `bayta_darell` | Bayta Darell | 10 |
| `ebling_mis` | Ebling Mis | 10 |

### Crises majeures (~76 cartes)

| Deck | Déclencheur | ~Cartes |
|------|------------|--------|
| `crisis_anacreonian_war` | year 50–80 | 10 |
| `crisis_bel_riose` | year 200–250 | 10 |
| `crisis_mulet_arrival` | year 290–320 | 12 |
| `crisis_sf_exposed` | year 350–400 | 10 |
| `crisis_merchant_revolt` | year 400–450 | 10 |
| `crisis_terminus_siege` | military < 20 | 8 |
| `crisis_commercial_collapse` | commerce < 15 | 8 |
| `crisis_religious_schism` | religion > 80 | 8 |

### Planètes (~64 cartes)

| Deck | Planète | ~Cartes |
|------|---------|--------|
| `planet_terminus` | Terminus | 15 |
| `planet_trantor` | Trantor | 15 |
| `planet_anacreon` | Anacréon | 12 |
| `planet_kalgan` | Kalgan | 12 |
| `planet_sayshell` | Sayshell | 10 |

---

## 15. Cycle de Vie, Mort et Respawn

### Mort naturelle — probabilité progressive

```
age >= 75 : 5%  de chance par tour → carte "mort naturelle"
age >= 77 : 15%
age >= 79 : 35%
age >= 81 : 60%
age >= 83 : 100% — mort garantie
```

Vers 65–70 ans : cartes évoquent la fatigue et l'âge.  
À partir de 75 : certaines options disparaissent (trop épuisant).  
La mort arrive via une carte narrative dédiée dans le deck `new_speaker` (gating par `age`).

### Respawn — retour au début de l'ère en cours

```
Mort à l'an 60  → repart à l'an 1   (début ère Hardin)
Mort à l'an 120 → repart à l'an 80  (début ère Marchands)
Mort à l'an 280 → repart à l'an 200 (début ère Mallow)
Mort à l'an 320 → repart à l'an 290 (début ère Mulet)
```

Les variables `toKeep` persistent — la mémoire galactique est conservée.

### Fin de règne — score et légitimité suivante

| Cause | Modificateur score | Légitimité suivante |
|-------|--------------------|---------------------|
| Mort naturelle | **×1.5** + carte bonus | 100 |
| Ressource à 0 ou 100 | ×1.0 | 80 |
| Légitimité à 0 (démasqué) | ×1.0 | 50 |

### Procédure de respawn

```
EmptyOfNonKeep()    ← vide tout sauf toKeep=true
year               → début de l'ère en cours
Ressources         → 50
Légitimité         → selon type de mort
age                → 35–40 (aléatoire)
Couverture         → tirée aléatoirement dans le pool de l'ère
Deck new_speaker   → s'active
```

### Écran de mort

- **En-tête :** nom du Speaker, âge, couverture, cause de mort, années couvertes
- **Timeline du règne :** crises traversées, quêtes complétées, jalons validés/ratés
- **État de la galaxie :** 4 ressources, 9 factions, 12 planètes, année galactique
- **Contribution au Plan :** texte narratif ("Le Plan dévie de X%...")
- **Héritage transmis :** variables `toKeep` actives, quêtes d'arc en cours
- **Message holographique de Seldon :** commentaire court sur le règne

---

## 16. Progression et Rankings

### Double progression

- **Score de règne** → contribue à la progression méta
- **Rang méta** → persiste entre toutes les parties, débloque du contenu permanent

### 15 rangs — 3 tiers

| Tier | Rangs | Nom | Débloque |
|------|-------|-----|----------|
| 1 | 1–5 | **Initié** | Decks de base, fins standard |
| 2 | 6–10 | **Speaker** | Decks avancés, crises enrichies |
| 3 | 11–15 | **Psychohistorien** | Fins secrètes, decks late game, vrai dénouement an 1000 |

### Calcul du score de règne

| Action | Points |
|--------|--------|
| Crise Seldon traversée dans le couloir | +200 |
| Règne sans game over ressource | +100 |
| Quête de règne complétée | +150 |
| Quête d'arc avancée | +100 |
| Légitimité maintenue à la mort naturelle | +50 |
| Découverte d'une nouvelle carte | +10 |
| **Mort naturelle (vieillesse)** | **×1.5 sur tout le règne** |

La durée du règne seule ne rapporte pas de points.

### Seuils de rang méta

| Rang | Points cumulés | Rang | Points cumulés |
|------|---------------|------|---------------|
| 1 | 0 | 9 | 12 000 |
| 2 | 500 | 10 | 16 000 |
| 3 | 1 200 | 11 | 21 000 |
| 4 | 2 000 | 12 | 27 000 |
| 5 | 3 000 | 13 | 34 000 |
| 6 | 4 500 | 14 | 42 000 |
| 7 | 6 500 | 15 | 50 000 |
| 8 | 9 000 | | |

Estimation : ~3–5 règnes pour rang 5 · ~15–20 pour rang 10 · ~30–40 pour rang 15

---

## 17. Personnages

### Personnages récurrents (noms fixes, canoniques)

Figures narratives avec sprites dédiés. Noms immuables entre les règnes.

| Personnage | Décks liés | Rôle narratif |
|-----------|-----------|---------------|
| Hari Seldon | `seldon_vault` | Messages enregistrés depuis la Crypte |
| Salvor Hardin | `hardin_legacy` | Premier maire de Terminus |
| Hober Mallow | `mallow_legacy` | Premier Prince Marchand |
| Bayta Darell | `bayta_darell` | Héroïne de l'ère du Mulet |
| Ducem Barr | `ducem_barr` | Érudit, témoin de la chute de l'Empire |
| Ebling Mis | `ebling_mis` | Psychohistorien de remplacement |

### PNJ de remplissage (noms générés)

```
Prénom : pool ~50 prénoms style galactique (futuristes, multiculturels)
Nom    : pool ~30 noms de famille
Genre  : aléatoire ou contraint par le contexte de la carte
```

### Langue

Toutes les cartes sont rédigées en **français** en premier. Traduction anglaise après validation du contenu prototype.

---

## 18. Structure des Données

### Enum Variables

```csharp
custom     = 0    // variables nommées génériques
deck       = 1    // activation/désactivation de deck
military   = 2    // RESSOURCE
religion   = 3    // RESSOURCE
commerce   = 4    // RESSOURCE
politics   = 5    // RESSOURCE
turns      = 6    // tours écoulés
year       = 7    // année galactique (toKeep)
month      = 8    // mois (entier libre)
day        = 9    // jour (entier libre)
quest      = 10   // ID quête + état
link       = 11   // enchaînement forcé de cartes
seen       = 12   // noeud déjà vu
objective  = 13   // objectif
location   = 14   // planète actuelle
region     = 15   // état planète (entier, conv. -1/0/1)
party      = 16   // membre d'équipage présent
relation   = 17   // relation avec faction
mood       = 18   // humeur interlocuteur
faction    = 19   // faction active
age        = 20   // âge du Speaker
legitimacy = 21   // légitimité (cachée, 0–100)
```

### Classes principales

```csharp
class Node {
    int id;
    string label;
    bool hidden;
    int weight;
    int lockturn;
    string bearer;           // deck d'appartenance
    string[] question;       // [FR, EN, ...] — 16 langues max
    Answer leftAnswer;
    Answer rightAnswer;
    List<Condition> conditions;
    List<DataElement> yesOutcome;
    List<DataElement> noOutcome;
    List<DataElement> loadOutcome;
    NodeMoods moods;
}

class Answer {
    string[] title;          // texte du choix affiché
    string[] reaction;       // réaction narrative après swipe
}

class Condition {
    Variables variable;
    int intValue;
    string stringValue;
    Ope operation;           // equal / below / above / not
}

class DataElement {
    Variables variable;
    int intValue;
    string stringValue;
    bool addOperation;       // true = += / false = écraser
    bool toKeep;             // survit à la mort
}

struct NodeMoods {
    Moods mood_default;
    Moods mood_yes;
    Moods mood_no;
}
```

### Format JSON d'une carte

```json
{
  "id": 1042,
  "label": "Délégation d'Anacréon",
  "deck": "anacreonian_threat",
  "weight": 3,
  "lockturn": 15,
  "hidden": false,
  "bearer": "anacreonian_ambassador",
  "question": {
    "FR": "L'ambassadeur anacréonien exige un tribut mensuel.",
    "EN": "The Anacreon ambassador demands a monthly tribute."
  },
  "conditions": [
    { "variable": "year", "op": "above", "value": 50 },
    { "variable": "relation_anacreon", "op": "below", "value": 30 }
  ],
  "loadOutcome": [],
  "leftAnswer": {
    "title": { "FR": "Accepter le tribut", "EN": "Accept the tribute" },
    "reaction": { "FR": "Vous signez l'accord en serrant les dents.", "EN": "You sign the agreement through gritted teeth." }
  },
  "rightAnswer": {
    "title": { "FR": "Refuser poliment", "EN": "Decline politely" },
    "reaction": { "FR": "L'ambassadeur quitte la salle, furieux.", "EN": "The ambassador storms out." }
  },
  "yesOutcome": [
    { "variable": "commerce", "intValue": -15, "addOperation": true },
    { "variable": "relation_anacreon", "intValue": 10, "addOperation": true }
  ],
  "noOutcome": [
    { "variable": "relation_anacreon", "intValue": -20, "addOperation": true },
    { "variable": "military", "intValue": -10, "addOperation": true }
  ],
  "moods": {
    "default": "angry",
    "yes": "neutral",
    "no": "angry"
  }
}
```

---

## 19. Architecture Technique

### Stack

| Couche | Choix |
|--------|-------|
| **Moteur** | Godot 4.x |
| **Plateformes** | Mobile (iOS/Android) + PC |
| **Données** | JSON parsé au démarrage (pas de SQLite) |
| **Langue principale** | Français |
| **Sauvegarde** | JSON automatique après chaque carte, slot unique, local |

### Fichiers de données

```
data/
├── foundation_cards.json     ← toutes les cartes (41 decks)
├── given_names.json          ← ~50 prénoms PNJ
├── family_names.json         ← ~30 noms de famille PNJ
├── factions.json             ← 9 factions
├── planets.json              ← 12 planètes
├── characters.json           ← personnages récurrents fixes
├── covers.json               ← identités de couverture par ère
└── moods.json                ← 8 définitions de mood
```

### Modules Godot

```
FoundationGameData    charge et parse tous les JSON au démarrage
NarrativeModel        sélection de carte, pondération weight, link
Context               état du jeu — toutes les variables runtime
ConditionEvaluator    évaluation AND des conditions de chaque carte
LegitimacySystem      suivi caché, signaux textuels, triggers
RespawnSystem         calcul début d'ère, EmptyOfNonKeep()
DeathScreen           timeline, stats, message holographique Seldon
GalaxyMap             carte statique, planètes cliquables/colorées
UIManager             swipes tactile + souris, barres ressources animées
SaveSystem            JSON, slot unique, auto-save après chaque carte
```

### Boucle principale

```
1. Charger tous les JSON → construire FoundationGameData
2. Charger sauvegarde existante OU initialiser Context (nouveau jeu)
3. Deck new_speaker → première carte du règne
4. BOUCLE :
   a. Évaluer decks actifs (year, conditions de deck, relations)
   b. Filtrer cartes disponibles (conditions, lockturn, seen)
   c. Piocher selon weight
   d. Afficher carte + mood interlocuteur
   e. Joueur swipe (gauche = yes / droite = no)
   f. Appliquer loadOutcome → yesOutcome OU noOutcome
   g. Vérifier game over (ressource 0/100, légitimité 0, Terminus perdue)
   h. Vérifier link forcé → carte suivante imposée ?
   i. Vérifier mort naturelle (age ≥ 75, probabilité par palier)
   j. Sauvegarder
   k. Tour suivant
```

---

## 20. Ce qu'on garde / adapte / supprime de Reigns

### Garde — hérité de Reigns: Three Kingdoms

| Élément | Pourquoi |
|---------|----------|
| Structure Node / Condition / DataElement | Éprouvée, flexible, data-driven |
| Variable `link` (enchaînement forcé) | Cœur des crises majeures |
| Pondération `weight` | Équilibrage fin sans code |
| `lockturn` anti-spam | Évite les répétitions |
| Decks verrouillables / activables | Progression narrative |
| Cycle mort / réincarnation | Roguelike naturel |
| Deck `after_death` → `new_speaker` | Bridge narratif entre règnes |
| Quêtes états entiers | Simple, efficace |
| `seen` pour tracker les cartes vues | Mémoire narrative |

### Adapte

| Élément | Changement |
|---------|-----------|
| 4 ressources | military / religion / commerce / politics |
| `toKeep` | Pleinement exploité (Reigns ne l'utilisait jamais) |
| Mood | Visuel pur → état interlocuteur avec effets mécaniques ciblés |
| Rankings | 15 rangs (Initié / Speaker / Psychohistorien) |
| Régions | Planètes galactiques, états -1/0/1 extensibles |
| Bearer | Personnages canoniques fixes + PNJ générés |
| Respawn | Retour au début de l'ère (pas l'an 1) |

### Nouveau

| Élément | Description |
|---------|-------------|
| Légitimité | Jauge cachée 0–100, signaux textuels uniquement |
| 3 variables temporelles | year (toKeep) + month + day, entiers libres |
| Crises A+C | Mineures (1 carte) + Majeures (séquences link 2–3 cartes) |
| 6 Crises de Seldon | Jalons avec couloirs définis par le contenu |
| Message Seldon | Hologramme commentaire à chaque mort |
| Bonus ×1.5 mort naturelle | Récompense la difficulté de survivre longtemps |
| Double progression | Score règne + rang méta (15 rangs) |
| Carte galactique statique | 12 planètes cliquables colorées par état |
| Identité de couverture | Aléatoire par ère, bonus de départ mineur |
| Mort naturelle progressive | Probabilité croissante 75→83 ans |

### Supprime

| Élément | Remplacé par |
|---------|-------------|
| Combat tactique (battle decks) | Crises narratives (A + C) |
| Mood facial pur | Mood interlocuteur avec effets mécaniques |
| Unités multijoueur | Personnages récurrents + PNJ générés |
| Multijoueur | Hors scope |

### Réservé post-prototype

- Relations inter-factions (entre factions elles-mêmes)
- Cloud save
- États planètes au-delà de -1/0/1
- Localisation anglaise

---

## 21. Phases de Développement

### Phase 1 — Données (1–2 jours)

- [ ] `foundation_cards.json` : 20–30 cartes prototype (`ambient` + `hardin_era`)
- [ ] `given_names.json` + `family_names.json` (~50 + ~30 noms)
- [ ] `factions.json` : 9 factions avec périodes et valeurs de départ
- [ ] `planets.json` : 12 planètes avec états initiaux
- [ ] `characters.json` : personnages récurrents canoniques
- [ ] `covers.json` : identités de couverture par ère
- [ ] `moods.json` : 8 définitions de mood

### Phase 2 — Moteur Godot (3–5 jours)

- [ ] `FoundationGameData` — charge et parse les JSON
- [ ] `Context` — variables runtime, toKeep, legitimacy
- [ ] `ConditionEvaluator` — AND logique, tous les opérateurs
- [ ] `NarrativeModel` — sélection, weight, link, lockturn
- [ ] `LegitimacySystem` — suivi caché, signaux, triggers
- [ ] `RespawnSystem` — calcul ère, EmptyOfNonKeep
- [ ] `SaveSystem` — JSON, slot unique, auto-save

### Phase 3 — UI (3–5 jours)

- [ ] Écran de carte (question, 2 choix, swipe tactile + souris)
- [ ] Barres de ressources animées (seuils danger < 15 / > 85)
- [ ] Expressions faciales selon mood interlocuteur
- [ ] Écran de mort (timeline, stats, message Seldon)
- [ ] Indicateur année galactique + âge Speaker
- [ ] Carte galactique statique cliquable
- [ ] Signaux textuels de légitimité uniquement (pas de barre)

### Phase 4 — Contenu (5–10 jours)

- [ ] 100+ cartes FR pour le contenu principal
- [ ] Decks `hardin_era`, `merchant_era`, `ambient` complets
- [ ] 3 quêtes de règne exemplaires
- [ ] Crise majeure Anacréon complète (séquence link, ~10 cartes)
- [ ] Deck `new_speaker` avec héritage narratif
- [ ] Couloirs des 6 Crises de Seldon définis

### Phase 5 — Polish (2–3 jours)

- [ ] Calibrage seuils de danger et de mort naturelle
- [ ] Calibrage couloirs Seldon
- [ ] Calibrage scores et seuils de rang
- [ ] Musique / SFX
- [ ] Tests du cycle complet (naissance → mort → respawn × 3)

---

## Références

| Fichier | Description |
|---------|-------------|
| `FOUNDATION_PLAN.md` | Document de conception détaillé (sessions de design) |
| `PROPOSITIONS_SYSTEMES.md` | Propositions A/B/C/D pour crises et carte galactique |
| `BIBLE_ANALYSE.md` | Analyse complète de l'architecture de Reigns: Three Kingdoms |
| `REIGNS_DATA_EXPORT/json/cards_fr.json` | 67 decks, 2 454 nœuds — référence structurelle |
| `il2cpp_dump2/dump.cs` | Code C# extrait de Reigns (807 612 lignes) |

---

*GDD v1.0 — Foundation × Reigns — 09/06/2026*
