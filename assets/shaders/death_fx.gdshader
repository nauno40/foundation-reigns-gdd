shader_type canvas_item;

// Effondrement holographique à l'instant de la mort (app.jsx .deathfx) :
// flash radial cyan→danger + bandes de scanlines en « screen ». Piloté par
// progress (0→1) tweené sur ~0.76 s par Main avant l'écran de mort.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(460.0, 920.0);

void fragment() {
	float p = progress;

	// flash : deux pics (dfxFlash) puis extinction
	float flash = exp(-pow((p - 0.12) / 0.08, 2.0)) + 0.8 * exp(-pow((p - 0.40) / 0.13, 2.0));
	flash = clamp(flash, 0.0, 1.0);
	vec2 d = UV - vec2(0.5, 0.44);
	float radial = smoothstep(0.76, 0.0, length(d));
	vec3 cyan = vec3(0.588, 0.933, 0.980);
	vec3 danger = vec3(0.851, 0.416, 0.353);
	vec3 fcol = mix(danger, cyan, smoothstep(0.0, 0.42, radial));
	float fa = flash * radial;

	// bandes horizontales défilantes (dfxBands), disparaissent en fin
	float band = step(0.5, fract(UV.y * rect_size.y / 6.0 + p * 9.0));
	float ba = band * (1.0 - smoothstep(0.7, 1.0, p)) * 0.22 * step(0.02, p);

	vec3 col = fcol * fa + cyan * ba;
	float a = clamp(fa + ba, 0.0, 1.0);
	COLOR = vec4(col, a);
}
