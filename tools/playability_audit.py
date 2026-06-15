#!/usr/bin/env python3
"""Audit de jouabilité : pour chaque deck cloné, classe les cartes selon leur
*atteignabilité réelle* dans le moteur actuel.

Catégories par carte :
  hidden      — carte de chaîne (atteinte par un `link`, pas tirée au hasard).
  dispatch    — weight -1 hors `deaths`/`new_speaker` : le moteur ne la dispatche
                pas → dormante tant que le dispatcher n'est pas étendu.
  blocked     — tirable mais une condition porte sur une variable JAMAIS posée
                (ni gérée par le moteur, ni écrite par un outcome) avec un test
                qui exige une valeur non nulle → ne peut jamais devenir vraie.
  window      — tirable, conditionnée uniquement par année/mois/lieu (fenêtre).
  open        — tirable immédiatement (aucune condition bloquante).

Sortie : récap par deck + rollup global + top des variables bloquantes.
Lecture seule : ne modifie aucune donnée.
"""
import glob
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).parent.parent
cards = json.loads((ROOT / "data/foundation_cards.json").read_text())
clone_decks = {json.loads(Path(f).read_text())["target_deck"]
               for f in glob.glob(str(ROOT / "data/skeletons/*.json"))}

# Variables que le moteur gère/pose lui-même (donc une condition dessus est
# potentiellement satisfiable au cours d'une partie).
ENGINE_VARS = {"military", "religion", "commerce", "politics", "legitimacy",
               "turns", "year", "month", "day", "age", "mood", "location",
               "link", "faction", "region", "dev_deck"}
ENGINE_PREFIXES = ("deck_", "seen_", "lockturn_", "planet_", "relation_",
                   "region_", "seldon_crisis_")
# Variables posées par les *systèmes* moteur (pas par un outcome de carte).
ENGINE_VARS |= {"evaluate_seldon_crisis", "dying", "cover_name", "times_died",
                "second_empire_progress"}

# Toute variable écrite par un outcome (set ou add), n'importe où → "posable".
settable = set()
for c in cards:
    for key in ("loadOutcome", "yesOutcome", "noOutcome"):
        for o in c.get(key, []):
            v = o.get("variable", "")
            if v and v != "link":
                settable.add(v)


def is_satisfiable_var(v):
    if v in ENGINE_VARS or v in settable:
        return True
    return any(v.startswith(p) for p in ENGINE_PREFIXES)


def cond_can_block(cond):
    """True si cette condition ne peut JAMAIS passer (var jamais posée + test
    exigeant une valeur non nulle, alors que la valeur par défaut est 0)."""
    v = cond.get("variable", "")
    if is_satisfiable_var(v):
        return False
    op, val = cond.get("op"), cond.get("value", 0)
    # valeur par défaut d'une var jamais posée : 0 (ou "")
    if op == "above":   # x > val ; défaut 0 → bloque si val >= 0
        return isinstance(val, (int, float)) and val >= 0
    if op == "equal":   # x == val ; défaut 0 → bloque si val != 0
        return val not in (0, "0", "")
    if op == "not":     # x != val ; défaut 0 → bloque si val == 0
        return val in (0, "0", "")
    if op == "below":   # x < val ; défaut 0 → bloque si val <= 0
        return isinstance(val, (int, float)) and val <= 0
    return False


WINDOW_VARS = {"year", "month", "day", "location"}
rollup = Counter()
blocking_vars = Counter()
per_deck = {}

for c in cards:
    deck = c["deck"]
    if deck not in clone_decks:
        continue
    d = per_deck.setdefault(deck, Counter())
    if c.get("hidden"):
        cat = "hidden"
    elif int(c.get("weight", 1)) < 0 and deck not in ("deaths", "new_speaker"):
        cat = "dispatch"
    else:
        conds = c.get("conditions", [])
        blockers = [co for co in conds if cond_can_block(co)]
        if blockers:
            cat = "blocked"
            for co in blockers:
                blocking_vars[co["variable"]] += 1
        elif conds and all(co.get("variable") in WINDOW_VARS for co in conds):
            cat = "window"
        else:
            cat = "open"
    d[cat] += 1
    rollup[cat] += 1

order = ["open", "window", "blocked", "dispatch", "hidden"]
print(f"{'deck':22} {'open':>5} {'wind':>5} {'block':>6} {'disp':>5} {'hid':>5}  total")
print("-" * 64)
for deck in sorted(per_deck):
    d = per_deck[deck]
    tot = sum(d.values())
    flag = "  ⚠" if d["blocked"] or d["dispatch"] > tot * 0.5 else ""
    print(f"{deck:22} {d['open']:>5} {d['window']:>5} {d['blocked']:>6} "
          f"{d['dispatch']:>5} {d['hidden']:>5}  {tot:>5}{flag}")

print("-" * 64)
tot = sum(rollup.values())
for cat in order:
    print(f"  {cat:9}: {rollup[cat]:>5}  ({100*rollup[cat]/tot:.0f}%)")
print(f"  {'TOTAL':9}: {tot:>5}")

print("\nTop variables bloquantes (jamais posées, exigées non nulles) :")
for v, n in blocking_vars.most_common(20):
    print(f"  {v:28} bloque {n} carte(s)")
