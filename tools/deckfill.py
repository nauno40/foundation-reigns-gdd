#!/usr/bin/env python3
"""Helper de remplissage : transpose un squelette en cartes Fondation en
préservant exactement la structure de liens. Les scripts par deck importent
fill_deck() et fournissent la prose + les mappings.

AUCUN texte du jeu original n'est lu ici — seul le squelette structurel l'est.
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent.parent

# Variables custom du jeu de base → Fondation (étendable par deck)
DEFAULT_VAR = {
    "people": "politics", "morality": "religion", "supply": "commerce",
    "treasury": "commerce",
}

# Préfixes de variables persistantes (toKeep)
KEEP_PREFIXES = ("planet_", "relation_", "seen_", "party_", "arc_",
                 "positronic_", "ending_", "second_empire_", "inquiry_",
                 "echo_", "widow_", "quest_", "seldon_crisis_", "family_affair")


def _conv_outcomes(node, key, var_map, planet_map, deck_close):
    out = []
    for o in node[key]:
        var = o["variable"]
        name = o.get("custom_name") or var
        if var == "link":
            t = o["target"]
            if isinstance(t, int) or str(t).isdigit():
                out.append({"variable": "link", "intValue": int(t),
                            "addOperation": False, "toKeep": False})
            else:
                out.append({"variable": "link", "intValue": 0, "stringValue": str(t),
                            "addOperation": False, "toKeep": False})
            continue
        raw = o.get("value", 0)
        if var == "location" or isinstance(raw, str):
            out.append({"variable": "location", "intValue": 0, "stringValue": str(raw),
                        "addOperation": False, "toKeep": True})
            continue
        value = int(raw)
        if name == "planet_state":
            pid = planet_map.get(abs(value), "terminus")
            out.append({"variable": "planet_%s_state" % pid,
                        "intValue": -1 if value < 0 else 1,
                        "addOperation": False, "toKeep": True})
            continue
        if var == "deck" or name == "deck":
            if value < 0 and deck_close:
                out.append({"variable": "deck_%s" % deck_close, "intValue": 0,
                            "addOperation": False, "toKeep": False})
            continue
        n = var_map.get(name, DEFAULT_VAR.get(name, name))
        out.append({"variable": n, "intValue": value,
                    "addOperation": o["operation"] == "add",
                    "toKeep": any(n.startswith(p) for p in KEEP_PREFIXES)})
    return out


def _conv_conditions(node, var_map, planet_map, seen_map):
    out = []
    for c in node["conditions"]:
        var = c.get("custom_name") or c["variable"]
        value = c["value"]
        if var == "seen":
            var, value = seen_map.get(value, "seen_%s" % value), 1
        elif var == "planet_state":
            var, value = "planet_%s_state" % planet_map.get(abs(value), "terminus"), 1
        else:
            var = var_map.get(var, DEFAULT_VAR.get(var, var))
        out.append({"variable": var, "op": c["op"], "value": value})
    return out


def fill_deck(deck, texts, bearers, *, var_map=None, planet_map=None,
              seen_map=None, deck_close=None, aliases=None, roles=None,
              characters=None, bearer_map=None):
    """texts: {id: (q, lt, lr, rt, rr, mood, m_yes, m_no)}.
    bearers: {"B123": "role:x" | "char_id" | None}.
    Renvoie le nombre de cartes écrites."""
    var_map = var_map or {}
    planet_map = planet_map or {}
    seen_map = seen_map or {}
    sk = json.loads((ROOT / "data/skeletons" / (deck + ".json")).read_text())
    nodes = {n["id"]: n for n in sk["nodes"]}
    unknown = set(texts) - set(nodes)
    assert not unknown, "ids hors squelette: %s" % unknown
    # Remplissage partiel autorisé (decks géants, mode _in_progress) : seuls
    # les nœuds fournis sont écrits ; check_structure tolère les manquants.

    cards = []
    for nid, tx in texts.items():
        q, lt, lr, rt, rr, m0, my, mn = tx
        n = nodes[nid]
        slot = (n["bearer_slot"] or "").split("(")[0]
        cards.append({
            "id": nid, "label": "%s_%d" % (deck, nid), "deck": deck,
            "weight": n["weight"], "lockturn": n["lockturn"], "hidden": n["hidden"],
            "bearer": bearers.get(slot),
            "question": {"FR": q},
            "conditions": _conv_conditions(n, var_map, planet_map, seen_map),
            "loadOutcome": _conv_outcomes(n, "loadOutcome", var_map, planet_map, deck_close),
            "leftAnswer": {"title": {"FR": lt}, "reaction": {"FR": lr}},
            "rightAnswer": {"title": {"FR": rt}, "reaction": {"FR": rr}},
            "yesOutcome": _conv_outcomes(n, "yesOutcome", var_map, planet_map, deck_close),
            "noOutcome": _conv_outcomes(n, "noOutcome", var_map, planet_map, deck_close),
            "moods": {"default": m0, "yes": my, "no": mn},
        })

    _merge_json("data/foundation_cards.json", cards, is_list=True)
    if aliases:
        _merge_json("data/link_aliases.json", aliases)
    if roles:
        _merge_json("data/roles.json", roles)
    if characters:
        _merge_json("data/characters.json", characters)
    if bearer_map:
        _merge_json("tools/bearer_mapping.json", bearer_map)
    return len(cards)


def _merge_json(path, data, is_list=False):
    p = ROOT / path
    cur = json.loads(p.read_text())
    if is_list:
        existing = {c["id"] for c in cur}
        clash = existing & {c["id"] for c in data}
        assert not clash, "collision d'IDs: %s" % clash
        cur.extend(data)
        cur.sort(key=lambda c: c["id"])
    else:
        for k, v in data.items():
            cur.setdefault(k, v)
    p.write_text(json.dumps(cur, ensure_ascii=False, indent="\t") + "\n")
