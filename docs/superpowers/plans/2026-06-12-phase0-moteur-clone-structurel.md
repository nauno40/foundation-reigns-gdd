# Phase 0 — Moteur & outillage du clone structurel · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Livrer les systèmes moteur et l'outillage nécessaires au clone 1:1 des structures narratives du jeu de base (spec `docs/superpowers/specs/2026-06-12-clone-structurel-reigns-design.md`), avec un jeu qui reste jouable et 100 % des tests verts.

**Architecture:** Quatre extensions du moteur existant (aliases de link, `weight:-1`, `location`+voyage, rôles persistants) suivant le pattern établi — classes core en GDScript pur testées par GUT, données JSON dans `data/`, UI minimale. Deux outils Python (`extract_skeletons.py`, `check_structure.py`) forment le pipeline de production des phases 1–5. Les duels mentaliques n'exigent **aucun code moteur** (séquences link + variables ordinaires) — ils seront traités dans le plan de la phase 4.

**Tech Stack:** Godot 4.6 (GDScript), GUT, Python 3 (stdlib uniquement).

**Plans suivants :** un plan par phase de contenu (1 à 5), générés après cette phase à partir des squelettes extraits.

---

## Conventions partagées (lire avant toute tâche)

- Tests : `timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit` (ajouter `-gtest=res://tests/<fichier>.gd` pour un seul fichier).
- Après création d'un nouveau `class_name`, régénérer le cache : `godot --headless --editor --quit`, puis committer le `.uid` généré.
- Mapping des variables du jeu de base → Fondation (utilisé par l'outillage) :
  `military(4)→military · people(5)→politics · morality(6)→religion · supply(7)→commerce · turns(8)→turns · year(10)→year · link(11)→link · seen(16)→seen_<id> · location(18)→location · region(19)→planet_<id>_state · relation(22)→relation_<faction_id> · mood(24)→mood`
- Aucun texte du jeu original ne doit apparaître dans un fichier généré ou commité.

---

### Task 1 : Link par alias (`_enddispatch`, `_jump_*`, nœuds nommés)

Le jeu de base enchaîne via `link` en chaîne de caractères : ID numérique (`"1985"`) ou alias système (`"_enddispatch"`). Notre moteur ne gère que les IDs.

**Files:**
- Create: `data/link_aliases.json`
- Modify: `src/core/FoundationGameData.gd` (chargement)
- Modify: `src/core/NarrativeModel.gd:12-26` (`draw_card`)
- Test: `tests/test_narrative_model.gd`

- [ ] **Step 1 : Créer le registre d'aliases**

`data/link_aliases.json` :
```json
{
	"_enddispatch": {"action": "enddispatch"},
	"_jump_terminus":   {"action": "jump", "planet": "terminus"},
	"_jump_trantor":    {"action": "jump", "planet": "trantor"},
	"_jump_anacreon":   {"action": "jump", "planet": "anacreon"},
	"_jump_santanni":   {"action": "jump", "planet": "santanni"},
	"_jump_smyrno":     {"action": "jump", "planet": "smyrno"},
	"_jump_askone":     {"action": "jump", "planet": "askone"},
	"_jump_korell":     {"action": "jump", "planet": "korell"},
	"_jump_siwenna":    {"action": "jump", "planet": "siwenna"},
	"_jump_kalgan":     {"action": "jump", "planet": "kalgan"},
	"_jump_neotrantor": {"action": "jump", "planet": "neotrantor"},
	"_jump_rossem":     {"action": "jump", "planet": "rossem"},
	"_jump_sayshell":   {"action": "jump", "planet": "sayshell"}
}
```
Les aliases vers des nœuds (`{"node": 20123}`) seront ajoutés par les phases de
contenu (`_new_speaker_greeting`, `_cover_union`, `_heir`…).

- [ ] **Step 2 : Écrire les tests rouges**

Ajouter à `tests/test_narrative_model.gd` :
```gdscript
# --- Aliases de link (structure du jeu de base) ---

func test_link_alias_node_resolves():
	data.link_aliases["_test_alias"] = {"node": 1002}
	ctx.set_var("link", "_test_alias")
	var card = model.draw_card()
	assert_eq(card.get("id"), 1002, "un alias {node} force la carte cible")

func test_link_alias_enddispatch_returns_to_pool():
	ctx.set_var("link", "_enddispatch")
	var card = model.draw_card()
	assert_false(card.is_empty(), "_enddispatch retombe sur le tirage aléatoire")
	assert_eq(str(ctx.get_var("link", "")), "", "link consommé")

func test_link_alias_jump_changes_location():
	ctx.set_var("link", "_jump_anacreon")
	var card = model.draw_card()
	assert_eq(ctx.get_var("location", ""), "anacreon", "le saut change la planète")
	assert_false(card.is_empty(), "après le saut, tirage normal")

func test_link_unknown_alias_falls_back():
	ctx.set_var("link", "_alias_inconnu")
	var card = model.draw_card()
	assert_false(card.is_empty(), "alias inconnu : avertissement + tirage normal")

func test_outcome_string_value_sets_link_alias():
	# les cartes posent les aliases via stringValue (format du jeu de base)
	model.apply_outcomes([{"variable": "link", "stringValue": "_enddispatch",
		"intValue": 0, "addOperation": false, "toKeep": false}])
	assert_eq(str(ctx.get_var("link", "")), "_enddispatch")
```

- [ ] **Step 3 : Vérifier l'échec**

Run : suite GUT sur `test_narrative_model.gd`. Attendu : les 4 nouveaux tests FAIL
(`link_aliases` inexistant / location non changée).

- [ ] **Step 4 : Charger le registre dans FoundationGameData**

Dans `src/core/FoundationGameData.gd`, ajouter le champ et le chargement :
```gdscript
var link_aliases: Dictionary = {}
```
et dans `load_all()` après le chargement de `seldon_crises` :
```gdscript
	ok = ok and _load_dict("res://data/link_aliases.json", link_aliases)
```

- [ ] **Step 5 : Résoudre les aliases dans draw_card**

Remplacer le bloc link de `NarrativeModel.draw_card()` par :
```gdscript
func draw_card() -> Dictionary:
	# Forced link takes absolute priority
	var link = str(_ctx.get_var("link", ""))
	if link != "" and link != "0":
		_ctx.set_var("link", "")
		if link.begins_with("_"):
			var resolved = _resolve_alias(link)
			if not resolved.is_empty():
				return resolved
			# alias d'action ou inconnu : retombe sur le tirage aléatoire
		else:
			var linked = _data.get_card_by_id(int(link))
			if not linked.is_empty():
				return linked

	var eligible = _get_eligible_cards()
	if eligible.is_empty():
		push_warning("NarrativeModel: no eligible cards — returning empty")
		return {}

	return _weighted_random(eligible)

# Alias système du jeu de base : {"node": id} force une carte,
# {"action": ...} déclenche un effet moteur puis rend la main au tirage.
func _resolve_alias(alias: String) -> Dictionary:
	var entry: Dictionary = _data.link_aliases.get(alias, {})
	if entry.is_empty():
		push_warning("NarrativeModel: alias de link inconnu '%s'" % alias)
		return {}
	if entry.has("node"):
		return _data.get_card_by_id(int(entry["node"]))
	match entry.get("action", ""):
		"enddispatch":
			pass  # rien : retour au tirage aléatoire
		"jump":
			_ctx.set_var("location", str(entry.get("planet", "terminus")), true)
		_:
			push_warning("NarrativeModel: action d'alias inconnue '%s'" % str(entry.get("action")))
	return {}
```

- [ ] **Step 6 : Supporter `stringValue` dans apply_outcomes**

Dans `NarrativeModel.apply_outcomes()`, le posage de variable devient : si l'outcome
a un `stringValue` non vide, c'est lui la valeur (sinon `intValue` comme aujourd'hui) :
```gdscript
		var value = outcome.get("intValue", 0)
		var sv = str(outcome.get("stringValue", ""))
		if sv != "":
			value = sv
```
(adapter l'affectation existante pour utiliser `value` dans les deux branches
`addOperation` — un `+=` sur une chaîne est interdit : si `sv != ""`, forcer le mode
`set`).

- [ ] **Step 7 : Vérifier le vert puis committer**

Run : suite GUT complète. Attendu : 0 échec.
```bash
git add data/link_aliases.json src/core/FoundationGameData.gd src/core/NarrativeModel.gd tests/test_narrative_model.gd
git commit -m "feat(engine): link aliases (_enddispatch, _jump_*) like the base game"
```

---

### Task 2 : `weight: -1` = jamais tiré au hasard

Le jeu de base marque certains nœuds `weight: -1` : atteignables par link/conditions
mais exclus du tirage pondéré (équivalent souple de `hidden`).

**Files:**
- Modify: `src/core/NarrativeModel.gd` (`_get_eligible_cards`)
- Test: `tests/test_narrative_model.gd`

- [ ] **Step 1 : Test rouge**

```gdscript
func test_negative_weight_excluded_from_random_draw():
	data.cards.append({
		"id": 99903, "label": "w_neg", "deck": "ambient",
		"weight": -1, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"}, "conditions": [],
	})
	var eligible = model._get_eligible_cards()
	for card in eligible:
		assert_ne(int(card.get("id", 0)), 99903,
			"weight -1 : jamais dans le tirage aléatoire")
```
Run : FAIL attendu.

- [ ] **Step 2 : Implémentation**

Dans `_get_eligible_cards()`, après le filtre `hidden` :
```gdscript
		# weight négatif : carte atteignable uniquement par link (jeu de base)
		if int(card.get("weight", 1)) < 0:
			continue
```

- [ ] **Step 3 : Vert + commit**

Run : suite complète, 0 échec.
```bash
git add src/core/NarrativeModel.gd tests/test_narrative_model.gd
git commit -m "feat(engine): support weight -1 (link-only, base game convention)"
```

---

### Task 3 : `location` + decks planétaires filtrés

**Files:**
- Modify: `src/main/Main.gd` (seed `location` en nouvelle partie)
- Modify: `src/core/NarrativeModel.gd` (`_get_eligible_cards`)
- Test: `tests/test_narrative_model.gd`

- [ ] **Step 1 : Tests rouges**

```gdscript
# --- Decks planétaires : actifs seulement sur la planète courante ---

func test_planet_deck_filtered_by_location():
	data.cards.append({
		"id": 99904, "label": "p_anac", "deck": "planet_anacreon",
		"weight": 5, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"}, "conditions": [],
	})
	ctx.set_var("location", "terminus", true)
	for card in model._get_eligible_cards():
		assert_ne(int(card.get("id", 0)), 99904,
			"deck planet_anacreon inactif depuis terminus")
	ctx.set_var("location", "anacreon", true)
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_has(ids, 99904, "deck planet_anacreon actif sur anacreon")

func test_location_defaults_to_terminus_for_planet_decks():
	data.cards.append({
		"id": 99905, "label": "p_term", "deck": "planet_terminus",
		"weight": 5, "lockturn": 0, "hidden": false,
		"question": {"FR": "?"}, "conditions": [],
	})
	var ids = model._get_eligible_cards().map(func(c): return int(c.get("id", 0)))
	assert_has(ids, 99905, "sans location posée, on est sur terminus")
```
Run : FAIL attendu.

- [ ] **Step 2 : Implémentation du filtre**

Dans `_get_eligible_cards()`, après le filtre weight :
```gdscript
		# Decks planétaires : uniquement sur la planète courante
		if deck.begins_with("planet_"):
			var here: String = str(_ctx.get_var("location", "terminus"))
			if deck.trim_prefix("planet_") != here:
				continue
```
Note : `deck` est déjà déclaré plus haut dans la boucle — déplacer sa déclaration
avant ce bloc si nécessaire.

- [ ] **Step 3 : Seed en nouvelle partie**

Dans `Main._ready()`, branche nouvelle partie (après `seed_faction_relations`) :
```gdscript
		_ctx.set_var("location", "terminus", true)
```

- [ ] **Step 4 : Vert + commit**

```bash
git add src/core/NarrativeModel.gd src/main/Main.gd tests/test_narrative_model.gd
git commit -m "feat(engine): location variable gates planet_* decks"
```

---

### Task 4 : Voyage — GalaxyMap interactive

Cliquer une planète ≠ courante propose « Voyager » ; confirmer pose
`link = "_jump_<planet>"`, ferme la carte et enchaîne.

**Files:**
- Modify: `src/ui/GalaxyMap.gd`
- Modify: `src/main/Main.gd`
- Test: capture `tools/screenshot.gd` mode `map`

- [ ] **Step 1 : Signal + bouton Voyager dans GalaxyMap**

Dans `src/ui/GalaxyMap.gd` :
```gdscript
signal jump_requested(planet_id: String)

var _travel_btn: Button
var _popup_planet: String = ""
```
Dans `_ready()`, après la construction du popup existant, créer le bouton (ajouté au
VBox du popup, après `%PopupState`) :
```gdscript
	_travel_btn = Button.new()
	_travel_btn.text = "VOYAGER →"
	_travel_btn.focus_mode = Control.FOCUS_NONE
	_travel_btn.add_theme_font_override("font", FONT_MONO)
	_travel_btn.add_theme_font_size_override("font_size", 10)
	_travel_btn.pressed.connect(_on_travel_pressed)
	%PopupState.get_parent().add_child(_travel_btn)
```
Dans `_on_planet_pressed(planet_id)`, mémoriser et conditionner :
```gdscript
	_popup_planet = planet_id
	var here: String = str(_ctx_ref.get_var("location", "terminus"))
	_travel_btn.visible = planet_id != here
```
Et :
```gdscript
func _on_travel_pressed() -> void:
	_popup.hide()
	hide()
	jump_requested.emit(_popup_planet)
```

- [ ] **Step 2 : Brancher dans Main**

Dans `Main._ready()` (avec les autres connexions) :
```gdscript
	_galaxy_map.jump_requested.connect(_on_jump_requested)
```
Et la méthode (près de `_on_map_pressed`) :
```gdscript
func _on_jump_requested(planet_id: String) -> void:
	_ctx.set_var("link", "_jump_" + planet_id)
	_save.save(_ctx)
	_next_card()
```

- [ ] **Step 3 : Vérification visuelle**

```bash
rm -f ~/.local/share/godot/app_userdata/"Foundation Reigns"/foundation_save.json
timeout 120 godot --path . -s tools/screenshot.gd -- /tmp/p0_map.png 460 920 40 map
```
Inspecter `/tmp/p0_map.png` : popup d'une planète avec bouton « VOYAGER → ».
(Le mode `map` du tool ouvre la carte ; pour voir le popup, ajouter temporairement un
`_on_planet_pressed("anacreon")` n'est PAS nécessaire — vérifier au moins que la
carte s'ouvre sans erreur script, le popup étant testé manuellement.)

- [ ] **Step 4 : Suite GUT complète puis commit**

```bash
git add src/ui/GalaxyMap.gd src/main/Main.gd
git commit -m "feat(ui): interactive galaxy map — travel via _jump_* aliases"
```

---

### Task 5 : Personnages v2 — rôles institutionnels persistants

`bearer: "role:<id>"` → un nom généré à la première apparition, persistant (toKeep)
jusqu'à ce qu'un outcome le réinitialise (`role_<id>_name = ""`).

**Files:**
- Create: `data/roles.json`
- Modify: `src/core/FoundationGameData.gd` (chargement)
- Modify: `src/ui/CardUtils.gd` (`resolve_bearer`)
- Test: `tests/test_card_utils.gd`

- [ ] **Step 1 : Créer `data/roles.json`**

```json
{
	"sf_contact":    {"title": "Contact de la Seconde Fondation"},
	"high_priest":   {"title": "Grand Prêtre de l'Esprit Galactique"},
	"guild_master":  {"title": "Maître de la Guilde Marchande"},
	"terminus_mayor":{"title": "Maire de Terminus"},
	"spy_handler":   {"title": "Maître-espion du réseau"},
	"imperial_envoy":{"title": "Émissaire impérial"}
}
```
(D'autres rôles seront ajoutés par les phases de contenu.)

- [ ] **Step 2 : Tests rouges**

Ajouter à `tests/test_card_utils.gd` (le fichier instancie déjà `data` et utilise
`CardUtils.resolve_bearer(card, data)` ; adapter : la résolution de rôle prend aussi
`ctx`) :
```gdscript
# --- Rôles institutionnels persistants (bearer "role:<id>") ---

func test_role_bearer_generates_and_persists_name():
	var ctx = Context.new()
	var card = {"bearer": "role:high_priest"}
	var info1 = CardUtils.resolve_bearer(card, data, ctx)
	assert_ne(info1["name"], "", "un nom est généré")
	assert_eq(info1["role"], "Grand Prêtre de l'Esprit Galactique")
	var info2 = CardUtils.resolve_bearer(card, data, ctx)
	assert_eq(info2["name"], info1["name"], "le nom persiste entre les cartes")
	ctx.empty_non_keep()
	var info3 = CardUtils.resolve_bearer(card, data, ctx)
	assert_eq(info3["name"], info1["name"], "le visage du rôle survit à la mort (toKeep)")

func test_role_name_reset_regenerates():
	var ctx = Context.new()
	var card = {"bearer": "role:high_priest"}
	var info1 = CardUtils.resolve_bearer(card, data, ctx)
	ctx.set_var("role_high_priest_name", "")
	var info2 = CardUtils.resolve_bearer(card, data, ctx)
	assert_ne(info2["name"], "", "nom régénéré après reset")
```
Run : FAIL attendu (signature + logique absentes).

- [ ] **Step 3 : Charger roles.json**

`FoundationGameData.gd` :
```gdscript
var roles: Dictionary = {}
```
et dans `load_all()` :
```gdscript
	ok = ok and _load_dict("res://data/roles.json", roles)
```

- [ ] **Step 4 : Étendre `CardUtils.resolve_bearer`**

La signature devient `resolve_bearer(card: Dictionary, data: FoundationGameData,
ctx: Context = null)`. Au début de la résolution, avant la logique existante :
```gdscript
	var bearer = card.get("bearer")
	if bearer is String and bearer.begins_with("role:") and ctx != null:
		var role_id: String = bearer.trim_prefix("role:")
		var role: Dictionary = data.roles.get(role_id, {})
		var name_key := "role_%s_name" % role_id
		var name: String = str(ctx.get_var(name_key, ""))
		if name == "":
			name = data.get_random_name()
			ctx.set_var(name_key, name, true)
		return {"name": name, "role": role.get("title", role_id), "key": false}
```
Mettre à jour l'appelant `CardScreen._update_portrait` pour passer `ctx` (le
`show_card(card, ctx)` l'a déjà sous la main — stocker `_ctx_ref = ctx` dans
`show_card` et passer `_ctx_ref`).

- [ ] **Step 5 : Vert + commit**

Run : suite complète (les tests existants de `resolve_bearer` doivent rester verts —
le paramètre `ctx` a un défaut `null`).
```bash
git add data/roles.json src/core/FoundationGameData.gd src/ui/CardUtils.gd src/ui/CardScreen.gd tests/test_card_utils.gd
git commit -m "feat(core): persistent institutional roles (bearer role:<id>)"
```

---

### Task 6 : `tools/extract_skeletons.py` + table de mapping

**Files:**
- Create: `tools/deck_mapping.json`
- Create: `tools/extract_skeletons.py`
- Output (généré, commité) : `data/skeletons/<deck>.json`

- [ ] **Step 1 : Créer `tools/deck_mapping.json`**

Reprendre la table complète de la spec §2 (67 entrées). Format :
```json
{
	"commoner":        {"target": "ambient",        "id_base": 20000},
	"region_ruler":    {"target": "planet_ruler",   "id_base": 20400},
	"mainline":        {"target": "seldon_plan",    "id_base": 20800},
	"after_death":     {"target": "new_speaker",    "id_base": 21200},
	"jingzhou_liu_biao": {"target": "anacreon_throne", "id_base": 21600},
	"jizhou_ghostbuster": {"target": "mentalic_inquiry", "id_base": 22000},
	"honey_trap":      {"target": "infiltration",   "id_base": 22400},
	"defenders":       {"target": "terminus_defense","id_base": 22800},
	"marriage":        {"target": "cover_union",    "id_base": 23200},
	"hangzhong_zhang_lu": {"target": "church_primate", "id_base": 23600},
	"yellow_turbans":  {"target": "church_schism",  "id_base": 24000},
	"deaths":          {"target": "deaths",         "id_base": 24400},
	"yizhou_silk":     {"target": "transmuter_trade","id_base": 24800},
	"qingzhou_scholar":{"target": "encyclopaedia",  "id_base": 25200},
	"movement":        {"target": "hyperjumps",     "id_base": 25600},
	"region_jingzhou": {"target": "planet_terminus","id_base": 26000},
	"formidable_young_lord": {"target": "gifted_orphan", "id_base": 26400},
	"legend_of_beauty":{"target": "lady_callia",    "id_base": 26800},
	"red_cliffs":      {"target": "fall_of_terminus","id_base": 27200},
	"guandu_battles":  {"target": "riose_campaign", "id_base": 27600},
	"eastern_capital": {"target": "trantor_court",  "id_base": 28000},
	"yanzhou_affair":  {"target": "siwenna_affair", "id_base": 28400},
	"cao_cao_wanted":  {"target": "speaker_hunted", "id_base": 28800},
	"region_yuzhou":   {"target": "planet_anacreon","id_base": 29200},
	"expedition_dong_zhuo": {"target": "expedition_mule", "id_base": 29600},
	"jingzhou_machome":{"target": "forell_house",   "id_base": 30000},
	"start":           {"target": "start",          "id_base": 30400},
	"jade_seal":       {"target": "imperial_sigil", "id_base": 30800},
	"region_xuzhou":   {"target": "planet_trantor", "id_base": 31200},
	"wine_for_power":  {"target": "nucleics_for_power", "id_base": 31600},
	"beihai_kong_rong":{"target": "askone_elders",  "id_base": 32000},
	"jingzhou_xu_shu": {"target": "defector_advisor","id_base": 32400},
	"region_yangzhou": {"target": "planet_korell",  "id_base": 32800},
	"xuzhou_tao_qian": {"target": "dying_viceroy",  "id_base": 33200},
	"yangzhou_sea_trading": {"target": "outer_trade_routes", "id_base": 33600},
	"ghost_in_the_palace": {"target": "ghost_in_the_vault", "id_base": 34000},
	"xuzhou_bass":     {"target": "agri_worlds",    "id_base": 34400},
	"sword_princess":  {"target": "bayta_darell",   "id_base": 34800},
	"trade_secret":    {"target": "trade_secret",   "id_base": 35200},
	"fledgling_pheonix": {"target": "ebling_mis",   "id_base": 35600},
	"recruit_zhao_yun":{"target": "recruit_pritcher","id_base": 36000},
	"region_youzhou":  {"target": "planet_kalgan",  "id_base": 36400},
	"sleeping_dragon": {"target": "hidden_speaker", "id_base": 36800},
	"betryal_of_yuan_shu": {"target": "usurper_betrayal", "id_base": 37200},
	"region_yizhou":   {"target": "planet_askone",  "id_base": 37600},
	"uprising":        {"target": "uprising",       "id_base": 38000},
	"yuanshao_qingzhou": {"target": "kalgan_campaign", "id_base": 38400},
	"ma_chao_rebellion": {"target": "santanni_rebellion", "id_base": 38800},
	"wine_making":     {"target": "gadget_craft",   "id_base": 39200},
	"caozhiaffaire":   {"target": "heirs_quarrel",  "id_base": 39600},
	"castration":      {"target": "imperial_chamberlains", "id_base": 40000},
	"a_dou":           {"target": "feeble_heir",    "id_base": 40400},
	"region_yanzhou":  {"target": "planet_siwenna", "id_base": 40800},
	"recruit_lu_zhi":  {"target": "recruit_archivist", "id_base": 41200},
	"region_liangzhou":{"target": "planet_smyrno",  "id_base": 41600},
	"giant_horns":     {"target": "outer_barbarians","id_base": 42000},
	"region_qingzhou": {"target": "planet_santanni","id_base": 42400},
	"hanzhong_cult":   {"target": "local_cult",     "id_base": 42800},
	"jingzhou_surrender": {"target": "province_surrender", "id_base": 43200},
	"jingzhou_macson": {"target": "forell_son",     "id_base": 43600},
	"find_liu_bei":    {"target": "find_the_contact","id_base": 44000},
	"region_jizhou":   {"target": "planet_neotrantor", "id_base": 44400},
	"taishi_mom":      {"target": "agents_mother",  "id_base": 44800},
	"the_elephant_tribe": {"target": "gas_miners",  "id_base": 45200},
	"battle":          {"target": "duel",           "id_base": 45600},
	"bot":             {"target": "bot",            "id_base": 45700},
	"dev":             {"target": "dev",            "id_base": 45800}
}
```

- [ ] **Step 2 : Écrire `tools/extract_skeletons.py`**

```python
#!/usr/bin/env python3
"""Extrait les squelettes structurels anonymes des decks du jeu de base.

Pour chaque deck mappé dans tools/deck_mapping.json, produit
data/skeletons/<target>.json : topologie complète (liens, hidden, weight,
lockturn, slots de personnages, forme des conditions) avec IDs renumérotés
dans nos plages. AUCUN texte original n'est exporté.
"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
SOURCE = ROOT / "reference/REIGNS_DATA_EXPORT/json/cards_fr.json"
MAPPING = ROOT / "tools/deck_mapping.json"
OUT_DIR = ROOT / "data/skeletons"

# Variables du jeu de base → variables Fondation
VAR_MAP = {
    4: "military", 5: "politics", 6: "religion", 7: "commerce",
    8: "turns", 10: "year", 11: "link", 13: "quest", 15: "age",
    16: "seen", 17: "objective", 18: "location", 19: "planet_state",
    21: "party", 22: "relation", 24: "mood", 0: "custom", 2: "deck",
}
OP_MAP = {0: "equal", 1: "below", 2: "above", 3: "not", "==": "equal",
          "<": "below", ">": "above", "!=": "not"}

# Aliases systémiques du jeu de base → aliases Fondation
ALIAS_MAP = {
    "_enddispatch": "_enddispatch",
    "_reincarnation_greeting": "_new_speaker_greeting",
    "_wedding": "_cover_union",
    "_pregnaunt": "_heir",
    "_travel_somewhere": "_jump_somewhere",
}

def map_link(string_value, id_map, unknown_aliases):
    sv = str(string_value)
    if sv.isdigit():
        return id_map.get(int(sv), f"EXTERNE:{sv}")
    if sv.startswith("_travel_to_"):
        return "_jump_PLANETE"  # à résoudre au remplissage
    mapped = ALIAS_MAP.get(sv)
    if mapped is None:
        unknown_aliases.add(sv)
        return sv  # conservé tel quel, à mapper dans link_aliases.json
    return mapped

def map_outcomes(outcomes, id_map, unknown_aliases):
    result = []
    for o in outcomes or []:
        var = VAR_MAP.get(o.get("variable"), f"VAR_{o.get('variable')}")
        entry = {"variable": var, "operation": o.get("operation", "set")}
        if var == "link":
            entry["target"] = map_link(o.get("stringValue", ""), id_map, unknown_aliases)
        else:
            entry["value"] = o.get("value")
            # stringValue d'outcome non-link : nom de variable custom — gardé
            if o.get("stringValue"):
                entry["custom_name"] = "A_TRANSPOSER"
        result.append(entry)
    return result

def map_conditions(conds, unknown_aliases):
    result = []
    for c in conds or []:
        var = VAR_MAP.get(c.get("variable"), f"VAR_{c.get('variable')}")
        result.append({
            "variable": var,
            "op": OP_MAP.get(c.get("op"), str(c.get("op"))),
            "value": c.get("value"),
        })
    return result

def main():
    data = json.loads(SOURCE.read_text())
    mapping = json.loads(MAPPING.read_text())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    unknown_aliases = set()
    bearer_freq = {}
    for deck in data.values():
        for n in deck["nodes"]:
            b = n.get("bearer")
            if b is not None:
                bearer_freq[b] = bearer_freq.get(b, 0) + 1

    for src_name, conf in mapping.items():
        deck = data.get(src_name)
        if deck is None:
            print(f"ABSENT: {src_name}", file=sys.stderr)
            continue
        nodes = deck["nodes"]
        id_map = {n["id"]: conf["id_base"] + i for i, n in enumerate(nodes)}
        skeleton = {
            "source_deck": src_name,
            "target_deck": conf["target"],
            "node_count": len(nodes),
            "hidden_count": sum(1 for n in nodes if n.get("hidden")),
            "nodes": [],
        }
        for i, n in enumerate(nodes):
            bearer = n.get("bearer")
            skeleton["nodes"].append({
                "id": conf["id_base"] + i,
                "orig_id": n["id"],
                "hidden": bool(n.get("hidden")),
                "weight": n.get("weight", 1),
                "lockturn": n.get("lockturn", 0),
                "bearer_slot": (f"B{bearer}(x{bearer_freq[bearer]})"
                                 if bearer is not None else None),
                "mood_hint": n.get("moods"),
                "conditions": map_conditions(n.get("conditions"), unknown_aliases),
                "loadOutcome": map_outcomes(n.get("loadOutcome"), id_map, unknown_aliases),
                "yesOutcome": map_outcomes(n.get("yesOutcome"), id_map, unknown_aliases),
                "noOutcome": map_outcomes(n.get("noOutcome"), id_map, unknown_aliases),
                "question": "", "leftAnswer": "", "rightAnswer": "",
                "reactionLeft": "", "reactionRight": "",
            })
        out = OUT_DIR / f"{conf['target']}.json"
        out.write_text(json.dumps(skeleton, ensure_ascii=False, indent="\t") + "\n")
        print(f"{conf['target']}: {len(nodes)} nœuds ({skeleton['hidden_count']} hidden)")
    if unknown_aliases:
        print(f"\nAliases à mapper dans data/link_aliases.json : {sorted(unknown_aliases)}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 3 : Exécuter et vérifier**

```bash
python3 tools/extract_skeletons.py
```
Attendu : 67 lignes `<deck>: N nœuds (Mh hidden)` avec les comptes du tableau de la
spec (`ambient: 320 (162 hidden)`, etc.), et la liste des aliases inconnus à mapper.

Contrôle anti-texte (doit ne rien retourner) :
```bash
python3 - << 'EOF'
import json, pathlib
for f in pathlib.Path("data/skeletons").glob("*.json"):
    sk = json.loads(f.read_text())
    for n in sk["nodes"]:
        assert n["question"] == "" and n["leftAnswer"] == "", f.name
print("OK aucun texte dans les squelettes")
EOF
```

- [ ] **Step 4 : Commit**

```bash
git add tools/deck_mapping.json tools/extract_skeletons.py data/skeletons/
git commit -m "feat(tools): extract anonymous structural skeletons from the base game"
```

---

### Task 7 : `tools/check_structure.py` — diff structurel

**Files:**
- Create: `tools/check_structure.py`
- Create: `tools/structure_additions.json` (whitelist des ajouts assumés)

- [ ] **Step 1 : Créer la whitelist vide**

`tools/structure_additions.json` :
```json
{}
```
(Format : `{"<deck>": [<ids ajoutés>]}` — rempli au fil des phases.)

- [ ] **Step 2 : Écrire l'outil**

```python
#!/usr/bin/env python3
"""Diff structurel squelettes ↔ cartes livrées dans foundation_cards.json.

Pour chaque deck dont AU MOINS une carte existe dans les données du jeu,
vérifie contre data/skeletons/<deck>.json :
  - chaque nœud du squelette livré est présent (même id) ;
  - hidden / weight / lockturn identiques ;
  - chaque outcome `link` du squelette pointe vers la même cible (id ou alias) ;
  - les cartes en plus sont soit dans tools/structure_additions.json, soit ERREUR.
Un deck sans aucune carte livrée est signalé "non rempli" (pas une erreur).
Sortie 1 si au moins une erreur.
"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
errors, delivered, pending = [], 0, 0
cards = json.loads((ROOT / "data/foundation_cards.json").read_text())
by_deck = {}
for c in cards:
    by_deck.setdefault(c["deck"], {})[c["id"]] = c
additions = json.loads((ROOT / "tools/structure_additions.json").read_text())

def links_of(card_or_node, key):
    out = []
    for o in card_or_node.get(key) or []:
        if o.get("variable") == "link":
            # squelette : "target" ; carte livrée : stringValue (alias) ou intValue (id)
            target = o.get("target")
            if target is None:
                target = o.get("stringValue") or o.get("intValue", "")
            out.append(str(target))
    return out

for sk_file in sorted((ROOT / "data/skeletons").glob("*.json")):
    sk = json.loads(sk_file.read_text())
    deck = sk["target_deck"]
    have = by_deck.get(deck, {})
    if not have:
        pending += 1
        continue
    delivered += 1
    sk_ids = set()
    for n in sk["nodes"]:
        sk_ids.add(n["id"])
        card = have.get(n["id"])
        if card is None:
            errors.append(f"{deck}: nœud {n['id']} (orig {n['orig_id']}) manquant")
            continue
        for field in ("hidden", "weight", "lockturn"):
            if card.get(field, 0 if field != "hidden" else False) != n[field]:
                errors.append(f"{deck}#{n['id']}: {field} = "
                              f"{card.get(field)!r} ≠ squelette {n[field]!r}")
        for key in ("yesOutcome", "noOutcome", "loadOutcome"):
            want = links_of(n, key)
            got = links_of(card, key)
            if want and want != got:
                errors.append(f"{deck}#{n['id']}: liens {key} {got} ≠ {want}")
    extra = set(have) - sk_ids - set(additions.get(deck, []))
    for x in sorted(extra):
        errors.append(f"{deck}: carte {x} hors squelette (ajouter à "
                      f"structure_additions.json si assumée)")

print(f"decks livrés: {delivered} · non remplis: {pending}")
if errors:
    print(f"ÉCHEC — {len(errors)} écart(s):")
    for e in errors:
        print(f"  x {e}")
    sys.exit(1)
print("OK structure conforme au jeu de base")
```

- [ ] **Step 3 : Exécuter**

```bash
python3 tools/check_structure.py
```
Attendu : `decks livrés: 0 · non remplis: 67` puis `OK` (aucun deck cloné encore —
les decks actuels `ambient`/`new_speaker` actuels n'utilisent pas les IDs des
squelettes, ils seront reclassés en phase 1). Si `ambient` actuel déclenche des
« hors squelette » : c'est attendu — ajouter les IDs existants (1001–1040, 9101…)
dans `structure_additions.json` sous `"ambient"` en attendant le reclassement de
phase 1, et relancer.

- [ ] **Step 4 : Commit**

```bash
git add tools/check_structure.py tools/structure_additions.json
git commit -m "feat(tools): structural diff between skeletons and shipped decks"
```

---

### Task 8 : Extensions de validation + documentation

**Files:**
- Modify: `scripts/validate_data.py`
- Modify: `CLAUDE.md` (section Architecture/Data) et `docs/GDD.md` §6

- [ ] **Step 1 : Valider les nouveaux fichiers de données**

Ajouter à `scripts/validate_data.py` avant le bloc Report :
```python
# --- link_aliases.json ---
aliases = load("link_aliases.json")
if aliases:
    for name, entry in aliases.items():
        check(name.startswith("_"), f"alias '{name}' doit commencer par _")
        check(("node" in entry) != ("action" in entry),
              f"alias '{name}': exactement un de node/action requis")
        if entry.get("action") == "jump" and planets:
            check(entry.get("planet") in {p["id"] for p in planets},
                  f"alias '{name}': planète inconnue '{entry.get('planet')}'")

# --- roles.json ---
roles = load("roles.json")
if roles:
    for rid, r in roles.items():
        check("title" in r, f"role '{rid}' sans title")
```

- [ ] **Step 2 : Exécuter les validations**

```bash
python3 scripts/validate_data.py && python3 tools/check_structure.py
```
Attendu : `OK All data files valid` et `OK structure conforme`.

- [ ] **Step 3 : Documenter**

Dans `CLAUDE.md`, section « Card Data Format », ajouter après la liste des clés :
```markdown
- `link` outcomes accept node IDs or string aliases (`_enddispatch`, `_jump_<planet>`,
  see `data/link_aliases.json`); `weight: -1` = link-only card; `bearer` accepts
  `"role:<id>"` (persistent institutional roles, `data/roles.json`); `planet_<id>`
  decks are gated by the `location` context variable.
- Production pipeline: `tools/extract_skeletons.py` → fill `data/skeletons/<deck>.json`
  → `tools/check_structure.py` (structural 1:1 clone of the base game, see
  `docs/superpowers/specs/2026-06-12-clone-structurel-reigns-design.md`).
```
Dans `docs/GDD.md` §6.4, remplacer les phases 4–5 restantes par un renvoi à la spec
du clone structurel (les phases 1–5 du clone remplacent l'ancien plan de contenu) :
```markdown
### 🆕 Refonte contenu (12/06/2026) — clone structurel 1:1 du jeu de base
Le plan de contenu ci-dessus est remplacé par le clone structurel des 67 decks du
jeu de base (voir `docs/superpowers/specs/2026-06-12-clone-structurel-reigns-design.md`).
Moteur prêt (aliases, location/voyage, rôles persistants, weight -1) ; phases de
contenu 1–5 à venir, deck par deck, avec diff structurel automatique.
```

- [ ] **Step 4 : Commit**

```bash
git add scripts/validate_data.py CLAUDE.md docs/GDD.md
git commit -m "chore: validation + docs for structural-clone engine systems"
```

---

### Task 9 : Vérification finale de phase

- [ ] **Step 1 : Suite complète**

```bash
timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gexit
python3 scripts/validate_data.py
python3 tools/check_structure.py
```
Attendu : 100 % des tests verts (≥ 121), validations OK.

- [ ] **Step 2 : Partie jouable**

```bash
rm -f ~/.local/share/godot/app_userdata/"Foundation Reigns"/foundation_save.json
timeout 120 godot --path . -s tools/screenshot.gd -- /tmp/p0_card.png 460 920 40 card
timeout 120 godot --path . -s tools/screenshot.gd -- /tmp/p0_map.png 460 920 40 map
```
Inspecter les deux captures : carte normale + carte galactique sans erreur script.

- [ ] **Step 3 : Mettre à jour le suivi**

Cocher les cases de ce plan, puis annoncer la phase 1 (remplissage
`new_speaker`/`ambient`/`planet_ruler`/`seldon_plan`) qui fera l'objet de son propre
plan s'appuyant sur les squelettes générés ici.
