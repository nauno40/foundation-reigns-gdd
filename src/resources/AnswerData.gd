class_name AnswerData
extends Resource

# Une réponse de carte (gauche ou droite) : titre, réaction, et effets sur les jauges.

@export var title: String
@export_multiline var reaction: String
@export var fx: Dictionary = {}   # {ressource: delta} ; clés "legit"/"legitimacy" gérées à part
