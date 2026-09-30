class_name RegoleCancelli
extends RefCounted
## Regole dei cancelli: come si generano le coppie e che effetto hanno.
##
## È pura logica (nessun nodo, nessuna grafica), così si può provare da sola.
## Ogni cancello è un Array di due elementi: [operazione, valore].

enum Op { SOMMA, SOTTRAI, MOLTIPLICA, DIVIDI }

var unita_minime_dopo_malus: int
var unita_massime: int

var _malus_base: float
var _malus_incremento: float
var _malus_massima: float
var _p_ingannevole: float
var _peso_moltiplica: float
var _somma_min: int
var _somma_max: int
var _somma_crescita: float
var _moltiplica_min: int
var _moltiplica_max: int
var _peso_dividi: float
var _sottrai_min: int
var _sottrai_max: int
var _sottrai_crescita: float
var _dividi_min: int
var _dividi_max: int
var _ondata_minima_doppio_malus: int
var _ultima_doppio_malus := false


func _init() -> void:
	unita_minime_dopo_malus = Config.intero("cancelli", "unita_minime_dopo_malus")
	unita_massime = Config.intero("cancelli", "unita_massime")
	_malus_base = Config.num("cancelli", "malus_probabilita_base")
	_malus_incremento = Config.num("cancelli", "malus_incremento_per_ondata")
	_malus_massima = Config.num("cancelli", "malus_probabilita_massima")
	_p_ingannevole = Config.num("cancelli", "probabilita_coppia_ingannevole")
	_peso_moltiplica = Config.num("cancelli", "peso_moltiplica")
	_somma_min = Config.intero("cancelli", "somma_min")
	_somma_max = Config.intero("cancelli", "somma_max")
	_somma_crescita = Config.num("cancelli", "somma_crescita_per_ondata")
	_moltiplica_min = maxi(Config.intero("cancelli", "moltiplica_min"), 2)
	_moltiplica_max = maxi(Config.intero("cancelli", "moltiplica_max"), _moltiplica_min)
	_peso_dividi = Config.num("cancelli", "peso_dividi")
	_sottrai_min = Config.intero("cancelli", "sottrai_min")
	_sottrai_max = Config.intero("cancelli", "sottrai_max")
	_sottrai_crescita = Config.num("cancelli", "sottrai_crescita_per_ondata")
	_dividi_min = maxi(Config.intero("cancelli", "dividi_min"), 2)
	_dividi_max = maxi(Config.intero("cancelli", "dividi_max"), _dividi_min)
	_ondata_minima_doppio_malus = Config.intero("cancelli", "ondata_minima_coppie_malus")


## Probabilità che il secondo cancello di una coppia sia un malus, all'ondata data.
func probabilita_malus(ondata: int) -> float:
	return minf(_malus_base + _malus_incremento * ondata, _malus_massima)


## Genera una coppia di cancelli [sinistro, destro] per l'ondata e le unità attuali.
func genera_coppia(ondata: int, unita: int) -> Array:
	var malus := randf() < probabilita_malus(ondata)
	var coppia: Array
	if randf() < _p_ingannevole:
		# Una coppia con due malus ("il male minore") non arriva nelle prime
		# ondate e mai due volte di fila: nessuna sfortuna deve essere senza rimedio.
		var doppio_malus := malus and ondata >= _ondata_minima_doppio_malus \
				and not _ultima_doppio_malus
		coppia = _coppia_ingannevole(maxi(unita, 1), doppio_malus)
		_ultima_doppio_malus = doppio_malus
	else:
		coppia = [_cancello(ondata, false), _cancello(ondata, malus)]
		_ultima_doppio_malus = false
	if randf() < 0.5:
		coppia.reverse()
	return coppia


## Unità dopo aver attraversato un cancello (con minimo per i malus e tetto massimo).
func applica(cancello: Array, unita: int) -> int:
	var op: int = cancello[0]
	var valore: int = cancello[1]
	var risultato := unita
	match op:
		Op.SOMMA:
			risultato = unita + valore
		Op.SOTTRAI:
			risultato = unita - valore
		Op.MOLTIPLICA:
			risultato = unita * valore
		Op.DIVIDI:
			risultato = unita / valore  # divisione intera: arrotonda per difetto
	if e_malus(cancello):
		risultato = maxi(risultato, mini(unita_minime_dopo_malus, unita))
	return clampi(risultato, 0, maxi(unita_massime, unita))


static func e_malus(cancello: Array) -> bool:
	return cancello[0] == Op.SOTTRAI or cancello[0] == Op.DIVIDI


## Testo da scrivere sul cancello, es. "+5", "-3", "×2", "÷2".
static func testo(cancello: Array) -> String:
	var simbolo: String = ["+", "-", "×", "÷"][cancello[0]]
	return "%s%d" % [simbolo, cancello[1]]


func _cancello(ondata: int, malus: bool) -> Array:
	if malus:
		if randf() < _peso_dividi:
			return [Op.DIVIDI, randi_range(_dividi_min, _dividi_max)]
		return [Op.SOTTRAI, randi_range(_sottrai_min, _sottrai_max) + int(_sottrai_crescita * ondata)]
	if randf() < _peso_moltiplica:
		return [Op.MOLTIPLICA, randi_range(_moltiplica_min, _moltiplica_max)]
	return [Op.SOMMA, randi_range(_somma_min, _somma_max) + int(_somma_crescita * ondata)]


## Coppia che richiede di fare il conto: due risultati vicini ma diversi.
## Bonus: ×N contro +M. Malus: ÷N contro -M ("il male minore").
func _coppia_ingannevole(unita: int, malus: bool) -> Array:
	var scarto := randi_range(1, maxi(2, unita / 4))
	if randf() < 0.5:
		scarto = -scarto
	if malus:
		var d := randi_range(_dividi_min, _dividi_max)
		var persi := unita - unita / d
		return [[Op.DIVIDI, d], [Op.SOTTRAI, maxi(persi + scarto, 1)]]
	var m := randi_range(_moltiplica_min, _moltiplica_max)
	var guadagno := unita * m - unita
	return [[Op.MOLTIPLICA, m], [Op.SOMMA, maxi(guadagno + scarto, 1)]]
