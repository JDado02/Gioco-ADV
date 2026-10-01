class_name Pista
extends Node3D
## Il campo di battaglia: un lungo ponte di notte sopra il mare.
##
## La folla resta sempre attorno a Z = 0. Se [pista] velocita_avanzamento è
## maggiore di 0 è il mondo a scorrere verso la telecamera (asse +Z), così le
## coordinate restano piccole e non servono segmenti di pista da istanziare.
## Con velocità 0 (impostazione attuale) il ponte sta fermo.

const LUNGHEZZA := 200.0
const Z_LONTANO := -170.0
const Z_VICINO := 30.0
## Larghezza del cordolo scuro ai lati della strada.
const BORDO := 0.9
## Quota del mare sotto il ponte.
const QUOTA_MARE := -3.0
const PASSO_PALI := 2.5
const OGNI_QUANTI_LAMPIONI := 4
const NUM_BRACI := 70

var larghezza: float

var _scorrimento := 0.0
var _materiali: Array[ShaderMaterial] = []
var _pali: MultiMesh
var _pali_buf: PackedFloat32Array
var _pali_z := PackedFloat32Array()
var _pali_x := PackedFloat32Array()
var _luci: MultiMesh
var _luci_buf: PackedFloat32Array
var _braci: MultiMesh
var _braci_buf: PackedFloat32Array
var _braci_pos: Array[Vector3] = []
var _braci_vel: Array[Vector3] = []


func _ready() -> void:
	larghezza = Config.num("pista", "larghezza")
	var meta := larghezza * 0.5
	# Il mare (più in basso) e il piano stradale del ponte.
	_crea_piano(Vector2(260, LUNGHEZZA + 60), QUOTA_MARE)
	_crea_piano(Vector2(larghezza + BORDO * 2.0, LUNGHEZZA), 0.0)
	_crea_fiancate(meta)
	_crea_ringhiere(meta)
	_crea_braci()


## Fa avanzare il ponte di `delta` secondi alla velocità indicata e anima le braci.
func aggiorna(delta: float, velocita: float) -> void:
	var passo := velocita * delta
	if passo != 0.0:
		# Lo scorrimento viene riportato indietro periodicamente (multiplo del
		# disegno) per non perdere precisione nei float dello shader.
		_scorrimento = fmod(_scorrimento + passo, 240.0)
		for m in _materiali:
			m.set_shader_parameter("scorrimento", _scorrimento)
		_aggiorna_pali(passo)

	for i in NUM_BRACI:
		var p := _braci_pos[i] + (_braci_vel[i] + Vector3(0, 0, velocita)) * delta
		if p.y > 9.0 or p.z > Z_VICINO:
			p = _bracia_casuale(true)
		_braci_pos[i] = p
		MultiMeshHelper.scrivi(_braci_buf, i, p, p.y, 1.0)
	_braci.buffer = _braci_buf


func _crea_piano(dimensioni: Vector2, quota: float) -> void:
	var piano := PlaneMesh.new()
	piano.size = dimensioni
	var materiale := ShaderMaterial.new()
	materiale.shader = preload("res://shaders/pista.gdshader")
	materiale.set_shader_parameter("meta_larghezza", larghezza * 0.5)
	materiale.set_shader_parameter("larghezza_bordo", BORDO)
	_materiali.append(materiale)
	var mi := MeshInstance3D.new()
	mi.mesh = piano
	mi.material_override = materiale
	mi.position = Vector3(0, quota, (Z_LONTANO + Z_VICINO) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Le pareti laterali del ponte, dal piano stradale fino al mare.
func _crea_fiancate(meta: float) -> void:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = Color(0.2, 0.22, 0.28)
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var box := BoxMesh.new()
	box.size = Vector3(0.5, -QUOTA_MARE, LUNGHEZZA)
	for lato in [-1.0, 1.0]:
		var parete := MeshInstance3D.new()
		parete.mesh = box
		parete.material_override = materiale
		parete.position = Vector3(lato * (meta + BORDO), QUOTA_MARE * 0.5, (Z_LONTANO + Z_VICINO) * 0.5)
		add_child(parete)


## Ringhiere metalliche: pali (MultiMesh), corrimano e un lampione ogni tanto.
func _crea_ringhiere(meta: float) -> void:
	var metallo := StandardMaterial3D.new()
	metallo.albedo_color = Color(0.55, 0.6, 0.68)
	metallo.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var x_ringhiera := meta + BORDO * 0.6

	var corrimano := BoxMesh.new()
	corrimano.size = Vector3(0.12, 0.12, LUNGHEZZA)
	for lato in [-1.0, 1.0]:
		for altezza in [0.55, 1.0]:
			var barra := MeshInstance3D.new()
			barra.mesh = corrimano
			barra.material_override = metallo
			barra.position = Vector3(lato * x_ringhiera, altezza, (Z_LONTANO + Z_VICINO) * 0.5)
			add_child(barra)

	var per_lato := int(LUNGHEZZA / PASSO_PALI)
	var n := per_lato * 2
	var palo := BoxMesh.new()
	palo.size = Vector3(0.16, 1.1, 0.16)
	palo.material = metallo
	_pali = MultiMeshHelper.crea(palo, n)
	_pali.visible_instance_count = n
	_pali_buf = MultiMeshHelper.crea_buffer(n)
	_pali_x.resize(n)
	_pali_z.resize(n)
	var lampada := BoxMesh.new()
	lampada.size = Vector3(0.3, 0.22, 0.3)
	var luce := StandardMaterial3D.new()
	luce.albedo_color = Color(1.0, 0.85, 0.45)
	luce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lampada.material = luce
	var n_luci := ceili(float(per_lato) / OGNI_QUANTI_LAMPIONI) * 2
	_luci = MultiMeshHelper.crea(lampada, n_luci)
	_luci.visible_instance_count = n_luci
	_luci_buf = MultiMeshHelper.crea_buffer(n_luci)
	for i in n:
		_pali_x[i] = x_ringhiera * (-1.0 if i % 2 == 0 else 1.0)
		_pali_z[i] = Z_LONTANO + (i / 2) * PASSO_PALI
	for mm in [_pali, _luci]:
		var istanza := MultiMeshInstance3D.new()
		istanza.multimesh = mm
		istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(istanza)
	_aggiorna_pali(0.0)


func _aggiorna_pali(passo: float) -> void:
	var n := _pali_z.size()
	for i in n:
		var z := _pali_z[i] + passo
		if z > Z_VICINO:
			z -= LUNGHEZZA
		_pali_z[i] = z
		MultiMeshHelper.scrivi(_pali_buf, i, Vector3(_pali_x[i], 0.55, z), 0.0)
		var numero_palo := i / 2
		if numero_palo % OGNI_QUANTI_LAMPIONI == 0:
			var k := (numero_palo / OGNI_QUANTI_LAMPIONI) * 2 + i % 2
			MultiMeshHelper.scrivi(_luci_buf, k, Vector3(_pali_x[i], 1.2, z), 0.0)
	_pali.buffer = _pali_buf
	_luci.buffer = _luci_buf


## Braci arancioni che salgono lentamente: danno l'atmosfera da campo di battaglia.
func _crea_braci() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_braci = MultiMeshHelper.crea(mesh, NUM_BRACI)
	_braci.visible_instance_count = NUM_BRACI
	_braci_buf = MultiMeshHelper.crea_buffer(NUM_BRACI)
	for i in NUM_BRACI:
		_braci_pos.append(_bracia_casuale(false))
		_braci_vel.append(Vector3(randf_range(-0.3, 0.3), randf_range(0.4, 1.0), randf_range(-0.2, 0.2)))
	var istanza := MultiMeshInstance3D.new()
	istanza.multimesh = _braci
	istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(istanza)
	aggiorna(0.0, 0.0)


func _bracia_casuale(dal_basso: bool) -> Vector3:
	var lato := -1.0 if randf() < 0.5 else 1.0
	var x := lato * randf_range(larghezza * 0.5 + 1.5, larghezza * 0.5 + 18.0)
	var y := QUOTA_MARE if dal_basso else randf_range(QUOTA_MARE, 9.0)
	return Vector3(x, y, randf_range(Z_LONTANO * 0.6, Z_VICINO * 0.5))
