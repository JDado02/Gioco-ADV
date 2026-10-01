extends Node3D
## Scena principale della partita.
##
## Coordina pista, arsenale, folla, cancelli, proiettili, nemici, effetti e
## ondate. L'ordine di
## aggiornamento è deciso qui (e non dai _process dei singoli nodi) così ogni
## fotogramma si svolge sempre nella stessa sequenza.

## Limite al passo di tempo: dopo un rallentamento (o al ritorno
## dall'app in background) il gioco non fa "salti" enormi.
const DELTA_MASSIMO := 1.0 / 20.0

## Posizione della telecamera: dietro e sopra la folla, guarda in avanti.
const CAMERA_POSIZIONE := Vector3(0.0, 14.0, 4.0)
const CAMERA_BERSAGLIO := Vector3(0.0, 0.0, -12.0)

var _velocita_pista: float
var _larghezza_pista: float
var _sensibilita: float
var _finita := false

@onready var _pista: Pista = $Pista
@onready var _arsenale: Arsenale = $Arsenale
@onready var _folla: Folla = $Folla
@onready var _cancelli: GestoreCancelli = $Cancelli
@onready var _proiettili: GestoreProiettili = $Proiettili
@onready var _nemici: GestoreNemici = $Nemici
@onready var _effetti: GestoreEffetti = $Effetti
@onready var _ondate: GestoreOndate = $Ondate
@onready var _hud: Hud = $HUD
@onready var _game_over: SchermataGameOver = $GameOver
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_velocita_pista = Config.num("pista", "velocita_avanzamento")
	_larghezza_pista = Config.num("pista", "larghezza")
	_sensibilita = Config.num("folla", "sensibilita_trascinamento")

	_camera.look_at_from_position(CAMERA_POSIZIONE, CAMERA_BERSAGLIO)

	_folla.unita_cambiate.connect(_hud.aggiorna_unita)
	_folla.annientata.connect(_fine_partita)
	_ondate.ondata_iniziata.connect(_hud.mostra_ondata)
	_game_over.riprova.connect(_riprova)
	_cancelli.cancello_attraversato.connect(_on_cancello_attraversato)
	_cancelli.ostacolo_distrutto.connect(_on_ostacolo_distrutto)
	_arsenale.arma_cambiata.connect(_on_arma_cambiata)
	_hud.aggiorna_unita(_folla.unita)
	_on_arma_cambiata(_arsenale.arma())


func _unhandled_input(event: InputEvent) -> void:
	if _finita:
		return
	# Trascinamento libero: conta solo lo spostamento orizzontale del dito,
	# ovunque sia appoggiato sullo schermo. (Col mouse funziona uguale grazie
	# all'impostazione "emulate touch from mouse".)
	if event is InputEventScreenDrag:
		var larghezza_schermo := get_viewport().get_visible_rect().size.x
		_folla.sposta_di(event.relative.x / larghezza_schermo * _larghezza_pista * _sensibilita)


func _process(delta: float) -> void:
	if _finita:
		return
	var dt := minf(delta, DELTA_MASSIMO)
	_pista.aggiorna(dt, _velocita_pista)
	_arsenale.aggiorna(dt)
	_folla.aggiorna(dt)
	_cancelli.aggiorna(dt, _velocita_pista, _folla.position.x, _folla.unita, maxi(_ondate.ondata, 1))
	_proiettili.aggiorna(dt)
	var perdite := _nemici.aggiorna(dt, _velocita_pista, _folla.position.x, _folla.raggio)
	_folla.perdi(perdite)
	_effetti.aggiorna(dt, _velocita_pista)
	_hud.aggiorna_bonus(_arsenale.descrizione_bonus())
	if not _finita:
		_ondate.aggiorna(dt)


func _on_cancello_attraversato(cancello: Array) -> void:
	var prima := _folla.unita
	var dopo := _cancelli.regole.applica(cancello, prima)
	_folla.imposta_unita(dopo)
	_hud.mostra_esito("%s  →  %d" % [RegoleCancelli.testo(cancello), dopo], dopo >= prima)


func _on_ostacolo_distrutto(ricompensa: String, posizione: Vector3) -> void:
	_effetti.esplosione(posizione, 1.6)
	_hud.mostra_esito(_arsenale.ottieni(ricompensa) + "!", true)


func _on_arma_cambiata(arma: Dictionary) -> void:
	_proiettili.imposta_arma(arma)
	_hud.aggiorna_arma(arma.nome)


func _fine_partita() -> void:
	_finita = true
	_game_over.mostra(_ondate.ondata, _folla.unita_massime)


func _riprova() -> void:
	get_tree().reload_current_scene()
