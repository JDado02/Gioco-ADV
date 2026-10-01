class_name GestoreOndate
extends Node
## Regia delle ondate di nemici.
##
## Ondata n:  nemici = nemici_base + nemici_incremento × n   (crescita LINEARE)
##            velocità = velocita_base + velocita_incremento_per_ondata × n (con tetto)
##            vita = vita_base + vita_incremento_per_ondata × n
## Ogni variante (veloce, corazzato, tiratore) si sblocca a una certa ondata e
## moltiplica vita e velocità. I nemici di un'ondata compaiono a squadrette o
## a ORDE (gruppi con contatore), distribuiti su `durata_comparsa` secondi.
## L'ondata finisce quando sono tutti comparsi e non ne resta nessuno in campo.

signal ondata_iniziata(numero: int)

## Attesa prima della primissima ondata.
const PAUSA_INIZIALE := 1.5
## Distanza laterale tra i membri di una squadretta.
const SPAZIO_SQUADRA := 1.2
## Se il pool dei nemici è pieno, riprova dopo questo tempo.
const ATTESA_POOL_PIENO := 0.2
## Massimo di tiratori in una squadretta.
const MAX_TIRATORI_INSIEME := 2

@export var nemici: GestoreNemici

## Numero dell'ondata in corso (0 = partita non ancora iniziata).
var ondata := 0
## Se true non compaiono nuovi nemici (per esempio durante un mini boss).
var sospesa := false

var _nemici_base: int
var _nemici_incremento: int
var _durata_comparsa: float
var _max_squadra: int
var _pausa_tra_ondate: float
var _vita_base: float
var _vita_incremento: float
var _vel_base: float
var _vel_incremento: float
var _vel_max: float
var _distanza: float
var _meta_pista: float
var _orde_inizio: int
var _p_orda: float
var _orda_base: int
var _orda_incremento: float
var _orda_max: int

var _da_generare := 0
var _intervallo := 0.0
var _timer_comparsa := 0.0
var _velocita_ondata := 0.0
var _vita_ondata := 0.0
var _in_pausa := true
var _pausa := PAUSA_INIZIALE


func _ready() -> void:
	_nemici_base = Config.intero("ondate", "nemici_base")
	_nemici_incremento = Config.intero("ondate", "nemici_incremento")
	_durata_comparsa = Config.num("ondate", "durata_comparsa")
	_max_squadra = maxi(Config.intero("ondate", "dimensione_massima_squadra"), 1)
	_pausa_tra_ondate = Config.num("ondate", "pausa_tra_ondate")
	_vita_base = Config.num("nemici", "vita_base")
	_vita_incremento = Config.num("nemici", "vita_incremento_per_ondata")
	_vel_base = Config.num("nemici", "velocita_base")
	_vel_incremento = Config.num("nemici", "velocita_incremento_per_ondata")
	_vel_max = Config.num("nemici", "velocita_massima")
	_distanza = Config.num("nemici", "distanza_comparsa")
	_meta_pista = Config.num("pista", "larghezza") * 0.5
	_orde_inizio = Config.intero("orde", "ondata_inizio")
	_p_orda = Config.num("orde", "probabilita")
	_orda_base = Config.intero("orde", "dimensione_base")
	_orda_incremento = Config.num("orde", "dimensione_incremento_per_ondata")
	_orda_max = Config.intero("orde", "dimensione_massima")


func aggiorna(delta: float) -> void:
	if sospesa:
		return
	if _in_pausa:
		_pausa -= delta
		if _pausa <= 0.0:
			_inizia_ondata()
		return

	if _da_generare > 0:
		_timer_comparsa -= delta
		if _timer_comparsa <= 0.0:
			_genera()
	elif nemici.attivi == 0:
		_in_pausa = true
		_pausa = _pausa_tra_ondate


## Numero di nemici previsto per l'ondata n.
func nemici_per_ondata(n: int) -> int:
	return maxi(_nemici_base + _nemici_incremento * n, 1)


## Velocità di camminata del nemico base all'ondata n (con tetto massimo).
func velocita_per_ondata(n: int) -> float:
	return minf(_vel_base + _vel_incremento * n, _vel_max)


## Vita del nemico base all'ondata n.
func vita_per_ondata(n: int) -> float:
	return _vita_base + _vita_incremento * n


func _inizia_ondata() -> void:
	ondata += 1
	_in_pausa = false
	_da_generare = nemici_per_ondata(ondata)
	_intervallo = _durata_comparsa / _da_generare
	_velocita_ondata = velocita_per_ondata(ondata)
	_vita_ondata = vita_per_ondata(ondata)
	_timer_comparsa = 0.0
	ondata_iniziata.emit(ondata)


## Sceglie una variante tra quelle già sbloccate, in proporzione al loro peso.
func _scegli_tipo() -> int:
	var totale := 0.0
	for t in GestoreNemici.Tipo.size():
		var d := nemici.dati_tipo(t)
		if ondata >= d.ondata_sblocco:
			totale += d.peso
	var estratto := randf() * totale
	for t in GestoreNemici.Tipo.size():
		var d := nemici.dati_tipo(t)
		if ondata >= d.ondata_sblocco:
			estratto -= d.peso
			if estratto <= 0.0:
				return t
	return GestoreNemici.Tipo.BASE


func _genera() -> void:
	if nemici.posti_liberi() <= 0:
		_timer_comparsa = ATTESA_POOL_PIENO
		return
	var tipo := _scegli_tipo()
	var d := nemici.dati_tipo(tipo)
	var vita: float = _vita_ondata * d.vita
	var vel: float = _velocita_ondata * d.velocita
	var z := -_distanza + randf_range(-0.6, 0.6)
	var generati := 0

	var orda_possibile := tipo == GestoreNemici.Tipo.BASE or tipo == GestoreNemici.Tipo.VELOCE
	if orda_possibile and ondata >= _orde_inizio and randf() < _p_orda:
		var dimensione := mini(_orda_base + int(_orda_incremento * ondata), _orda_max)
		var membri := mini(dimensione, _da_generare)
		var raggio := nemici.raggio_per(membri, tipo)
		var margine := maxf(_meta_pista - raggio - 0.3, 0.0)
		if nemici.genera(tipo, randf_range(-margine, margine), z, membri, vita, vel):
			generati = membri
	else:
		var massimo := MAX_TIRATORI_INSIEME if tipo == GestoreNemici.Tipo.TIRATORE else _max_squadra
		var quanti := mini(mini(randi_range(1, massimo), _da_generare), nemici.posti_liberi())
		var ingombro := (quanti - 1) * SPAZIO_SQUADRA
		var margine := maxf(_meta_pista - 0.6 - ingombro * 0.5, 0.0)
		var centro := randf_range(-margine, margine)
		for k in quanti:
			var x := centro - ingombro * 0.5 + k * SPAZIO_SQUADRA
			if nemici.genera(tipo, x, z + randf_range(-0.5, 0.5), 1, vita, vel):
				generati += 1

	_da_generare -= generati
	# Il tempo fino alla prossima comparsa è proporzionale ai nemici appena
	# generati: in media l'ondata dura sempre `durata_comparsa` secondi.
	_timer_comparsa += maxi(generati, 1) * _intervallo
