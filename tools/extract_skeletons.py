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
    9: "month", 12: "trigger", 14: "moon",
    16: "seen", 17: "objective", 18: "location", 19: "planet_state",
    21: "party", 22: "relation", 24: "mood", 0: "custom", 2: "deck",
}
OP_MAP = {0: "equal", 1: "below", 2: "above", 3: "not", "==": "equal",
          "<": "below", ">": "above", "!=": "not"}

# Régions du jeu de base (ints) → planètes Fondation
REGION_MAP = {
    2: "smyrno", 3: "kalgan", 4: "askone", 5: "neotrantor", 6: "terminus",
    7: "korell", 8: "trantor", 9: "anacreon", 10: "rossem", 11: "siwenna",
    12: "santanni", 13: "sayshell", 14: "santanni",
}
TRAVEL_MAP = {
    "_travel_to_jingzhou": "_jump_terminus",
    "_travel_to_liangzhou": "_jump_smyrno",
    "_travel_to_qingzhou": "_jump_santanni",
    "_travel_to_xuzhou": "_jump_trantor",
    "_travel_to_yangzhou": "_jump_korell",
    "_travel_to_yanzhou": "_jump_siwenna",
    "_travel_to_yizhou": "_jump_askone",
    "_travel_to_yizhou_mountain": "_jump_askone",
    "_travel_to_yizhou_mountain_alt": "_jump_askone",
    "_travel_to_yizhou_river": "_jump_askone",
    "_travel_to_yizhou_river_hard": "_jump_askone",
    "_travel_to_yuzhou": "_jump_anacreon",
    "_travel_to_jizhou": "_jump_neotrantor",
    "_travel_to_youzhou": "_jump_kalgan",
    "_travel_to_luoyang": "_jump_trantor",
    "_travel_to_changan_guarded": "_jump_neotrantor",
    "_travel_to_hanzhong": "_jump_sayshell",
}

# Aliases systémiques du jeu de base → aliases Fondation
ALIAS_MAP = {
    "_family_affair_dad": "_affaire_barr_patriarche",
    "_family_affair_1st_task": "_affaire_barr_tache_1",
    "_family_affair_2nd_task": "_affaire_barr_tache_2",
    "_family_affair_good_plan": "_affaire_barr_bon_plan",
    "_family_affair_fair_cut": "_affaire_barr_partage",
    "_family_affair_fair_share": "_affaire_barr_accord",
    "_family_affair_fail": "_affaire_barr_echec",
    "_liu_dai_money_back": "_affaire_barr_remboursement",
    "_death_abducted_by_panda": "_death_emporte_par_robot",
    "_death_assassinated": "_death_assassine",
    "_death_battleground": "_death_champ_de_bataille",
    "_death_castration": "_death_purge_imperiale",
    "_death_child_birth": "_death_en_couches",
    "_death_debt": "_death_dettes",
    "_death_drown": "_death_noyade",
    "_death_for_love": "_death_par_amour",
    "_death_fumbled_escape": "_death_evasion_ratee",
    "_death_ghost_love": "_death_amour_mentalique",
    "_death_green_dragon_blade": "_death_blaster_ancestral",
    "_death_haunted": "_death_hante",
    "_death_heavenly_sword": "_death_lame_psychique",
    "_death_heavy_halberd": "_death_canon_neutronique",
    "_death_lucy": "_death_chat_du_cargo",
    "_death_no_escape": "_death_sans_issue",
    "_death_retired": "_death_retraite",
    "_death_salamander": "_death_salamandre",
    "_death_split_apart": "_death_ecartele",
    "_death_torture": "_death_interrogatoire",
    "_death_while_asleep": "_death_dans_son_sommeil",
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
    if sv in TRAVEL_MAP:
        return TRAVEL_MAP[sv]
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
            value = o.get("value")
            if var == "location" and value in REGION_MAP:
                value = REGION_MAP[value]
            entry["value"] = value
            # stringValue d'outcome non-link : nom de la variable custom
            # du jeu de base, gardé comme indice de transposition
            if o.get("stringValue"):
                entry["custom_name"] = str(o.get("stringValue"))
        result.append(entry)
    return result

def map_conditions(node, unknown_aliases):
    raw = node.get("conditions_raw")
    result = []
    if raw:
        for c in raw:
            el = c.get("conditionElement", {})
            var = VAR_MAP.get(el.get("variable"), f"VAR_{el.get('variable')}")
            value = el.get("intValue")
            if var == "location" and value in REGION_MAP:
                value = REGION_MAP[value]
            entry = {
                "variable": var,
                "op": OP_MAP.get(c.get("operation"), str(c.get("operation"))),
                "value": value,
            }
            if el.get("stringValue"):
                entry["custom_name"] = str(el.get("stringValue"))
            result.append(entry)
        return result
    for c in node.get("conditions") or []:
        var = VAR_MAP.get(c.get("variable"), f"VAR_{c.get('variable')}")
        value = c.get("value")
        if var == "location" and value in REGION_MAP:
            value = REGION_MAP[value]
        result.append({
            "variable": var,
            "op": OP_MAP.get(c.get("op"), str(c.get("op"))),
            "value": value,
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
                "conditions": map_conditions(n, unknown_aliases),
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
