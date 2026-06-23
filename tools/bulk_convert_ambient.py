#!/usr/bin/env python3
"""Convertit automatiquement les titres/réactions 'On' → dialogue direct pour le deck ambient."""

import json, re

DATA = "data/foundation_cards.json"
DECK = "ambient"

with open(DATA) as f:
    cards = json.load(f)

ON_RE = re.compile(r'\bOn\s+(\w+)')

# Mapping d'expressions « On + verbe » → réponse du joueur ou réaction du personnage
PLAYER_RESPONSES = {
    # Verbes d'action du joueur
    "y_assiste": "J'y assisye",
    "y_assiste": "Je m'y rends",
    "l_accepte": "J'accepte",
    "l_accepte": "Accepté",
    "l_refuse": "Je refuse",
    "l_refuse": "Refusé",
    "l'interdit": "Je l'interdis",
    "lance": "Je lance",
    "lance": "Je déclenche",
    "enquête": "J'enquête",
    "enquête": "Je vais vérifier",
    "calme": "J'apaise",
    "calme": "Je calme",
    "laisse": "Je laisse faire",
    "laisse": "Laisse fuir",
    "attend": "J'attends",
    "part": "Je pars",
    "reste": "Je reste",
    "reste": "Reste",
    "tient": "Je tient",
    "prend": "Je prends",
    "donne": "Je donne",
    "note": "Je note",
    "observe": "J'observe",
    "hésite": "J'hésite",
}

def convert_on_text(text):
    """Convertit une phrase commençant par 'On' vers le style direct."""
    if not text or not ON_RE.search(text):
        return text
    
    # Pattern: On [verbe] [complément]
    # Ex: "On y assiste" → "J'y assisye" / "Je m'y rends"
    # Ex: "On accepte" → "J'accepte"
    
    # Simplification : On remplace "On" par "Je" et on ajuste le verbe
    m = ON_RE.match(text)
    if m:
        verb = m.group(1).lower()
        rest = text[m.end():]
        if verb in PLAYER_RESPONSES:
            return PLAYER_RESPONSES[verb] + rest
        # Retour fallback : transformation directe
        if verb.endswith('e'):
            return "Je " + verb + rest
        elif verb.endswith('s'):
            return "Je " + verb[:-1] + "s" + rest
        else:
            return "Je " + verb + rest
    return text

count = 0
for c in cards:
    if c.get("deck") != DECK:
        continue
    
    # Convertir les titres et réactions
    for side in ["leftAnswer", "rightAnswer"]:
        answer = c.get(side, {})
        title = answer.get("title", {}).get("FR", "")
        reaction = answer.get("reaction", {}).get("FR", "")
        
        if ON_RE.search(title):
            old = title
            new = convert_on_text(title)
            c[side]["title"]["FR"] = new
            count += 1
        if ON_RE.search(reaction):
            old = reaction
            new = convert_on_text(reaction)
            c[side]["reaction"]["FR"] = new
            count += 1

print(f"Converti {count} occurrences dans le deck [{DECK}]")
with open(DATA, "w") as f:
    json.dump(cards, f, indent="\t", ensure_ascii=False)
print(f"Fichier sauvegardé : {DATA}")