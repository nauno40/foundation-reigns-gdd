class_name CardData
extends Resource

# Une carte du deck : porteur, rôle, humeur, question, et les deux réponses.

@export var id: String
@export var bearer: String
@export var role: String
@export var mood: String
@export var key: bool = false
@export_multiline var question: String
@export var left_answer: AnswerData
@export var right_answer: AnswerData
