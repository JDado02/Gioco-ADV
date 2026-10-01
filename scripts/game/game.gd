extends Node3D
## Scena principale.
##
## Coordina pista, arsenale, folla, cancelli, proiettili, nemici, boss,
## effetti e ondate, più il menu, la pausa, la scelta dei potenziamenti e il
## game over. L'ordine di aggiornamento è deciso qui (e non dai _process dei
## singoli nodi) così ogni fotogramma si svolge sempre nella stessa sequenza.

enum Stato { MENU, GIOCO, PAUSA, SCELTA, FINITA }

## Limite al passo di tempo: dopo un rallentamento (o al ritorno
## dall'app in background) il gioco non fa "salti" enormi.
const DELTA_MASSIMO := 1.0 / 20.0

## Posizione della telecamera: dietro e sopra la folla, guarda in avanti.
const CAMERA_POSIZIONE := Vector3(0.0, 9.0, 8.0)
const CAMERA_BERSAGLIO := Vector3(0.0, 0.0, -14.0)

var stato := Stato.MENU

var _velocita_pista: float
var _larghezza_pista: float
var _sensibilita: float
var _potenziamenti := Potenziamenti.new()

@onready var _pista: Pista = $Pista
@onready var _arsenale: Arsenale = $Arsenale
@onready var _folla: Folla = $Folla
@onready var _cancelli: GestoreCancelli = $Cancelli
@onready var _proiettili: GestoreProiettili = $Proiettili
@onready var _nemici: GestoreNemici = $Nemici
@onready var _effetti: GestoreEffetti = $Effetti
@onready var _ondate: GestoreOndate = $Ondate
@onready var _boss: GestoreBoss = $Boss
@onready var _menu: MenuPrincipale = $Menu
@onready var _pausa: SchermataPausa = $Pausa
@onready var _scelta: SceltaPotenziamento = $SceltaPotenziamento
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
	_cancelli.cancello_attraversato.connect(_on_cancello_attraversato)
	_cancelli.ostacolo_distrutto.connect(_on_ostacolo_distrutto)
	_arsenale.arma_cambiata.connect(_on_arma_cambiata)
	_boss.avviso.connect(func() -> void: _hud.mostra_avviso("BOSS IN ARRIVO", Config.num("boss", "durata_avviso")))
	_boss.fase_due.connect(func() -> void: _hud.mostra_esito("SCUDO!", false))
	_boss.arrabbiato.connect(func() -> void: _hud.mostra_avviso("IL BOSS AVANZA!", 2.0))
	_boss.colpo_a_segno.connect(func(perse: int) -> void: _hud.mostra_esito("-%d" % perse, false))
	_boss.sconfitto.connect(_on_boss_sconfitto)
	_scelta.scelto.connect(_on_potenziamento_scelto)
	_menu.gioca.connect(_inizia_partita)
	_hud.pausa_premuta.connect(_metti_in_pausa)
	_pausa.riprendi.connect(_riprendi)
	_pausa.menu.connect(_torna_al_menu)
	_game_over.riprova.connect(_riprova)
	_game_over.menu.connect(_torna_al_menu)
	_hud.aggiorna_unita(_folla.unita)
	_on_arma_cambiata(_arsenale.arma())

	if Dati.avvio_diretto:
		Dati.avvio_diretto = false
		_inizia_partita()
	else:
		_hud.visible = false
		_folla.visible = false
		_menu.visible = true


func _notification(what: int) -> void:
	# Tasto "indietro" di Android: pausa in partita, chiude l'app dal menu.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match stato:
			Stato.GIOCO: _metti_in_pausa()
			Stato.PAUSA: _riprendi()
			Stato.MENU: get_tree().quit()
			Stato.FINITA: _torna_al_menu()
	# Se l'app va in background durante la partita, si mette in pausa da sola.
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and stato == Stato.GIOCO:
		_metti_in_pausa()


func _unhandled_input(event: InputEvent) -> void:
	if stato != Stato.GIOCO:
		return
	# Trascinamento libero: conta solo lo spostamento orizzontale del dito,
	# ovunque sia appoggiato sullo schermo. (Col mouse funziona uguale grazie
	# all'impostazione "emulate touch from mouse".)
	if event is InputEventScreenDrag:
		var larghezza_schermo := get_viewport().get_visible_rect().size.x
		_folla.sposta_di(event.relative.x / larghezza_schermo * _larghezza_pista * _sensibilita)


func _process(delta: float) -> void:
	var dt := minf(delta, DELTA_MASSIMO)
	if stato == Stato.MENU:
		_pista.aggiorna(dt, 0.0)  # nel menu si muovono solo mare e braci
		return
	if stato != Stato.GIOCO:
		return
	_pista.aggiorna(dt, _velocita_pista)
	_arsenale.aggiorna(dt)
	_folla.aggiorna(dt)
	_cancelli.aggiorna(dt, _velocita_pista, _folla.position.x, _folla.unita, maxi(_ondate.ondata, 1))
	_proiettili.aggiorna(dt)
	var perdite := _nemici.aggiorna(dt, _velocita_pista, _folla.position.x, _folla.raggio)
	perdite += _boss.aggiorna(dt, _folla.position.x, _folla.raggio, _folla.unita, maxi(_ondate.ondata, 1))
	_folla.perdi(perdite)
	_effetti.aggiorna(dt, _velocita_pista)
	_hud.aggiorna_bonus(_arsenale.descrizione_bonus())
	if stato == Stato.GIOCO:
		_ondate.aggiorna(dt)


# --- Flusso della partita ----------------------------------------------------

func _inizia_partita() -> void:
	_menu.visible = false
	_hud.visible = true
	_folla.visible = true
	stato = Stato.GIOCO


func _metti_in_pausa() -> void:
	if stato != Stato.GIOCO:
		return
	stato = Stato.PAUSA
	_pausa.visible = true


func _riprendi() -> void:
	if stato != Stato.PAUSA:
		return
	_pausa.visible = false
	stato = Stato.GIOCO


func _torna_al_menu() -> void:
	Dati.avvio_diretto = false
	get_tree().reload_current_scene()


func _riprova() -> void:
	Dati.avvio_diretto = true
	get_tree().reload_current_scene()


func _fine_partita() -> void:
	if stato == Stato.FINITA:
		return
	stato = Stato.FINITA
	var ondata := _ondate.ondata
	var nuovo := Dati.registra_partita(ondata)
	_hud.visible = false
	_game_over.mostra(ondata, Dati.record, nuovo, _folla.unita_massime, _boss.sconfitti)


# --- Eventi di gioco ---------------------------------------------------------

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


func _on_boss_sconfitto(posizione: Vector3) -> void:
	_effetti.esplosione(posizione, 4.0)
	_hud.mostra_esito("BOSS SCONFITTO!", true)
	# Mentre si sceglie il potenziamento il mondo resta fermo.
	stato = Stato.SCELTA
	_scelta.mostra(_potenziamenti.proponi(), _potenziamenti)


func _on_potenziamento_scelto(id: String) -> void:
	_potenziamenti.applica(id, _arsenale, _folla, _cancelli.regole.unita_massime)
	_hud.mostra_esito(_potenziamenti.titolo(id) + "!", true)
	_ondate.sospesa = false
	_boss.nuova_soglia()
	stato = Stato.GIOCO
