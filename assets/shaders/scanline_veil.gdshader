shader_type canvas_item;

// Voile de scanlines du cadre (1px clair toutes les 3px, très subtil)

uniform float strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	float line = step(mod(FRAGCOORD.y, 3.0), 1.0);
	COLOR = vec4(1.0, 1.0, 1.0, 0.018 * line * strength);
}
