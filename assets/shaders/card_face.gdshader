shader_type canvas_item;

// Fond de carte du nouveau template (app.jsx .cardbg) : dégradé radial teinté
// par interlocuteur (tone_hi en haut → tone_lo) + grille masquée radialement
// + scanlines + ombre interne basse (rim). Teintes passées en uniforms au runtime.

uniform vec2 rect_size = vec2(300.0, 300.0);
uniform vec2 grid_offset = vec2(0.0);
uniform vec4 tone_lo : source_color = vec4(0.110, 0.227, 0.231, 1.0);
uniform vec4 tone_hi : source_color = vec4(0.220, 0.337, 0.341, 1.0);
uniform float scan_strength : hint_range(0.0, 1.0) = 0.7;
uniform float corner_radius = 16.0;

void fragment() {
	vec2 uv = UV;

	// radial-gradient(120% 85% at 50% 0%, tone_hi, tone_lo)
	vec2 d = (uv - vec2(0.5, 0.0)) / vec2(1.2, 0.85);
	float t = clamp(length(d), 0.0, 1.0);
	vec3 col = mix(tone_hi.rgb, tone_lo.rgb, t);

	// grille 24px blanche, masquée radialement (75% 70% at 50% 42%)
	vec2 px = uv * rect_size;
	vec2 cell = mod(px + grid_offset, 24.0);
	float line = clamp(step(cell.x, 1.0) + step(cell.y, 1.0), 0.0, 1.0);
	float mask = 1.0 - smoothstep(0.0, 0.75, distance(uv, vec2(0.5, 0.42)));
	col += vec3(1.0) * 0.05 * line * mask;

	// scanlines 2px sombres toutes les 4px
	float band = step(2.0, mod(px.y, 4.0));
	col = mix(col, vec3(0.0), 0.09 * band * scan_strength);

	// ombre interne basse (rim inset -46px)
	col *= 1.0 - 0.28 * smoothstep(0.82, 1.0, uv.y);

	// masque coins arrondis (SDF rounded box) → carte réellement arrondie
	vec2 halfsize = rect_size * 0.5;
	vec2 p = (uv - 0.5) * rect_size;
	vec2 q = abs(p) - (halfsize - vec2(corner_radius));
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	float alpha = 1.0 - smoothstep(-1.0, 1.0, dist);

	COLOR = vec4(col, alpha);
}
