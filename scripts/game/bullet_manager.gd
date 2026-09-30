class_name GestoreProiettili
extends Node3D
## Pool di proiettili della folla, disegnati con un unico MultiMesh.
##
## Ogni proiettile porta un danno "aggregato" (può valere per molte unità reali).
## Colpi normali: tolgono vita al primo bersaglio; se il danno avanza, il
## proiettile prosegue sul successivo, così nessun danno va sprecato e la
## potenza di fuoco reale è sempre rispettata.
## Colpi esplosivi (lanciarazzi): esplodono al primo impatto e fanno danno a
## tutto ciò che si trova nel raggio dell'esplosione.
## I bersagli sono i nemici e gli ostacoli bonus.

## Numero massimo di proiettili contemporanei (dimensione del pool).
const MAX_PROIETTILI := 512

@export var nemici: GestoreNemici
@export var cancelli: GestoreCancelli
@export var effetti: GestoreEffetti

var _attivi := 0
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _z := PackedFloat32Array()
var _danno := PackedFloat32Array()
var _percorso := PackedFloat32Array()
var _velocita := PackedFloat32Array()
var _gittata := PackedFloat32Array()
var _raggio := PackedFloat32Array()
var _esplosione := PackedFloat32Array()
var _mm: MultiMesh
var _buf: PackedFloat32Array
var _materiale: StandardMaterial3D
var _mesh_per_arma := {}


func _ready() -> void:
	_x.resize(MAX_PROIETTILI)
	_y.resize(MAX_PROIETTILI)
	_z.resize(MAX_PROIETTILI)
	_danno.resize(MAX_PROIETTILI)
	_percorso.resize(MAX_PROIETTILI)
	_velocita.resize(MAX_PROIETTILI)
	_gittata.resize(MAX_PROIETTILI)
	_raggio.resize(MAX_PROIETTILI)
	_esplosione.resize(MAX_PROIETTILI)
	_buf = MultiMeshHelper.crea_buffer(MAX_PROIETTILI)

	_materiale = MeshFactory.materiale_luminoso()
	_mm = MultiMeshHelper.crea(null, MAX_PROIETTILI)
	var istanza := MultiMeshInstance3D.new()
	istanza.name = "Proiettili"
	istanza.multimesh = _mm
	istanza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(istanza)


## Cambia l'aspetto dei proiettili per l'arma indicata (colore e dimensione).
func imposta_arma(arma: Dictionary) -> void:
	var chiave: String = arma.nome
	if not _mesh_per_arma.has(chiave):
		var colore: Color = arma.colore if arma.colore is Color else Color(1, 0.86, 0.35)
		var mesh := MeshFactory.proiettile(colore, arma.dimensione)
		mesh.surface_set_material(0, _materiale)
		_mesh_per_arma[chiave] = mesh
	_mm.mesh = _mesh_per_arma[chiave]


## Spara un proiettile in avanti (verso -Z) dalla posizione indicata.
func spara(pos: Vector3, danno: float, arma: Dictionary) -> void:
	if _attivi >= MAX_PROIETTILI or danno <= 0.0:
		return
	var i := _attivi
	_x[i] = pos.x
	_y[i] = pos.y
	_z[i] = pos.z
	_danno[i] = danno
	_percorso[i] = 0.0
	_velocita[i] = arma.velocita_proiettile
	_gittata[i] = arma.gittata
	_raggio[i] = arma.raggio_proiettile
	_esplosione[i] = arma.raggio_esplosione
	_attivi += 1


func aggiorna(delta: float) -> void:
	var i := 0
	while i < _attivi:
		var passo := _velocita[i] * delta
		var z_prima := _z[i]
		var z_dopo := z_prima - passo
		# Il controllo copre tutto il tratto percorso nel fotogramma,
		# così un proiettile veloce non "salta" un bersaglio.
		var finito := false
		if _esplosione[i] > 0.0:
			finito = _gestisci_razzo(i, z_dopo, z_prima)
		else:
			var residuo := cancelli.colpisci(_x[i], z_dopo, z_prima, _raggio[i], _danno[i])
			if residuo > 0.0:
				residuo = nemici.colpisci(_x[i], z_dopo, z_prima, _raggio[i], residuo)
			_danno[i] = residuo
			finito = residuo <= 0.0
		_percorso[i] += passo
		if finito or _percorso[i] >= _gittata[i]:
			_rimuovi(i)
			continue
		_z[i] = z_dopo
		MultiMeshHelper.scrivi(_buf, i, Vector3(_x[i], _y[i], z_dopo), 0.0)
		i += 1
	_mm.visible_instance_count = _attivi
	_mm.buffer = _buf


## Un razzo esplode al primo impatto. Restituisce true se è esploso.
func _gestisci_razzo(i: int, z_dopo: float, z_prima: float) -> bool:
	var x := _x[i]
	var r := _raggio[i]
	if not (nemici.tocca(x, z_dopo, z_prima, r) or cancelli.tocca(x, z_dopo, z_prima, r)):
		return false
	var raggio_esplosione := _esplosione[i]
	nemici.danno_area(x, z_dopo, raggio_esplosione, _danno[i])
	cancelli.danno_area(x, z_dopo, raggio_esplosione, _danno[i])
	effetti.esplosione(Vector3(x, _y[i], z_dopo), raggio_esplosione)
	return true


## Rimozione in O(1): l'ultimo proiettile attivo prende il posto di quello rimosso.
func _rimuovi(i: int) -> void:
	_attivi -= 1
	_x[i] = _x[_attivi]
	_y[i] = _y[_attivi]
	_z[i] = _z[_attivi]
	_danno[i] = _danno[_attivi]
	_percorso[i] = _percorso[_attivi]
	_velocita[i] = _velocita[_attivi]
	_gittata[i] = _gittata[_attivi]
	_raggio[i] = _raggio[_attivi]
	_esplosione[i] = _esplosione[_attivi]
