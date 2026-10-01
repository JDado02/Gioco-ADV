class_name Folla
extends Node3D
## La folla del giocatore.
##
## - `unita` è il numero REALE di soldati (quello mostrato dal contatore).
## - Ne vengono disegnati al massimo VISUAL_UNIT_CAP: oltre quella soglia il
##   contatore sale ma la grafica resta uguale.
## - La potenza di fuoco usa il numero reale: ogni soldato visibile spara
##   proiettili "aggregati" che portano il danno di unita / visibili soldati.

signal unita_cambiate(unita: int)
signal annientata

## Altezza della canna del fucile (da dove partono i proiettili).
const ALTEZZA_CANNA := 0.64 * MeshFactory.SCALA_SOLDATO
## Spostamento laterale della canna rispetto al centro del soldato.
const LATO_CANNA := 0.17 * MeshFactory.SCALA_SOLDATO
## Raggio di ingombro di un singolo soldato.
const RAGGIO_SOLDATO := 0.3 * MeshFactory.SCALA_SOLDATO
## Angolo aureo: distribuisce i soldati in una formazione compatta e rotonda.
const ANGOLO_AUREO := 2.39996323

@export var proiettili: GestoreProiettili
@export var arsenale: Arsenale

## Numero reale di unità.
var unita := 0
## Massimo numero di unità raggiunto nella partita.
var unita_massime := 0
## Raggio della formazione visibile (usato per contatti e limiti della pista).
var raggio := RAGGIO_SOLDATO
## Probabilità che un'unità sopravviva a un colpo (potenziamento "soldati corazzati").
var resistenza := 0.0

var _cap: int
var _passo_formazione: float
var _ricompattamento: float
var _meta_pista: float
var _in_corsa: bool

var _visibili := 0
var _tempo := 0.0
var _mm: MultiMesh
var _buf: PackedFloat32Array
var _off_x := PackedFloat32Array()
var _off_z := PackedFloat32Array()
var _timer_sparo := PackedFloat32Array()

@onready var _contatore: Label3D = $Contatore


func _ready() -> void:
	_cap = maxi(Config.intero("folla", "visual_unit_cap"), 1)
	_passo_formazione = Config.num("folla", "spaziatura_unita") * 0.6
	_ricompattamento = Config.num("folla", "velocita_ricompattamento")
	_meta_pista = Config.num("pista", "larghezza") * 0.5
	_in_corsa = Config.num("pista", "velocita_avanzamento") > 0.0

	_off_x.resize(_cap)
	_off_z.resize(_cap)
	_timer_sparo.resize(_cap)
	_buf = MultiMeshHelper.crea_buffer(_cap)

	var mesh := MeshFactory.soldato(MeshFactory.PALETTE_GIOCATORE)
	mesh.surface_set_material(0, MeshFactory.materiale_colori_vertice())
	_mm = MultiMeshHelper.crea(mesh, _cap)
	var istanza := MultiMeshInstance3D.new()
	istanza.name = "Soldati"
	istanza.multimesh = _mm
	add_child(istanza)

	imposta_unita(Config.intero("folla", "unita_iniziali"))


## Imposta il numero reale di unità e aggiorna la formazione visibile.
func imposta_unita(n: int) -> void:
	var prima := _visibili
	unita = maxi(n, 0)
	unita_massime = maxi(unita_massime, unita)
	_visibili = mini(unita, _cap)
	# I nuovi soldati visibili compaiono direttamente al loro posto,
	# con il primo colpo sfalsato per non sparare tutti insieme.
	for i in range(prima, _visibili):
		var p := _posto_in_formazione(i)
		_off_x[i] = p.x
		_off_z[i] = p.y
		_timer_sparo[i] = randf() / arsenale.cadenza()
	raggio = _passo_formazione * sqrt(maxf(_visibili - 1, 0)) + RAGGIO_SOLDATO
	_mm.visible_instance_count = _visibili
	_contatore.text = str(unita)
	_contatore.visible = unita > 0
	unita_cambiate.emit(unita)
	if unita == 0:
		annientata.emit()


func aggiungi(n: int) -> void:
	imposta_unita(unita + n)


## Perde n unità; con la resistenza una parte sopravvive.
## Restituisce quante unità sono state davvero perse.
func perdi(n: int) -> int:
	if n <= 0 or unita <= 0:
		return 0
	if resistenza > 0.0:
		# Sopravvissuti attesi, con arrotondamento casuale per i decimali.
		var salvati := n * resistenza
		n -= int(salvati) + (1 if randf() < salvati - int(salvati) else 0)
	n = mini(n, unita)
	if n > 0:
		imposta_unita(unita - n)
	return n


## Sposta la folla di lato (in metri di gioco), senza uscire dalla pista.
func sposta_di(dx: float) -> void:
	position.x = clampf(position.x + dx, -_meta_pista + raggio, _meta_pista - raggio)


## Aggiornamento di un fotogramma: formazione, animazione e sparo automatico.
func aggiorna(delta: float) -> void:
	if _visibili == 0:
		_mm.visible_instance_count = 0
		return
	_tempo += delta
	sposta_di(0.0)  # la formazione può essersi allargata: resta dentro la pista

	var k := 1.0 - exp(-_ricompattamento * delta)
	var arma := arsenale.arma()
	var intervallo_sparo := 1.0 / arsenale.cadenza()
	var danno_aggregato := arsenale.danno() * float(unita) / float(_visibili)
	for i in _visibili:
		var p := _posto_in_formazione(i)
		_off_x[i] = lerpf(_off_x[i], p.x, k)
		_off_z[i] = lerpf(_off_z[i], p.y, k)
		# Piccolo saltello di corsa (solo se la folla avanza), sfasato per ogni soldato.
		var y := absf(sin(_tempo * 9.0 + i * 1.7)) * 0.08 if _in_corsa else 0.0
		MultiMeshHelper.scrivi(_buf, i, Vector3(_off_x[i], y, _off_z[i]), 0.0)

		_timer_sparo[i] -= delta
		if _timer_sparo[i] <= 0.0:
			_timer_sparo[i] += intervallo_sparo
			proiettili.spara(
				Vector3(position.x + _off_x[i] + LATO_CANNA, ALTEZZA_CANNA, _off_z[i] - 0.5),
				danno_aggregato, arma)

	_mm.visible_instance_count = _visibili
	_mm.buffer = _buf


## Posizione (x, z) del soldato numero i nella formazione a girasole.
func _posto_in_formazione(i: int) -> Vector2:
	if i == 0:
		return Vector2.ZERO
	var r := _passo_formazione * sqrt(float(i))
	var a := i * ANGOLO_AUREO
	return Vector2(cos(a) * r, sin(a) * r)
