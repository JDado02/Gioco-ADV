class_name GestoreNemici
extends Node3D
## Pool dei nemici, disegnati con un unico MultiMesh.
##
## I dati di ogni nemico stanno in array paralleli (niente nodi per nemico):
## nessuna istanziazione durante la partita e aggiornamento molto leggero.
## In Fase 1 esiste solo il nemico base; le varianti arriveranno in Fase 3.

## Vita sotto la quale un nemico è considerato morto (tolleranza sui decimali).
const VITA_MINIMA := 0.001
## Oltre questa distanza dietro la folla un nemico che l'ha mancata sparisce.
const Z_USCITA := 6.0

## Nemici uccisi dal giocatore in tutta la partita (servirà per i mini boss).
var uccisi_totali := 0
## Nemici attualmente in campo.
var attivi := 0

var _max: int
var _raggio: float
var _vel_laterale: float
var _uccise_al_contatto: int

var _x := PackedFloat32Array()
var _z := PackedFloat32Array()
var _vita := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _scarto := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _tempo := 0.0
var _mm: MultiMesh
var _buf: PackedFloat32Array


func _ready() -> void:
	_max = maxi(Config.intero("nemici", "max_nemici_attivi"), 1)
	_raggio = Config.num("nemici", "raggio")
	_vel_laterale = Config.num("nemici", "velocita_laterale")
	_uccise_al_contatto = Config.intero("nemici", "unita_uccise_al_contatto")
	_x.resize(_max)
	_z.resize(_max)
	_vita.resize(_max)
	_vel.resize(_max)
	_scarto.resize(_max)
	_fase.resize(_max)
	_buf = MultiMeshHelper.crea_buffer(_max)

	var mesh := MeshFactory.soldato(MeshFactory.PALETTE_NEMICO_BASE)
	mesh.surface_set_material(0, MeshFactory.materiale_colori_vertice())
	_mm = MultiMeshHelper.crea(mesh, _max)
	var istanza := MultiMeshInstance3D.new()
	istanza.name = "Soldati"
	istanza.multimesh = _mm
	add_child(istanza)


func posti_liberi() -> int:
	return _max - attivi


## Fa comparire un nemico. Restituisce false se il pool è pieno.
func genera(x: float, z: float, vita: float, velocita: float) -> bool:
	if attivi >= _max:
		return false
	var i := attivi
	_x[i] = x
	_z[i] = z
	_vita[i] = vita
	_vel[i] = velocita
	# Ogni nemico punta a un punto leggermente diverso della folla,
	# così non si ammassano tutti sulla stessa linea.
	_scarto[i] = randf_range(-0.8, 0.8)
	_fase[i] = randf() * TAU
	attivi += 1
	return true


## Applica il danno di un proiettile che nel fotogramma è passato da z_a a z_da
## (z_da < z_a) lungo la linea x. Restituisce il danno avanzato (0 = esaurito).
func colpisci(x: float, z_da: float, z_a: float, raggio_proiettile: float, danno: float) -> float:
	var r := _raggio + raggio_proiettile
	for j in attivi:
		if _vita[j] <= VITA_MINIMA:
			continue
		var z := _z[j]
		if z < z_da - _raggio or z > z_a + _raggio:
			continue
		if absf(_x[j] - x) > r:
			continue
		var inflitto := minf(danno, _vita[j])
		_vita[j] -= inflitto
		danno -= inflitto
		if danno <= VITA_MINIMA:
			return 0.0
	return danno


## True se un proiettile che passa da z_a a z_da lungo la linea x tocca un nemico vivo.
func tocca(x: float, z_da: float, z_a: float, raggio_proiettile: float) -> bool:
	var r := _raggio + raggio_proiettile
	for j in attivi:
		if _vita[j] > VITA_MINIMA and _z[j] >= z_da - _raggio and _z[j] <= z_a + _raggio \
				and absf(_x[j] - x) <= r:
			return true
	return false


## Danno ad area (esplosioni): ogni nemico entro il raggio subisce `danno`.
func danno_area(x: float, z: float, raggio_area: float, danno: float) -> void:
	var r := raggio_area + _raggio
	for j in attivi:
		if _vita[j] <= VITA_MINIMA:
			continue
		var dx := _x[j] - x
		var dz := _z[j] - z
		if dx * dx + dz * dz <= r * r:
			_vita[j] -= minf(danno, _vita[j])


## Muove i nemici verso la folla, gestisce morti e contatti.
## Restituisce il numero di unità del giocatore uccise in questo fotogramma.
func aggiorna(delta: float, velocita_pista: float, folla_x: float, folla_raggio: float) -> int:
	_tempo += delta
	var perdite := 0
	var r_contatto := folla_raggio + _raggio
	var i := 0
	while i < attivi:
		if _vita[i] <= VITA_MINIMA:
			uccisi_totali += 1
			_rimuovi(i)
			continue

		_z[i] += (velocita_pista + _vel[i]) * delta
		_x[i] = move_toward(_x[i], folla_x + _scarto[i] * folla_raggio, _vel_laterale * delta)

		var dx := _x[i] - folla_x
		var dz := _z[i]
		if dx * dx + dz * dz < r_contatto * r_contatto:
			# Scontro: il nemico uccide alcune unità e muore a sua volta.
			perdite += _uccise_al_contatto
			_rimuovi(i)
			continue
		if _z[i] > Z_USCITA:
			_rimuovi(i)
			continue

		var y := absf(sin(_tempo * 8.0 + _fase[i])) * 0.08
		MultiMeshHelper.scrivi(_buf, i, Vector3(_x[i], y, _z[i]), PI)
		i += 1
	_mm.visible_instance_count = attivi
	_mm.buffer = _buf
	return perdite


func _rimuovi(i: int) -> void:
	attivi -= 1
	_x[i] = _x[attivi]
	_z[i] = _z[attivi]
	_vita[i] = _vita[attivi]
	_vel[i] = _vel[attivi]
	_scarto[i] = _scarto[attivi]
	_fase[i] = _fase[attivi]
