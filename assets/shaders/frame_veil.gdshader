shader_type canvas_item;

// Voile de scanlines sur le cadre (HTML .frame::after) :
// repeating-linear-gradient 1px clair toutes les 3px, très subtil.

uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float line = step(mod(FRAGCOORD.y, 3.0), 1.0);
	COLOR = vec4(1.0, 1.0, 1.0, 0.018 * line * strength);
}
