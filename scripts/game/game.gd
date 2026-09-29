extends Node3D
## Scena principale della partita.
##
## Coordina pista, folla, proiettili, nemici e ondate. L'ordine di
## aggiornamento è deciso qui (e non dai _process dei singoli nodi) così ogni
## fotogramma si svolge sempre nella stessa sequenza.

## Limite al passo di tempo: dopo un rallentamento (o al ritorno
## dall'app in background) il gioco non fa "salti" enormi.
const DELTA_MASSIMO := 1.0 / 20.0

## Posizione della telecamera: dietro e sopra la folla, guarda in avanti.
const CAMERA_POSIZIONE := Vector3(0.0, 10.0, 7.5)
const CAMERA_BERSAGLIO := Vector3(0.0, 0.0, -11.0)

var _velocita_pista: float
var _larghezza_pista: float
var _sensibilita: float
var _finita := false

@onready var _pista: Pista = $Pista
@onready var _folla: Folla = $Folla
@onready var _proiettili: GestoreProiettili = $Proiettili
@onready var _nemici: GestoreNemici = $Nemici
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
	_hud.aggiorna_unita(_folla.unita)


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
	_folla.aggiorna(dt)
	_proiettili.aggiorna(dt)
	var perdite := _nemici.aggiorna(dt, _velocita_pista, _folla.position.x, _folla.raggio)
	_folla.perdi(perdite)
	if not _finita:
		_ondate.aggiorna(dt)


func _fine_partita() -> void:
	_finita = true
	_game_over.mostra(_ondate.ondata, _folla.unita_massime)


func _riprova() -> void:
	get_tree().reload_current_scene()
