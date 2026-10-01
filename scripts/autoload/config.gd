extends Node
## Autoload "Config": legge i parametri di bilanciamento dal file unico
## res://config/bilanciamento.cfg e li mette a disposizione di tutto il gioco.
##
## Uso: Config.num("nemici", "vita_base")  oppure  Config.intero("folla", "visual_unit_cap")

const PERCORSO := "res://config/bilanciamento.cfg"

var _cfg := ConfigFile.new()


func _init() -> void:
	# Caricato in _init (e non in _ready) così i valori sono pronti
	# prima che qualunque altra scena li chieda.
	var errore := _cfg.load(PERCORSO)
	if errore != OK:
		push_error("Impossibile leggere %s (errore %d)" % [PERCORSO, errore])


## Restituisce il valore grezzo di un parametro. Se manca lo segnala e restituisce 0.
func valore(sezione: String, chiave: String) -> Variant:
	if not _cfg.has_section_key(sezione, chiave):
		push_error("Parametro mancante in %s: [%s] %s" % [PERCORSO, sezione, chiave])
		return 0
	return _cfg.get_value(sezione, chiave)


## Parametro numerico decimale.
func num(sezione: String, chiave: String) -> float:
	return float(valore(sezione, chiave))


## Parametro numerico intero.
func intero(sezione: String, chiave: String) -> int:
	return int(valore(sezione, chiave))
