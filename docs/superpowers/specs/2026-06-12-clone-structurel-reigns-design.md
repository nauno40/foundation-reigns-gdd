# Clone structurel 1:1 — Reigns: Three Kingdoms → Foundation Reigns

**Date** : 2026-06-12 · **Statut** : validé (design approuvé en session)

## Contexte

Le contenu actuel (131 cartes) a été écrit sans suivre la grammaire narrative du jeu
de base. L'analyse du jeu décompilé (`reference/`) montre que *Reigns: Three Kingdoms*
est construit très différemment : 56 % des 2 454 nœuds sont des cartes de séquence
(`hidden`, atteintes par `link`), organisées en 67 decks aux rôles précis, avec des
personnages récurrents portant jusqu'à 189 cartes dans 35 decks. Objectif : **cloner
exactement ces structures narratives** en transposant tout dans l'univers de Fondation.

## Décisions actées

| Question | Décision |
|---|---|
| Volume | **Clone 1:1 complet** — 67 decks, ~2 454 nœuds à terme |
| Espace → ? | **Régions → planètes** — voyage entre les 12 planètes, GalaxyMap interactive, decks filtrés par `location` |
| Combat → ? | **Duels mentaliques** — affrontements psychiques (Mulet, agents, foules), structure des battle-decks conservée |
| Personnages | **Rôles + Seldon** — Seldon récurrent partout (Crypte/hologrammes) ; rôles institutionnels persistants dont le visage change par ère ; figures canoniques dans leur ère |
| Méthode | **Squelettes extraits** — outil d'extraction du graphe anonyme de chaque deck original, remplissage deck par deck, diff structurel automatique |

## Garde-fou propriété intellectuelle

Les squelettes extraits ne contiennent **aucun texte** du jeu original (uniquement la
topologie : liens, hidden, weights, lockturns, forme des conditions, emplacements de
bearers). Toute la prose est écrite originale pour Fondation. Les textes du jeu de
base ne sont jamais copiés, traduits ni paraphrasés.

## 1. Principe

Pour chaque deck original : même nombre de nœuds, mêmes arêtes (`link` par réponse),
mêmes proportions hidden/aléatoire, mêmes weights/lockturns, mêmes emplacements de
personnages récurrents, même forme de conditions (en variables Fondation). Seule la
peau change. Des cartes *peuvent être ajoutées* ponctuellement pour la cohérence
narrative (signalées dans le diff structurel comme additions assumées).

## 2. Mapping complet des 67 decks

### Decks systémiques

| Original | Taille (hidden) | Fondation | Logique |
|---|---|---|---|
| commoner | 320 (162h) | `ambient` | Citoyens de la planète courante |
| region_ruler | 280 (79h) | `planet_ruler` | Pouvoir local : roi, Commdor, vice-roi, Maire |
| mainline | 172 (56h) | `seldon_plan` | Colonne vertébrale 1 000 ans, porte les 6 crises |
| after_death | 169 (108h) | `new_speaker` | Pont entre règnes, héritage |
| deaths | 53 (37h) | `deaths` | Morts du Speaker |
| movement | 39 (16h) | `hyperjumps` | Voyage entre planètes |
| start | 26 (23h) | `start` | Ouverture de partie |
| battle / bot / dev | 1+1+1 | `duel` / `bot` / `dev` | Nœuds techniques |

### Decks régionaux → planétaires

| Original | Taille | Fondation |
|---|---|---|
| region_jingzhou | 36 | `planet_terminus` |
| region_yuzhou | 29 | `planet_anacreon` |
| region_xuzhou | 24 | `planet_trantor` |
| region_yangzhou | 21 | `planet_korell` |
| region_youzhou | 14 | `planet_kalgan` |
| region_yizhou | 12 | `planet_askone` |
| region_yanzhou | 9 | `planet_siwenna` |
| region_liangzhou | 8 | `planet_smyrno` |
| region_qingzhou | 7 | `planet_santanni` |
| region_jizhou | 4 | `planet_neotrantor` |
| *(additions assumées)* | — | `planet_rossem`, `planet_sayshell` (petits decks, cohérence 12 planètes) |

### Arcs narratifs (par fonction structurelle)

| Original | Taille (hidden) | Fondation | Transposition |
|---|---|---|---|
| jingzhou_liu_biao | 92 (64h) | `anacreon_throne` | La cour d'Anacréon : roi enfant, régent Wienis (ère Hardin) |
| jizhou_ghostbuster | 70 (59h) | `mentalic_inquiry` | Enquêtes sur des phénomènes « surnaturels » = traces mentaliques |
| honey_trap | 66 (53h) | `infiltration` | Séduction/retournement d'agents |
| defenders | 64 (41h) | `terminus_defense` | Sièges et défenses de Terminus |
| marriage | 64 (36h) | `cover_union` | Mariage de l'identité de couverture |
| hangzhong_zhang_lu | 62 (31h) | `church_primate` | Le Grand Prêtre et son fief théocratique |
| yellow_turbans | 61 (44h) | `church_schism` | Schisme millénariste de l'Église de la Science |
| yizhou_silk | 49 (41h) | `transmuter_trade` | Commerce des transmuteurs (la « soie » de la périphérie) |
| qingzhou_scholar | 44 (37h) | `encyclopaedia` | Les Encyclopédistes |
| formidable_young_lord | 34 (19h) | `gifted_orphan` | L'orphelin surdoué (préfigure le Mulet, ans 250–290) |
| legend_of_beauty | 33 (29h) | `lady_callia` | La courtisane de Kalgan |
| red_cliffs | 33 (21h) | `fall_of_terminus` | La chute de Terminus devant le Mulet (crise 3) |
| guandu_battles | 32 (22h) | `riose_campaign` | La campagne de Bel Riose (crise 2) |
| eastern_capital | 30 (21h) | `trantor_court` | La cour impériale de Trantor |
| yanzhou_affair | 30 (24h) | `siwenna_affair` | L'affaire de Siwenna (Ducem Barr, gouverneur rebelle) |
| cao_cao_wanted | 29 (23h) | `speaker_hunted` | La traque du Speaker |
| expedition_dong_zhuo | 26 (21h) | `expedition_mule` | La coalition contre le Mulet |
| jingzhou_machome | 26 (24h) | `forell_house` | La maison Forell (héritage Mallow) |
| jade_seal | 24 (18h) | `imperial_sigil` | Un sceau impérial authentique — relique de légitimité |
| wine_for_power | 22 (16h) | `nucleics_for_power` | Gadgets nucléaires contre faveurs politiques |
| beihai_kong_rong | 21 (14h) | `askone_elders` | Les Anciens d'Askone, monde technophobe |
| jingzhou_xu_shu | 21 (14h) | `defector_advisor` | Le conseiller exfiltré |
| xuzhou_tao_qian | 21 (12h) | `dying_viceroy` | Le vice-roi mourant qui lègue son monde |
| yangzhou_sea_trading | 21 (17h) | `outer_trade_routes` | Routes commerciales de la périphérie |
| ghost_in_the_palace | 20 (17h) | `ghost_in_the_vault` | Un « fantôme » dans la Crypte de Seldon |
| xuzhou_bass | 20 (7h) | `agri_worlds` | Mondes agricoles, approvisionnement |
| sword_princess | 19 (8h) | `bayta_darell` | Bayta Darell |
| trade_secret | 19 (7h) | `trade_secret` | Secret industriel |
| fledgling_pheonix | 15 (11h) | `ebling_mis` | Le savant prodige Ebling Mis |
| recruit_zhao_yun | 15 (10h) | `recruit_pritcher` | Recruter Han Pritcher |
| sleeping_dragon | 14 (10h) | `hidden_speaker` | Le génie caché (Preem Palver, fermier de Rossem) |
| betryal_of_yuan_shu | 13 (9h) | `usurper_betrayal` | Le prétendant impérial de Neotrantor |
| uprising | 12 (6h) | `uprising` | Soulèvement populaire |
| yuanshao_qingzhou | 12 (10h) | `kalgan_campaign` | Campagne du seigneur de Kalgan |
| ma_chao_rebellion | 11 (5h) | `santanni_rebellion` | La rébellion de Santanni |
| wine_making | 11 (8h) | `gadget_craft` | Artisanat de micro-réacteurs |
| caozhiaffaire | 10 (4h) | `heirs_quarrel` | Querelle d'héritiers d'une maison marchande |
| castration | 10 (1h) | `imperial_chamberlains` | Les chambellans de Trantor |
| a_dou | 9 (1h) | `feeble_heir` | L'héritier décevant de la couverture |
| recruit_lu_zhi | 8 (6h) | `recruit_archivist` | Recruter l'archiviste |
| giant_horns | 7 (6h) | `outer_barbarians` | Barbares de la périphérie |
| hanzhong_cult | 6 (5h) | `local_cult` | Culte dévoyé de l'Esprit Galactique |
| jingzhou_surrender | 6 (5h) | `province_surrender` | Reddition d'un monde |
| jingzhou_macson | 5 (3h) | `forell_son` | Le fils Forell |
| find_liu_bei | 4 (1h) | `find_the_contact` | Retrouver le Contact disparu |
| taishi_mom | 4 (0h) | `agents_mother` | La mère de l'agent |
| the_elephant_tribe | 3 (0h) | `gas_miners` | Mineurs de gaz exotiques |

Le mapping d'un deck peut être ajusté au moment de son remplissage si la transposition
ne fonctionne pas à l'écriture — la **structure**, elle, ne bouge pas.

### Aliases systémiques

| Original | Fondation |
|---|---|
| `_enddispatch` | `_enddispatch` (fin de séquence → retour au tirage) |
| `_travel_somewhere` / `_travel_to_<region>` | `_jump_somewhere` / `_jump_<planet>` |
| `_reincarnation_greeting` | `_new_speaker_greeting` |
| `_wedding` | `_cover_union` |
| `_pregnaunt` | `_heir` |
| autres aliases découverts à l'extraction | mappés au fil de l'eau dans `data/link_aliases.json` |

## 3. Systèmes moteur (avant le contenu)

1. **Link par alias** — `link` accepte `"_nom"` en plus d'un ID numérique.
   Registre `data/link_aliases.json` : alias → ID de nœud ou action système
   (`_enddispatch` = vider le link et tirer au hasard). Résolution dans
   `NarrativeModel.draw_card()`. Tests GUT.
2. **`location` + voyage** — variable `location` (id de planète, toKeep, défaut
   `terminus`). Les decks `planet_<id>` et `ambient`/`planet_ruler` sont filtrés par
   la planète courante (conditions générées dans les squelettes). GalaxyMap
   interactive : cliquer une planète accessible déclenche `_jump_<planet>` (séquence
   du deck `hyperjumps`). Tests GUT + capture.
3. **Personnages v2** — `characters.json` étendu :
   - figures canoniques datées (`era_window`) ;
   - **rôles institutionnels** (`role: "sf_contact" | "high_priest" | "guild_master" |
     "terminus_mayor" | …`) : un nom est généré à la première apparition et persiste
     (vars `role_<id>_name`, toKeep) jusqu'à renouvellement (mort du personnage, fin
     d'ère). `bearer` accepte `"role:<id>"`.
   - Seldon : bearer récurrent via la Crypte, toutes ères.
4. **Duels mentaliques** — variable d'ascendant psychique (`duel_edge`), séquences
   clonées des battle-decks : escalade par états, issues victoire/défaite/retraite,
   coût en légitimité en cas d'usage mentalique visible. Détail au plan
   d'implémentation.
5. **`weight: -1`** — supporté comme « jamais tiré au hasard » (équivalent hidden
   pour le tirage, mais visible aux conditions/links).

## 3 bis. Ton & voix (directive d'écriture — 12/06/2026)

Conserver le ton narratif de Reigns, pas seulement ses structures :

- **Pas de narrateur unique.** La majorité des cartes sont la *parole directe* de
  l'interlocuteur (première personne, registre propre au personnage : bureaucrate
  tatillon, contrebandier gouailleur, prêtre pompeux, enfant, droïde de protocole
  vétuste…). Le narrateur omniscient existe mais reste minoritaire.
- **Humour assumé** dans les decks d'ambiance, de voyage et de personnages
  secondaires (l'équivalent des pandas et coqs de bagarre du jeu de base) — absurde
  léger, personnages hauts en couleur, situations cocasses, sans casser l'univers.
- **Gravité préservée** sur la colonne vertébrale (`seldon_plan`, crises, Crypte) :
  l'humour y est rare et sec, façon Hardin.
- Le « vous » reste le Speaker sous couverture ; l'ironie dramatique (le joueur en
  sait plus que son interlocuteur) est un ressort comique récurrent.

## 4. Pipeline de production

1. `tools/extract_skeletons.py` — pour chaque deck original : graphe anonyme →
   `data/skeletons/<deck_fondation>.json` (ids renumérotés dans nos plages, liens,
   hidden, weight, lockturn, slots bearer taggés par récurrence, forme des conditions
   avec variables à transposer, aliases). Zéro texte original.
2. **Remplissage** deck par deck : prose Fondation écrite dans le squelette
   (assistant), **relecture/retouche par l'auteur** (toi) avant commit.
3. `tools/check_structure.py` — diff structurel original ↔ clone : nombre de nœuds,
   arêtes, hidden, weights ; additions assumées listées explicitement. Branché à la
   CI de tests.
4. `scripts/validate_data.py` étendu aux nouveaux champs (aliases, roles, location).

## 5. Phases

| Phase | Contenu | Volume |
|---|---|---|
| 0 | Systèmes moteur (§3) + outillage (§4) | code |
| 1 | Decks systémiques : `new_speaker`, `ambient`, `planet_ruler`, `seldon_plan`, `start`, `deaths`, `hyperjumps` | ~1 060 nœuds |
| 2 | 12 decks planétaires | ~190 nœuds |
| 3 | Arcs ère Hardin (`anacreon_throne`, `church_*`, `encyclopaedia`…) puis ère par ère | ~700 nœuds |
| 4 | Duels mentaliques + grandes confrontations (`riose_campaign`, `fall_of_terminus`…) | ~250 nœuds |
| 5 | Intrigues transverses (`cover_union`, `infiltration`, `speaker_hunted`, `imperial_sigil`…) | ~250 nœuds |

Chaque phase livre : squelettes remplis + diff structurel vert + tests verts +
partie jouable vérifiée en capture.

## 6. Intégration de l'existant

Les 131 cartes actuelles sont conservées et reclassées : `ambient` actuel = noyau du
nouvel `ambient` (Terminus), `hardin_era` ventilé vers `planet_terminus` /
`anacreon_throne` / `seldon_plan`, `merchant_era` vers `transmuter_trade` /
`outer_trade_routes`, `crisis_anacreonian_war` absorbé par `seldon_plan`,
`new_speaker` actuel = amorce du nouveau. Le détail du reclassement est traité en
phase 1 ; aucune carte existante n'est supprimée sans équivalent.

## 7. Vérification

- 115 tests GUT existants verts à chaque commit ; chaque système moteur arrive avec
  ses tests.
- `check_structure.py` vert sur chaque deck livré.
- `validate_data.py` vert.
- Capture de jeu (`tools/screenshot.gd`) après chaque phase.
