shader_type canvas_item;

// Fond spatial du prototype : base sombre + halos radiaux cyan/violet + étoiles

uniform float star_density : hint_range(0.0, 1.0) = 0.12;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float star_layer(vec2 uv, float cells, float t) {
	vec2 g = uv * cells;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash21(id);
	if (h > star_density) {
		return 0.0;
	}
	vec2 offset = vec2(hash21(id + 7.3), hash21(id + 2.9)) - 0.5;
	float d = length(f - offset * 0.8);
	float bright = 0.45 + 0.55 * hash21(id + 4.1);
	float twinkle = 0.75 + 0.25 * sin(t * (0.6 + 2.0 * h) + h * 17.0);
	return smoothstep(0.06, 0.0, d) * bright * twinkle;
}

void fragment() {
	vec2 uv = UV;

	// base : dégradé radial profond (#070b14 → #03040a)
	float r = distance(uv, vec2(0.5)) * 1.4;
	vec3 col = mix(vec3(0.027, 0.043, 0.078), vec3(0.012, 0.016, 0.039), clamp(r, 0.0, 1.0));

	// halo cyan en haut à droite
	float halo1 = exp(-pow(distance(uv, vec2(0.78, -0.10)) * 1.6, 2.0));
	col += vec3(0.310, 0.839, 0.910) * 0.10 * halo1;

	// halo violet en bas à gauche
	float halo2 = exp(-pow(distance(uv, vec2(0.12, 1.15)) * 1.7, 2.0));
	col += vec3(0.725, 0.541, 0.839) * 0.07 * halo2;

	// deux couches d'étoiles
	float s = star_layer(uv, 34.0, TIME) * 0.9;
	s += star_layer(uv + 13.7, 21.0, TIME * 0.7) * 0.6;
	col += vec3(0.906, 0.929, 0.965) * s * 0.7;

	COLOR = vec4(col, 1.0);
}
