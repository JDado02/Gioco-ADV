class_name GestoreBoss
extends Node3D
## Mini boss.
##
## - Arriva dopo un numero di uccisioni pari a una soglia configurabile ±20%,
##   preceduto dall'avviso "BOSS IN ARRIVO" (intanto le ondate si fermano).
## - Si ferma a distanza e lancia attacchi ad area: una zona rossa compare a
##   terra e dopo un preavviso esplode. Bisogna trascinare la folla fuori.
## - Sotto metà vita entra in fase 2: alza uno scudo per qualche secondo e poi
##   attacca più spesso. Se resiste troppo a lungo si arrabbia e avanza.

signal avviso
signal comparso
signal sconfitto(posizione: Vector3)
signal fase_due
signal arrabbiato
signal colpo_a_segno(unita_perse: int)

enum Stato { INATTIVO, AVVISO, ARRIVO, COMBATTIMENTO }
enum Attacco { MIRATO, FASCIA, DOPPIO }

## Grandezza del modello rispetto a un soldato.
const SCALA := 4.6
## Ingombro del boss per colpi e contatti.
const RAGGIO := 2.3
const MAX_ZONE := 4
const COLORE_ZONA := Color(1.0, 0.12, 0.08)
const LARGHEZZA_BARRA := 4.6

@export var nemici: GestoreNemici
@export var ondate: GestoreOndate
@export var effetti: GestoreEffetti

var stato := Stato.INATTIVO
## Boss sconfitti in questa partita.
var sconfitti := 0
var vita := 0.0
var vita_massima := 1.0

var _uccisioni_base: int
var _uccisioni_incremento: int
var _variazione: float
var _durata_avviso: float
var _vita_base: float
var _vita_per_ondata: float
var _crescita: float
var _velocita: float
var _distanza: float
var _tempo_rabbia: float
var _velocita_rabbia: float
var _uccise_contatto: int
var _intervallo_1: float
var _intervallo_2: float
var _preavviso: float
var _percentuale: float
var _perse_minime: int
var _raggio_zona: float
var _soglia_fase_2: float
var _durata_scudo: float
var _meta_pista: float
var _distanza_comparsa: float

var _soglia_uccisioni := 0
var _uccisi_al_via := 0
var _timer := 0.0
var _timer_attacco := 0.0
var _tempo_combattimento := 0.0
var _fase := 1
var _timer_scudo := 0.0
var _in_rabbia := false
var _tempo := 0.0

var _corpo: MeshInstance3D
var _scudo: MeshInstance3D
var _barra: MeshInstance3D
var _testo_vita: Label3D
## Zone di attacco: {nodo, attiva, timer, cerchio, x, z, raggio, meta_larghezza, meta_lunghezza}
var _zone: Array[Dictionary] = []


func _ready() -> void:
	_uccisioni_base = Config.intero("boss", "uccisioni_base")
	_uccisioni_incremento = Config.intero("boss", "uccisioni_incremento_per_boss")
	_variazione = Config.num("boss", "variazione_casuale")
	_durata_avviso = Config.num("boss", "durata_avviso")
	_vita_base = Config.num("boss", "vita_base")
	_vita_per_ondata = Config.num("boss", "vita_per_ondata")
	_crescita = Config.num("boss", "crescita_per_boss")
	_velocita = Config.num("boss", "velocita")
	_distanza = Config.num("boss", "distanza_combattimento")
	_tempo_rabbia = Config.num("boss", "tempo_prima_della_rabbia")
	_velocita_rabbia = Config.num("boss", "velocita_rabbia")
	_uccise_contatto = Config.intero("boss", "unita_uccise_al_contatto")
	_intervallo_1 = maxf(Config.num("boss", "intervallo_attacchi"), 0.5)
	_intervallo_2 = maxf(Config.num("boss", "intervallo_attacchi_fase_2"), 0.5)
	_preavviso = maxf(Config.num("boss", "preavviso_attacco"), 0.3)
	_percentuale = Config.num("boss", "percentuale_unita_perse")
	_perse_minime = Config.intero("boss", "unita_perse_minime")
	_raggio_zona = Config.num("boss", "raggio_zona")
	_soglia_fase_2 = Config.num("boss", "soglia_fase_2")
	_durata_scudo = Config.num("boss", "durata_scudo")
	_meta_pista = Config.num("pista", "larghezza") * 0.5
	_distanza_comparsa = Config.num("nemici", "distanza_comparsa")
	_crea_grafica()
	nuova_soglia()


## Prepara il conteggio delle uccisioni per il prossimo boss (base ± variazione).
func nuova_soglia() -> void:
	var base := _uccisioni_base + _uccisioni_incremento * sconfitti
	_soglia_uccisioni = maxi(int(base * (1.0 + randf_range(-_variazione, _variazione))), 1)
	_uccisi_al_via = nemici.uccisi_totali


## True mentre il boss è in campo (arriva o combatte).
func in_campo() -> bool:
	return stato == Stato.ARRIVO or stato == Stato.COMBATTIMENTO


## Uccisioni mancanti al prossimo boss (per l'interfaccia).
func uccisioni_mancanti() -> int:
	return maxi(_soglia_uccisioni - (nemici.uccisi_totali - _uccisi_al_via), 0)


## Restituisce le unità del giocatore perse in questo fotogramma.
func aggiorna(delta: float, folla_x: float, folla_raggio: float, unita: int, ondata: int) -> int:
	_tempo += delta
	var perdite := 0
	match stato:
		Stato.INATTIVO:
			if nemici.uccisi_totali - _uccisi_al_via >= _soglia_uccisioni:
				stato = Stato.AVVISO
				_timer = _durata_avviso
				ondate.sospesa = true
				avviso.emit()
		Stato.AVVISO:
			_timer -= delta
			if _timer <= 0.0:
				_compari(ondata)
		Stato.ARRIVO:
			position.z += _velocita * delta
			if position.z >= -_distanza:
				position.z = -_distanza
				stato = Stato.COMBATTIMENTO
				_timer_attacco = _intervallo_1 * 0.6
				_tempo_combattimento = 0.0
		Stato.COMBATTIMENTO:
			perdite += _combatti(delta, folla_x, folla_raggio)
	if in_campo():
		# Il boss segue lentamente la folla di lato e ondeggia mentre cammina.
		position.x = move_toward(position.x, clampf(folla_x, -_meta_pista + 2.0, _meta_pista - 2.0), 2.0 * delta)
		_corpo.position.y = absf(sin(_tempo * 3.0)) * 0.15
	perdite += _aggiorna_zone(delta, folla_x, folla_raggio, unita)
	return perdite


# --- Colpi del giocatore ---------------------------------------------------

func colpisci(x: float, z_da: float, z_a: float, raggio_proiettile: float, danno: float) -> float:
	if not _toccato(x, z_da, z_a, raggio_proiettile):
		return danno
	if _timer_scudo > 0.0:
		return 0.0  # lo scudo assorbe il colpo
	var inflitto := minf(danno, vita)
	_ferisci(inflitto)
	return danno - inflitto


func tocca(x: float, z_da: float, z_a: float, raggio_proiettile: float) -> bool:
	return _toccato(x, z_da, z_a, raggio_proiettile)


func danno_area(x: float, z: float, raggio_area: float, danno: float) -> void:
	if not in_campo() or vita <= 0.0 or _timer_scudo > 0.0:
		return
	var r := raggio_area + RAGGIO
	var dx := position.x - x
	var dz := position.z - z
	if dx * dx + dz * dz <= r * r:
		_ferisci(minf(danno, vita))


# --- Funzioni interne -------------------------------------------------------

func _compari(ondata: int) -> void:
	vita_massima = (_vita_base + _vita_per_ondata * ondata) * (1.0 + _crescita * sconfitti)
	vita = vita_massima
	position = Vector3(0, 0, -_distanza_comparsa)
	_fase = 1
	_timer_scudo = 0.0
	_in_rabbia = false
	_scudo.visible = false
	visible = true
	stato = Stato.ARRIVO
	_aggiorna_barra()
	comparso.emit()


func _combatti(delta: float, folla_x: float, folla_raggio: float) -> int:
	var perdite := 0
	_tempo_combattimento += delta
	if _timer_scudo > 0.0:
		_timer_scudo -= delta
		_scudo.visible = _timer_scudo > 0.0
	_timer_attacco -= delta
	if _timer_attacco <= 0.0:
		_timer_attacco = _intervallo_2 if _fase == 2 else _intervallo_1
		_lancia_attacco(folla_x)
	if _tempo_combattimento > _tempo_rabbia:
		if not _in_rabbia:
			_in_rabbia = true
			arrabbiato.emit()
		position.z += _velocita_rabbia * delta
		if position.z >= -(folla_raggio + RAGGIO):
			# Il boss travolge la folla e poi torna indietro.
			perdite += _uccise_contatto
			effetti.esplosione(Vector3(position.x, 1.0, position.z), 3.0)
			position.z = -_distanza
			_tempo_combattimento = 0.0
			_in_rabbia = false
	return perdite


func _lancia_attacco(folla_x: float) -> void:
	var scelte := [Attacco.MIRATO, Attacco.FASCIA]
	if _fase == 2:
		scelte.append(Attacco.DOPPIO)
	match scelte.pick_random():
		Attacco.MIRATO:
			_nuova_zona_cerchio(folla_x, 0.0)
		Attacco.FASCIA:
			# Copre metà strada, dal lato in cui si trova la folla.
			var lato := -1.0 if folla_x < 0.0 else 1.0
			_nuova_zona_fascia(lato * _meta_pista * 0.5, 0.0, _meta_pista * 0.5, 4.0)
		Attacco.DOPPIO:
			_nuova_zona_cerchio(folla_x, 0.0)
			var verso := 1.0 if randf() < 0.5 else -1.0
			var x2 := clampf(folla_x + verso * _raggio_zona * 2.4, -_meta_pista + 1.0, _meta_pista - 1.0)
			_nuova_zona_cerchio(x2, 0.0)


func _nuova_zona_cerchio(x: float, z: float) -> void:
	var zona := _zona_libera()
	if zona.is_empty():
		return
	zona.cerchio = true
	zona.raggio = _raggio_zona
	_attiva_zona(zona, x, z, Vector3(_raggio_zona, 1.0, _raggio_zona))


func _nuova_zona_fascia(x: float, z: float, meta_larghezza: float, meta_lunghezza: float) -> void:
	var zona := _zona_libera()
	if zona.is_empty():
		return
	zona.cerchio = false
	zona.meta_larghezza = meta_larghezza
	zona.meta_lunghezza = meta_lunghezza
	_attiva_zona(zona, x, z, Vector3(meta_larghezza, 1.0, meta_lunghezza))


func _attiva_zona(zona: Dictionary, x: float, z: float, scala: Vector3) -> void:
	zona.x = x
	zona.z = z
	zona.timer = _preavviso
	zona.attiva = true
	var nodo: MeshInstance3D = zona.cerchio_nodo if zona.cerchio else zona.fascia_nodo
	zona.nodo = nodo
	nodo.position = Vector3(x, 0.04, z)
	nodo.scale = scala
	nodo.visible = true


func _zona_libera() -> Dictionary:
	for z in _zone:
		if not z.attiva:
			return z
	return {}


func _aggiorna_zone(delta: float, folla_x: float, folla_raggio: float, unita: int) -> int:
	var perdite := 0
	for zona in _zone:
		if not zona.attiva:
			continue
		zona.timer -= delta
		var nodo: MeshInstance3D = zona.nodo
		# La zona lampeggia sempre più in fretta mentre si avvicina l'esplosione.
		var t: float = 1.0 - zona.timer / _preavviso
		var mat: StandardMaterial3D = nodo.material_override
		mat.albedo_color.a = 0.3 + 0.45 * t * absf(sin(_tempo * (6.0 + 14.0 * t)))
		if zona.timer > 0.0:
			continue
		zona.attiva = false
		nodo.visible = false
		var dentro := false
		if zona.cerchio:
			var r: float = zona.raggio + folla_raggio * 0.5
			var dx: float = folla_x - zona.x
			var dz: float = zona.z
			dentro = dx * dx + dz * dz <= r * r
			effetti.esplosione(Vector3(zona.x, 0.5, zona.z), zona.raggio)
		else:
			dentro = absf(folla_x - zona.x) <= zona.meta_larghezza + folla_raggio * 0.3
			effetti.esplosione(Vector3(zona.x, 0.5, zona.z), zona.meta_larghezza * 0.8)
		if dentro and unita > 0:
			var perse := maxi(ceili(unita * _percentuale), _perse_minime)
			perdite += perse
			colpo_a_segno.emit(perse)
	return perdite


func _toccato(x: float, z_da: float, z_a: float, r: float) -> bool:
	if not in_campo() or vita <= 0.0:
		return false
	var z := position.z
	return z >= z_da - RAGGIO and z <= z_a + RAGGIO and absf(position.x - x) <= RAGGIO + r


func _ferisci(danno: float) -> void:
	vita -= danno
	if _fase == 1 and vita < vita_massima * _soglia_fase_2 and vita > 0.0:
		_fase = 2
		_timer_scudo = _durata_scudo
		_scudo.visible = true
		fase_due.emit()
	_aggiorna_barra()
	if vita <= 0.0:
		_sconfitto()


func _sconfitto() -> void:
	vita = 0.0
	stato = Stato.INATTIVO
	sconfitti += 1
	visible = false
	nuova_soglia()
	for zona in _zone:
		zona.attiva = false
		zona.nodo.visible = false
	sconfitto.emit(position + Vector3(0, 2.0, 0))


func _aggiorna_barra() -> void:
	var frazione := clampf(vita / vita_massima, 0.0, 1.0)
	_barra.scale.x = maxf(frazione, 0.001)
	_barra.position.x = -LARGHEZZA_BARRA * 0.5 * (1.0 - frazione)
	_testo_vita.text = str(ceili(vita))


func _crea_grafica() -> void:
	visible = false
	_corpo = MeshInstance3D.new()
	var mesh := MeshFactory.soldato(MeshFactory.PALETTE_BOSS, {"zaino": false})
	mesh.surface_set_material(0, MeshFactory.materiale_colori_vertice())
	_corpo.mesh = mesh
	_corpo.scale = Vector3.ONE * SCALA
	_corpo.rotation.y = PI
	add_child(_corpo)

	var altezza := 1.15 * MeshFactory.SCALA_SOLDATO * SCALA + 0.6
	var fondo := _box(Vector3(LARGHEZZA_BARRA + 0.16, 0.6, 0.06), Color(0.1, 0.05, 0.05))
	fondo.position = Vector3(0, altezza, 0)
	add_child(fondo)
	_barra = _box(Vector3(LARGHEZZA_BARRA, 0.46, 0.08), Color(0.95, 0.15, 0.1))
	var supporto := Node3D.new()
	supporto.position = Vector3(0, altezza, 0.02)
	supporto.add_child(_barra)
	add_child(supporto)
	_testo_vita = Label3D.new()
	_testo_vita.font_size = 150
	_testo_vita.outline_size = 24
	_testo_vita.pixel_size = 0.012
	_testo_vita.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_testo_vita.no_depth_test = true
	_testo_vita.position = Vector3(0, altezza + 0.8, 0)
	add_child(_testo_vita)

	var sfera := SphereMesh.new()
	sfera.radius = 3.6
	sfera.height = 7.2
	_scudo = MeshInstance3D.new()
	_scudo.mesh = sfera
	var mat_scudo := StandardMaterial3D.new()
	mat_scudo.albedo_color = Color(0.35, 0.75, 1.0, 0.35)
	mat_scudo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_scudo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scudo.material_override = mat_scudo
	_scudo.position = Vector3(0, 3.2, 0)
	_scudo.visible = false
	add_child(_scudo)

	# Le zone d'attacco stanno a terra: non devono muoversi con il boss.
	var cerchio := CylinderMesh.new()
	cerchio.top_radius = 1.0
	cerchio.bottom_radius = 1.0
	cerchio.height = 0.02
	cerchio.radial_segments = 28
	var rettangolo := BoxMesh.new()
	rettangolo.size = Vector3(2.0, 0.02, 2.0)
	for i in MAX_ZONE:
		var c := MeshInstance3D.new()
		c.mesh = cerchio
		c.material_override = _nuovo_materiale_zona()
		c.visible = false
		var f := MeshInstance3D.new()
		f.mesh = rettangolo
		f.material_override = _nuovo_materiale_zona()
		f.visible = false
		var contenitore := get_parent()
		contenitore.add_child.call_deferred(c)
		contenitore.add_child.call_deferred(f)
		_zone.append({"attiva": false, "timer": 0.0, "cerchio": true, "x": 0.0, "z": 0.0,
				"raggio": 1.0, "meta_larghezza": 1.0, "meta_lunghezza": 1.0,
				"cerchio_nodo": c, "fascia_nodo": f, "nodo": c})


## Ogni zona ha il suo materiale, così può lampeggiare per conto suo.
func _nuovo_materiale_zona() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(COLORE_ZONA, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(dimensioni: Vector3, colore: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = dimensioni
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	return mi
