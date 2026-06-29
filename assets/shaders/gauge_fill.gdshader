shader_type canvas_item;
render_mode blend_mix;

// Jauge « icône-masque » (app.jsx .glyph) : l'icône (trait blanc, alpha) sert de
// masque. Sous la ligne de niveau → couleur ressource ; au-dessus → gris de base.
// Graduations 25/50/75 + ligne de niveau lumineuse, visibles seulement sur le trait.

uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform vec4 res_color : source_color = vec4(1.0);
uniform vec4 base_color : source_color = vec4(0.235, 0.282, 0.376, 1.0);
uniform vec4 grad_color : source_color = vec4(1.0, 1.0, 1.0, 0.20);
uniform vec4 water_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float level = 1.0 - clamp(fill, 0.0, 1.0);
	vec3 col = (UV.y >= level) ? res_color.rgb : base_color.rgb;

	float g = 0.0;
	g += step(abs(UV.y - 0.25), 0.012);
	g += step(abs(UV.y - 0.50), 0.012);
	g += step(abs(UV.y - 0.75), 0.012);
	col = mix(col, grad_color.rgb, clamp(g, 0.0, 1.0) * grad_color.a);

	if (fill > 0.001 && fill < 0.999) {
		float w = step(abs(UV.y - level), 0.022);
		col = mix(col, water_color.rgb, w * water_color.a);
	}

	COLOR = vec4(col, a);
}
