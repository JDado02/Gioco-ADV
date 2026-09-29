class_name GestoreProiettili
extends Node3D
## Pool di proiettili della folla, disegnati con un unico MultiMesh.
##
## Ogni proiettile porta un danno "aggregato" (può valere per molte unità reali).
## Quando colpisce un nemico gli toglie vita; se il danno avanza, il proiettile
## prosegue e colpisce il nemico successivo: così nessun danno va sprecato e la
## potenza di fuoco reale è sempre rispettata.

## Numero massimo di proiettili contemporanei (dimensione del pool).
const MAX_PROIETTILI := 512
const COLORE := Color(1.0, 0.86, 0.35)

@export var nemici: GestoreNemici

var _velocita: float
var _gittata: float
var _raggio: float

var _attivi := 0
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _z := PackedFloat32Array()
var _danno := PackedFloat32Array()
var _percorso := PackedFloat32Array()
var _mm: MultiMesh
var _buf: PackedFloat32Array


func _ready() -> void:
	_velocita = Config.num("arma", "velocita_proiettile")
	_gittata = Config.num("arma", "gittata")
	_raggio = Config.num("arma", "raggio_proiettile")
	_x.resize(MAX_PROIETTILI)
	_y.resize(MAX_PROIETTILI)
	_z.resize(MAX_PROIETTILI)
	_danno.resize(MAX_PROIETTILI)
	_percorso.resize(MAX_PROIETTILI)
	_buf = MultiMeshHelper.crea_buffer(MAX_PROIETTILI)

	var mesh := MeshFactory.proiettile(COLORE)
	mesh.surface_set_material(0, MeshFactory.materiale_luminoso())
	_mm = MultiMeshHelper.crea(mesh, MAX_PROIETTILI)
	var istanza := MultiMeshInstance3D.new()
	istanza.name = "Proiettili"
	istanza.multimesh = _mm
	istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(istanza)


## Spara un proiettile in avanti (verso -Z) dalla posizione indicata.
func spara(pos: Vector3, danno: float) -> void:
	if _attivi >= MAX_PROIETTILI or danno <= 0.0:
		return
	var i := _attivi
	_x[i] = pos.x
	_y[i] = pos.y
	_z[i] = pos.z
	_danno[i] = danno
	_percorso[i] = 0.0
	_attivi += 1


func aggiorna(delta: float) -> void:
	var passo := _velocita * delta
	var i := 0
	while i < _attivi:
		var z_prima := _z[i]
		var z_dopo := z_prima - passo
		# Il controllo copre tutto il tratto percorso nel fotogramma,
		# così un proiettile veloce non "salta" un nemico.
		var residuo := nemici.colpisci(_x[i], z_dopo, z_prima, _raggio, _danno[i])
		_percorso[i] += passo
		if residuo <= 0.0 or _percorso[i] >= _gittata:
			_rimuovi(i)
			continue
		_z[i] = z_dopo
		_danno[i] = residuo
		MultiMeshHelper.scrivi(_buf, i, Vector3(_x[i], _y[i], z_dopo), 0.0)
		i += 1
	_mm.visible_instance_count = _attivi
	_mm.buffer = _buf


## Rimozione in O(1): l'ultimo proiettile attivo prende il posto di quello rimosso.
func _rimuovi(i: int) -> void:
	_attivi -= 1
	_x[i] = _x[_attivi]
	_y[i] = _y[_attivi]
	_z[i] = _z[_attivi]
	_danno[i] = _danno[_attivi]
	_percorso[i] = _percorso[_attivi]
