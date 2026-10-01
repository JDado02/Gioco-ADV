class_name MenuPrincipale
extends CanvasLayer
## Menu iniziale: titolo, record personale, pulsante "GIOCA" e audio on/off.
## Il ponte resta visibile dietro, con il mare e le braci che si muovono.

signal gioca

@onready var _record: Label = $Radice/Colonna/Record
@onready var _gioca: Button = $Radice/Colonna/Gioca
@onready var _audio: Button = $Radice/Colonna/Audio


func _ready() -> void:
	_gioca.pressed.connect(func() -> void: gioca.emit())
	_audio.pressed.connect(_cambia_audio)
	aggiorna()


func aggiorna() -> void:
	_record.text = "RECORD: ONDATA %d" % Dati.record if Dati.record > 0 else "Nessun record: fai la prima partita!"
	_audio.text = "AUDIO: SÌ" if Dati.audio_attivo else "AUDIO: NO"


func _cambia_audio() -> void:
	Dati.imposta_audio(not Dati.audio_attivo)
	aggiorna()
