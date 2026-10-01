class_name GestoreNemici
extends Node3D
## Pool dei nemici: varianti, orde con contatore e proiettili nemici.
##
## Ogni voce del pool è un GRUPPO: un nemico singolo è un gruppo da 1, un'orda
## è un gruppo da tanti membri. La vita di un gruppo è la somma di quella dei
## membri: ogni colpo toglie vita e, quando basta, fa calare il contatore.
## I dati stanno in array paralleli (niente nodi per nemico) e ogni variante
## è disegnata con un suo MultiMesh: nessuna istanziazione durante la partita.

enum Tipo { BASE, VELOCE, CORAZZATO, TIRATORE }
const NOMI_TIPI := ["base", "veloce", "corazzato", "tiratore"]

## Vita sotto la quale un gruppo è considerato morto (tolleranza sui decimali).
const VITA_MINIMA := 0.001
## Oltre questa distanza dietro la folla un gruppo che l'ha mancata sparisce.
const Z_USCITA := 6.0
## Soldati disegnabili al massimo per ogni variante.
const MAX_ISTANZE_PER_TIPO := 1000
const MAX_PROIETTILI := 160
const MAX_ETICHETTE := 32
## Quanti membri di un'orda può colpire al massimo un'esplosione.
const MEMBRI_COLPITI_DA_ESPLOSIONE := 4
## Distanza tra i membri di un'orda.
const PASSO_ORDA := 0.62 * MeshFactory.SCALA_SOLDATO
const RAGGIO_PROIETTILE_NEMICO := 0.35
const ANGOLO_AUREO := 2.39996323

@export var effetti: GestoreEffetti

## Membri uccisi dal giocatore in tutta la partita (serve per i mini boss).
var uccisi_totali := 0
## Gruppi attualmente in campo.
var attivi := 0
## Se false i nemici non avanzano (usato durante la scelta dei potenziamenti).
var in_movimento := true

var _max: int
var _raggio: float
var _vel_laterale: float
var _cap_visibili: int
var _dati: Array[Dictionary] = []
var _distanza_tiro: float
var _intervallo_tiro: float
var _vel_proiettile: float
var _uccise_per_colpo: int

# Dati dei gruppi.
var _tipo := PackedInt32Array()
var _numero := PackedInt32Array()
var _x := PackedFloat32Array()
var _z := PackedFloat32Array()
var _vita := PackedFloat32Array()
var _vita_membro := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _scarto := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _timer_tiro := PackedFloat32Array()
var _raggio_gruppo := PackedFloat32Array()
var _etichetta := PackedInt32Array()
var _tempo := 0.0

# Grafica.
var _mm: Array[MultiMesh] = []
var _buf: Array[PackedFloat32Array] = []
var _etichette: Array[Label3D] = []
var _etichette_libere: Array[int] = []

# Proiettili dei tiratori.
var _pb_attivi := 0
var _pb_x := PackedFloat32Array()
var _pb_z := PackedFloat32Array()
var _pb_vx := PackedFloat32Array()
var _pb_vz := PackedFloat32Array()
var _pb_mm: MultiMesh
var _pb_buf: PackedFloat32Array


func _ready() -> void:
	_max = maxi(Config.intero("nemici", "max_nemici_attivi"), 1)
	_raggio = Config.num("nemici", "raggio")
	_vel_laterale = Config.num("nemici", "velocita_laterale")
	_cap_visibili = maxi(Config.intero("orde", "membri_visibili_massimi"), 1)
	for nome in NOMI_TIPI:
		var sezione: String = "nemico_" + nome
		_dati.append({
			"ondata_sblocco": Config.intero(sezione, "ondata_sblocco"),
			"peso": Config.num(sezione, "peso"),
			"vita": Config.num(sezione, "vita_moltiplicatore"),
			"velocita": Config.num(sezione, "velocita_moltiplicatore"),
			"scala": Config.num(sezione, "scala"),
			"uccise_al_contatto": Config.intero(sezione, "unita_uccise_al_contatto"),
		})
	_distanza_tiro = Config.num("nemico_tiratore", "distanza_tiro")
	_intervallo_tiro = maxf(Config.num("nemico_tiratore", "intervallo_tiro"), 0.2)
	_vel_proiettile = Config.num("nemico_tiratore", "velocita_proiettile")
	_uccise_per_colpo = Config.intero("nemico_tiratore", "unita_uccise_per_colpo")

	_tipo.resize(_max)
	_numero.resize(_max)
	_etichetta.resize(_max)
	_x.resize(_max)
	_z.resize(_max)
	_vita.resize(_max)
	_vita_membro.resize(_max)
	_vel.resize(_max)
	_scarto.resize(_max)
	_fase.resize(_max)
	_timer_tiro.resize(_max)
	_raggio_gruppo.resize(_max)
	_crea_grafica()


# --- Interrogazioni usate dagli altri sistemi -------------------------------

func posti_liberi() -> int:
	return _max - attivi


## Dati della variante (vita, velocità, peso, sblocco...).
func dati_tipo(tipo: int) -> Dictionary:
	return _dati[tipo]


## Raggio che avrà un gruppo di `numero` membri (per farlo stare nella pista).
func raggio_per(numero: int, tipo: int) -> float:
	var visibili := mini(numero, _cap_visibili)
	return PASSO_ORDA * sqrt(maxf(visibili - 1, 0)) + _raggio * _dati[tipo].scala


## Membri ancora in campo (tutti i gruppi).
func membri_in_campo() -> int:
	var totale := 0
	for i in attivi:
		totale += _numero[i]
	return totale


# --- Comparsa -------------------------------------------------------------

## Fa comparire un gruppo. Restituisce false se il pool è pieno.
func genera(tipo: int, x: float, z: float, numero: int, vita_membro: float, velocita: float) -> bool:
	if attivi >= _max or numero <= 0:
		return false
	var i := attivi
	_tipo[i] = tipo
	_numero[i] = numero
	_x[i] = x
	_z[i] = z
	_vita_membro[i] = maxf(vita_membro, 0.01)
	_vita[i] = _vita_membro[i] * numero
	_vel[i] = velocita
	# Ogni gruppo punta a un punto leggermente diverso della folla,
	# così non si ammassano tutti sulla stessa linea.
	_scarto[i] = randf_range(-0.8, 0.8)
	_fase[i] = randf() * TAU
	_timer_tiro[i] = randf_range(0.5, 1.0) * _intervallo_tiro
	_raggio_gruppo[i] = raggio_per(numero, tipo)
	_etichetta[i] = -1
	if numero > 1 and not _etichette_libere.is_empty():
		var e: int = _etichette_libere.pop_back()
		_etichetta[i] = e
		_etichette[e].text = str(numero)
		_etichette[e].visible = true
	attivi += 1
	return true


# --- Colpi del giocatore ---------------------------------------------------

## Applica il danno di un proiettile che nel fotogramma è passato da z_a a z_da
## (z_da < z_a) lungo la linea x. Restituisce il danno avanzato (0 = esaurito).
func colpisci(x: float, z_da: float, z_a: float, raggio_proiettile: float, danno: float) -> float:
	for j in attivi:
		if not _toccato(j, x, z_da, z_a, raggio_proiettile):
			continue
		var inflitto := minf(danno, _vita[j])
		_ferisci(j, inflitto)
		danno -= inflitto
		if danno <= VITA_MINIMA:
			return 0.0
	return danno


## True se un proiettile tocca un gruppo vivo.
func tocca(x: float, z_da: float, z_a: float, raggio_proiettile: float) -> bool:
	for j in attivi:
		if _toccato(j, x, z_da, z_a, raggio_proiettile):
			return true
	return false


## Danno ad area (esplosioni): colpisce fino a MEMBRI_COLPITI_DA_ESPLOSIONE
## membri di ogni gruppo entro il raggio.
func danno_area(x: float, z: float, raggio_area: float, danno: float) -> void:
	for j in attivi:
		if _vita[j] <= VITA_MINIMA:
			continue
		var r := raggio_area + _raggio_gruppo[j]
		var dx := _x[j] - x
		var dz := _z[j] - z
		if dx * dx + dz * dz <= r * r:
			var membri := mini(_numero[j], MEMBRI_COLPITI_DA_ESPLOSIONE)
			_ferisci(j, minf(danno * membri, _vita[j]))


# --- Aggiornamento ----------------------------------------------------------

## Muove i gruppi, fa sparare i tiratori, gestisce morti e contatti.
## Restituisce il numero di unità del giocatore uccise in questo fotogramma.
func aggiorna(delta: float, velocita_pista: float, folla_x: float, folla_raggio: float) -> int:
	_tempo += delta
	var perdite := 0
	var conteggio := PackedInt32Array([0, 0, 0, 0])
	var i := 0
	while i < attivi:
		if _vita[i] <= VITA_MINIMA:
			_rimuovi(i)
			continue
		var tipo := _tipo[i]
		if in_movimento:
			if tipo == Tipo.TIRATORE and _z[i] >= -_distanza_tiro:
				# Il tiratore si ferma e spara verso il punto in cui si trova la folla.
				_z[i] += velocita_pista * delta
				_timer_tiro[i] -= delta
				if _timer_tiro[i] <= 0.0:
					_timer_tiro[i] = _intervallo_tiro * randf_range(0.8, 1.2)
					_spara(_x[i], _z[i], folla_x)
			else:
				_z[i] += (velocita_pista + _vel[i]) * delta
			_x[i] = move_toward(_x[i], folla_x + _scarto[i] * folla_raggio, _vel_laterale * delta)

		var dx := _x[i] - folla_x
		var dz := _z[i]
		var r_contatto := folla_raggio + _raggio_gruppo[i]
		if dx * dx + dz * dz < r_contatto * r_contatto:
			# Scontro: ogni membro rimasto uccide le sue unità e il gruppo muore.
			perdite += _numero[i] * int(_dati[tipo].uccise_al_contatto)
			_rimuovi(i)
			continue
		if _z[i] > Z_USCITA:
			_rimuovi(i)
			continue

		_disegna_gruppo(i, conteggio)
		i += 1

	for t in _mm.size():
		_mm[t].visible_instance_count = conteggio[t]
		_mm[t].buffer = _buf[t]
	perdite += _aggiorna_proiettili(delta, velocita_pista, folla_x, folla_raggio)
	return perdite


# --- Funzioni interne -------------------------------------------------------

func _toccato(j: int, x: float, z_da: float, z_a: float, r: float) -> bool:
	if _vita[j] <= VITA_MINIMA:
		return false
	var rg := _raggio_gruppo[j]
	var z := _z[j]
	return z >= z_da - rg and z <= z_a + rg and absf(_x[j] - x) <= rg + r


## Toglie vita a un gruppo e aggiorna il contatore dei membri.
func _ferisci(j: int, danno: float) -> void:
	_vita[j] -= danno
	var rimasti := maxi(ceili(_vita[j] / _vita_membro[j] - 0.0001), 0)
	if rimasti < _numero[j]:
		var morti := _numero[j] - rimasti
		uccisi_totali += morti
		effetti.detriti(Vector3(_x[j], 0.8, _z[j]), mini(morti, 5) * 3, GestoreEffetti.Colore.NEMICO)
		Suoni.suona("morte")
		_numero[j] = rimasti
		_raggio_gruppo[j] = raggio_per(maxi(rimasti, 1), _tipo[j])
		if _etichetta[j] >= 0:
			_etichette[_etichetta[j]].text = str(rimasti)


func _disegna_gruppo(i: int, conteggio: PackedInt32Array) -> void:
	var tipo := _tipo[i]
	var scala: float = _dati[tipo].scala
	var visibili := mini(_numero[i], _cap_visibili)
	var buf := _buf[tipo]
	var passo := 9.0 if tipo == Tipo.VELOCE else 7.0
	for m in visibili:
		var k := conteggio[tipo]
		if k >= MAX_ISTANZE_PER_TIPO:
			break
		var ox := 0.0
		var oz := 0.0
		if m > 0:
			var r := PASSO_ORDA * sqrt(float(m))
			var a := m * ANGOLO_AUREO
			ox = cos(a) * r
			oz = sin(a) * r
		var y := absf(sin(_tempo * passo + _fase[i] + m * 1.3)) * 0.08 if in_movimento else 0.0
		MultiMeshHelper.scrivi(buf, k, Vector3(_x[i] + ox, y, _z[i] + oz), PI, scala)
		conteggio[tipo] = k + 1
	if _etichetta[i] >= 0:
		_etichette[_etichetta[i]].position = Vector3(_x[i], 2.4 + _raggio_gruppo[i] * 0.4, _z[i])


func _rimuovi(i: int) -> void:
	if _etichetta[i] >= 0:
		_etichette[_etichetta[i]].visible = false
		_etichette_libere.append(_etichetta[i])
	attivi -= 1
	_tipo[i] = _tipo[attivi]
	_numero[i] = _numero[attivi]
	_x[i] = _x[attivi]
	_z[i] = _z[attivi]
	_vita[i] = _vita[attivi]
	_vita_membro[i] = _vita_membro[attivi]
	_vel[i] = _vel[attivi]
	_scarto[i] = _scarto[attivi]
	_fase[i] = _fase[attivi]
	_timer_tiro[i] = _timer_tiro[attivi]
	_raggio_gruppo[i] = _raggio_gruppo[attivi]
	_etichetta[i] = _etichetta[attivi]


## Un colpo del tiratore: va dritto verso il punto in cui era la folla.
func _spara(x: float, z: float, bersaglio_x: float) -> void:
	if _pb_attivi >= MAX_PROIETTILI:
		return
	var direzione := Vector2(bersaglio_x - x, -z).normalized() * _vel_proiettile
	var k := _pb_attivi
	_pb_x[k] = x
	_pb_z[k] = z + 0.8
	_pb_vx[k] = direzione.x
	_pb_vz[k] = direzione.y
	_pb_attivi += 1


func _aggiorna_proiettili(delta: float, velocita_pista: float, folla_x: float, folla_raggio: float) -> int:
	var perdite := 0
	var r := folla_raggio + RAGGIO_PROIETTILE_NEMICO
	var k := 0
	while k < _pb_attivi:
		if in_movimento:
			_pb_x[k] += _pb_vx[k] * delta
			_pb_z[k] += (_pb_vz[k] + velocita_pista) * delta
		var dx := _pb_x[k] - folla_x
		var dz := _pb_z[k]
		var colpito := dx * dx + dz * dz < r * r
		if colpito or _pb_z[k] > Z_USCITA:
			if colpito:
				perdite += _uccise_per_colpo
			_pb_attivi -= 1
			_pb_x[k] = _pb_x[_pb_attivi]
			_pb_z[k] = _pb_z[_pb_attivi]
			_pb_vx[k] = _pb_vx[_pb_attivi]
			_pb_vz[k] = _pb_vz[_pb_attivi]
			continue
		MultiMeshHelper.scrivi(_pb_buf, k, Vector3(_pb_x[k], 0.9, _pb_z[k]), atan2(_pb_vx[k], _pb_vz[k]))
		k += 1
	_pb_mm.visible_instance_count = _pb_attivi
	_pb_mm.buffer = _pb_buf
	return perdite


func _crea_grafica() -> void:
	var palette := [MeshFactory.PALETTE_NEMICO_BASE, MeshFactory.PALETTE_NEMICO_VELOCE,
			MeshFactory.PALETTE_NEMICO_CORAZZATO, MeshFactory.PALETTE_NEMICO_TIRATORE]
	var opzioni := [{}, {"zaino": false}, {"scudo": true}, {"fucile_lungo": true, "zaino": false}]
	var materiale := MeshFactory.materiale_colori_vertice()
	for t in NOMI_TIPI.size():
		var mesh := MeshFactory.soldato(palette[t], opzioni[t])
		mesh.surface_set_material(0, materiale)
		var mm := MultiMeshHelper.crea(mesh, MAX_ISTANZE_PER_TIPO)
		_mm.append(mm)
		_buf.append(MultiMeshHelper.crea_buffer(MAX_ISTANZE_PER_TIPO))
		var istanza := MultiMeshInstance3D.new()
		istanza.name = "Nemici_" + NOMI_TIPI[t]
		istanza.multimesh = mm
		add_child(istanza)

	for e in MAX_ETICHETTE:
		var l := Label3D.new()
		l.font_size = 110
		l.outline_size = 22
		l.pixel_size = 0.012
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = Color(1, 0.92, 0.9)
		l.outline_modulate = Color(0.45, 0.02, 0.02)
		l.visible = false
		add_child(l)
		_etichette.append(l)
		_etichette_libere.append(e)

	_pb_x.resize(MAX_PROIETTILI)
	_pb_z.resize(MAX_PROIETTILI)
	_pb_vx.resize(MAX_PROIETTILI)
	_pb_vz.resize(MAX_PROIETTILI)
	_pb_buf = MultiMeshHelper.crea_buffer(MAX_PROIETTILI)
	var colpo := MeshFactory.proiettile(Color(0.85, 0.35, 1.0), 1.6)
	colpo.surface_set_material(0, MeshFactory.materiale_luminoso())
	_pb_mm = MultiMeshHelper.crea(colpo, MAX_PROIETTILI)
	var ist := MultiMeshInstance3D.new()
	ist.name = "ProiettiliNemici"
	ist.multimesh = _pb_mm
	add_child(ist)
