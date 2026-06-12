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
