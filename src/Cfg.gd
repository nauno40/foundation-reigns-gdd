@tool
extends Node

# Réglages live (port du panneau Tweaks de app.jsx). Autoload « Cfg ».
# @tool : pour que les scènes @tool (Codex/Death…) lisent Cfg.accent dans l'éditeur.

signal changed

var difficulty := "normal"   # doux / normal / brutal → multiplie les fx
var prose := 17              # taille du texte de question
var motion := 1.0           # grain / scanlines (0..1)
var accent := Color("#4fd6e8")

func emit_changed() -> void:
	changed.emit()
