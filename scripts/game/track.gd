class_name Pista
extends Node3D
## Pista infinita.
##
## La folla resta sempre attorno a Z = 0. Se [pista] velocita_avanzamento è
## maggiore di 0 è il mondo a scorrere verso la telecamera (asse +Z), così le
## coordinate restano piccole e non servono segmenti di pista da istanziare.
## Con velocità 0 (impostazione attuale) la strada sta ferma.

const LUNGHEZZA_TERRENO := 180.0
const NUM_ALBERI := 40
const Z_ALBERI_LONTANO := -130.0
const Z_ALBERI_VICINO := 25.0

var larghezza: float

var _scorrimento := 0.0
var _materiale: ShaderMaterial
var _alberi: MultiMesh
var _alberi_buf: PackedFloat32Array
var _alberi_x := PackedFloat32Array()
var _alberi_z := PackedFloat32Array()
var _alberi_scala := PackedFloat32Array()


func _ready() -> void:
	larghezza = Config.num("pista", "larghezza")
	_crea_terreno()
	_crea_bordi()
	_crea_alberi()


## Fa avanzare la pista di `delta` secondi alla velocità indicata.
func aggiorna(delta: float, velocita: float) -> void:
	var passo := velocita * delta
	# Lo scorrimento viene riportato indietro periodicamente (multiplo del
	# disegno) per non perdere precisione nei float dello shader.
	_scorrimento = fmod(_scorrimento + passo, 240.0)
	_materiale.set_shader_parameter("scorrimento", _scorrimento)

	for i in NUM_ALBERI:
		var z := _alberi_z[i] + passo
		if z > Z_ALBERI_VICINO:
			z -= Z_ALBERI_VICINO - Z_ALBERI_LONTANO
			_alberi_x[i] = _x_casuale_albero()
		_alberi_z[i] = z
		MultiMeshHelper.scrivi(_alberi_buf, i, Vector3(_alberi_x[i], 0, z), float(i), _alberi_scala[i])
	_alberi.buffer = _alberi_buf


func _crea_terreno() -> void:
	var piano := PlaneMesh.new()
	piano.size = Vector2(90, LUNGHEZZA_TERRENO)
	_materiale = ShaderMaterial.new()
	_materiale.shader = preload("res://shaders/pista.gdshader")
	_materiale.set_shader_parameter("meta_larghezza", larghezza * 0.5)
	var terreno := MeshInstance3D.new()
	terreno.name = "Terreno"
	terreno.mesh = piano
	terreno.material_override = _materiale
	terreno.position = Vector3(0, 0, -LUNGHEZZA_TERRENO * 0.5 + 25.0)
	terreno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terreno)


## Due cordoli bassi ai lati della pista (sono uniformi lungo Z: non serve farli scorrere).
func _crea_bordi() -> void:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = Color(0.93, 0.93, 0.95)
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.3, LUNGHEZZA_TERRENO)
	for lato in [-1.0, 1.0]:
		var bordo := MeshInstance3D.new()
		bordo.name = "Bordo"
		bordo.mesh = box
		bordo.material_override = materiale
		bordo.position = Vector3(lato * (larghezza * 0.5 + 0.2), 0.15, -LUNGHEZZA_TERRENO * 0.5 + 25.0)
		add_child(bordo)


func _crea_alberi() -> void:
	var mesh := MeshFactory.albero()
	mesh.surface_set_material(0, MeshFactory.materiale_colori_vertice())
	_alberi = MultiMeshHelper.crea(mesh, NUM_ALBERI)
	_alberi.visible_instance_count = NUM_ALBERI
	_alberi_buf = MultiMeshHelper.crea_buffer(NUM_ALBERI)
	_alberi_x.resize(NUM_ALBERI)
	_alberi_z.resize(NUM_ALBERI)
	_alberi_scala.resize(NUM_ALBERI)
	var passo := (Z_ALBERI_VICINO - Z_ALBERI_LONTANO) / NUM_ALBERI
	for i in NUM_ALBERI:
		_alberi_x[i] = _x_casuale_albero()
		_alberi_z[i] = Z_ALBERI_LONTANO + i * passo
		_alberi_scala[i] = randf_range(0.8, 1.4)
	var istanza := MultiMeshInstance3D.new()
	istanza.name = "Alberi"
	istanza.multimesh = _alberi
	add_child(istanza)
	aggiorna(0.0, 0.0)


func _x_casuale_albero() -> float:
	var lato := -1.0 if randf() < 0.5 else 1.0
	return lato * (larghezza * 0.5 + randf_range(2.0, 14.0))
