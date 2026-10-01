class_name MeshFactory
## Costruisce via codice le mesh low-poly del gioco (soldati, proiettili, barili, ...).
##
## Ogni modello è formato da pochi blocchi colorati fusi in UNA sola mesh con
## colori per vertice: così un MultiMesh disegna centinaia di soldati con una
## sola chiamata di disegno. Tutta la grafica è originale e generata qui.

## Palette di un soldato: divisa, elmetto, pantaloni, pelle, arma, cintura.
## Il giocatore ha elmetti bianchi e divisa blu; ogni variante di nemico ha
## colori e sagoma diversi per essere riconoscibile a colpo d'occhio.
const PALETTE_GIOCATORE := {
	"divisa": Color(0.16, 0.42, 0.92),
	"elmetto": Color(0.94, 0.95, 0.98),
	"pantaloni": Color(0.12, 0.2, 0.42),
	"pelle": Color(0.98, 0.8, 0.65),
	"arma": Color(0.15, 0.15, 0.17),
	"cintura": Color(0.48, 0.3, 0.12),
}

## Nemico base: rosso, come l'orda delle pubblicità.
const PALETTE_NEMICO_BASE := {
	"divisa": Color(0.9, 0.16, 0.14),
	"elmetto": Color(0.72, 0.07, 0.07),
	"pantaloni": Color(0.32, 0.06, 0.06),
	"pelle": Color(0.85, 0.7, 0.6),
	"arma": Color(0.12, 0.12, 0.12),
	"cintura": Color(0.25, 0.08, 0.05),
}

## Nemico veloce: arancione/giallo, più piccolo e senza zaino.
const PALETTE_NEMICO_VELOCE := {
	"divisa": Color(1.0, 0.58, 0.08),
	"elmetto": Color(1.0, 0.86, 0.18),
	"pantaloni": Color(0.45, 0.25, 0.05),
	"pelle": Color(0.85, 0.7, 0.6),
	"arma": Color(0.12, 0.12, 0.12),
	"cintura": Color(0.3, 0.15, 0.05),
}

## Nemico corazzato: grigio scuro con scudo d'acciaio, più grosso.
const PALETTE_NEMICO_CORAZZATO := {
	"divisa": Color(0.34, 0.35, 0.4),
	"elmetto": Color(0.18, 0.18, 0.2),
	"pantaloni": Color(0.16, 0.16, 0.18),
	"pelle": Color(0.8, 0.68, 0.58),
	"arma": Color(0.1, 0.1, 0.1),
	"cintura": Color(0.75, 0.12, 0.1),
	"scudo": Color(0.66, 0.68, 0.74),
}

## Nemico tiratore: viola, con un fucile lungo.
const PALETTE_NEMICO_TIRATORE := {
	"divisa": Color(0.58, 0.2, 0.88),
	"elmetto": Color(0.32, 0.1, 0.52),
	"pantaloni": Color(0.2, 0.06, 0.32),
	"pelle": Color(0.85, 0.7, 0.6),
	"arma": Color(0.08, 0.08, 0.08),
	"cintura": Color(0.95, 0.85, 0.3),
}

## Mini boss: giacca rossa e capelli biondi a spazzola (al posto dell'elmetto).
const PALETTE_BOSS := {
	"divisa": Color(0.82, 0.1, 0.1),
	"elmetto": Color(1.0, 0.82, 0.18),
	"pantaloni": Color(0.18, 0.18, 0.22),
	"pelle": Color(0.95, 0.75, 0.6),
	"arma": Color(0.2, 0.2, 0.22),
	"cintura": Color(0.95, 0.95, 0.95),
}

## Fattore di grandezza dei soldati (folla e nemici).
const SCALA_SOLDATO := 1.3


## Soldato stilizzato e "massiccio" alto circa 1.15 × SCALA_SOLDATO, rivolto
## verso -Z (in avanti). Opzioni: "zaino", "scudo", "fucile_lungo" (bool).
static func soldato(palette: Dictionary, opzioni: Dictionary = {}) -> ArrayMesh:
	var parti: Array = [
		# [dimensioni, centro, colore]
		[Vector3(0.16, 0.36, 0.18), Vector3(-0.11, 0.18, 0.0), palette.pantaloni],  # gamba sx
		[Vector3(0.16, 0.36, 0.18), Vector3(0.11, 0.18, 0.0), palette.pantaloni],   # gamba dx
		[Vector3(0.46, 0.42, 0.3), Vector3(0.0, 0.57, 0.0), palette.divisa],        # busto
		[Vector3(0.48, 0.09, 0.32), Vector3(0.0, 0.64, 0.0), palette.cintura],      # cartucciera
		[Vector3(0.12, 0.32, 0.14), Vector3(-0.29, 0.57, -0.04), palette.divisa],   # braccio sx
		[Vector3(0.12, 0.32, 0.14), Vector3(0.29, 0.57, -0.04), palette.divisa],    # braccio dx
		[Vector3(0.25, 0.24, 0.25), Vector3(0.0, 0.9, 0.0), palette.pelle],         # testa
		[Vector3(0.34, 0.15, 0.34), Vector3(0.0, 1.06, 0.0), palette.elmetto],      # elmetto
	]
	if opzioni.get("fucile_lungo", false):
		parti.append([Vector3(0.07, 0.07, 0.95), Vector3(0.21, 0.62, -0.45), palette.arma])
	else:
		parti.append([Vector3(0.09, 0.09, 0.6), Vector3(0.21, 0.62, -0.28), palette.arma])
	if opzioni.get("zaino", true):
		parti.append([Vector3(0.32, 0.3, 0.12), Vector3(0.0, 0.6, 0.21), palette.elmetto])
	if opzioni.get("scudo", false):
		parti.append([Vector3(0.62, 0.66, 0.08), Vector3(-0.05, 0.55, -0.34), palette.scudo])
	for p in parti:
		p[0] *= SCALA_SOLDATO
		p[1] *= SCALA_SOLDATO
	return _unisci_blocchi(parti)


## Barile giallo (ostacolo bonus), alto circa 1.9 e di raggio 1.
static func barile() -> ArrayMesh:
	var corpo := CylinderMesh.new()
	corpo.top_radius = 1.0
	corpo.bottom_radius = 1.0
	corpo.height = 1.9
	corpo.radial_segments = 16
	corpo.rings = 1
	var arrays := _array_colorati(corpo.get_mesh_arrays(), Vector3(0, 0.95, 0), Color(1.0, 0.78, 0.12))
	for y in [0.18, 1.72]:
		var fascia := CylinderMesh.new()
		fascia.top_radius = 1.04
		fascia.bottom_radius = 1.04
		fascia.height = 0.16
		fascia.radial_segments = 16
		fascia.rings = 1
		arrays = _accoda(arrays, _array_colorati(fascia.get_mesh_arrays(), Vector3(0, y, 0), Color(0.2, 0.18, 0.16)))
	return _crea_mesh(arrays)


## Proiettile: bastoncino luminoso allungato lungo Z.
static func proiettile(colore: Color, dimensione: float = 1.0) -> ArrayMesh:
	return _unisci_blocchi([[Vector3(0.10, 0.10, 0.55) * dimensione, Vector3.ZERO, colore]])


## Sfera low-poly di raggio 1 (per le esplosioni), con colore per vertice.
static func sfera(colore: Color) -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 10
	s.rings = 5
	return _crea_mesh(_array_colorati(s.get_mesh_arrays(), Vector3.ZERO, colore))


## Albero low-poly per i bordi della pista (tronco + chioma a cono).
static func albero() -> ArrayMesh:
	var tronco := BoxMesh.new()
	tronco.size = Vector3(0.3, 1.0, 0.3)
	var chioma := CylinderMesh.new()
	chioma.top_radius = 0.0
	chioma.bottom_radius = 1.0
	chioma.height = 2.2
	chioma.radial_segments = 6
	chioma.rings = 1
	chioma.cap_top = false
	return _crea_mesh(_accoda(
		_array_colorati(tronco.get_mesh_arrays(), Vector3(0, 0.5, 0), Color(0.42, 0.28, 0.16)),
		_array_colorati(chioma.get_mesh_arrays(), Vector3(0, 2.0, 0), Color(0.22, 0.55, 0.27))))


## Materiale condiviso per le mesh con colori per vertice.
static func materiale_colori_vertice() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	# Illuminazione per vertice: più leggera sui telefoni e identica
	# visivamente su modelli a blocchi.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m


## Materiale senza illuminazione (per proiettili ed effetti luminosi).
static func materiale_luminoso() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# --- Funzioni interne --------------------------------------------------------

static func _unisci_blocchi(parti: Array) -> ArrayMesh:
	var risultato: Array = []
	for p in parti:
		var box := BoxMesh.new()
		box.size = p[0]
		var arrays := _array_colorati(box.get_mesh_arrays(), p[1], p[2])
		risultato = arrays if risultato.is_empty() else _accoda(risultato, arrays)
	return _crea_mesh(risultato)


## Sposta i vertici di una primitiva e le assegna un colore uniforme.
static func _array_colorati(arrays: Array, spostamento: Vector3, colore: Color) -> Array:
	var vertici: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertici.size():
		vertici[i] += spostamento
	var colori := PackedColorArray()
	colori.resize(vertici.size())
	colori.fill(colore)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertici
	out[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
	out[Mesh.ARRAY_COLOR] = colori
	out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	return out


## Unisce due gruppi di array (vertici, normali, colori, indici) in uno solo.
static func _accoda(a: Array, b: Array) -> Array:
	var scarto: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var indici_b: PackedInt32Array = b[Mesh.ARRAY_INDEX]
	for i in indici_b.size():
		indici_b[i] += scarto
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array) + (b[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	out[Mesh.ARRAY_NORMAL] = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array) + (b[Mesh.ARRAY_NORMAL] as PackedVector3Array)
	out[Mesh.ARRAY_COLOR] = (a[Mesh.ARRAY_COLOR] as PackedColorArray) + (b[Mesh.ARRAY_COLOR] as PackedColorArray)
	out[Mesh.ARRAY_INDEX] = (a[Mesh.ARRAY_INDEX] as PackedInt32Array) + indici_b
	return out


static func _crea_mesh(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
