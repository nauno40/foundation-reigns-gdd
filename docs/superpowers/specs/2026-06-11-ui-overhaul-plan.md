# Refonte complète de l'interface — nuit du 11/06/2026

## Diagnostic (cause racine du « immonde et injouable »)

1. **`project.godot` n'a aucune section `[display]`** : pas de taille de fenêtre, pas de mode stretch, pas d'orientation. Le jeu portrait s'ouvre en fenêtre paysage 1152×648 par défaut, sans aucune mise à l'échelle — tout est cassé sur PC, et le serait aussi sur mobile.
2. Le thème est embryonnaire (24 lignes) ; les scènes WIP ont été construites sans cette fondation d'échelle.
3. La maquette React (`reference/ui-prototype/`) est une spec pixel-perfect complète (cadre 460×920, toutes les valeurs CSS) — je l'ai lue intégralement, chaque valeur sera transposée.

## Principe directeur

Réglages recommandés par la doc Godot « Multiple resolutions » : stretch `canvas_items` + aspect `expand` + orientation `portrait`. Base **460×920** = le cadre du prototype, pour une transposition 1:1 de toutes les valeurs CSS (fonts, hauteurs, rayons…).

Comme dans le prototype : un **fond spatial** remplit toute la fenêtre (gradients radiaux + étoiles + filigrane d'équations psychohistoriques), et le **cadre de jeu portrait** (max 460×920, bordure, coins arrondis) est centré. Sur desktop on voit le fond autour ; sur mobile le cadre remplit l'écran.

## Étape 1 — Fondations
- `project.godot` : `[display]` viewport 460×920, stretch `canvas_items`/`expand`, portrait, fenêtre redimensionnable avec taille mini
- `Main.tscn` : SpaceBackground plein écran (shader étoiles + gradients + filigrane ∫∂Ψ…) + `Frame` centré (max 460×920, scanline veil)
- `theme/foundation_theme.tres` complet : 5 fontes, tailles, couleurs du prototype, styleboxes ; `ThemeColors.gd` = source unique des constantes

## Étape 2 — Composants de l'écran de jeu (CardScreen)
- **ResourceBar** : colonne 58px, remplissage coloré dégradé + liseré lumineux en crête, glyphe, label ; états `warn` (label ambre), `crit` (pulse rouge), `affected` (bordure cyan pulsée + pip) — révèle quelles barres vont bouger, jamais le sens
- **Topbar** : rangée méta (ère cyan letterspaced + sceau ☼), An/âge + couverture, barres, mood (dot glow + label + « vous lisez son esprit »), murmure de légitimité
- **Carte** : portrait holo 190px (grille cyan masquée radialement via shader, buste, scanlines, flicker, badge « Figure du Plan », nom+rôle) avec **résolution du bearer** (`characters.json` → nom/rôle canoniques ; null → nom PNJ généré) ; question Spectral 19px ; chips ◄ GAUCHE / DROITE ► ; labels de bord pendant le drag ; réaction italique
- **Swipe** : seuil 92px, tilt 0.045°/px, fly-out 150 %/22°/0.5s, flèches clavier ; barres « affected » pilotées par les outcomes de la carte
- **Footer** : « Glissez la carte ◄ ► » + kbd ← →

## Étape 3 — Écrans secondaires
- **DeathScreen** : cause rouge, h1 Spectral 30px, sous-titre, boîte holo Seldon ambre (en-tête « ☼ MESSAGE — HARI SELDON »), grille stats 2×2, snapshot 4 ressources avec mini-barres, bouton « Nouveau règne → »
- **GalaxyMap** : restylage au thème (fond, typo, couleurs d'états) — fonctionnel, sans refonte profonde

## Étape 4 — Vérification continue (toute la nuit)
- Suite GUT maintenue verte (81 tests) + tests de contrat scène↔script par écran
- **Auto-vérification visuelle** : DISPLAY=:0 disponible → lancement réel + capture de screenshots (PNG) en fenêtre desktop large et au format mobile, inspection des images à chaque jalon, itération jusqu'à fidélité à la maquette
- Lancement final : zéro erreur, zéro warning
- Un commit par étape validée ; GDD mis à jour en fin de nuit (Partie 4 + §6.1)

## Hors scope cette nuit
Panneau de tweaks/difficulté (pas dans le jeu cible), refonte profonde GalaxyMap, localisation EN.
