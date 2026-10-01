class_name GestoreEffetti
extends Node3D
## Effetti visivi leggeri, tutti con pool e MultiMesh (nessun nodo creato in
## partita):
## - esplosioni: una sfera che si allarga e sparisce;
## - detriti: cubetti colorati che schizzano via quando muoiono nemici o
##   soldati del giocatore;
## - scintille: lampi gialli sui colpi a segno.

const MAX_ESPLOSIONI := 48
const DURATA_ESPLOSIONE := 0.28
const MAX_PARTICELLE := 360
const GRAVITA := 18.0

enum Colore { NEMICO, GIOCATORE, SCINTILLA }

var _attive := 0
var _pos: Array[Vector3] = []
var _raggio := PackedFloat32Array()
var _eta := PackedFloat32Array()
var _mm: MultiMesh
var _buf: PackedFloat32Array

## Un pool di particelle per ogni colore: {pos, vel, vita, durata, n, mm, buf, dimensione}
var _sciami: Array[Dictionary] = []


func _ready() -> void:
	_pos.resize(MAX_ESPLOSIONI)
	_raggio.resize(MAX_ESPLOSIONI)
	_eta.resize(MAX_ESPLOSIONI)
	_buf = MultiMeshHelper.crea_buffer(MAX_ESPLOSIONI)
	var mesh := MeshFactory.sfera(Color(1.0, 0.62, 0.2))
	mesh.surface_set_material(0, MeshFactory.materiale_luminoso())
	_mm = MultiMeshHelper.crea(mesh, MAX_ESPLOSIONI)
	_aggiungi_istanza(_mm, "Esplosioni")

	_sciami.append(_crea_sciame(Color(0.9, 0.18, 0.14), 0.16, "DetritiNemici"))
	_sciami.append(_crea_sciame(Color(0.3, 0.6, 1.0), 0.16, "DetritiSoldati"))
	_sciami.append(_crea_sciame(Color(1.0, 0.92, 0.5), 0.09, "Scintille"))


func esplosione(pos: Vector3, raggio: float) -> void:
	Suoni.suona("esplosione_grande" if raggio >= 3.0 else "esplosione")
	detriti(pos, 6, Colore.SCINTILLA, 4.0 + raggio)
	if _attive >= MAX_ESPLOSIONI:
		return
	_pos[_attive] = pos
	_raggio[_attive] = raggio
	_eta[_attive] = 0.0
	_attive += 1


## Cubetti che schizzano via da un punto (morte di nemici o di soldati).
func detriti(pos: Vector3, quanti: int, colore: int, forza: float = 5.0) -> void:
	var s := _sciami[colore]
	for k in quanti:
		var i: int = s.n
		if i >= MAX_PARTICELLE:
			return
		var p: PackedVector3Array = s.pos
		var v: PackedVector3Array = s.vel
		p[i] = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))
		v[i] = Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.4), randf_range(-1.0, 1.0)) * forza
		s.pos = p
		s.vel = v
		s.vita[i] = randf_range(0.35, 0.7)
		s.n = i + 1


## Piccolo lampo nel punto in cui un colpo va a segno.
func scintilla(pos: Vector3) -> void:
	detriti(pos, 2, Colore.SCINTILLA, 3.0)


## Esplosioni e particelle restano ferme sulla pista, quindi scorrono con essa.
func aggiorna(delta: float, velocita_pista: float) -> void:
	var i := 0
	while i < _attive:
		_eta[i] += delta
		if _eta[i] >= DURATA_ESPLOSIONE:
			_attive -= 1
			_pos[i] = _pos[_attive]
			_raggio[i] = _raggio[_attive]
			_eta[i] = _eta[_attive]
			continue
		_pos[i].z += velocita_pista * delta
		var t := _eta[i] / DURATA_ESPLOSIONE
		# Si allarga in fretta e poi si restringe.
		var scala := _raggio[i] * sin(t * PI) * 0.9
		MultiMeshHelper.scrivi(_buf, i, _pos[i], 0.0, maxf(scala, 0.01))
		i += 1
	_mm.visible_instance_count = _attive
	_mm.buffer = _buf

	for s in _sciami:
		_aggiorna_sciame(s, delta, velocita_pista)


func _aggiorna_sciame(s: Dictionary, delta: float, velocita_pista: float) -> void:
	var p: PackedVector3Array = s.pos
	var v: PackedVector3Array = s.vel
	var vita: PackedFloat32Array = s.vita
	var buf: PackedFloat32Array = s.buf
	var n: int = s.n
	var i := 0
	while i < n:
		vita[i] -= delta
		if vita[i] <= 0.0:
			n -= 1
			p[i] = p[n]
			v[i] = v[n]
			vita[i] = vita[n]
			continue
		v[i].y -= GRAVITA * delta
		p[i] += (v[i] + Vector3(0, 0, velocita_pista)) * delta
		if p[i].y < 0.05:
			p[i].y = 0.05
			v[i] *= 0.5
		MultiMeshHelper.scrivi(buf, i, p[i], vita[i] * 9.0, minf(vita[i] * 2.5, 1.0))
		i += 1
	s.pos = p
	s.vel = v
	s.vita = vita
	s.n = n
	var mm: MultiMesh = s.mm
	mm.visible_instance_count = n
	mm.buffer = buf


func _crea_sciame(colore: Color, dimensione: float, nome: String) -> Dictionary:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * dimensione
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colore
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	var mm := MultiMeshHelper.crea(box, MAX_PARTICELLE)
	_aggiungi_istanza(mm, nome)
	var pos := PackedVector3Array()
	pos.resize(MAX_PARTICELLE)
	var vel := PackedVector3Array()
	vel.resize(MAX_PARTICELLE)
	var vita := PackedFloat32Array()
	vita.resize(MAX_PARTICELLE)
	return {"pos": pos, "vel": vel, "vita": vita, "n": 0, "mm": mm,
			"buf": MultiMeshHelper.crea_buffer(MAX_PARTICELLE)}


func _aggiungi_istanza(mm: MultiMesh, nome: String) -> void:
	var istanza := MultiMeshInstance3D.new()
	istanza.name = nome
	istanza.multimesh = mm
	istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(istanza)
