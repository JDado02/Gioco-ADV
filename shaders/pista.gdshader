// Terreno: il ponte (strada di cemento con segnaletica) e il mare scuro ai lati.
// Se la pista scorre ("scorrimento" che aumenta) il disegno della strada si
// muove verso la telecamera; il mare ondeggia sempre da solo.
shader_type spatial;
render_mode unshaded;

uniform float scorrimento = 0.0;
uniform float meta_larghezza = 7.0;
uniform float larghezza_bordo = 0.9;
uniform vec3 colore_strada_a : source_color = vec3(0.62, 0.63, 0.66);
uniform vec3 colore_strada_b : source_color = vec3(0.57, 0.58, 0.62);
uniform vec3 colore_linea : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 colore_bordo_strada : source_color = vec3(1.0, 0.78, 0.15);
uniform vec3 colore_cordolo : source_color = vec3(0.24, 0.26, 0.32);
uniform vec3 colore_mare : source_color = vec3(0.03, 0.07, 0.17);
uniform vec3 colore_onda : source_color = vec3(0.07, 0.16, 0.32);

varying vec3 pos_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 0 o 1 a bande alterne lungo z.
float bande(float z, float lunghezza) {
	return step(0.5, fract(z / (2.0 * lunghezza)));
}

void fragment() {
	float z = pos_mondo.z - scorrimento;
	float ax = abs(pos_mondo.x);

	// Strada: lastre di cemento, tratteggio centrale e linee gialle ai bordi.
	vec3 strada = mix(colore_strada_a, colore_strada_b, bande(z, 3.0));
	float giunto = 1.0 - step(0.06, fract(z / 6.0));
	strada *= 1.0 - giunto * 0.12;
	float tratteggio = step(ax, 0.1) * bande(z, 1.6);
	strada = mix(strada, colore_linea, tratteggio * 0.85);
	float linea_bordo = step(meta_larghezza - 0.35, ax) * step(ax, meta_larghezza - 0.15);
	strada = mix(strada, colore_bordo_strada, linea_bordo);

	// Mare: onde lente che si muovono anche se la strada è ferma.
	float onda = sin(pos_mondo.x * 0.35 + TIME * 0.8) * sin(pos_mondo.z * 0.25 - TIME * 0.6);
	vec3 mare = mix(colore_mare, colore_onda, smoothstep(0.55, 0.95, onda));

	vec3 colore = mare;
	if (ax < meta_larghezza) {
		colore = strada;
	} else if (ax < meta_larghezza + larghezza_bordo) {
		colore = colore_cordolo;
	}
	ALBEDO = colore;
}
