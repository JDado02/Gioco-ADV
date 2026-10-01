class_name SchermataPausa
extends CanvasLayer
## Pausa: riprendi la partita oppure torna al menu (la partita è persa).

signal riprendi
signal menu

@onready var _riprendi: Button = $Sfondo/Centro/Riquadro/Riprendi
@onready var _menu: Button = $Sfondo/Centro/Riquadro/Menu


func _ready() -> void:
	visible = false
	_riprendi.pressed.connect(func() -> void: riprendi.emit())
	_menu.pressed.connect(func() -> void: menu.emit())
