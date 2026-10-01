class_name SchermataGameOver
extends CanvasLayer
## Schermata di fine partita: ondata raggiunta, record (con "NUOVO RECORD!"),
## unità massime, boss sconfitti, "Riprova" e "Menu".

signal riprova
signal menu

@onready var _nuovo_record: Label = $Sfondo/Centro/Riquadro/NuovoRecord
@onready var _ondata: Label = $Sfondo/Centro/Riquadro/Ondata
@onready var _record: Label = $Sfondo/Centro/Riquadro/Record
@onready var _unita_max: Label = $Sfondo/Centro/Riquadro/UnitaMassime
@onready var _boss: Label = $Sfondo/Centro/Riquadro/Boss
@onready var _riprova: Button = $Sfondo/Centro/Riquadro/Riprova
@onready var _menu: Button = $Sfondo/Centro/Riquadro/Menu


func _ready() -> void:
	visible = false
	_riprova.pressed.connect(func() -> void: riprova.emit())
	_menu.pressed.connect(func() -> void: menu.emit())


func mostra(ondata: int, record: int, nuovo_record: bool, unita_massime: int, boss_sconfitti: int) -> void:
	_ondata.text = "Ondata raggiunta: %d" % ondata
	_record.text = "Record: ondata %d" % record
	_nuovo_record.visible = nuovo_record
	_unita_max.text = "Unità massime: %d" % unita_massime
	_boss.text = "Boss sconfitti: %d" % boss_sconfitti
	visible = true
	if nuovo_record:
		var t := create_tween().set_loops(4)
		t.tween_property(_nuovo_record, "modulate:a", 0.3, 0.3)
		t.tween_property(_nuovo_record, "modulate:a", 1.0, 0.3)
