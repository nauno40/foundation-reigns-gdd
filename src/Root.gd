extends Control

# Racine (HTML <body> + #space + .frame) : fond spatial plein écran + filigrane
# d'équations, un cadre 460 centré « flottant dans l'espace » sur grand écran.

func _ready() -> void:
	_fill_equ()
	resized.connect(_on_resized)
	_on_resized()
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
