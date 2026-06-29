extends Control

# Racine (HTML <body> + #space + .frame) : fond spatial plein écran + filigrane
# d'équations, un cadre 460 centré « flottant dans l'espace » sur grand écran.

func _ready() -> void:
	_fit_window()
	_fill_equ()
	resized.connect(_on_resized)
	_on_resized()

# Fenêtre portrait téléphone ajustée à l'écran + centrée (jeu mobile sur PC).
func _fit_window() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if scr.size.y <= 200:
		return                                      # headless / écran invalide
	var h: int = mini(828, scr.size.y - 60)        # marge barre de titre / tâches
	var w: int = int(round(h * 460.0 / 920.0))     # garde le ratio 1:2 du design
	var win := get_window()
	win.size = Vector2i(w, h)
	win.move_to_center()
	Cfg.changed.connect(_apply_motion)
	_apply_motion()

func _apply_motion() -> void:
	var veil := get_node_or_null("Row/Frame/Veil") as ColorRect
	if veil and veil.material:
		(veil.material as ShaderMaterial).set_shader_parameter("strength", Cfg.motion)

func _on_resized() -> void:
	var sb := ($SpaceBg as ColorRect).material as ShaderMaterial
	if sb:
		sb.set_shader_parameter("rect_size", size)

func _fill_equ() -> void:
	var syms := "∫ ∂ Ψ Σ ∇ λ Φ ε δ → ∞ ± ∮ ≈ √ μ Δ ⟨ ⟩ π τ ω".split(" ")
	var s := ""
	for i in range(1600):
		s += syms[randi() % syms.size()] + ("  " if randf() < 0.15 else " ")
	($Equ as Label).text = s
