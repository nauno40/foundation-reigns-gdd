extends Node

# Autoload « AudioManager » : gère la musique d'ambiance et les SFX.
# Bus : Master → Music, SFX, UI. Les lecteurs sont créés en code (autoload sans scène).

signal music_finished

var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _ui: AudioStreamPlayer

func _ready() -> void:
	_music = _make_player("Music")
	_sfx = _make_player("SFX")
	_ui = _make_player("UI")
	_music.finished.connect(_on_music_finished)

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _on_music_finished() -> void:
	music_finished.emit()

# Joue une musique d'ambiance (avec fondu d'entrée optionnel en secondes).
func play_music(stream: AudioStream, fade_in: float = 0.0) -> void:
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = -40.0 if fade_in > 0.0 else 0.0
	_music.play()
	if fade_in > 0.0:
		create_tween().tween_property(_music, "volume_db", 0.0, fade_in)

func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	_sfx.stream = stream
	_sfx.play()

func play_ui(stream: AudioStream) -> void:
	if stream == null:
		return
	_ui.stream = stream
	_ui.play()
