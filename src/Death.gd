@tool
class_name Death
extends Control

# Écran de mort (port de app.jsx Death). Structure dans Death.tscn ; ce script remplit
# les nœuds (textes/stats/snapshot) et joue les animations.

signal respawn_pressed

# Réglages d'animation (mêmes valeurs que les littéraux d'origine).
@export var sweep_duration: float = 0.7
@export var entry_scale: float = 1.035
@export var entry_duration: float = 0.5

@onready var _cause: Label = %Cause
@onready var _name: Label = %DeathName
@onready var _sub: Label = %Sub
@onready var _message: Label = %Message
@onready var _stats := [%Stat0, %Stat1, %Stat2, %Stat3]
@onready var _snaps := {
	"military": %SnapMilitary, "religion": %SnapReligion,
	"commerce": %SnapCommerce, "politics": %SnapPolitics,
}

func _ready() -> void:
	%NewReignBtn.pressed.connect(_on_new_reign_pressed)
	if Engine.is_editor_hint():
		if get_tree().edited_scene_root == self:
			show_death({
				"causeLabel": "Militaire — effondrement", "bearerName": "Orateur — Prêtre scientifique",
				"sub": "38 ans · Règne couvert : An 1 → An 2",
				"message": "Une Fondation qui ne sait pas se défendre n'est qu'une bibliothèque attendant l'incendie.",
				"turns": 1, "years": 1, "score": 108, "deviation": "dévié de 6.3 %",
				"res": {"military": 4, "religion": 52, "commerce": 60, "politics": 48},
			})
		return
	visible = false

func _on_new_reign_pressed() -> void:
	respawn_pressed.emit()

func show_death(info: Dictionary) -> void:
	_cause.text = str(info["causeLabel"]).to_upper()
	_name.text = info["bearerName"]
	_sub.text = info["sub"]
	_message.text = info["message"]
	(_stats[0] as StatBox).setup("DÉCISIONS PRISES", str(info["turns"]))
	(_stats[1] as StatBox).setup("ANNÉES COUVERTES", "%d ans" % info["years"])
	(_stats[2] as StatBox).setup("SCORE DU RÈGNE", "%d pts" % info["score"])
	(_stats[3] as StatBox).setup("PLAN DE SELDON", info["deviation"])
	for r in Data.RESOURCES:
		(_snaps[r["key"]] as ResSnapshot).setup(r["key"], r["label"], int(info["res"][r["key"]]))

	visible = true
	if Engine.is_editor_hint():
		return   # pas d'animation dans l'aperçu éditeur
	# deathIn : flash + léger zoom
	pivot_offset = size * 0.5
	scale = Vector2(entry_scale, entry_scale)
	modulate = Color(1.7, 1.7, 1.7)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE, entry_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate", Color.WHITE, entry_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var fk := create_tween()
	for a in [0.3, 1.0, 0.5, 1.0]:
		fk.tween_property(_cause, "modulate:a", a, 0.09)
	_play_sweep()

# deathSweep : bande lumineuse cyan qui balaie l'écran de haut en bas (.death::after)
func _play_sweep() -> void:
	var band_h := size.y * 0.34
	var grad := Gradient.new()
	grad.set_color(0, Color(0.47, 0.9, 0.96, 0.16))
	grad.set_color(1, Color(0.47, 0.9, 0.96, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var sweep := TextureRect.new()
	sweep.texture = gt
	sweep.stretch_mode = TextureRect.STRETCH_SCALE
	sweep.size = Vector2(size.x, band_h)
	sweep.position = Vector2(0, -band_h * 0.4)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sweep)
	var t := create_tween().set_parallel()
	t.tween_property(sweep, "position:y", size.y * 1.2, sweep_duration).set_ease(Tween.EASE_OUT)
	t.tween_property(sweep, "modulate:a", 0.0, sweep_duration)
	t.chain().tween_callback(sweep.queue_free)
