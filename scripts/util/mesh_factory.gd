class_name MeshFactory
## Costruisce via codice le mesh low-poly del gioco (soldati, proiettili, alberi).
##
## Ogni modello è formato da pochi blocchi colorati fusi in UNA sola mesh con
## colori per vertice: così un MultiMesh disegna centinaia di soldati con una
## sola chiamata di disegno. Tutta la grafica è originale e generata qui.

## Palette di un soldato: divisa, elmetto, pantaloni, pelle, arma.
const PALETTE_GIOCATORE := {
	"divisa": Color(0.18, 0.46, 0.92),
	"elmetto": Color(0.10, 0.25, 0.55),
	"pantaloni": Color(0.12, 0.18, 0.32),
	"pelle": Color(0.96, 0.78, 0.62),
	"arma": Color(0.15, 0.15, 0.17),
}

const PALETTE_NEMICO_BASE := {
	"divisa": Color(0.86, 0.20, 0.18),
	"elmetto": Color(0.45, 0.07, 0.07),
	"pantaloni": Color(0.28, 0.08, 0.08),
	"pelle": Color(0.80, 0.70, 0.60),
	"arma": Color(0.12, 0.12, 0.12),
}


## Fattore di grandezza dei soldati (folla e nemici).
const SCALA_SOLDATO := 1.3


## Soldato stilizzato alto circa 1.1 × SCALA_SOLDATO, rivolto verso -Z (in avanti).
static func soldato(palette: Dictionary) -> ArrayMesh:
	var parti: Array = [
		# [dimensioni, centro, colore]
		[Vector3(0.14, 0.40, 0.16), Vector3(-0.10, 0.20, 0.0), palette.pantaloni],  # gamba sx
		[Vector3(0.14, 0.40, 0.16), Vector3(0.10, 0.20, 0.0), palette.pantaloni],   # gamba dx
		[Vector3(0.40, 0.40, 0.24), Vector3(0.0, 0.60, 0.0), palette.divisa],       # busto
		[Vector3(0.28, 0.26, 0.10), Vector3(0.0, 0.62, 0.16), palette.elmetto],     # zaino
		[Vector3(0.20, 0.20, 0.20), Vector3(0.0, 0.90, 0.0), palette.pelle],        # testa
		[Vector3(0.27, 0.10, 0.27), Vector3(0.0, 1.03, 0.0), palette.elmetto],      # elmetto
		[Vector3(0.08, 0.08, 0.55), Vector3(0.17, 0.64, -0.24), palette.arma],      # fucile
	]
	for p in parti:
		p[0] *= SCALA_SOLDATO
		p[1] *= SCALA_SOLDATO
	return _unisci_blocchi(parti)


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
