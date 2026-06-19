# Notification de déblocage de deck (« Deck X débloqué » + empilement) — Design

Date : 2026-06-19
Statut : validé (brainstorming), prêt pour plan d'implémentation.

## Contexte

À la manière du *Reigns* original, quand un nouveau deck « jalon » apparaît pour la première
fois, le jeu doit afficher une **notification modale** : un message « DECK X DÉBLOQUÉ » et une
**animation d'empilement de cartes**, avant de présenter la carte déclencheuse.

État actuel du modèle : les decks sont gatés par `deck_<name>` (1 = actif par défaut, 0 =
désactivé). Le contenu utilise majoritairement `deck_<name> = 0` pour **fermer** un arc fini ;
il n'existe pas de cycle « verrouillé → débloqué » natif, ni de mapping id→nom lisible. Il y a
~70 decks, dont beaucoup de mini-arcs — déclencher sur tous serait du bruit.

Décisions de cadrage (brainstorming) :
- **Déclencheur** : seuls des decks **marqués « jalon » par l'auteur** (fichier de
  métadonnées) déclenchent la notif, à la **première apparition** d'une de leurs cartes.
  Non invasif : ne verrouille pas les decks, ne change pas le flux des arcs existants.
- **Persistance** : **une fois par carrière** (flag `toKeep` `deck_unlocked_<id>`) — la
  fanfare ne rejoue pas aux règnes suivants.
- **Interaction** : **modale** — les cartes s'empilent, le jeu attend un tap/clic/touche, puis
  la carte déclencheuse s'affiche.
- **Style** : identité holographique du projet ; réutilise le socle `Anim`.

## Architecture

### 1. Données — `data/deck_unlocks.json` *(créer)*
Liste des decks jalons :
```json
[
  { "id": "hardin_era",       "name": "Ère Hardin",            "subtitle": "La religion comme outil" },
  { "id": "merchant_era",     "name": "Ère des Marchands",     "subtitle": "L'expansion commerciale" },
  ...
]
```
Chargé par `FoundationGameData` (qui parse déjà tout `data/`) → exposé via un accès indexé
par id (ex: `game_data.deck_unlock(id) -> Dictionary` ou un dict `deck_unlocks`).
Pré-rempli avec ~12 jalons valides (ids vérifiés présents dans `foundation_cards.json`) :
`hardin_era` (Ère Hardin), `merchant_era` (Ère des Marchands), `encyclopaedia` (Projet
Encyclopédie), `mentalic_inquiry` (Enquête mentalique), `anacreon_throne` (Le Trône
d'Anacréon), `church_schism` (Schisme de l'Église), `fall_of_terminus` (La Chute de Terminus),
`riose_campaign` (Campagne de Bel Riose), `kalgan_campaign` (Campagne de Kalgan),
`bayta_darell` (Bayta Darell), `ebling_mis` (Ebling Mis), `hidden_speaker` (L'Orateur caché).

### 2. Détection — `src/core/DeckUnlock.gd` *(créer, GDScript pur)*
Fonction pure, testable sans arbre de scène :
```
static func pending_unlock(card: Dictionary, ctx: Context, unlocks: Dictionary) -> Dictionary
```
Retourne l'entrée de deck (`{id, name, subtitle}`) si : le deck de `card` est dans `unlocks`
ET `ctx.get_var("deck_unlocked_<id>", 0) == 0`. Sinon `{}`.

### 3. Intégration — `src/main/Main.gd`
Dans `_next_card()` (juste avant `_card_screen.show_card(_current_card, _ctx)`) :
- `var u := DeckUnlock.pending_unlock(_current_card, _ctx, _game_data.deck_unlocks)`
- si `u` non vide : `_ctx.set_var("deck_unlocked_" + u.id, 1, true)` (toKeep) puis afficher
  l'overlay de déblocage à la place ; mémoriser la carte en attente. À la réception de
  `continue_pressed`, appeler `_card_screen.show_card(_current_card, _ctx)`.
- sinon : flux inchangé.
L'overlay est **instancié dynamiquement** par `Main.gd` (pas d'édition de `Main.tscn`).
Couvre tirages aléatoires ET chaînes `link` (toutes deux passent par `_next_card`).

### 4. Overlay — `scenes/DeckUnlockScreen.tscn` + `src/ui/DeckUnlockScreen.gd` *(créer)*
Modal plein écran (z-index élevé, backdrop assombri), au style holographique :
- « NOUVEAU DECK » (cyan, mono, lettrage espacé)
- une **pile de ~5 silhouettes de cartes** holographiques (ColorRect/Panel) qui volent et
  s'empilent au centre
- le **nom** du deck (Spectral) + « DÉBLOQUÉ » (ambre) + `subtitle` (faint)
- « Tap pour continuer » (mono, pulse)
- API : `show_unlock(entry: Dictionary)` ; signal `continue_pressed` (tap/swipe/`ui_accept`).

### 5. Timings — `src/ui/AnimSettings.gd`
Groupe `@export_group("Unlock")` : `unlock_card_fly` (durée vol d'une carte), `unlock_stagger`
(décalage entre cartes), `unlock_card_offset` (décalage d'empilement px), `unlock_card_tilt`
(rotation alternée deg), `unlock_text_in` (fondu nom/label). Le `data/anim_settings.tres` est
régénéré/complété en conséquence.

### 6. Galerie — `src/ui/AnimGallery.gd`
Bouton « Deck débloqué » → instancie `DeckUnlockScreen`, `show_unlock({"name": "Réseau
d'espions", "subtitle": "Vos agents dans l'ombre"})`, branché en overlay (réutilise
`_open_overlay`/`_close_overlay`).

## Animation d'empilement (chorégraphie)

`DeckUnlockScreen.show_unlock(entry)` :
1. Backdrop en fondu (`Anim.fade_in`).
2. ~5 silhouettes de cartes partent hors écran (bas + léger éventail latéral) et arrivent une
   par une (`unlock_stagger`) vers le centre, chacune posée avec `unlock_card_offset` cumulé
   et une rotation alternée `±unlock_card_tilt` (effet pile éventail), easing `TRANS_BACK`
   (petit rebond) sur `unlock_card_fly`.
3. Après la dernière carte : `Anim.reveal_list([_new_label, _name, _unlocked_label, _subtitle])`
   en cascade (`unlock_text_in`).
4. Le hint « continuer » `Anim.pulse`.
5. Tap/clic/`ui_accept` → `continue_pressed`.

## Tests & vérification

- **GUT** (`tests/test_deck_unlock.gd`, logique pure) :
  - `pending_unlock` retourne l'entrée pour un deck listé non encore débloqué ;
  - retourne `{}` pour un deck non listé ;
  - retourne `{}` si `deck_unlocked_<id>` déjà à 1 ;
  - résout bien `name`/`subtitle` depuis les données.
- **Données** : `data/deck_unlocks.json` valide (JSON), tous les `id` existent dans
  `foundation_cards.json`.
- **Non-régression** : suite GUT verte ; flux de carte inchangé sans déblocage.
- **Manuel/headless** : aperçu via le bouton galerie + smoke ; en jeu, première apparition
  d'un deck jalon → overlay → tap → carte.

## Hors périmètre (YAGNI)

- Verrouillage par défaut des decks / cycle locked→unlocked dans le contenu (on détecte la
  première apparition, on ne reverrouille rien).
- Bandeau transitoire (toast) — l'option modale a été retenue.
- Re-notification par règne — c'est une fois par carrière.
- Curation exhaustive des 70 decks — seuls ~12 jalons sont pré-remplis ; l'auteur étend la liste.
