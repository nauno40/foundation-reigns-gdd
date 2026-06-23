#!/usr/bin/env python3
"Réécriture interactive de cartes — mode dialogue direct."

import json, os, sys

DATA = "data/foundation_cards.json"
BACKUP = DATA.replace(".json", "_before_rewrite.json")
DECK = "ambient"
START_ID = 20078
END_ID = 20087

with open(DATA) as f:
    cards = json.load(f)

if not os.path.exists(BACKUP):
    with open(BACKUP, "w") as f:
        json.dump(cards, f, indent="\t", ensure_ascii=False)
    print(f"Backup créé : {BACKUP}")

targets = [c for c in cards if c.get("deck") == DECK and START_ID <= c["id"] <= END_ID]
targets.sort(key=lambda c: c["id"])

if not targets:
    print(f"Aucune carte trouvée dans [{DECK}] entre {START_ID} et {END_ID}")
    sys.exit(1)

print(f"\n{'='*60}")
print(f"Réécriture du deck [{DECK}] — {len(targets)} cartes")
print(f"{'='*60}\n")

want_redo = ""
for idx, c in enumerate(targets):
    cid = c["id"]
    label = c.get("label", "")
    bearer = c.get("bearer", "—")

    if want_redo and cid < want_redo:
        continue
    if want_redo and cid > want_redo:
        want_redo = ""

    while True:
        print(f"\n{'─'*60}")
        print(f"CARTE #{cid}  [{label}]  [{bearer}]  ({idx+1}/{len(targets)})")
        print(f"{'─'*60}")

        q = c.setdefault("question", {}).setdefault("FR", "")
        lt = c.setdefault("leftAnswer", {}).setdefault("title", {}).setdefault("FR", "")
        lr = c.setdefault("leftAnswer", {}).setdefault("reaction", {}).setdefault("FR", "")
        rt = c.setdefault("rightAnswer", {}).setdefault("title", {}).setdefault("FR", "")
        rr = c.setdefault("rightAnswer", {}).setdefault("reaction", {}).setdefault("FR", "")

        yes = c.get("yesOutcome", [])
        no = c.get("noOutcome", [])

        print(f"\n  QUESTION actuelle:\n    « {q} »")
        print(f"  ◀ TITRE: « {lt} »")
        print(f"  ◀ RÉACTION: « {lr} »")
        print(f"  ▶ TITRE: « {rt} »")
        print(f"  ▶ RÉACTION: « {rr} »")
        if yes:
            print(f"  ◀ OUTCOMES: {[(o.get('variable'), o.get('intValue', 0)) for o in yes]}")
        if no:
            print(f"  ▶ OUTCOMES: {[(o.get('variable'), o.get('intValue', 0)) for o in no]}")

        if bearer != "—":
            print(f"\n  Le personnage qui parle est : {bearer}")

        print(f"\n  Tu veux réécrire ?")
        print(f"    [Entrée] →  oui, je réécris les champs un par un")
        print(f"    [s]      →  passer cette carte")
        print(f"    [q]      →  quitter")
        cmd = input("  > ").strip().lower()

        if cmd == "q":
            with open(DATA, "w") as f:
                json.dump(cards, f, indent="\t", ensure_ascii=False)
            print(f"\nSauvegardé dans {DATA}")
            sys.exit(0)
        if cmd == "s":
            print("  [passée]")
            break

        def edit_field(name, current):
            val = input(f"  {name} [{repr(current)}]  > ")
            return val if val else current

        nq = input(f"\n  Question [Enter=inchangée] > ")
        if nq:
            c["question"]["FR"] = nq

        nlt = input(f"  ◀ Titre [{repr(lt)}]  > ")
        if nlt:
            c["leftAnswer"]["title"]["FR"] = nlt

        nlr = input(f"  ◀ Réaction [{repr(lr)}]  > ")
        if nlr:
            c["leftAnswer"]["reaction"]["FR"] = nlr

        nrt = input(f"  ▶ Titre [{repr(rt)}]  > ")
        if nrt:
            c["rightAnswer"]["title"]["FR"] = nrt

        nrr = input(f"  ▶ Réaction [{repr(rr)}]  > ")
        if nrr:
            c["rightAnswer"]["reaction"]["FR"] = nrr

        with open(DATA, "w") as f:
            json.dump(cards, f, indent="\t", ensure_ascii=False)
        print("  ✓ Sauvegardé")

        print("\n  Continuer ?")
        print("    [Entrée] →  carte suivante")
        print("    [r]      →  refaire cette carte")
        print("    [q]      →  quitter")
        cmd = input("  > ").strip().lower()
        if cmd == "q":
            sys.exit(0)
        if cmd == "r":
            continue
        break

with open(DATA, "w") as f:
    json.dump(cards, f, indent="\t", ensure_ascii=False)
print(f"\n✓ Terminé. {len(targets)} cartes traitées. Fichier : {DATA}")
