shader_type canvas_item;
render_mode blend_mix;

// Jauge « icône-masque » : l'icône (trait blanc, alpha = silhouette) sert de
// masque. Sous la ligne de niveau → couleur ressource ; au-dessus → gris de base.
// Graduations gravées (25/50/75) + ligne de niveau lumineuse, visibles seulement
// sur le trait (multipliées par l'alpha du texel). Cf. app.jsx .glyph/.fill/.grad.

uniform float fill : hint_range(0.0, 1.0) = 0.5;          // niveau 0..1 (bas→haut)
uniform vec4 res_color : source_color = vec4(1.0);        // couleur ressource
uniform vec4 base_color : source_color = vec4(0.235, 0.282, 0.376, 1.0); // #3c4860
uniform vec4 grad_color : source_color = vec4(1.0, 1.0, 1.0, 0.20);
uniform vec4 water_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float grad_thickness = 0.012;
uniform float water_thickness = 0.022;
uniform bool show_grad = true;
uniform bool show_water = true;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a;

	// remplissage par le bas : rempli là où UV.y >= 1.0 - fill
	float level = 1.0 - clamp(fill, 0.0, 1.0);
	vec3 col = (UV.y >= level) ? res_color.rgb : base_color.rgb;

	// graduations gravées 25 / 50 / 75
	if (show_grad) {
		float g = 0.0;
		g += step(abs(UV.y - 0.25), grad_thickness);
		g += step(abs(UV.y - 0.50), grad_thickness);
		g += step(abs(UV.y - 0.75), grad_thickness);
		g = clamp(g, 0.0, 1.0);
		col = mix(col, grad_color.rgb, g * grad_color.a);
	}

	// ligne de niveau lumineuse (le « ras de l'eau »)
	if (show_water && fill > 0.001 && fill < 0.999) {
		float w = step(abs(UV.y - level), water_thickness);
		col = mix(col, water_color.rgb, w * water_color.a);
	}

	COLOR = vec4(col, a);
}
