class_name Potenziamenti
extends RefCounted
## Potenziamenti stile roguelite: dopo ogni boss se ne sceglie 1 tra 3,
## valgono fino alla fine della partita e si possono accumulare.

const CADENZA := "cadenza"
const DANNO := "danno"
const GITTATA := "gittata"
const RINFORZI := "rinforzi"
const AREA := "area"
const RESISTENZA := "resistenza"
const ELENCO := [CADENZA, DANNO, GITTATA, RINFORZI, AREA, RESISTENZA]

## Quante volte è stato scelto ogni potenziamento.
var livelli := {}

var _cadenza: float
var _danno: float
var _gittata: float
var _rinforzi: int
var _area_raggio: float
var _area_per_livello: float
var _area_frazione: float
var _resistenza: float
var _resistenza_max: float


func _init() -> void:
	_cadenza = Config.num("potenziamenti", "cadenza_bonus")
	_danno = Config.num("potenziamenti", "danno_bonus")
	_gittata = Config.num("potenziamenti", "gittata_bonus")
	_rinforzi = Config.intero("potenziamenti", "rinforzi_unita")
	_area_raggio = Config.num("potenziamenti", "area_raggio")
	_area_per_livello = Config.num("potenziamenti", "area_raggio_per_livello")
	_area_frazione = Config.num("potenziamenti", "area_frazione_danno")
	_resistenza = Config.num("potenziamenti", "resistenza_per_livello")
	_resistenza_max = Config.num("potenziamenti", "resistenza_massima")
	for id in ELENCO:
		livelli[id] = 0


## Tre potenziamenti diversi a caso (la resistenza solo finché non è al massimo).
func proponi(quanti: int = 3) -> Array:
	var candidati: Array = []
	for id in ELENCO:
		if id == RESISTENZA and resistenza_attuale() >= _resistenza_max:
			continue
		candidati.append(id)
	candidati.shuffle()
	return candidati.slice(0, mini(quanti, candidati.size()))


func titolo(id: String) -> String:
	match id:
		CADENZA: return "FUOCO PIÙ RAPIDO"
		DANNO: return "COLPI PIÙ POTENTI"
		GITTATA: return "TIRO LUNGO"
		RINFORZI: return "RINFORZI"
		AREA: return "COLPI ESPLOSIVI"
		RESISTENZA: return "SOLDATI CORAZZATI"
	return id


func descrizione(id: String) -> String:
	match id:
		CADENZA: return "+%d%% colpi al secondo" % roundi(_cadenza * 100)
		DANNO: return "+%d%% danno di ogni colpo" % roundi(_danno * 100)
		GITTATA: return "+%d%% distanza dei colpi" % roundi(_gittata * 100)
		RINFORZI: return "+%d unità subito" % _rinforzi
		AREA: return "Feriscono anche i vicini"
		RESISTENZA: return "+%d%% di sopravvivere ai colpi" % roundi(_resistenza * 100)
	return ""


func resistenza_attuale() -> float:
	return minf(livelli[RESISTENZA] * _resistenza, _resistenza_max)


## Applica il potenziamento scelto.
func applica(id: String, arsenale: Arsenale, folla: Folla, unita_massime: int) -> void:
	livelli[id] += 1
	match id:
		CADENZA:
			arsenale.molt_cadenza += _cadenza
		DANNO:
			arsenale.molt_danno += _danno
		GITTATA:
			arsenale.molt_gittata += _gittata
			arsenale.ricalcola_arma()
		RINFORZI:
			folla.imposta_unita(mini(folla.unita + _rinforzi, maxi(unita_massime, folla.unita)))
		AREA:
			arsenale.area_raggio = _area_raggio + _area_per_livello * (livelli[AREA] - 1)
			arsenale.area_frazione = _area_frazione
		RESISTENZA:
			folla.resistenza = resistenza_attuale()
