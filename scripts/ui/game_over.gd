class_name SchermataGameOver
extends CanvasLayer
## Schermata di fine partita (versione base della Fase 1).
## Il record personale e la schermata completa arriveranno in Fase 5.

signal riprova

@onready var _ondata: Label = $Sfondo/Centro/Riquadro/Ondata
@onready var _unita_max: Label = $Sfondo/Centro/Riquadro/UnitaMassime
@onready var _pulsante: Button = $Sfondo/Centro/Riquadro/Riprova


func _ready() -> void:
	visible = false
	_pulsante.pressed.connect(func() -> void: riprova.emit())


func mostra(ondata: int, unita_massime: int) -> void:
	_ondata.text = "Ondata raggiunta: %d" % ondata
	_unita_max.text = "Unità massime: %d" % unita_massime
	visible = true
