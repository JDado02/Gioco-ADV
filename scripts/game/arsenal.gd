class_name Arsenale
extends Node
## Arma della folla e bonus temporanei.
##
## Le armi si sbloccano in ordine ([armi] sequenza nel file di bilanciamento)
## e restano per tutta la partita. I bonus temporanei moltiplicano cadenza o
## danno per qualche secondo.

signal arma_cambiata(arma: Dictionary)

## Tipi di ricompensa degli ostacoli bonus.
const RICOMPENSA_ARMA := "arma"
const FUOCO_RAPIDO := "fuoco_rapido"
const COLPI_POTENZIATI := "colpi_potenziati"

const NOMI_BONUS := {
	FUOCO_RAPIDO: "FUOCO RAPIDO",
	COLPI_POTENZIATI: "COLPI POTENZIATI",
}

## Livello dell'arma attuale (0 = prima arma della sequenza).
var livello := 0

## Potenziamenti permanenti (scelti dopo i boss sconfitti).
var molt_cadenza := 1.0
var molt_danno := 1.0
var molt_gittata := 1.0
## Danno ad area aggiuntivo dei colpi normali (raggio 0 = nessuno).
var area_raggio := 0.0
var area_frazione := 0.0

var _armi: Array[Dictionary] = []
var _arma_effettiva: Dictionary
var _molt_rapido: float
var _durata_rapido: float
var _molt_potenziati: float
var _durata_potenziati: float
var _timer_rapido := 0.0
var _timer_potenziati := 0.0


func _ready() -> void:
	for id in Config.valore("armi", "sequenza"):
		_armi.append(_leggi_arma(str(id)))
	if _armi.is_empty():
		push_error("[armi] sequenza è vuota: uso un fucile di riserva")
		_armi.append({"nome": "FUCILE", "colpi_al_secondo": 1.5, "danno_per_colpo": 1.0,
			"velocita_proiettile": 38.0, "gittata": 28.0, "raggio_proiettile": 0.15,
			"raggio_esplosione": 0.0, "dimensione": 1.0, "colore": Color(1, 0.86, 0.35)})
	_molt_rapido = Config.num("bonus_temporanei", "fuoco_rapido_moltiplicatore")
	_durata_rapido = Config.num("bonus_temporanei", "fuoco_rapido_durata")
	_molt_potenziati = Config.num("bonus_temporanei", "colpi_potenziati_moltiplicatore")
	_durata_potenziati = Config.num("bonus_temporanei", "colpi_potenziati_durata")
	ricalcola_arma()


func aggiorna(delta: float) -> void:
	_timer_rapido = maxf(_timer_rapido - delta, 0.0)
	_timer_potenziati = maxf(_timer_potenziati - delta, 0.0)


## L'arma attuale, con i potenziamenti permanenti già applicati.
func arma() -> Dictionary:
	return _arma_effettiva


## Da chiamare dopo aver cambiato arma o potenziamenti che la modificano.
func ricalcola_arma() -> void:
	_arma_effettiva = _armi[livello].duplicate()
	_arma_effettiva.gittata *= molt_gittata


func al_massimo() -> bool:
	return livello >= _armi.size() - 1


## Nome dell'arma che si otterrebbe salendo di livello.
func nome_prossima_arma() -> String:
	return _armi[mini(livello + 1, _armi.size() - 1)].nome


## Colpi al secondo di ogni unità, compresi i bonus temporanei.
func cadenza() -> float:
	var c: float = arma().colpi_al_secondo * molt_cadenza
	if _timer_rapido > 0.0:
		c *= _molt_rapido
	return maxf(c, 0.01)


## Danno di un colpo di una singola unità, compresi i bonus temporanei.
func danno() -> float:
	var d: float = arma().danno_per_colpo * molt_danno
	if _timer_potenziati > 0.0:
		d *= _molt_potenziati
	return d


## Applica una ricompensa di un ostacolo bonus. Restituisce il testo da mostrare.
func ottieni(ricompensa: String) -> String:
	match ricompensa:
		RICOMPENSA_ARMA:
			if not al_massimo():
				livello += 1
				ricalcola_arma()
				arma_cambiata.emit(arma())
			return arma().nome
		FUOCO_RAPIDO:
			_timer_rapido = _durata_rapido
		COLPI_POTENZIATI:
			_timer_potenziati = _durata_potenziati
	return NOMI_BONUS.get(ricompensa, ricompensa)


## Descrizione dei bonus temporanei attivi, es. "FUOCO RAPIDO 5s" (vuota se nessuno).
func descrizione_bonus() -> String:
	var parti: PackedStringArray = []
	if _timer_rapido > 0.0:
		parti.append("%s %ds" % [NOMI_BONUS[FUOCO_RAPIDO], ceili(_timer_rapido)])
	if _timer_potenziati > 0.0:
		parti.append("%s %ds" % [NOMI_BONUS[COLPI_POTENZIATI], ceili(_timer_potenziati)])
	return "  ·  ".join(parti)


func _leggi_arma(id: String) -> Dictionary:
	var sezione := "arma_" + id
	return {
		"nome": str(Config.valore(sezione, "nome")),
		"colpi_al_secondo": Config.num(sezione, "colpi_al_secondo"),
		"danno_per_colpo": Config.num(sezione, "danno_per_colpo"),
		"velocita_proiettile": Config.num(sezione, "velocita_proiettile"),
		"gittata": Config.num(sezione, "gittata"),
		"raggio_proiettile": Config.num(sezione, "raggio_proiettile"),
		"raggio_esplosione": Config.num(sezione, "raggio_esplosione"),
		"dimensione": Config.num(sezione, "dimensione"),
		"colore": Config.valore(sezione, "colore"),
	}
