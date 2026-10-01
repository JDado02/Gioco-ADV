// Terreno della pista infinita.
// Il disegno (riquadri dell'asfalto, tratteggio centrale, bordi, erba) è
// calcolato in base alla posizione nel mondo meno lo "scorrimento": aumentando
// lo scorrimento il disegno si muove verso la telecamera e sembra di correre.
shader_type spatial;
render_mode unshaded;

uniform float scorrimento = 0.0;
uniform float meta_larghezza = 4.5;
uniform float lunghezza_riquadro = 4.0;
uniform vec3 colore_asfalto_a : source_color = vec3(0.42, 0.44, 0.50);
uniform vec3 colore_asfalto_b : source_color = vec3(0.37, 0.39, 0.45);
uniform vec3 colore_bordo : source_color = vec3(0.98, 0.80, 0.20);
uniform vec3 colore_erba_a : source_color = vec3(0.40, 0.68, 0.33);
uniform vec3 colore_erba_b : source_color = vec3(0.35, 0.62, 0.30);

varying vec3 pos_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 0 o 1 a bande alterne lungo Z.
float bande(float z, float lunghezza) {
	return step(0.5, fract(z / (2.0 * lunghezza)));
}

void fragment() {
	float z = pos_mondo.z - scorrimento;
	float ax = abs(pos_mondo.x);

	vec3 asfalto = mix(colore_asfalto_a, colore_asfalto_b, bande(z, lunghezza_riquadro));
	float tratteggio = step(ax, 0.07) * bande(z, 1.5);
	asfalto = mix(asfalto, vec3(0.92), tratteggio * 0.7);

	vec3 erba = mix(colore_erba_a, colore_erba_b, bande(z, lunghezza_riquadro * 2.0));

	vec3 colore = ax < meta_larghezza ? asfalto : erba;
	float bordo = step(meta_larghezza - 0.25, ax) * step(ax, meta_larghezza + 0.05);
	ALBEDO = mix(colore, colore_bordo, bordo);
}
