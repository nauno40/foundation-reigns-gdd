extends Node

# Autoload « AudioManager » (scène scenes/AudioManager.tscn) : gère la musique
# d'ambiance et les SFX. Bus : Master → Music, SFX, UI. Les lecteurs sont des
# nœuds de la scène (Music/SFX/UI).

signal music_finished

# Streams optionnels, réglables dans l'inspecteur (nœud racine de AudioManager.tscn).
# Non assignés → les sites d'appel passent un fallback synthétique (SfxBank).
# Aucun asset par défaut → silence comme avant.
@export var swipe_sfx: AudioStream
@export var commit_sfx: AudioStream
@export var death_sfx: AudioStream
@export var unlock_sfx: AudioStream
@export var respawn_sfx: AudioStream
@export var music_ambient: AudioStream

@onready var _music: AudioStreamPlayer = $Music
@onready var _sfx: AudioStreamPlayer = $SFX
@onready var _ui: AudioStreamPlayer = $UI

func _ready() -> void:
	_music.finished.connect(_on_music_finished)

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

func play_sfx(stream: AudioStream, fallback: AudioStream = null) -> void:
	var s: AudioStream = stream if stream != null else fallback
	if s == null:
		return
	_sfx.stream = s
	_sfx.play()

func play_ui(stream: AudioStream) -> void:
	if stream == null:
		return
	_ui.stream = stream
	_ui.play()
