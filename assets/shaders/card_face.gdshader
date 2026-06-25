shader_type canvas_item;

// Fond de carte (app.jsx .cardbg) : dégradé radial teinté par interlocuteur
// (tone_hi en haut → tone_lo) + grille masquée radialement + scanlines + ombre
// interne basse + coins arrondis (carte réellement arrondie).

uniform vec2 rect_size = vec2(300.0, 300.0);
uniform vec4 tone_lo : source_color = vec4(0.110, 0.227, 0.231, 1.0);
uniform vec4 tone_hi : source_color = vec4(0.220, 0.337, 0.341, 1.0);
uniform float corner_radius = 16.0;

void fragment() {
	vec2 uv = UV;

	vec2 d = (uv - vec2(0.5, 0.0)) / vec2(1.2, 0.85);
	float t = clamp(length(d), 0.0, 1.0);
	vec3 col = mix(tone_hi.rgb, tone_lo.rgb, t);

	vec2 px = uv * rect_size;
	vec2 cell = mod(px, 24.0);
	float line = clamp(step(cell.x, 1.0) + step(cell.y, 1.0), 0.0, 1.0);
	float mask = 1.0 - smoothstep(0.0, 0.75, distance(uv, vec2(0.5, 0.42)));
	col += vec3(1.0) * 0.05 * line * mask;

	float band = step(2.0, mod(px.y, 4.0));
	col = mix(col, vec3(0.0), 0.09 * band);

	col *= 1.0 - 0.28 * smoothstep(0.82, 1.0, uv.y);

	vec2 halfsize = rect_size * 0.5;
	vec2 p = (uv - 0.5) * rect_size;
	vec2 q = abs(p) - (halfsize - vec2(corner_radius));
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	float alpha = 1.0 - smoothstep(-1.0, 1.0, dist);

	COLOR = vec4(col, alpha);
}
