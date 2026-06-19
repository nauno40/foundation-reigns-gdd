class_name OptionsScreen
extends Control

signal back_pressed

const SaveSystem = preload("res://src/core/SaveSystem.gd")

const DIFF_OPTIONS = ["doux", "normal", "brutal"]
const DIFF_LABELS = {
	"doux": "Doux — variations amorties (×0.7)",
	"normal": "Normal — équilibré (×1.0)",
	"brutal": "Brutal — punitif (×1.45)",
}

@onready var _diff_select: OptionButton = %DiffSelect
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_val: Label = %MusicVal
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_val: Label = %SfxVal
@onready var _delete_btn: Button = %DeleteBtn
@onready var _back_btn: Button = %BackBtn
@onready var _vbox: VBoxContainer = $Center/VBox

var _delete_confirm: bool = false

func _ready() -> void:
	for key in DIFF_OPTIONS:
		_diff_select.add_item(DIFF_LABELS[key])
		_diff_select.set_item_metadata(_diff_select.item_count - 1, key)
	if Globals.difficulty in DIFF_OPTIONS:
		_diff_select.select(DIFF_OPTIONS.find(Globals.difficulty))

	_music_slider.value = Globals.music_vol
	_sfx_slider.value = Globals.sfx_vol
	_update_vol_label(_music_val, _music_slider.value)
	_update_vol_label(_sfx_val, _sfx_slider.value)

	_music_slider.value_changed.connect(func(v): _update_vol_label(_music_val, v))
	_sfx_slider.value_changed.connect(func(v): _update_vol_label(_sfx_val, v))
	_delete_btn.pressed.connect(_on_delete)
	_back_btn.pressed.connect(_on_back)

# Entrée animée : le fond s'assombrit, les sections se révèlent en cascade.
func animate_in() -> void:
	var s := Anim.settings
	modulate.a = 1.0
	Anim.fade_in($Overlay, s.options_in)
	Anim.reveal_list(_vbox.get_children(), s.options_tab_stagger, s.options_in)

# Sortie animée puis exécution de la fermeture (on_done).
func animate_out(on_done: Callable) -> void:
	var tw := Anim.fade_out(self, Anim.settings.options_out)
	tw.finished.connect(on_done, CONNECT_ONE_SHOT)

func _on_back() -> void:
	animate_out(func(): back_pressed.emit())

func _update_vol_label(label: Label, v: float) -> void:
	label.text = "%d%%" % int(v * 100)

func apply() -> void:
	var idx = _diff_select.selected
	if idx >= 0 and idx < DIFF_OPTIONS.size():
		Globals.difficulty = DIFF_OPTIONS[idx]
	Globals.music_vol = _music_slider.value
	Globals.sfx_vol = _sfx_slider.value
	Globals.save_config()

func _on_delete() -> void:
	if not _delete_confirm:
		_delete_confirm = true
		_delete_btn.text = "CONFIRMER ?"
		var t = get_tree().create_timer(3.0)
		await t.timeout
		_delete_confirm = false
		_delete_btn.text = "SUPPRIMER LA SAUVEGARDE"
		return

	var save = SaveSystem.new()
	save.delete_save()
	_delete_btn.text = "SAUVEGARDE SUPPRIMÉE"
	_delete_confirm = false
