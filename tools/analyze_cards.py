#!/usr/bin/env python3
"""Analyse tous les patterns « On » et incohérences stats dans foundation_cards.json.
Génère un rapport structuré pour guider la réécriture."""

import json, re, sys
from collections import Counter

DATA = "data/foundation_cards.json"

with open(DATA) as f:
    cards = json.load(f)

ON_RE = re.compile(r'\bOn\s+(\w+)', re.UNICODE)
RESOURCES = {"military", "religion", "commerce", "politics"}

# ── 1. Patterns « On » dans titres et réactions ──────────────────────

on_left_titles = []   # (card_id, deck, verb, original)
on_right_titles = []
on_left_reactions = []
on_right_reactions = []

for c in cards:
    lt = c.get('leftAnswer', {}).get('title', {}).get('FR', '')
    rt = c.get('rightAnswer', {}).get('title', {}).get('FR', '')
    lr = c.get('leftAnswer', {}).get('reaction', {}).get('FR', '')
    rr = c.get('rightAnswer', {}).get('reaction', {}).get('FR', '')
    deck = c.get('deck', '?')
    cid = c['id']

    for m in ON_RE.finditer(lt):
        on_left_titles.append((cid, deck, m.group(1), lt[:100]))
    for m in ON_RE.finditer(rt):
        on_right_titles.append((cid, deck, m.group(1), rt[:100]))
    for m in ON_RE.finditer(lr):
        on_left_reactions.append((cid, deck, m.group(1), lr[:100]))
    for m in ON_RE.finditer(rr):
        on_right_reactions.append((cid, deck, m.group(1), rr[:100]))

# ── 2. Stats incohérentes ────────────────────────────────────────────

identical_outcomes = []  # cartes où yesOutcome == noOutcome (choix sans impact)
extreme_swings = []      # swing ≥ 15 sur une ressource
narrative_mismatch = []  # indice : narratif positif → stat négative

for c in cards:
    yes = c.get('yesOutcome', [])
    no = c.get('noOutcome', [])
    cid = c['id']
    deck = c.get('deck', '?')
    q = c.get('question', {}).get('FR', '')[:100]

    if yes and no:
        # Nettoyer les link outcomes qui faussent la comparaison
        yes_clean = [o for o in yes if o.get('variable') != 'link']
        no_clean = [o for o in no if o.get('variable') != 'link']
        if yes_clean and no_clean and yes_clean == no_clean:
            identical_outcomes.append((cid, deck, q))

    for side, outcomes in [('G', yes), ('D', no)]:
        for o in outcomes:
            v = o.get('variable', '')
            val = o.get('intValue', 0)
            if v in RESOURCES and abs(val) >= 15:
                extreme_swings.append((cid, deck, side, v, val, q))

# ── 3. Rapport ───────────────────────────────────────────────────────

print("=" * 72)
print("RAPPORT D'ANALYSE DES CARTES")
print(f"Total : {len(cards)} cartes dans {DATA}")
print("=" * 72)

# ── 3a. Pattern « On » ──────────────────────────────────────────────

print(f"\n{'='*72}")
print(f"1. PATRON « On » (3e personne) — {len(on_left_titles)+len(on_right_titles)+len(on_left_reactions)+len(on_right_reactions)} occurrences")
print(f"{'='*72}")

for label, data in [
    ("Titres G (choix gauche)", on_left_titles),
    ("Titres D (choix droit)", on_right_titles),
    ("Réactions G", on_left_reactions),
    ("Réactions D", on_right_reactions),
]:
    print(f"\n  ► {label} : {len(data)}")
    verbs = Counter(v for _,_,v,_ in data)
    for v, n in verbs.most_common(20):
        print(f"    On {v} : {n}x")

# ── 3b. Verbes « On » avec proposition de réécriture ────────────────

print(f"\n{'='*72}")
print("2. PROPOSITIONS DE RÉÉCRITURE (patrons « On + verbe » → style direct)")
print(f"{'='*72}")

# Mapping des verbes les plus courants vers impératif (adresse au joueur)
# ou 1ère personne (le joueur parle)
VERB_MAP = {
    # Impératif (le personnage donne un ordre / conseille)
    "déploie": "Déployez",
    "déploient": "Déployez",
    "lance": "Lancez",
    "lancé": "Lancez",
    "envoie": "Envoyez",
    "envoient": "Envoyez",
    "laisse": "Laissez",
    "prend": "Prenez",
    "accepte": "Acceptez",
    "refuse": "Refusez",
    "demande": "Demandez",
    "offre": "Offrez",
    "ordonne": "Ordonnez",
    "interdit": "Interdisez",
    "propose": "Proposez",
    "tente": "Tentez",
    "cherche": "Cherchez",
    "continue": "Continuez",
    "garde": "Gardez",
    "confie": "Confiez",
    "choisit": "Choisissez",
    "écoute": "Écoutez",
    "parle": "Parlez",
    "appelle": "Appelez",
    "suit": "Suivez",
    "ouvre": "Ouvrez",
    "ferme": "Fermez",
    "monte": "Montez",
    "descend": "Descendez",
    "entre": "Entrez",
    "sort": "Sortez",
    "donne": "Donnez",
    "montre": "Montrez",
    "explique": "Expliquez",
    "annonce": "Annoncez",
    "prépare": "Préparez",
    "attend": "Attendez",
    "regarde": "Regardez",
    "écrit": "Écrivez",
    "lit": "Lisez",
    "met": "Mettez",
    "tient": "Tenez",
    "revient": "Revenez",
    "passe": "Passez",
    "tourne": "Tournez",
    "change": "Changez",
    "reste": "Restez",
    "part": "Partez",
    "va": "Allez",
    "vient": "Venez",
    "voit": "Voyez",
    "sait": "Sachez",
    "pense": "Pensez",
    "croit": "Croyez",
    "dit": "Dites",
    "répond": "Répondez",
    "demandé": "Demandez",
    "parvenez": "Parvenez",
    "conseille": "Conseillez",
    "menace": "Menacez",
    "rassure": "Rassurez",
    "flatte": "Flattez",
    "félicite": "Félicitez",
    "presse": "Pressez",
    "presque": "—",  # faux positif "presque"
    # 1ère personne (le joueur exprime)
    "savoure": "Je savoure",
    "souri": "Je souris",
    "hoche": "Je hoche",
    "approuve": "J'approuve",
    "comprends": "Je comprends",
    "observe": "J'observe",
    "réfléchit": "Je réfléchis",
    "hésite": "J'hésite",
    "insiste": "J'insiste",
    "soupire": "Je soupire",
    "murmure": "Je murmure",
    "concède": "Je concède",
    "acquiesce": "J'acquiesce",
    "profite": "Je profite",
    "penche": "Je penche",
    "s'approche": "Je m'approche",
    "s'éloigne": "Je m'éloigne",
    "s'assied": "Je m'assieds",
    "se lève": "Je me lève",
    "se tourne": "Je me tourne",
    "se penche": "Je me penche",
    "se tait": "Je me tais",
    "se lamente": "Je me lamente",
    "se méfie": "Je me méfie",
    "s'inquiète": "Je m'inquiète",
    "s'étonne": "Je m'étonne",
    "s'incline": "Je m'incline",
    "s'impatiente": "Je m'impatiente",
}

# Grouper par verbe
all_on_verbs = Counter()
for _,_,v,_ in on_left_titles + on_right_titles + on_left_reactions + on_right_reactions:
    all_on_verbs[v] += 1

print(f"\n  {'Verbe':<25} {'Occ':<5} Proposition")
print(f"  {'─'*25} {'─'*5} {'─'*40}")
for v, n in all_on_verbs.most_common(40):
    prop = VERB_MAP.get(v, "—")
    if prop == "—":
        continue
    print(f"  On {v:<22} {n:<5} {prop}")

# Verbes non mappés
unmapped = [v for v in all_on_verbs if v not in VERB_MAP and v != "presque"]
if unmapped:
    print(f"\n  ⚠  Verbes non mappés ({len(unmapped)}) : {', '.join(unmapped[:15])}")

# ── 3c. Exemples concrets ───────────────────────────────────────────

print(f"\n{'='*72}")
print("3. EXEMPLES « On » — ORIGINAL → PROPOSITION")
print(f"{'='*72}")

def rewrite_on(text):
    """Tente une réécriture automatique d'un texte commençant par On."""
    if not text:
        return text
    m = ON_RE.match(text)
    if m:
        v = m.group(1)
        prop = VERB_MAP.get(v)
        if prop:
            rest = text[m.end():]
            if prop.startswith("Je "):
                # 1ère personne : garder le reste tel quel
                new_text = prop + rest
            else:
                # Impératif : garder le reste
                new_text = prop + rest
            return new_text.strip()
    return text

shown = 0
for c in cards:
    if shown >= 25:
        break
    cid = c['id']
    deck = c.get('deck', '?')
    q = c.get('question', {}).get('FR', '')[:100]
    lt = c.get('leftAnswer', {}).get('title', {}).get('FR', '')
    rt = c.get('rightAnswer', {}).get('title', {}).get('FR', '')
    lr = c.get('leftAnswer', {}).get('reaction', {}).get('FR', '')
    rr = c.get('rightAnswer', {}).get('reaction', {}).get('FR', '')

    if not (ON_RE.search(lt) or ON_RE.search(rt) or ON_RE.search(lr) or ON_RE.search(rr)):
        continue

    shown += 1
    print(f"\n  [#{cid}] [{deck}] {q}")
    if ON_RE.search(lt):
        new_lt = rewrite_on(lt)
        print(f"    ◀ « {lt} »")
        if new_lt != lt:
            print(f"    →   « {new_lt} »")
    if ON_RE.search(rt):
        new_rt = rewrite_on(rt)
        print(f"    ▶ « {rt} »")
        if new_rt != rt:
            print(f"    →   « {new_rt} »")
    if ON_RE.search(lr):
        new_lr = rewrite_on(lr)
        print(f"    ◀≈ « {lr} »")
        if new_lr != lr:
            print(f"    →    « {new_lr} »")
    if ON_RE.search(rr):
        new_rr = rewrite_on(rr)
        print(f"    ▶≈ « {rr} »")
        if new_rr != rr:
            print(f"    →    « {new_rr} »")
    print()

# ── 4. Stats incohérentes ──────────────────────────────────────────

print(f"\n{'='*72}")
print("4. CARTES AVEC OUTCOMES IDENTIQUES G/D — {len(identical_outcomes)} cartes")
print("   (le choix du joueur n'a aucun impact)")
print(f"{'='*72}")
for cid, deck, q in identical_outcomes[:20]:
    print(f"  [#{cid}] [{deck}] {q}")
if len(identical_outcomes) > 20:
    print(f"  ... et {len(identical_outcomes)-20} autres")

print(f"\n{'='*72}")
print(f"5. SWINGS EXTRÊMES (≥ ±15) — {len(extreme_swings)} occurrences")
print(f"{'='*72}")
for cid, deck, side, var, val, q in extreme_swings[:25]:
    print(f"  [#{cid}] [{deck}] {side} → {var} {val:+d} : {q}")
if len(extreme_swings) > 25:
    print(f"  ... et {len(extreme_swings)-25} autres")

# ── 5. Résumé deck par deck ─────────────────────────────────────────

print(f"\n{'='*72}")
print("6. RÉSUMÉ PAR DECK")
print(f"{'='*72}")
print(f"  {'Deck':<30} {'Total':<6} {'« On »':<6} {'Idem G/D':<9} {'Swings':<7}")
print(f"  {'─'*30} {'─'*6} {'─'*6} {'─'*9} {'─'*7}")

deck_stats = {}
for c in cards:
    d = c.get('deck', '?')
    if d not in deck_stats:
        deck_stats[d] = {'total': 0, 'on': 0, 'identical': 0, 'swings': 0}
    deck_stats[d]['total'] += 1
    
    lt = c.get('leftAnswer', {}).get('title', {}).get('FR', '')
    rt = c.get('rightAnswer', {}).get('title', {}).get('FR', '')
    lr = c.get('leftAnswer', {}).get('reaction', {}).get('FR', '')
    rr = c.get('rightAnswer', {}).get('reaction', {}).get('FR', '')
    if ON_RE.search(lt) or ON_RE.search(rt) or ON_RE.search(lr) or ON_RE.search(rr):
        deck_stats[d]['on'] += 1
    
    yes = c.get('yesOutcome', [])
    no = c.get('noOutcome', [])
    yes_clean = [o for o in yes if o.get('variable') != 'link']
    no_clean = [o for o in no if o.get('variable') != 'link']
    if yes_clean and no_clean and yes_clean == no_clean:
        deck_stats[d]['identical'] += 1
    
    for o in yes + no:
        if o.get('variable', '') in RESOURCES and abs(o.get('intValue', 0)) >= 15:
            deck_stats[d]['swings'] += 1

for d in sorted(deck_stats, key=lambda x: -deck_stats[x]['total']):
    s = deck_stats[d]
    if s['on'] > 0 or s['identical'] > 0 or s['swings'] > 0:
        print(f"  {d:<30} {s['total']:<6} {s['on']:<6} {s['identical']:<9} {s['swings']:<7}")

print(f"\nFichier analysé : {DATA}")
print(f"Utilisez ce rapport pour guider la réécriture.")
print(f"Proposition : lancer tools/rewrite_cards.py avec le VERB_MAP ci-dessus")
print(f"pour une réécriture automatique des ~1200 titres/réactions 'On'.")
