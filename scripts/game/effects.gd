class_name GestoreEffetti
extends Node3D
## Effetti visivi leggeri, con pool e un unico MultiMesh.
## Per ora: le esplosioni dei razzi (una sfera che si allarga e sparisce).
## Gli altri effetti arriveranno in Fase 6.

const MAX_ESPLOSIONI := 48
const DURATA_ESPLOSIONE := 0.28

var _attive := 0
var _pos: Array[Vector3] = []
var _raggio := PackedFloat32Array()
var _eta := PackedFloat32Array()
var _mm: MultiMesh
var _buf: PackedFloat32Array


func _ready() -> void:
	_pos.resize(MAX_ESPLOSIONI)
	_raggio.resize(MAX_ESPLOSIONI)
	_eta.resize(MAX_ESPLOSIONI)
	_buf = MultiMeshHelper.crea_buffer(MAX_ESPLOSIONI)
	var mesh := MeshFactory.sfera(Color(1.0, 0.62, 0.2))
	mesh.surface_set_material(0, MeshFactory.materiale_luminoso())
	_mm = MultiMeshHelper.crea(mesh, MAX_ESPLOSIONI)
	var istanza := MultiMeshInstance3D.new()
	istanza.name = "Esplosioni"
	istanza.multimesh = _mm
	istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(istanza)


func esplosione(pos: Vector3, raggio: float) -> void:
	if _attive >= MAX_ESPLOSIONI:
		return
	_pos[_attive] = pos
	_raggio[_attive] = raggio
	_eta[_attive] = 0.0
	_attive += 1


## Le esplosioni restano ferme sulla pista, quindi scorrono con essa.
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
