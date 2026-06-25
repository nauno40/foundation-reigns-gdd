# État des lieux — Projet Godot (rebuild) vs Nouveau template

Comparaison du projet Godot reconstruit (`src/`, `scenes/Main.tscn`) avec le
prototype de référence `reference/UI Nouvelle version/` (`app.jsx`, `codex.jsx`,
`data.jsx`, `Foundation Reigns Prototype.html`).

Légende : ✅ iso · 🟡 proche / écart mineur · 🔴 manquant ou différent

---

## 1. Fondations

| Élément | Template | Projet | Statut |
|---|---|---|---|
| Résolution / portrait | cadre 460×920 | viewport 460×920, stretch `keep` | ✅ |
| Renderer | navigateur | GL Compatibility (opengl3) | ✅ |
| Palette de base | `:root` (bg/accent/amber/danger/ink…) | `Theme.gd` (valeurs identiques) | ✅ |
| Couleurs ressources | **oklch** (mil/rel/com/pol) | converties sRGB exact dans `Theme.gd` | ✅ |
| Polices | Spectral, Space Mono, Caveat (CDN) | mêmes TTF dans `assets/fonts/` | ✅ |
| Données | `data.jsx` (10 cartes, 1 ère…) | `Data.gd` (port 1:1) | ✅ |

---

## 2. Écran de jeu

| Élément | Template | Projet | Statut |
|---|---|---|---|
| Top bar sombre | ère + 4 jauges | idem | ✅ |
| Libellé ère | « SECONDE FONDATION · **ÈRE HARDIN** · ANS 1–80 » (mot accent) | RichText accent | ✅ |
| Jauges icône-masque | remplissage bas→haut, graduations, ligne de niveau | `Gauge.gd` + `gauge_fill` | ✅ |
| États jauge | warn (ambre), crit (rouge pulsé), aff (cyan + base éclaircie) | idem | ✅ |
| Flash ▲/▼ au choix | vert/rouge, .9s | idem | ✅ |
| Question | Space Mono 17, centrée, max ~30 caractères | idem + **défilable** si trop longue | ✅ |
| Murmure légitimité < 35 | Caveat ambre 17 | idem | ✅ |
| Carte carrée | 1:1, min(300,76%), coins 16 | idem (`CardView`) | ✅ |
| Pile de deck derrière | décalée (9,9) rot 2.5° | idem | ✅ |
| Fond de carte teinté | dégradé radial par interlocuteur + grille + scanlines | `card_face` shader | ✅ |
| Buste plat sans visage | épaules + tête + initiales | `CardBust.gd` | ✅ |
| Badge « Figure du Plan » | cartes `key` | idem | ✅ |
| Texte du choix sur la carte | au swipe (gauche/droite) | idem | ✅ |
| Nom + rôle sous la carte | Space Mono + accent | idem | ✅ |
| Bottom bar | année (Caveat **gras**) + âge·couverture | idem | ✅ |
| Poignée « Tableau de bord » | sous la bottombar | idem | ✅ |

---

## 3. Animations

| Animation | Template | Projet | Statut |
|---|---|---|---|
| Entrée carte `cardRise` | .36s, translate(8,12)/rot2.2/scale.965 | idem (suit la base en direct) | ✅ |
| Pile `deckRise` | .42s | idem | ✅ |
| Suivi du doigt | direct, rot = drag·0.055°, scale 1.025 en saisie | idem | ✅ |
| Relâchement | ressort sous-amorti (STIFF .16 / DAMP .74) | idem | ✅ |
| Fly-out | ±150% / ±18°, .42s | idem | ✅ |
| Bannière « Nouveau deck » | cartes qui glissent + bandeau 2.2s | idem (`_play_deck_unlock`) | ✅ |
| Anciennes anims (flip, parallaxe, compteur, wobble) | absentes | **supprimées** | ✅ |

---

## 4. Codex / Tableau de bord

| Élément | Template | Projet | Statut |
|---|---|---|---|
| Panneau coulissant bas→haut | .42s | idem | ✅ |
| 3 onglets + soulignement actif | Personnages / Succès-Decks / Galaxie | idem | ✅ |
| Cartes personnages | carrées, grille holo + buste + ★ key | idem | ✅ |
| Succès | boîtes bordées + coche en cercle | idem | ✅ |
| Decks débloqués / verrouillés | chips bordés, verrouillés grisés | idem | ✅ |
| Galaxie | bras concentriques + planètes colorées + info au clic | idem | ✅ |
| Données codex | réelles (mini-moteur) | statiques (port `data.jsx`) | ✅ |

---

## 5. Écran de mort

| Élément | Template | Projet | Statut |
|---|---|---|---|
| Glitch/collapse holographique | bandes + flash ~0.76s | `death_fx` shader | ✅ |
| `deathIn` (flash + léger zoom) | .55s | idem | ✅ |
| Scintillement de la cause | dthFlick | idem | ✅ |
| Cause (sans suffixe) | « Religion — excès fatal » | idem | ✅ |
| Identité Orateur | Spectral | idem | ✅ |
| Transmission Seldon | encadré ambre « ☼ TRANSMISSION — HARI SELDON » | idem | ✅ |
| Stats 2×2 | statiques | idem | ✅ |
| Snapshot 4 ressources | icône colorée + mini-barre (pas de chiffre) | idem | ✅ |
| Bouton « Nouveau règne → » | cyan | idem | ✅ |

---

## 6. Logique de jeu (mini-moteur du prototype)

| Règle | Template | Projet | Statut |
|---|---|---|---|
| Tirage sans répétition immédiate | `pickCard` | `Data.pick_card` | ✅ |
| Application des fx au choix | += par ressource | idem | ✅ |
| Pas d'étape « réaction » | la réaction n'est jamais affichée dans `app.jsx` | non affichée (fidèle) | ✅ |
| Mort (ressource 0/100, légitimité 0) | idem | idem | ✅ |
| Respawn (légit 50 si démasqué, sinon 80) | idem | idem | ✅ |
| Couverture + bonus +5 | idem | idem | ✅ |
| Déblocages aux tours 3/8/14/21 | idem | idem | ✅ |
| Vieillissement / année | age +1 (p≈.4), year +1 | idem | ✅ |

---

## 7. Écarts — désormais TRAITÉS

| Élément | Template | Projet | Statut |
|---|---|---|---|
| **Cadre flottant dans l'espace** (desktop) | cadre 460 centré, radius 18 + ombre, fond spatial autour | stretch `expand` + cadre 460 centré (`Row/Frame`), `FrameShadow` (ombre+radius), coins haut/bas arrondis, fond spatial plein écran autour | ✅ |
| **Filigrane d'équations** (`#equ`) | symboles ∫∂ΨΣ… faibles en fond | `Root.gd` génère le filigrane (Label faible derrière le cadre) | ✅ |
| **Multiplicateur de difficulté** | DIFF doux/normal/brutal × fx | `Cfg.difficulty` appliqué dans `Game._on_committed` | ✅ |
| **Panneau « Tweaks »** (dev) | accent, grain/scanlines, taille texte, difficulté | `TweaksPanel.gd` (bouton ⚙) + autoload `Cfg` ; accent/grain/texte/difficulté **en direct** | ✅ |
| **Police Spectral (poids)** | h1 mort en 500 | titre de mort en Spectral-Medium | ✅ |
| Luminosité « surround » | navigateur ~2-3 niveaux plus clair | Godot | 🟡 gamma de rendu, négligeable |

Réglages live (`Cfg` + `Cfg.changed`) :
- **Accent** → ère, jauges (état affected), onglets/soulignement codex.
- **Grain** → force du voile scanline (`Root._apply_motion`).
- **Taille texte** → police de la question.
- **Difficulté** → multiplicateur des fx.

---

## 8. Synthèse

Tous les écrans (jeu, codex 3 onglets, mort), les animations, les données, la
palette, les polices, la logique **et** les éléments périphériques (cadre flottant
+ fond spatial + filigrane, panneau Tweaks + difficulté) sont désormais portés.
Vérifié par comparaison Godot ↔ rendu HTML (Playwright) + smoke-test sans erreur.
Seul écart résiduel : un très léger gamma de rendu (navigateur vs Godot), négligeable.
