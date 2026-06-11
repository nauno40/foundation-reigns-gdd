shader_type canvas_item;

// Grille holographique cyan du portrait, masquée radialement (70% à 50%,40%)

uniform vec2 rect_size = vec2(360.0, 190.0);

void fragment() {
	vec2 px = UV * rect_size;
	vec2 cell = mod(px, 22.0);
	float line = (step(cell.x, 1.0) + step(cell.y, 1.0));
	line = clamp(line, 0.0, 1.0);

	vec2 center = vec2(0.5, 0.40);
	float mask = 1.0 - smoothstep(0.35, 0.70, distance(UV, center));

	COLOR = vec4(0.310, 0.839, 0.910, 0.08 * line * mask);
}
