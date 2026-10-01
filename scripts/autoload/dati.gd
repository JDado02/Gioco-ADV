extends Node
## Autoload "Dati": record personale e impostazioni salvati sul telefono.
##
## Si salva solo il record (ondata più alta raggiunta) e l'audio acceso/spento:
## nessun potenziamento permanente tra una partita e l'altra.

const PERCORSO := "user://salvataggio.cfg"

## Ondata più alta mai raggiunta.
var record := 0
var audio_attivo := true
## Se true la prossima partita parte subito, senza passare dal menu ("Riprova").
var avvio_diretto := false


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PERCORSO) == OK:
		record = int(cfg.get_value("record", "ondata", 0))
		audio_attivo = bool(cfg.get_value("impostazioni", "audio", true))


## Registra il risultato di una partita. Restituisce true se è un nuovo record.
func registra_partita(ondata: int) -> bool:
	if ondata <= record:
		return false
	record = ondata
	salva()
	return true


func imposta_audio(attivo: bool) -> void:
	audio_attivo = attivo
	AudioServer.set_bus_mute(0, not attivo)
	salva()


func salva() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("record", "ondata", record)
	cfg.set_value("impostazioni", "audio", audio_attivo)
	var errore := cfg.save(PERCORSO)
	if errore != OK:
		push_error("Impossibile salvare %s (errore %d)" % [PERCORSO, errore])


func _ready() -> void:
	AudioServer.set_bus_mute(0, not audio_attivo)
