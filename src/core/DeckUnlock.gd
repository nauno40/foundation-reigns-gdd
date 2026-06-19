class_name DeckUnlock

# Retourne l'entrée du deck à débloquer ({id, name, subtitle}) si la carte
# appartient à un deck jalon (présent dans `unlocks`) pas encore débloqué
# (flag toKeep deck_unlocked_<id> non posé). Sinon {} (cas par défaut).
static func pending_unlock(card: Dictionary, ctx: Context, unlocks: Dictionary) -> Dictionary:
	var deck: String = str(card.get("deck", ""))
	if deck == "" or not unlocks.has(deck):
		return {}
	if int(ctx.get_var("deck_unlocked_" + deck, 0)) != 0:
		return {}
	return unlocks[deck]
