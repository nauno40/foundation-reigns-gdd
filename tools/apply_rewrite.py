#!/usr/bin/env python3
"Réécriture manuelle des cartes 20078-20087 avec dialogue direct"

import json

DATA = "data/foundation_cards.json"

with open(DATA) as f:
    cards = json.load(f)

# Cartes à réécrire
rewrites = {
    20078: {
        "question_FR": "« Magistrat ! Je lance ce soir le grand combat de coqs de la saison. Les paris sont déjà en marche. Vous honorez-nous de votre présence ? » — Le maître de guilde",
        "left_title_FR": "Avec plaisir, c'est un spectacle à ne pas manquer.",
        "left_reaction_FR": "Le maître s'illumine : « Le peuple est ravi, magistrat ! »",
        "right_title_FR": "Non, je ne cautionne pas ce genre de jeu.",
        "right_reaction_FR": "Le maître s'incline, déçu : « Comme vous voulez, mais les coqs combattront quand même. »",
    },
    20079: {
        "question_FR": "« J'ai misé une fortune sur mon coq favori, magistrat. C'est un génie ! » — Le maître d'école",
        "left_title_FR": "Faites preuve de prudence.",
        "left_reaction_FR": "Il se rembrunit : « Vous avez raison… Je modère mes paris. »",
        "right_title_FR": "Laissez-le jouer, chance et passion.",
        "right_reaction_FR": "Il se détend : « Merci, magistrat. La chance sourit aux audacieux. »",
    },
    20080: {
        "question_FR": "« Un parieur conteste mon gain, magistrat. Je dois d'abord résoudre ça avant la révolution populaire. » — Le juge civique",
        "left_title_FR": "Je donne raison au parieur.",
        "left_reaction_FR": "Le juge crie la décision. La moitié de la foule acclame, l'autre grogne.",
        "right_title_FR": "Annulez le pari, c'est trop risqué.",
        "right_reaction_FR": "Le juge annule le pari. Mécontentement général. Personne n'est vraiment content.",
    },
    20081: {
        "question_FR": "« On a trouvé des traces de triche ! Mon coq a été drogué, j'en suis sûr. Enquêter ? » — Le maître d'école, les poings serrés",
        "left_title_FR": "Je m'en occupe immédiatement.",
        "left_reaction_FR": "Vous vérifiez l'accusation. L'affaire prise de pied. Il vous remercie.",
        "right_title_FR": "C'est une histoire de coq, laissez-le en paix.",
        "right_reaction_FR": "Il se tait, humilié. L'affaire reste ouverte.",
    },
    20082: {
        "question_FR": "« Le rival m'attaque en publiant des mensonges, magistrat. Que faites-vous ? » — Le maître d'école, rouge de colère",
        "left_title_FR": "Démêlez cette histoire.",
        "left_reaction_FR": "Vous débarrassez l'affaire de coqs. Cocasse et chronophage. Il vous remercie.",
        "right_title_FR": "Renvoyez-leur dos à dos.",
        "right_reaction_FR": "Vous séparez les coqueleurs. Le juge soupire. L'affaire reste au tribunal.",
    },
    20083: {
        "question_FR": "« Les parieurs se disputent ! La foule monte au crédit. Comment réagissez-vous ? » — Des voix dans la foule",
        "left_title_FR": "Apaisez la foule.",
        "left_reaction_FR": "Vous calmez les esprits. L'ordre revient. La paix est restaurée.",
        "right_title_FR": "Laissez-les se battre.",
        "right_reaction_FR": "Vous laissez le jeu suivre son cours. Risqué, mais la foule se fatigue.",
    },
    20084: {
        "question_FR": "« Je propose d'encadrer les paris avec une taxe, magistrat. Plus de danger, plus de recettes pour la ville. » — Le juge civique",
        "left_title_FR": "Acceptez la réforme.",
        "left_reaction_FR": "Vous réglementez les paris. Ordre et recettes. La ville vous remercie.",
        "right_title_FR": "Laissez les paris libres.",
        "right_reaction_FR": "Vous laissez les paris en libre. Joyeux désordre. La caisse souffre.",
    },
    20085: {
        "question_FR": "« La bagarre éclate entre parieurs ! Les voisins se Battent. La garde est-elle nécessaire ? » — Des cris dans la foule",
        "left_title_FR": "Faites appel à la garde.",
        "left_reaction_FR": "Vous faites appel à la garde. L'ordre est rétabli par la force. Légèrement saignant.",
        "right_title_FR": "Essayez de les calmer.",
        "right_reaction_FR": "Vous tentez de les calmer. Ça marche… temporairement. La tension reste.",
    },
    20086: {
        "question_FR": "« Après la rixe, que faire du jeu de coqs ? L'interdire définitivement ou le réformer ? » — Le juge civique, les manches sleeves",
        "left_title_FR": "Réformez le jeu.",
        "left_reaction_FR": "Vous réformez le jeu plutôt que de l'interdire. Un compromis raisonnable.",
        "right_title_FR": "Interdisez-le définitivement.",
        "right_reaction_FR": "Vous interdisez les combats de coqs. Vertueux, mais la passion du peuple s'éteint.",
    },
    20087: {
        "question_FR": "« Merci d'avoir géré cette affaire, magistrat. Vos décisions ont été… utiles. » — Le maître de guilde, un sourire énigmatique",
        "left_title_FR": "Acceptez ses remerciements.",
        "left_reaction_FR": "Vous glisserez un pourboire. Un allié de plus. Il vous regarde avec attention.",
        "right_title_FR": "Restez neutre.",
        "right_reaction_FR": "Il hoche la tête : « Compris. La retenue a son charme. »",
    },
}

for c in cards:
    cid = c["id"]
    if cid in rewrites:
        r = rewrites[cid]
        c["question"]["FR"] = r["question_FR"]
        c["leftAnswer"]["title"]["FR"] = r["left_title_FR"]
        c["leftAnswer"]["reaction"]["FR"] = r["left_reaction_FR"]
        c["rightAnswer"]["title"]["FR"] = r["right_title_FR"]
        c["rightAnswer"]["reaction"]["FR"] = r["right_reaction_FR"]
        print(f"✓ Carte #{cid} réécrite")

with open(DATA, "w") as f:
    json.dump(cards, f, indent="\t", ensure_ascii=False)

print(f"\nFichier sauvegardé : {DATA}")