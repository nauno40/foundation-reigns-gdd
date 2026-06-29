shader_type canvas_item;

// Grille holographique cyan masquée radialement (app.jsx .cgrid / portrait grid).

uniform vec2 rect_size = vec2(200.0, 200.0);

void fragment() {
	vec2 px = UV * rect_size;
	vec2 cell = mod(px, 20.0);
	float line = clamp(step(cell.x, 1.0) + step(cell.y, 1.0), 0.0, 1.0);
	float mask = 1.0 - smoothstep(0.35, 0.72, distance(UV, vec2(0.5, 0.42)));
	COLOR = vec4(0.310, 0.839, 0.910, 0.06 * line * mask);
}
