extends Node
## Autoload "Suoni": effetti sonori generati via codice all'avvio.
##
## Nessun file audio esterno: ogni suono è sintetizzato (rumore, toni e
## inviluppi) in un AudioStreamWAV. I suoni frequenti (spari, colpi) hanno un
## intervallo minimo, per non saturare l'audio quando sparano 200 soldati.
##
## Uso: Suoni.suona("sparo")

const FREQUENZA := 22050
const NUM_CANALI := 10

## nome -> [AudioStreamWAV, volume_db, intervallo_minimo_secondi]
var _suoni := {}
var _ultimo := {}
var _canali: Array[AudioStreamPlayer] = []
var _prossimo := 0


func _ready() -> void:
	for i in NUM_CANALI:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_canali.append(p)
	_suoni["sparo"] = [_sparo(), -16.0, 0.07]
	_suoni["razzo"] = [_razzo(), -12.0, 0.12]
	_suoni["colpo"] = [_colpo(), -20.0, 0.05]
	_suoni["morte"] = [_morte(), -14.0, 0.06]
	_suoni["esplosione"] = [_esplosione(0.5), -6.0, 0.08]
	_suoni["esplosione_grande"] = [_esplosione(1.1), -2.0, 0.3]
	_suoni["perdita"] = [_perdita(), -8.0, 0.15]
	_suoni["cancello_buono"] = [_arpeggio([523.0, 659.0, 784.0], 0.07), -8.0, 0.1]
	_suoni["cancello_cattivo"] = [_arpeggio([392.0, 311.0, 233.0], 0.09, true), -8.0, 0.1]
	_suoni["bonus"] = [_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.06), -6.0, 0.1]
	_suoni["avviso_boss"] = [_sirena(), -6.0, 1.0]
	_suoni["vittoria"] = [_arpeggio([392.0, 523.0, 659.0, 784.0, 1047.0], 0.1), -4.0, 0.5]
	_suoni["sconfitta"] = [_arpeggio([392.0, 330.0, 262.0, 196.0], 0.18, true), -4.0, 0.5]
	_suoni["clic"] = [_arpeggio([880.0], 0.04), -12.0, 0.05]


## Suona un effetto (se l'audio è attivo e se non è stato suonato da troppo poco).
func suona(nome: String) -> void:
	if not Dati.audio_attivo or not _suoni.has(nome):
		return
	var adesso := Time.get_ticks_msec() / 1000.0
	var dati: Array = _suoni[nome]
	if adesso - float(_ultimo.get(nome, -10.0)) < dati[2]:
		return
	_ultimo[nome] = adesso
	var p := _canali[_prossimo]
	_prossimo = (_prossimo + 1) % NUM_CANALI
	p.stream = dati[0]
	p.volume_db = dati[1]
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


# --- Sintesi -----------------------------------------------------------------

func _crea(campioni: PackedFloat32Array) -> AudioStreamWAV:
	var dati := PackedByteArray()
	dati.resize(campioni.size() * 2)
	for i in campioni.size():
		dati.encode_s16(i * 2, int(clampf(campioni[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FREQUENZA
	wav.stereo = false
	wav.data = dati
	return wav


func _buffer(durata: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(durata * FREQUENZA))
	return b


## Colpo secco di fucile: rumore con decadimento rapido.
func _sparo() -> AudioStreamWAV:
	var b := _buffer(0.09)
	var filtro := 0.0
	for i in b.size():
		var t := float(i) / FREQUENZA
		filtro = lerpf(filtro, randf_range(-1.0, 1.0), 0.45)
		b[i] = filtro * exp(-t * 55.0) * 0.9
	return _crea(b)


## Razzo: soffio che si alza di tono.
func _razzo() -> AudioStreamWAV:
	var b := _buffer(0.25)
	var filtro := 0.0
	for i in b.size():
		var t := float(i) / FREQUENZA
		filtro = lerpf(filtro, randf_range(-1.0, 1.0), 0.15 + t)
		b[i] = filtro * (1.0 - t / 0.25) * 0.8
	return _crea(b)


## Colpo a segno: piccolo "tic".
func _colpo() -> AudioStreamWAV:
	var b := _buffer(0.04)
	for i in b.size():
		var t := float(i) / FREQUENZA
		b[i] = sin(TAU * 1800.0 * t) * exp(-t * 120.0) * 0.6
	return _crea(b)


## Nemico abbattuto: "pop" che scende di tono.
func _morte() -> AudioStreamWAV:
	var b := _buffer(0.12)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / FREQUENZA
		fase += TAU * lerpf(520.0, 160.0, t / 0.12) / FREQUENZA
		b[i] = sin(fase) * exp(-t * 30.0) * 0.7
	return _crea(b)


## Esplosione: rumore basso e rimbombante.
func _esplosione(durata: float) -> AudioStreamWAV:
	var b := _buffer(durata)
	var filtro := 0.0
	for i in b.size():
		var t := float(i) / FREQUENZA
		filtro = lerpf(filtro, randf_range(-1.0, 1.0), 0.08)
		var rimbombo := sin(TAU * 55.0 * t) * 0.4
		b[i] = (filtro * 2.2 + rimbombo) * exp(-t * 4.5 / durata)
	return _crea(b)


## Unità perse: tonfo cupo.
func _perdita() -> AudioStreamWAV:
	var b := _buffer(0.2)
	for i in b.size():
		var t := float(i) / FREQUENZA
		b[i] = (sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 73.0 * t)) * exp(-t * 18.0) * 0.8
	return _crea(b)


## Sequenza di note (onda quadra morbida). Se `scende` le note sono più cupe.
func _arpeggio(note: Array, durata_nota: float, scende: bool = false) -> AudioStreamWAV:
	var b := _buffer(durata_nota * note.size() + 0.05)
	for i in b.size():
		var t := float(i) / FREQUENZA
		var n := mini(int(t / durata_nota), note.size() - 1)
		var t_nota := t - n * durata_nota
		var f: float = note[n]
		var onda := signf(sin(TAU * f * t)) * 0.35 + sin(TAU * f * t) * 0.4
		var inviluppo := exp(-t_nota * (14.0 if scende else 9.0))
		b[i] = onda * inviluppo * 0.7
	return _crea(b)


## Sirena del boss: due toni alternati.
func _sirena() -> AudioStreamWAV:
	var b := _buffer(1.2)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / FREQUENZA
		var f := 620.0 if int(t * 5.0) % 2 == 0 else 440.0
		fase += TAU * f / FREQUENZA
		b[i] = signf(sin(fase)) * 0.3 * minf(1.0, (1.2 - t) * 4.0)
	return _crea(b)
