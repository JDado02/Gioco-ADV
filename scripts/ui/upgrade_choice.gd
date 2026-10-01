class_name SceltaPotenziamento
extends CanvasLayer
## Schermata "scegli 1 potenziamento su 3" mostrata dopo ogni boss sconfitto.
## Il gioco resta fermo finché non si tocca una carta.

signal scelto(id: String)

var _ids: Array = []

@onready var _pulsanti: Array[Button] = [
	$Sfondo/Centro/Riquadro/Carta1,
	$Sfondo/Centro/Riquadro/Carta2,
	$Sfondo/Centro/Riquadro/Carta3,
]


func _ready() -> void:
	visible = false
	for i in _pulsanti.size():
		_pulsanti[i].pressed.connect(_premuto.bind(i))


func mostra(ids: Array, potenziamenti: Potenziamenti) -> void:
	_ids = ids
	for i in _pulsanti.size():
		var b := _pulsanti[i]
		b.visible = i < ids.size()
		if b.visible:
			b.text = "%s\n%s" % [potenziamenti.titolo(ids[i]), potenziamenti.descrizione(ids[i])]
	visible = true


func _premuto(indice: int) -> void:
	if not visible or indice >= _ids.size():
		return
	visible = false
	scelto.emit(_ids[indice])
