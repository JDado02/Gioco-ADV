class_name GestoreCancelli
extends Node3D
## Cancelli a coppie e ostacoli bonus da distruggere.
##
## A intervalli regolari arriva un "evento" sulla pista:
## - una COPPIA di cancelli che occupa tutta la larghezza: la folla passa da
##   quello dal lato in cui si trova (sinistra o destra);
## - oppure un OSTACOLO BONUS con i punti vita scritti sopra: se la folla lo
##   abbatte sparando prima che la superi, ottiene la ricompensa indicata.
##
## I nodi grafici sono creati tutti all'avvio (pool) e riusati.

signal cancello_attraversato(cancello: Array)
signal ostacolo_distrutto(ricompensa: String, posizione: Vector3)

const MAX_COPPIE := 4
const MAX_OSTACOLI := 3
const ALTEZZA_CANCELLO := 2.4
const SPESSORE_CANCELLO := 0.12
## Spazio vuoto tra i due cancelli di una coppia.
const SPAZIO_CENTRALE := 0.3
const ALTEZZA_OSTACOLO := 1.5
const PROFONDITA_OSTACOLO := 0.9
## Oltre questa distanza dietro la folla un oggetto sparisce.
const Z_USCITA := 10.0
const VITA_MINIMA := 0.001

const COLORE_BONUS := Color(0.2, 0.62, 1.0)
const COLORE_MALUS := Color(1.0, 0.27, 0.22)
const COLORE_OSTACOLO := Color(0.96, 0.66, 0.16)
const COLORE_PREMIO_ARMA := Color(0.55, 1.0, 0.95)
const COLORE_PREMIO_TEMPORANEO := Color(1.0, 0.92, 0.35)


## Una coppia di cancelli (indice 0 = sinistra, 1 = destra).
class Coppia:
	var nodo: Node3D
	var pannelli: Array[MeshInstance3D] = []
	var cornici: Array[MeshInstance3D] = []
	var testi: Array[Label3D] = []
	var cancelli: Array = []
	var attiva := false
	var passata := false


class Ostacolo:
	var nodo: Node3D
	var testo_vita: Label3D
	var testo_premio: Label3D
	var attivo := false
	var vita := 0.0
	var vita_mostrata := -1
	var ricompensa := ""


@export var arsenale: Arsenale

var regole: RegoleCancelli

var _meta_pista: float
var _distanza: float
var _intervallo: float
var _p_ostacolo: float
var _vita_base: float
var _vita_incremento: float
var _meta_larghezza_ostacolo: float
var _p_bonus_temporaneo: float
var _timer: float

var _coppie: Array[Coppia] = []
var _ostacoli: Array[Ostacolo] = []
var _mat_pannello := {}
var _mat_cornice := {}


func _ready() -> void:
	regole = RegoleCancelli.new()
	_meta_pista = Config.num("pista", "larghezza") * 0.5
	_distanza = Config.num("nemici", "distanza_comparsa")
	_intervallo = maxf(Config.num("cancelli", "intervallo"), 1.0)
	_timer = Config.num("cancelli", "ritardo_iniziale")
	_p_ostacolo = Config.num("cancelli", "probabilita_ostacolo_bonus")
	_vita_base = Config.num("ostacoli_bonus", "vita_base")
	_vita_incremento = Config.num("ostacoli_bonus", "vita_incremento_per_ondata")
	_meta_larghezza_ostacolo = Config.num("ostacoli_bonus", "larghezza") * 0.5
	_p_bonus_temporaneo = Config.num("ostacoli_bonus", "probabilita_bonus_temporaneo")

	for malus in [false, true]:
		var colore: Color = COLORE_MALUS if malus else COLORE_BONUS
		_mat_pannello[malus] = _materiale(Color(colore, 0.42), true)
		_mat_cornice[malus] = _materiale(colore, false)
	for i in MAX_COPPIE:
		_coppie.append(_crea_coppia())
	for i in MAX_OSTACOLI:
		_ostacoli.append(_crea_ostacolo())
	arsenale.arma_cambiata.connect(func(_arma: Dictionary) -> void: _aggiorna_premi())


func aggiorna(delta: float, velocita_pista: float, folla_x: float, unita: int, ondata: int) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer += _intervallo
		if randf() < _p_ostacolo:
			_genera_ostacolo(ondata)
		else:
			_genera_coppia(ondata, unita)

	var passo := velocita_pista * delta
	for c in _coppie:
		if not c.attiva:
			continue
		c.nodo.position.z += passo
		if not c.passata and c.nodo.position.z >= 0.0:
			# La folla passa dal cancello del lato in cui si trova il suo centro.
			c.passata = true
			var lato := 0 if folla_x < 0.0 else 1
			c.pannelli[lato].visible = false
			cancello_attraversato.emit(c.cancelli[lato])
		if c.nodo.position.z > Z_USCITA:
			c.attiva = false
			c.nodo.visible = false

	for o in _ostacoli:
		if not o.attivo:
			continue
		o.nodo.position.z += passo
		var vita_intera := ceili(o.vita)
		if vita_intera != o.vita_mostrata:
			o.vita_mostrata = vita_intera
			o.testo_vita.text = str(vita_intera)
		if o.nodo.position.z > Z_USCITA:
			o.attivo = false
			o.nodo.visible = false


## La prossima coppia che la folla deve ancora attraversare (vuoto se nessuna).
## Restituisce {"z": distanza, "cancelli": [sinistro, destro]}.
func prossima_coppia() -> Dictionary:
	var migliore := {}
	for c in _coppie:
		if c.attiva and not c.passata:
			if migliore.is_empty() or c.nodo.position.z > migliore.z:
				migliore = {"z": c.nodo.position.z, "cancelli": c.cancelli}
	return migliore


## Applica il danno di un proiettile che passa da z_a a z_da lungo la linea x.
## Restituisce il danno avanzato (0 = esaurito).
func colpisci(x: float, z_da: float, z_a: float, raggio_proiettile: float, danno: float) -> float:
	for o in _ostacoli:
		if not _colpito(o, x, z_da, z_a, raggio_proiettile):
			continue
		var inflitto := minf(danno, o.vita)
		o.vita -= inflitto
		danno -= inflitto
		if o.vita <= VITA_MINIMA:
			_distruggi(o)
		if danno <= VITA_MINIMA:
			return 0.0
	return danno


func tocca(x: float, z_da: float, z_a: float, raggio_proiettile: float) -> bool:
	for o in _ostacoli:
		if _colpito(o, x, z_da, z_a, raggio_proiettile):
			return true
	return false


## Danno ad area (esplosioni) sugli ostacoli entro il raggio.
func danno_area(x: float, z: float, raggio: float, danno: float) -> void:
	for o in _ostacoli:
		if not o.attivo or o.vita <= VITA_MINIMA:
			continue
		var dx := maxf(absf(x - o.nodo.position.x) - _meta_larghezza_ostacolo, 0.0)
		var dz := maxf(absf(z - o.nodo.position.z) - PROFONDITA_OSTACOLO * 0.5, 0.0)
		if dx * dx + dz * dz <= raggio * raggio:
			o.vita -= minf(danno, o.vita)
			if o.vita <= VITA_MINIMA:
				_distruggi(o)


# --- Generazione -------------------------------------------------------------

func _genera_coppia(ondata: int, unita: int) -> void:
	for c in _coppie:
		if c.attiva:
			continue
		c.cancelli = regole.genera_coppia(ondata, unita)
		for lato in 2:
			var malus := RegoleCancelli.e_malus(c.cancelli[lato])
			c.pannelli[lato].material_override = _mat_pannello[malus]
			c.pannelli[lato].visible = true
			for cornice in c.cornici.slice(lato * 3, lato * 3 + 3):
				cornice.material_override = _mat_cornice[malus]
			c.testi[lato].text = RegoleCancelli.testo(c.cancelli[lato])
		c.nodo.position = Vector3(0, 0, -_distanza)
		c.nodo.visible = true
		c.attiva = true
		c.passata = false
		return


func _genera_ostacolo(ondata: int) -> void:
	for o in _ostacoli:
		if o.attivo:
			continue
		var margine := _meta_pista - _meta_larghezza_ostacolo - 0.2
		o.nodo.position = Vector3(randf_range(-margine, margine), 0, -_distanza)
		o.vita = _vita_base + _vita_incremento * ondata
		o.vita_mostrata = -1
		if arsenale.al_massimo() or randf() < _p_bonus_temporaneo:
			o.ricompensa = [Arsenale.FUOCO_RAPIDO, Arsenale.COLPI_POTENZIATI].pick_random()
		else:
			o.ricompensa = Arsenale.RICOMPENSA_ARMA
		_aggiorna_premio(o)
		o.nodo.visible = true
		o.attivo = true
		return


## Dopo un cambio d'arma, gli ostacoli già in pista mostrano il premio aggiornato.
func _aggiorna_premi() -> void:
	for o in _ostacoli:
		if o.attivo and o.ricompensa == Arsenale.RICOMPENSA_ARMA and arsenale.al_massimo():
			o.ricompensa = [Arsenale.FUOCO_RAPIDO, Arsenale.COLPI_POTENZIATI].pick_random()
		_aggiorna_premio(o)


func _aggiorna_premio(o: Ostacolo) -> void:
	if o.ricompensa == Arsenale.RICOMPENSA_ARMA:
		o.testo_premio.text = arsenale.nome_prossima_arma()
		o.testo_premio.modulate = COLORE_PREMIO_ARMA
	else:
		o.testo_premio.text = Arsenale.NOMI_BONUS.get(o.ricompensa, o.ricompensa)
		o.testo_premio.modulate = COLORE_PREMIO_TEMPORANEO


func _colpito(o: Ostacolo, x: float, z_da: float, z_a: float, r: float) -> bool:
	if not o.attivo or o.vita <= VITA_MINIMA:
		return false
	var oz := o.nodo.position.z
	var meta_profondita := PROFONDITA_OSTACOLO * 0.5
	return z_da <= oz + meta_profondita and z_a >= oz - meta_profondita \
			and absf(x - o.nodo.position.x) <= _meta_larghezza_ostacolo + r


func _distruggi(o: Ostacolo) -> void:
	o.vita = 0.0
	o.attivo = false
	o.nodo.visible = false
	ostacolo_distrutto.emit(o.ricompensa, o.nodo.position + Vector3(0, ALTEZZA_OSTACOLO * 0.5, 0))


# --- Costruzione della grafica (una volta sola, all'avvio) ------------------

func _crea_coppia() -> Coppia:
	var c := Coppia.new()
	c.nodo = Node3D.new()
	c.nodo.name = "Coppia"
	c.nodo.visible = false
	add_child(c.nodo)
	var larghezza := _meta_pista - SPAZIO_CENTRALE
	for lato in 2:
		var cx := (larghezza * 0.5 + SPAZIO_CENTRALE * 0.5) * (-1.0 if lato == 0 else 1.0)
		c.pannelli.append(_blocco(c.nodo, Vector3(larghezza, ALTEZZA_CANCELLO, SPESSORE_CANCELLO),
				Vector3(cx, ALTEZZA_CANCELLO * 0.5, 0)))
		# Cornice: due pali e una traversa in alto.
		for palo in [-1.0, 1.0]:
			c.cornici.append(_blocco(c.nodo, Vector3(0.14, ALTEZZA_CANCELLO, 0.2),
					Vector3(cx + palo * larghezza * 0.5, ALTEZZA_CANCELLO * 0.5, 0)))
		c.cornici.append(_blocco(c.nodo, Vector3(larghezza, 0.16, 0.22),
				Vector3(cx, ALTEZZA_CANCELLO, 0)))
		var testo := _etichetta(160, Color.WHITE)
		testo.position = Vector3(cx, ALTEZZA_CANCELLO * 0.55, SPESSORE_CANCELLO)
		c.nodo.add_child(testo)
		c.testi.append(testo)
	return c


func _crea_ostacolo() -> Ostacolo:
	var o := Ostacolo.new()
	o.nodo = Node3D.new()
	o.nodo.name = "Ostacolo"
	o.nodo.visible = false
	add_child(o.nodo)
	var larghezza := _meta_larghezza_ostacolo * 2.0
	var cassa := _blocco(o.nodo, Vector3(larghezza, ALTEZZA_OSTACOLO, PROFONDITA_OSTACOLO),
			Vector3(0, ALTEZZA_OSTACOLO * 0.5, 0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORE_OSTACOLO
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	cassa.material_override = mat
	# Fascia scura per dare l'idea di una barricata rinforzata.
	var fascia := _blocco(o.nodo, Vector3(larghezza + 0.04, 0.22, PROFONDITA_OSTACOLO + 0.04),
			Vector3(0, ALTEZZA_OSTACOLO * 0.72, 0))
	fascia.material_override = _materiale(Color(0.25, 0.2, 0.15), false)
	o.testo_vita = _etichetta(170, Color.WHITE)
	o.testo_vita.position = Vector3(0, ALTEZZA_OSTACOLO * 0.42, PROFONDITA_OSTACOLO * 0.5 + 0.02)
	o.nodo.add_child(o.testo_vita)
	o.testo_premio = _etichetta(80, COLORE_PREMIO_ARMA)
	o.testo_premio.position = Vector3(0, ALTEZZA_OSTACOLO + 0.55, 0)
	o.testo_premio.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	o.nodo.add_child(o.testo_premio)
	return o


func _blocco(genitore: Node3D, dimensioni: Vector3, posizione: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensioni
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = posizione
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	genitore.add_child(mi)
	return mi


func _etichetta(dimensione: int, colore: Color) -> Label3D:
	var l := Label3D.new()
	l.font_size = dimensione
	l.outline_size = dimensione / 6
	l.pixel_size = 0.01
	l.modulate = colore
	l.outline_modulate = Color(0.05, 0.05, 0.1)
	return l


func _materiale(colore: Color, trasparente: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if trasparente:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
