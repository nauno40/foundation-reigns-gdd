@tool
extends Node

# Réglages live (port du panneau Tweaks de app.jsx). Autoload « Cfg ».
# @tool : pour que les scènes @tool (Codex/Death…) lisent Cfg.accent dans l'éditeur.

signal changed

# Valeurs par défaut lues depuis ProjectSettings (section [foundation]) — éditables
# dans Projet → Paramètres du projet → foundation (Réglages avancés).
var difficulty: String = ProjectSettings.get_setting("foundation/difficulty", "normal")  # doux / normal / brutal
var prose: int = ProjectSettings.get_setting("foundation/prose", 17)                      # taille du texte de question
var motion: float = ProjectSettings.get_setting("foundation/motion", 1.0)                 # grain / scanlines (0..1)
var accent: Color = ProjectSettings.get_setting("foundation/accent", Color("#4fd6e8"))

func emit_changed() -> void:
	changed.emit()
