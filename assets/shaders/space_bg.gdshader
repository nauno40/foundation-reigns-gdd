shader_type canvas_item;

// Fond spatial profond (HTML #space) : halos cyan/violet + dégradé radial central
// + champ d'étoiles procédural.

uniform vec2 rect_size = vec2(460.0, 920.0);

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * rect_size;

	// dégradé radial central #070b14 → #04060c → #03040a
	float d = distance(uv, vec2(0.5));
	vec3 col = mix(vec3(0.027,0.043,0.078), vec3(0.012,0.016,0.039), smoothstep(0.0,0.85,d));

	// halo cyan haut-droite, halo violet bas-gauche
	col += vec3(0.310,0.839,0.910) * 0.10 * (1.0 - smoothstep(0.0,0.6, distance(uv, vec2(0.78,-0.1))));
	col += vec3(0.725,0.541,0.839) * 0.07 * (1.0 - smoothstep(0.0,0.6, distance(uv, vec2(0.12,1.15))));

	// étoiles : grille de cellules, une étoile aléatoire par cellule
	vec2 cell = floor(px / 7.0);
	vec2 f = fract(px / 7.0);
	float r = hash(cell);
	if (r > 0.86) {
		float star = smoothstep(0.5, 0.0, distance(f, vec2(0.5))) * (0.3 + 0.7 * hash(cell + 3.3));
		col += vec3(0.906,0.929,0.965) * star * 0.7;
	}

	COLOR = vec4(col, 1.0);
}
