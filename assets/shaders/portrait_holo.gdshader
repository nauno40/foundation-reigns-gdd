shader_type canvas_item;

// Portrait holographique : fond #070c16 + halo cyan en haut + grille 22px
// masquée radialement + scanlines sombres 2px/4px. Une seule passe.

uniform vec2 rect_size = vec2(324.0, 190.0);

void fragment() {
	vec2 uv = UV;
	vec3 cyan = vec3(0.310, 0.839, 0.910);

	vec3 col = vec3(0.027, 0.047, 0.086);

	// radial-gradient(120% 90% at 50% 8%, rgba(79,214,232,.16), transparent 62%)
	vec2 d = (uv - vec2(0.5, 0.08)) / vec2(1.2, 0.9);
	col += cyan * 0.12 * (1.0 - smoothstep(0.0, 0.62, length(d)));

	// grille 22px masquée radialement (70% à 50%,40%)
	vec2 px = uv * rect_size;
	vec2 cell = mod(px, 22.0);
	float line = clamp(step(cell.x, 1.0) + step(cell.y, 1.0), 0.0, 1.0);
	float mask = 1.0 - smoothstep(0.22, 0.58, distance(uv, vec2(0.5, 0.40)));
	col += cyan * 0.08 * line * mask;

	// scanlines : 2px sombres toutes les 4px
	float band = step(2.0, mod(px.y, 4.0));
	col = mix(col, vec3(0.0), 0.18 * band);

	COLOR = vec4(col, 1.0);
}
