class_name PlanetData
extends Resource

# Une planète de la carte galactique : position, faction, état, note.

@export var id: String
@export var name: String
@export var faction: String
@export var state: int = 0
@export var x: float
@export var y: float
@export_multiline var note: String
@export var base: bool = false
@export var hidden: bool = false
