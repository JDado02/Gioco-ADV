class_name GestoreOndate
extends Node
## Regia delle ondate di nemici.
##
## Ondata n:  nemici = nemici_base + nemici_incremento × n
##            velocità = velocita_base + velocita_incremento_per_ondata × n (con tetto)
## I nemici di un'ondata compaiono a piccole squadre, distribuiti su
## `durata_comparsa` secondi. L'ondata finisce quando sono tutti comparsi e
## non ne resta nessuno in campo; dopo una pausa parte la successiva.

signal ondata_iniziata(numero: int)

## Attesa prima della primissima ondata.
const PAUSA_INIZIALE := 1.5
## Distanza laterale tra i membri di una squadra.
const SPAZIO_SQUADRA := 1.0
## Se il pool dei nemici è pieno, riprova dopo questo tempo.
const ATTESA_POOL_PIENO := 0.2

@export var nemici: GestoreNemici

## Numero dell'ondata in corso (0 = partita non ancora iniziata).
var ondata := 0

var _nemici_base: int
var _nemici_incremento: int
var _durata_comparsa: float
var _max_squadra: int
var _pausa_tra_ondate: float
var _vita: float
var _vel_base: float
var _vel_incremento: float
var _vel_max: float
var _distanza: float
var _meta_pista: float

var _da_generare := 0
var _intervallo := 0.0
var _timer_comparsa := 0.0
var _velocita_ondata := 0.0
var _in_pausa := true
var _pausa := PAUSA_INIZIALE


func _ready() -> void:
	_nemici_base = Config.intero("ondate", "nemici_base")
	_nemici_incremento = Config.intero("ondate", "nemici_incremento")
	_durata_comparsa = Config.num("ondate", "durata_comparsa")
	_max_squadra = maxi(Config.intero("ondate", "dimensione_massima_squadra"), 1)
	_pausa_tra_ondate = Config.num("ondate", "pausa_tra_ondate")
	_vita = Config.num("nemici", "vita_base")
	_vel_base = Config.num("nemici", "velocita_base")
	_vel_incremento = Config.num("nemici", "velocita_incremento_per_ondata")
	_vel_max = Config.num("nemici", "velocita_massima")
	_distanza = Config.num("nemici", "distanza_comparsa")
	_meta_pista = Config.num("pista", "larghezza") * 0.5


func aggiorna(delta: float) -> void:
	if _in_pausa:
		_pausa -= delta
		if _pausa <= 0.0:
			_inizia_ondata()
		return

	if _da_generare > 0:
		_timer_comparsa -= delta
		if _timer_comparsa <= 0.0:
			_genera_squadra()
	elif nemici.attivi == 0:
		_in_pausa = true
		_pausa = _pausa_tra_ondate


## Numero di nemici previsto per l'ondata n.
func nemici_per_ondata(n: int) -> int:
	return maxi(_nemici_base + _nemici_incremento * n, 1)


## Velocità di camminata dei nemici all'ondata n (con tetto massimo).
func velocita_per_ondata(n: int) -> float:
	return minf(_vel_base + _vel_incremento * n, _vel_max)


func _inizia_ondata() -> void:
	ondata += 1
	_in_pausa = false
	_da_generare = nemici_per_ondata(ondata)
	_intervallo = _durata_comparsa / _da_generare
	_velocita_ondata = velocita_per_ondata(ondata)
	_timer_comparsa = 0.0
	ondata_iniziata.emit(ondata)


func _genera_squadra() -> void:
	var quanti := mini(mini(randi_range(1, _max_squadra), _da_generare), nemici.posti_liberi())
	if quanti <= 0:
		_timer_comparsa = ATTESA_POOL_PIENO
		return
	var ingombro := (quanti - 1) * SPAZIO_SQUADRA
	var margine := _meta_pista - 0.5 - ingombro * 0.5
	var centro := randf_range(-margine, margine)
	for k in quanti:
		var x := centro - ingombro * 0.5 + k * SPAZIO_SQUADRA
		nemici.genera(x, -_distanza + randf_range(-0.6, 0.6), _vita, _velocita_ondata)
	_da_generare -= quanti
	# Il tempo fino alla prossima squadra è proporzionale ai nemici appena generati:
	# in media l'ondata dura sempre `durata_comparsa` secondi.
	_timer_comparsa += quanti * _intervallo
