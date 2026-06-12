#!/usr/bin/env python3
"""Diff structurel squelettes ↔ cartes livrées dans foundation_cards.json.

Pour chaque deck dont AU MOINS une carte avec un id présent dans le squelette
existe dans les données du jeu (livré = démarré), vérifie :
  - chaque nœud du squelette est présent (même id) ;
  - hidden / weight / lockturn identiques ;
  - chaque outcome `link` du squelette pointe vers la même cible (id ou alias) ;
  - les cartes en plus sont soit dans tools/structure_additions.json, soit ERREUR.
Un deck sans aucune carte livrée dans la plage du squelette est signalé
"non rempli" (pas une erreur).
Sortie 1 si au moins une erreur.

Whitelist : {"<deck>": [<ids ajoutés>], "_in_progress": ["<deck>", ...]}
Un deck listé dans _in_progress tolère les nœuds de squelette manquants
(remplissage par lots) — ils sont comptés, pas signalés en erreur.
"""
import argparse
import json
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description="Structural diff skeletons vs shipped cards")
parser.add_argument("--root", type=Path, default=None,
                    help="Repo root (default: parent of this script's directory)")
args = parser.parse_args()

ROOT = args.root if args.root is not None else Path(__file__).parent.parent
errors, delivered, pending = [], 0, 0
cards = json.loads((ROOT / "data/foundation_cards.json").read_text())
by_deck = {}
for c in cards:
    by_deck.setdefault(c["deck"], {})[c["id"]] = c
additions = json.loads((ROOT / "tools/structure_additions.json").read_text())
in_progress = set(additions.get("_in_progress", []))


def links_of(card_or_node, key):
    out = []
    for o in (card_or_node.get(key) or []):
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

    # A deck is "started" only when at least one shipped card id appears in the skeleton
    sk_ids = {n["id"] for n in sk["nodes"]}
    started = any(i in sk_ids for i in have)
    if not started:
        pending += 1
        continue

    delivered += 1
    for n in sk["nodes"]:
        card = have.get(n["id"])
        if card is None:
            if deck not in in_progress:
                errors.append(f"{deck}: nœud {n['id']} (orig {n['orig_id']}) manquant")
            continue
        for field in ("hidden", "weight", "lockturn"):
            card_val = card.get(field, 0 if field != "hidden" else False)
            if card_val != n[field]:
                errors.append(
                    f"{deck}#{n['id']}: {field} = {card_val!r} ≠ squelette {n[field]!r}"
                )
        for key in ("yesOutcome", "noOutcome", "loadOutcome"):
            want = links_of(n, key)
            got = links_of(card, key)
            if want and want != got:
                errors.append(f"{deck}#{n['id']}: liens {key} {got} ≠ {want}")

    extra = set(have) - sk_ids - set(additions.get(deck, []))
    for x in sorted(extra):
        errors.append(
            f"{deck}: carte {x} hors squelette (ajouter à "
            f"structure_additions.json si assumée)"
        )

for deck in sorted(in_progress):
    sk_files = [f for f in (ROOT / "data/skeletons").glob("*.json")]
    for f in sk_files:
        s = json.loads(f.read_text())
        if s["target_deck"] == deck:
            filled = sum(1 for n in s["nodes"] if n["id"] in by_deck.get(deck, {}))
            print(f"en cours — {deck}: {filled}/{s['node_count']} nœuds")
print(f"decks livrés: {delivered} · non remplis: {pending}")
if errors:
    print(f"ÉCHEC — {len(errors)} écart(s):")
    for e in errors:
        print(f"  x {e}")
    sys.exit(1)
print("OK structure conforme au jeu de base")
