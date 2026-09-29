class_name Hud
extends CanvasLayer
## Interfaccia durante la partita: ondata in corso, contatore unità e
## annuncio a centro schermo all'inizio di ogni ondata.

@onready var _ondata: Label = $Radice/Ondata
@onready var _unita: Label = $Radice/Unita
@onready var _annuncio: Label = $Radice/Annuncio

var _tween: Tween


func _ready() -> void:
	_annuncio.modulate.a = 0.0


func aggiorna_unita(unita: int) -> void:
	_unita.text = "UNITÀ  %d" % unita


func mostra_ondata(numero: int) -> void:
	_ondata.text = "ONDATA %d" % numero
	_annuncio.text = "ONDATA %d" % numero
	if _tween:
		_tween.kill()
	_annuncio.modulate.a = 0.0
	_annuncio.pivot_offset = _annuncio.size * 0.5
	_annuncio.scale = Vector2(1.4, 1.4)
	_tween = create_tween()
	_tween.tween_property(_annuncio, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_annuncio, "scale", Vector2.ONE, 0.25)
	_tween.tween_interval(0.9)
	_tween.tween_property(_annuncio, "modulate:a", 0.0, 0.4)
