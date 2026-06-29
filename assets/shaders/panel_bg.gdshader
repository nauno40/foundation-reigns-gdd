shader_type canvas_item;

// Fond du panneau central (app.jsx .panel) :
//   radial-gradient(120% 55% at 50% 0%, rgba(79,214,232,.09), transparent 60%)
// + linear-gradient(180deg, #0f1827, #0a1320)
// + grille 30px rgba(79,214,232,.05) masquée vers le bas (transparent 65%).

void fragment() {
	vec2 uv = UV;
	vec3 cyan = vec3(0.310, 0.839, 0.910);

	vec3 top = vec3(0.059, 0.094, 0.153);  // #0f1827
	vec3 bot = vec3(0.039, 0.075, 0.125);  // #0a1320
	vec3 col = mix(top, bot, uv.y);

	vec2 d = (uv - vec2(0.5, 0.0)) / vec2(1.2, 0.55);
	col += cyan * 0.09 * (1.0 - smoothstep(0.0, 1.0, length(d)));

	vec2 cell = mod(FRAGCOORD.xy, 30.0);
	float line = clamp(step(cell.x, 1.0) + step(cell.y, 1.0), 0.0, 1.0);
	float mask = 1.0 - smoothstep(0.0, 0.65, uv.y);
	col += cyan * 0.05 * line * mask;

	COLOR = vec4(col, 1.0);
}
