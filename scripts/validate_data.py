#!/usr/bin/env python3
"""Validate all Foundation game data files for schema correctness."""
import json, sys
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
errors = []

def load(filename):
    path = DATA_DIR / filename
    if not path.exists():
        errors.append(f"MISSING: {filename}")
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"JSON ERROR in {filename}: {e}")
        return None

def check(condition, message):
    if not condition:
        errors.append(message)

# --- factions.json ---
factions = load("factions.json")
if factions:
    check(len(factions) == 9, f"factions.json: expected 9, got {len(factions)}")
    required = {"id", "name", "year_start", "year_end", "primary_resource", "starting_relation"}
    for f in factions:
        missing = required - set(f.keys())
        check(not missing, f"faction '{f.get('id','?')}' missing fields: {missing}")

# --- planets.json ---
planets = load("planets.json")
if planets:
    check(len(planets) == 12, f"planets.json: expected 12, got {len(planets)}")
    required = {"id", "name", "faction", "initial_state", "game_over_if_lost"}
    for p in planets:
        missing = required - set(p.keys())
        check(not missing, f"planet '{p.get('id','?')}' missing fields: {missing}")
        check(p.get("initial_state") in (-1, 0, 1),
              f"planet '{p.get('id','?')}' initial_state must be -1, 0, or 1")
    terminus = next((p for p in planets if p["id"] == "terminus"), None)
    check(terminus is not None, "planets.json: terminus not found")
    check(terminus and terminus.get("game_over_if_lost"), "terminus must have game_over_if_lost=true")

# --- moods.json ---
moods = load("moods.json")
if moods:
    check(len(moods) == 8, f"moods.json: expected 8 moods, got {len(moods)}")
    expected_moods = {"neutral","suspicious","afraid","angry","flattered","curious","sad","desperate"}
    check(set(moods.keys()) == expected_moods, f"moods.json: unexpected keys: {set(moods.keys()) ^ expected_moods}")

# --- given_names.json + family_names.json ---
given = load("given_names.json")
if given:
    check(len(given) >= 40, f"given_names.json: expected >=40, got {len(given)}")
family = load("family_names.json")
if family:
    check(len(family) >= 25, f"family_names.json: expected >=25, got {len(family)}")

# --- characters.json ---
characters = load("characters.json")
if characters:
    required = {"name", "deck", "fixed"}
    for cid, c in characters.items():
        missing = required - set(c.keys())
        check(not missing, f"character '{cid}' missing fields: {missing}")

# --- covers.json ---
covers = load("covers.json")
if covers:
    expected_eras = {"hardin","merchants","mallow","mulet","restoration","late_empire"}
    check(set(covers.keys()) == expected_eras, f"covers.json missing eras: {expected_eras - set(covers.keys())}")

# --- seldon_crises.json ---
crises = load("seldon_crises.json")
if crises:
    check(set(crises.keys()) == {f"crisis_{i}" for i in range(1, 7)},
          f"seldon_crises.json: expected crisis_1..crisis_6, got {sorted(crises.keys())}")
    valid_ops = {"equal", "above", "below", "not"}
    for cid, c in crises.items():
        missing = {"name", "year_window", "corridor", "description"} - set(c.keys())
        check(not missing, f"{cid} missing fields: {missing}")
        for cond in c.get("corridor", []):
            check(set(cond.keys()) == {"variable", "op", "value"},
                  f"{cid}: malformed corridor condition {cond}")
            check(cond.get("op") in valid_ops, f"{cid}: unknown op '{cond.get('op')}'")

# --- foundation_cards.json ---
cards = load("foundation_cards.json")
if cards:
    check(len(cards) >= 20, f"foundation_cards.json: expected >=20 cards, got {len(cards)}")
    ids = [c.get("id") for c in cards]
    check(len(ids) == len(set(ids)), "foundation_cards.json: duplicate IDs found")
    required = {"id","label","deck","weight","lockturn","question","leftAnswer","rightAnswer"}
    for c in cards:
        missing = required - set(c.keys())
        check(not missing, f"card {c.get('id','?')} missing fields: {missing}")
        check("FR" in c.get("question",{}), f"card {c.get('id','?')} missing FR question")
    if factions:
        faction_ids = {f["id"] for f in factions}
        for c in cards:
            for outcome in c.get("yesOutcome",[]) + c.get("noOutcome",[]) + c.get("loadOutcome",[]):
                var = outcome.get("variable","")
                if var.startswith("relation_"):
                    fid = var[len("relation_"):]
                    check(fid in faction_ids, f"card {c.get('id','?')}: unknown faction '{fid}' in outcome")

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

# --- Report ---
if errors:
    print(f"VALIDATION FAILED — {len(errors)} error(s):")
    for e in errors:
        print(f"  x {e}")
    sys.exit(1)
else:
    print("OK All data files valid")
