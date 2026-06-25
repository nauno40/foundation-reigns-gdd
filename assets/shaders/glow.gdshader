shader_type canvas_item;
render_mode blend_add;

// Halo flou (drop-shadow) pour les jauges : floute l'alpha de l'icône et l'émet
// en additif. La couleur/intensité vient du modulate du noeud.

void fragment() {
	float a = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE * 5.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			a += texture(TEXTURE, UV + vec2(float(x), float(y)) * px).a;
		}
	}
	a /= 25.0;
	COLOR = vec4(1.0, 1.0, 1.0, a);
}
