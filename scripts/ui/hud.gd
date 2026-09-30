class_name Hud
extends CanvasLayer
## Interfaccia durante la partita: ondata in corso, contatore unità, arma e
## bonus temporanei, annuncio delle ondate ed esito dei cancelli.

const COLORE_POSITIVO := Color(0.45, 1.0, 0.5)
const COLORE_NEGATIVO := Color(1.0, 0.38, 0.32)

@onready var _ondata: Label = $Radice/Ondata
@onready var _unita: Label = $Radice/Unita
@onready var _arma: Label = $Radice/Arma
@onready var _bonus: Label = $Radice/Bonus
@onready var _esito: Label = $Radice/Esito
@onready var _annuncio: Label = $Radice/Annuncio

var _tween_annuncio: Tween
var _tween_esito: Tween


func _ready() -> void:
	_annuncio.modulate.a = 0.0
	_esito.modulate.a = 0.0


func aggiorna_unita(unita: int) -> void:
	_unita.text = "UNITÀ  %d" % unita


func aggiorna_arma(nome: String) -> void:
	_arma.text = nome


func aggiorna_bonus(descrizione: String) -> void:
	if _bonus.text != descrizione:
		_bonus.text = descrizione


func mostra_ondata(numero: int) -> void:
	_ondata.text = "ONDATA %d" % numero
	_annuncio.text = "ONDATA %d" % numero
	_tween_annuncio = _anima(_annuncio, _tween_annuncio, 0.9)


## Messaggio breve a centro schermo, verde se positivo e rosso se negativo.
func mostra_esito(testo: String, positivo: bool) -> void:
	_esito.text = testo
	_esito.add_theme_color_override("font_color", COLORE_POSITIVO if positivo else COLORE_NEGATIVO)
	_tween_esito = _anima(_esito, _tween_esito, 0.6)


## Comparsa con piccolo "zoom", pausa e dissolvenza.
func _anima(etichetta: Label, tween: Tween, pausa: float) -> Tween:
	if tween:
		tween.kill()
	etichetta.modulate.a = 0.0
	etichetta.pivot_offset = etichetta.size * 0.5
	etichetta.scale = Vector2(1.4, 1.4)
	var t := create_tween()
	t.tween_property(etichetta, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(etichetta, "scale", Vector2.ONE, 0.25)
	t.tween_interval(pausa)
	t.tween_property(etichetta, "modulate:a", 0.0, 0.4)
	return t
