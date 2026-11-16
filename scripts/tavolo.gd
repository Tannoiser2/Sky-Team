class_name Tavolo
extends Control
## Il tavolo: pista di avvicinamento, plancia di comando originale, pista della quota e plance dei moduli.
## Disegna lo stato della partita e dice quale spazio è stato toccato.

signal spazio_toccato(sp: String)

const PW := 1300.0
const PH := 1992.0

## Centri degli spazi sulla plancia (coordinate dell'immagine pannello.webp)
const POS := {
	"radio0": Vector2(107, 488), "radio1a": Vector2(1190, 302), "radio1b": Vector2(1190, 488),
	"asse0": Vector2(308, 514), "asse1": Vector2(986, 514),
	"mot0": Vector2(446, 1166), "mot1": Vector2(852, 1166),
	"car0": Vector2(107, 900), "car1": Vector2(107, 1190), "car2": Vector2(107, 1480),
	"flap0": Vector2(1190, 900), "flap1": Vector2(1190, 1190), "flap2": Vector2(1190, 1480), "flap3": Vector2(1190, 1771),
	"fre0": Vector2(449, 1547), "fre1": Vector2(646, 1547), "fre2": Vector2(843, 1547),
	"conc0": Vector2(452, 1872), "conc1": Vector2(650, 1872), "conc2": Vector2(845, 1872),
}
const LUCI_CAR := [Vector2(107, 1034), Vector2(107, 1324), Vector2(107, 1617)]
const LUCI_FLAP := [Vector2(1190, 1034), Vector2(1190, 1324), Vector2(1190, 1617), Vector2(1190, 1907)]
const LUCI_FRE := [Vector2(481, 1684), Vector2(680, 1684), Vector2(875, 1684)]
const VELOCITA := {2: Vector2(283, 748), 3: Vector2(310, 845), 4: Vector2(370, 936), 5: Vector2(451, 1001),
	6: Vector2(543, 1044), 7: Vector2(650, 1060), 8: Vector2(754, 1047), 9: Vector2(848, 1001),
	10: Vector2(930, 930), 11: Vector2(991, 843), 12: Vector2(1017, 741)}
const FRENO_POS := [Vector2(407, 1326), Vector2(505, 1383), Vector2(710, 1407), Vector2(900, 1325)]
const CAFFE_POS := [Vector2(156, 1762), Vector2(156, 1882), Vector2(286, 1882)]
const ORIZZONTE := Vector2(648, 689)
const FINESTRA_SX := Rect2(234, 208, 338, 176)
const FINESTRA_DX := Rect2(728, 208, 332, 176)
const RILANCIO_POS := Vector2(117, 312)
const LATO := 118.0
## Freni da ghiaccio: la plancia si appoggia sui freni normali
const GHIACCIO_RECT := Rect2(352, 1330, 596, 339)

var s: Dictionary = {}
var io := 0                    # colore di chi guarda questo schermo (-1 = spettatore)
var evidenzia: Array = []      # spazi validi per il dado scelto
var valore_scelto := 0
var ultimo_spazio := ""
var lampo := 0.0

var r_pista := Rect2()
var r_pannello := Rect2()
var r_quota := Rect2()
var r_moduli := Rect2()
var k := 1.0                  # scala del pannello

var t_pannello: Texture2D
var t_pista: Texture2D
var t_quota: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	t_pannello = Stile.tex("res://assets/img/pannello.webp")
	resized.connect(_disponi)

func imposta(stato: Dictionary) -> void:
	var cambio_pista: bool = s.is_empty() or s.get("pista") != stato.get("pista")
	s = stato
	if cambio_pista:
		t_pista = Stile.tex("res://assets/img/piste/%s.webp" % s["pista"])
		var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dati/quote.json"))
		t_quota = Stile.tex("res://assets/img/piste/" + q[s["quota_tipo"]]["img"])
	_disponi()
	queue_redraw()

func _process(d: float) -> void:
	if lampo > 0:
		lampo = max(0.0, lampo - d)
	if is_visible_in_tree():
		queue_redraw()

func _disponi() -> void:
	if s.is_empty():
		return
	var W := size.x
	var H := size.y
	var m := 10.0
	var alt := H - 2 * m
	var dp: Dictionary = Motore.piste()[s["pista"]]
	var ap: float = 400.0 / float(dp["h"])          # larghezza/altezza pista
	var aq := 400.0 / 1672.0
	var ar := PW / PH
	var am := 0.2 if _ha_moduli() else 0.0
	var serve := alt * (ap + ar + aq * 0.8 + am) + 5 * m
	if serve > W:
		alt = (W - 5 * m) / (ap + ar + aq * 0.8 + am)
	r_pista = Rect2(m, m, alt * ap, alt)
	r_pannello = Rect2(r_pista.end.x + m, m, alt * ar, alt)
	r_quota = Rect2(r_pannello.end.x + m, m + alt * 0.1, alt * aq * 0.8, alt * 0.8)
	r_moduli = Rect2(r_quota.end.x + m, m, alt * am, alt)
	k = r_pannello.size.x / PW
	queue_redraw()

func larghezza_usata() -> float:
	return (r_moduli.end.x if r_moduli.size.x > 0 else r_quota.end.x) + 10.0

func _ha_moduli() -> bool:
	return Motore.ha(s, "cherosene") or Motore.ha(s, "perdita") or Motore.ha(s, "stagista") or Motore.ha(s, "vento") or Motore.ha(s, "allarmi") or Motore.abil(s, "insieme")

## Geometria della colonna dei moduli: restituisce i rettangoli di cherosene, tirocinante, vento, insieme
func _blocchi() -> Dictionary:
	var b := {}
	var x := r_moduli.position.x
	var w := r_moduli.size.x
	var y := r_moduli.position.y
	if Motore.ha(s, "cherosene") or Motore.ha(s, "perdita"):
		var h := w / 300.0 * 1426.0
		h = minf(h, r_moduli.size.y * 0.55)
		var ww := h * 300.0 / 1426.0
		b["kero"] = Rect2(x + (w - ww) * 0.5, y, ww, h)
		y += h + 10 + w * 0.2
	if Motore.ha(s, "allarmi"):
		var h3 := minf(w / 300.0 * 1121.0, r_moduli.end.y - y - (w if Motore.ha(s, "vento") else 0.0) - 10)
		var w3 := h3 * 300.0 / 1121.0
		b["allarmi"] = Rect2(x + (w - w3) * 0.5, y, w3, h3)
		y += h3 + 10
	if Motore.ha(s, "stagista"):
		b["stag"] = Rect2(x, y, w, w * 0.95)
		y += w * 0.95 + 10
	if Motore.abil(s, "insieme"):
		b["insieme"] = Rect2(x, y, w, w * 0.55)
		y += w * 0.55 + 10
	if Motore.ha(s, "vento"):
		var h2 := minf(w * 0.8, r_moduli.end.y - y - w * 0.15)
		b["vento"] = Rect2(x + (w - h2) * 0.5, r_moduli.end.y - h2 - w * 0.15, h2, h2)
	return b

func pt(p: Vector2) -> Vector2:
	return r_pannello.position + p * k

func pos_spazio(sp: String) -> Vector2:
	if POS.has(sp):
		return pt(POS[sp])
	if sp.begins_with("all_"):
		return _pos_allarme(sp.substr(4))
	var b := _blocchi()
	if sp == "kero" and b.has("kero"):
		var r: Rect2 = b["kero"]
		return r.position + Vector2(150.0 / 300.0, 142.0 / 1426.0) * r.size
	if sp == "stag0" and b.has("stag"):
		return b["stag"].position + Vector2(0.25, 0.42) * b["stag"].size
	if sp == "stag1" and b.has("stag"):
		return b["stag"].position + Vector2(0.75, 0.42) * b["stag"].size
	if sp == "insieme" and b.has("insieme"):
		return b["insieme"].position + Vector2(0.5, 0.62) * b["insieme"].size
	if sp.begins_with("gs") or sp.begins_with("gi"):
		var n := int(sp.substr(2))
		var x: float = [120.0, 309.0, 498.0, 687.0][n] / 800.0
		var y := 100.0 / 455.0 if sp.begins_with("gs") else 364.0 / 455.0
		return pt(GHIACCIO_RECT.position + Vector2(x, y) * GHIACCIO_RECT.size)
	return Vector2(-1000, -1000)

# ------------------------------------------------------------------ disegno

func _draw() -> void:
	if s.is_empty():
		return
	_disegna_pista()
	_disegna_quota()
	draw_texture_rect(t_pannello, r_pannello, false)
	_disegna_finestre()
	_disegna_orizzonte()
	_disegna_indicatori()
	if Motore.ha(s, "ghiaccio"):
		var tg := Stile.tex("res://assets/img/moduli/freni_ghiaccio.webp")
		draw_texture_rect(tg, Rect2(pt(GHIACCIO_RECT.position), GHIACCIO_RECT.size * k), false)
		var xs := [110.0, 300.0, 489.0, 681.0, 760.0]
		var g: int = s["ghiaccio"]
		var px: float = (xs[g] - (40.0 if g < 4 else 0.0)) / 800.0
		var c := pt(GHIACCIO_RECT.position + Vector2(px, 233.0 / 455.0) * GHIACCIO_RECT.size)
		draw_circle(c, 15 * k * 1.4, Color(0.05, 0.05, 0.05))
		draw_circle(c, 12 * k * 1.4, Stile.ROSSO)
	if s["speciale"] == "waw":
		for i in 3:
			_copri(POS["car%d" % i], "FUORI USO")
	if s["speciale"] == "ter":
		_copri(POS["mot0"], "SPENTO")
		_copri(POS["mot1"], "SPENTO")
	_disegna_moduli()
	_disegna_allarmi()
	_disegna_dadi()
	_disegna_evidenze()

func _disegna_moduli() -> void:
	var b := _blocchi()
	var f := Stile.grassetto()
	if b.has("kero"):
		var r: Rect2 = b["kero"]
		draw_texture_rect(Stile.tex("res://assets/img/moduli/cherosene.webp"), r, false)
		var v: int = s["cherosene"]
		var y := r.position.y + (274.0 + (20 - v) * 47.55) / 1426.0 * r.size.y
		var x := r.position.x + 175.0 / 300.0 * r.size.x
		var lw := r.size.x
		draw_rect(Rect2(x - lw * 0.32, y - 4, lw * 0.5, 8), Color.BLACK)
		draw_rect(Rect2(x - lw * 0.3, y - 2.5, lw * 0.46, 5), Stile.GIALLO)
		draw_colored_polygon(PackedVector2Array([Vector2(x - lw * 0.42, y - lw * 0.09), Vector2(x - lw * 0.42, y + lw * 0.09), Vector2(x - lw * 0.28, y)]), Stile.GIALLO)
		Stile.testo_bordato(self, Stile.cifre(), Vector2(r.position.x + r.size.x * 0.5, r.end.y + lw * 0.16), "Cherosene %d" % v, int(lw * 0.16), Stile.GIALLO, lw * 2.4)
		Stile.testo_bordato(self, Stile.cifre(), Vector2(r.position.x + r.size.x * 0.5, r.end.y + 4), "", 10, Color.WHITE)
		if Motore.ha(s, "perdita"):
			var c := r.position + Vector2(150.0 / 300.0, 142.0 / 1426.0) * r.size
			var l := r.size.x * 0.42
			draw_texture_rect(Stile.tex("res://assets/img/moduli/stagista_retro.webp"), Rect2(c - Vector2(l, l) * 0.5, Vector2(l, l)), false)
	if b.has("stag"):
		var r2: Rect2 = b["stag"]
		draw_style_box(Stile.scatola(Color("2a3240"), Color("596579"), 10, 2), r2)
		Stile.testo_centrato(self, f, r2.position + Vector2(r2.size.x * 0.5, r2.size.y * 0.1), "TIROCINANTE", int(r2.size.x * 0.13), Stile.TESTO, r2.size.x)
		for i in 2:
			var c2 := pos_spazio("stag%d" % i)
			var l2 := LATO * k
			var sb := Stile.scatola(Stile.BLU_SCURO if i == 0 else Stile.ARANCIO_SCURO, Stile.BLU if i == 0 else Stile.ARANCIO, 8, 2)
			draw_style_box(sb, Rect2(c2 - Vector2(l2, l2) * 0.5, Vector2(l2, l2)))
			if not s["stagisti"].is_empty():
				var prossimo: int = s["stagisti"][0] if i == 0 else s["stagisti"][-1]
				Stile.testo_centrato(self, f, c2 + Vector2(0, l2 * 0.72), "non %d" % prossimo, int(r2.size.x * 0.1), Stile.TESTO_DEBOLE, r2.size.x * 0.5)
		var resto: Array = s["stagisti"]
		var t := "Gettoni: %d" % resto.size() if not resto.is_empty() else "Addestrato!"
		Stile.testo_centrato(self, f, r2.position + Vector2(r2.size.x * 0.5, r2.size.y * 0.86), t, int(r2.size.x * 0.11), Stile.GIALLO if resto.is_empty() else Stile.TESTO, r2.size.x)
	if b.has("insieme"):
		var r3: Rect2 = b["insieme"]
		draw_style_box(Stile.scatola(Color("2a3240"), Color("596579"), 10, 2), r3)
		Stile.testo_centrato(self, f, r3.position + Vector2(r3.size.x * 0.5, r3.size.y * 0.17), "LAVORARE INSIEME", int(r3.size.x * 0.1), Stile.TESTO, r3.size.x)
		var c3 := pos_spazio("insieme")
		var l3 := LATO * k
		draw_style_box(Stile.scatola(Color("3b3f46"), Color("8a93a3"), 8, 2), Rect2(c3 - Vector2(l3, l3) * 0.5, Vector2(l3, l3)))
		if s["spazi"].has("insieme_a"):
			var d: Dictionary = s["spazi"]["insieme_a"]
			Stile.dado(self, c3, l3 * 0.9, int(d["v"]), int(d["c"]))
	if b.has("vento"):
		var r4: Rect2 = b["vento"]
		var c4 := r4.get_center()
		var ang := -float(s["vento"]) * TAU / 20.0
		draw_set_transform(c4, ang, Vector2.ONE)
		draw_texture_rect(Stile.tex("res://assets/img/moduli/vento_anello.webp"), Rect2(-r4.size * 0.5, r4.size), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var l4 := r4.size.x * 0.4
		draw_circle(c4, l4 * 0.58, Color(0.05, 0.08, 0.15))
		draw_texture_rect(Stile.tex("res://assets/img/moduli/vento_aereo.webp"), Rect2(c4 - Vector2(l4, l4 * 0.93) * 0.5, Vector2(l4, l4 * 0.93)), false)
		Stile.testo_bordato(self, Stile.cifre(), c4 + Vector2(0, r4.size.y * 0.66), "Vento %+d" % Motore.vento_valore(s), int(r4.size.x * 0.14), Stile.GIALLO, r4.size.x * 1.5)

func _copri(p: Vector2, t: String) -> void:
	var r := Rect2(pt(p) - Vector2(LATO, LATO) * k * 0.55, Vector2(LATO, LATO) * k * 1.1)
	draw_rect(r, Color(0.08, 0.08, 0.1, 0.85))
	Stile.testo_bordato(self, Stile.grassetto(), r.get_center(), t, int(26 * k * 1.3), Stile.ROSSO, r.size.x * 1.4)

func _disegna_pista() -> void:
	draw_rect(r_pista.grow(4), Color(0, 0, 0, 0.5))
	draw_texture_rect(t_pista, r_pista, false)
	var dp: Dictionary = Motore.piste()[s["pista"]]
	var sc := r_pista.size.y / float(dp["h"])
	var tok := Stile.tex("res://assets/img/moduli/pinguino.webp")
	for i in s["aerei"].size():
		var y0: float = dp["y"][i][0] * sc
		var y1: float = dp["y"][i][1] * sc
		var n: int = s["aerei"][i]
		var lato := minf((y1 - y0) * 0.55, r_pista.size.x * 0.22)
		# copre le icone stampate dei segnalini iniziali, poi mette i segnalini veri
		draw_rect(Rect2(r_pista.position.x + r_pista.size.x * 0.06, r_pista.position.y + y0 + 8 * sc, r_pista.size.x * 0.13, (y1 - y0) - 16 * sc), Color("0b1a33"))
		for j in n:
			var c := Vector2(r_pista.position.x + r_pista.size.x * (0.3 + 0.17 * (j % 4)), r_pista.position.y + (y0 + y1) * 0.5 - lato * 0.1 + (j / 4) * lato * 0.5)
			if s["pinguini"]:
				draw_circle(c, lato * 0.52, Color(0, 0, 0, 0.55))
				draw_texture_rect(tok, Rect2(c - Vector2(lato, lato) * 0.5, Vector2(lato, lato)), false)
			else:
				_aereo_traffico(c, lato * 0.5)
		if i == int(s["pos"]):
			var r := Rect2(r_pista.position.x + 4, r_pista.position.y + y0 - 2, r_pista.size.x - 8, y1 - y0 + 4)
			var pulsa := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
			draw_rect(r, Color(Stile.GIALLO, pulsa), false, 5)
			var tp := Stile.tex("res://assets/img/moduli/vento_aereo.webp")
			var lato2 := (y1 - y0) * 0.8
			draw_texture_rect(tp, Rect2(Vector2(r.end.x - lato2 - 6, r.get_center().y - lato2 * 0.5), Vector2(lato2, lato2 * 280.0 / 300.0)), false)

## Segnalino del traffico: disco bianco con la sagoma di un aereo
func _aereo_traffico(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, r * 0.12), r * 1.02, Color(0, 0, 0, 0.5))
	draw_circle(c, r, Color("f2f4f7"))
	draw_arc(c, r, 0, TAU, 32, Color("6b7686"), maxf(1.5, r * 0.08))
	var col := Color("1c2a44")
	var u := r * 0.78
	# fusoliera, ali, coda (vista dall'alto, muso in alto)
	draw_line(c + Vector2(0, -u), c + Vector2(0, u * 0.8), col, u * 0.22)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u * 0.25), c + Vector2(u * 0.95, u * 0.2), c + Vector2(u * 0.95, u * 0.36), c + Vector2(0, u * 0.12), c + Vector2(-u * 0.95, u * 0.36), c + Vector2(-u * 0.95, u * 0.2)]), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, u * 0.55), c + Vector2(u * 0.4, u * 0.82), c + Vector2(u * 0.4, u * 0.92), c + Vector2(0, u * 0.8), c + Vector2(-u * 0.4, u * 0.92), c + Vector2(-u * 0.4, u * 0.82)]), col)
	draw_circle(c + Vector2(0, -u), u * 0.11, col)

func _disegna_quota() -> void:
	draw_rect(r_quota.grow(3), Color(0, 0, 0, 0.5))
	draw_texture_rect(t_quota, r_quota, false)
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dati/quote.json"))[s["quota_tipo"]]
	var sc := r_quota.size.y / float(q["h"])
	var i: int = clampi(s["quota"], 0, 6)
	var y0: float = q["y"][i][0] * sc
	var y1: float = q["y"][i][1] * sc
	var r := Rect2(r_quota.position.x + 2, r_quota.position.y + y0 - 2, r_quota.size.x - 4, y1 - y0 + 4)
	draw_rect(r, Stile.GIALLO, false, 4)
	# quote già superate oscurate
	for j in range(0, i):
		var a: float = q["y"][j][0] * sc
		var b: float = q["y"][j][1] * sc
		draw_rect(Rect2(r_quota.position.x, r_quota.position.y + a, r_quota.size.x, b - a), Color(0, 0, 0, 0.55))
	# gettoni rilancio ancora sulla pista
	var tr := Stile.tex("res://assets/img/moduli/rilancio.webp")
	for j in s["rilanci_pista"]:
		var a2: float = q["y"][j][0] * sc
		var b2: float = q["y"][j][1] * sc
		var l := (b2 - a2) * 0.55
		draw_texture_rect(tr, Rect2(Vector2(r_quota.end.x - l - 6, r_quota.position.y + (a2 + b2) * 0.5 - l * 0.5), Vector2(l, l)), false)

func _disegna_finestre() -> void:
	# finestra sinistra: la casella attuale della pista; destra: la quota attuale
	var dp: Dictionary = Motore.piste()[s["pista"]]
	var y: Array = dp["y"][int(s["pos"])]
	var src := Rect2(0, y[0] - 6, 400, y[1] - y[0] + 12)
	var sz := t_pista.get_size()
	var fs := sz.x / 400.0
	draw_texture_rect_region(t_pista, Rect2(pt(FINESTRA_SX.position), FINESTRA_SX.size * k), Rect2(src.position * fs, src.size * fs))
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dati/quote.json"))[s["quota_tipo"]]
	var yq: Array = q["y"][clampi(s["quota"], 0, 6)]
	var fq := t_quota.get_size().x / 400.0
	draw_texture_rect_region(t_quota, Rect2(pt(FINESTRA_DX.position), FINESTRA_DX.size * k), Rect2(Vector2(0, yq[0] - 6) * fq, Vector2(400, yq[1] - yq[0] + 12) * fq))

func _disegna_orizzonte() -> void:
	var c := pt(ORIZZONTE)
	var r := 218.0 * k
	var a: int = s["asse"]
	var ang := deg_to_rad(-a * 14.0)
	# cielo
	draw_circle(c, r, Color("3f86d6"))
	# terra: semicerchio sotto la linea dell'orizzonte inclinata
	var punti := PackedVector2Array()
	for i in 41:
		var t := ang + PI * i / 40.0
		punti.append(c + Vector2(cos(t), sin(t)) * r)
	draw_colored_polygon(punti, Color("b9773b"))
	draw_line(c + Vector2(cos(ang), sin(ang)) * r, c - Vector2(cos(ang), sin(ang)) * r, Color(1, 1, 1, 0.8), 3 * k * 1.5)
	# sagoma fissa dell'aereo
	var w := r * 0.55
	draw_line(c - Vector2(w, 0), c - Vector2(w * 0.3, 0), Stile.GIALLO, 9 * k)
	draw_line(c + Vector2(w * 0.3, 0), c + Vector2(w, 0), Stile.GIALLO, 9 * k)
	draw_circle(c, 10 * k, Stile.GIALLO)
	# lancetta sull'anello: -2..+2 (X a +-3)
	var ap := deg_to_rad(-90.0 + a * 25.0)
	var dir := Vector2(cos(ap), sin(ap))
	var base := c + dir * r * 1.06
	var punta := c + dir * r * 0.86
	var lat := dir.orthogonal() * 18 * k * 1.4
	draw_colored_polygon(PackedVector2Array([base + lat, base - lat, punta]), Color.WHITE if a == 0 else (Stile.GIALLO if absi(a) == 1 else Stile.ROSSO))
	if a != 0:
		Stile.testo_bordato(self, Stile.cifre(), c + Vector2(0, r * 0.55), ("%+d" % a), int(46 * k * 1.3), Color.WHITE)

func _disegna_indicatori() -> void:
	# copre i segnalini stampati e mette quelli veri
	var scuro := Color("27292c")
	draw_circle(pt(Vector2(410, 968)), 17 * k * 1.3, scuro)
	draw_circle(pt(Vector2(801, 1024)), 17 * k * 1.3, scuro)
	draw_circle(pt(FRENO_POS[0]), 17 * k * 1.3, scuro)
	var b: int = s["blu"]
	var o: int = s["ara"]
	var mb: Vector2 = (VELOCITA[clampi(b, 2, 12)] + VELOCITA[clampi(b + 1, 2, 12)]) * 0.5
	var mo: Vector2 = (VELOCITA[clampi(o, 2, 12)] + VELOCITA[clampi(o + 1, 2, 12)]) * 0.5
	_segnalino(pt(mb), Stile.BLU)
	_segnalino(pt(mo), Stile.ARANCIO)
	if not Motore.ha(s, "ghiaccio"):
		var nf := 0
		for x in s["freni"]:
			if x: nf += 1
		_segnalino(pt(FRENO_POS[nf]), Stile.ROSSO)
	# interruttori
	for i in 3:
		_interruttore(LUCI_CAR[i], s["carrello"][i])
		if not Motore.ha(s, "ghiaccio"):
			_interruttore(LUCI_FRE[i], s["freni"][i])
	for i in 4:
		_interruttore(LUCI_FLAP[i], s["flap"][i])
	# caffè
	for i in 3:
		if i >= int(s["caffe"]):
			draw_circle(pt(CAFFE_POS[i]), 50 * k, Color(0.12, 0.12, 0.14, 0.8))
		else:
			draw_arc(pt(CAFFE_POS[i]), 52 * k, 0, TAU, 32, Stile.GIALLO, 4 * k * 1.3)
	# gettoni rilancio pronti
	var tr := Stile.tex("res://assets/img/moduli/rilancio.webp")
	var c := pt(RILANCIO_POS)
	if int(s["rilanci"]) > 0:
		draw_texture_rect(tr, Rect2(c - Vector2(62, 62) * k, Vector2(124, 124) * k), false)
		if int(s["rilanci"]) > 1:
			Stile.testo_bordato(self, Stile.cifre(), c + Vector2(50, 50) * k, "x%d" % s["rilanci"], int(40 * k * 1.3), Color.WHITE)
	# velocità dell'ultimo atterraggio
	if int(s.get("vel_finale", -1)) >= 0:
		Stile.testo_bordato(self, Stile.cifre(), pt(Vector2(650, 1260)), "Velocità %d" % s["vel_finale"], int(40 * k * 1.3), Stile.GIALLO, 400)

func _segnalino(c: Vector2, col: Color) -> void:
	draw_circle(c, 16 * k * 1.3, Color.BLACK)
	draw_circle(c, 13 * k * 1.3, col)
	draw_circle(c - Vector2(4, 4) * k, 4 * k * 1.3, Color(1, 1, 1, 0.5))

func _interruttore(p: Vector2, acceso: bool) -> void:
	var r := Rect2(pt(p) - Vector2(68, 32) * k, Vector2(136, 64) * k)
	if not acceso:
		var sb := Stile.scatola(Color("1d1f22"), Color("0c0d0e"), int(12 * k), 2)
		draw_style_box(sb, r)
		draw_circle(r.position + Vector2(r.size.x * 0.27, r.size.y * 0.5), r.size.y * 0.3, Color("4b5058"))
		draw_circle(r.position + Vector2(r.size.x * 0.72, r.size.y * 0.5), r.size.y * 0.24, Color("2a2e33"))

func _disegna_allarmi() -> void:
	for a in s["allarmi"]:
		if a["stato"] != "attivo":
			continue
		var sp := []
		match a["id"]:
			"conc": sp = ["conc0", "conc1", "conc2"]
			"flap": sp = ["flap0", "flap1", "flap2", "flap3"]
			"car": sp = ["car0", "car1", "car2"]
			"radio0": sp = ["radio0"]
			"radio1": sp = ["radio1a", "radio1b"]
			"fre": sp = ["fre0", "fre1", "fre2"]
		for x in sp:
			if s["spazi"].has(x):
				continue
			var c := pos_spazio(x)
			draw_rect(Rect2(c - Vector2(LATO, LATO) * k * 0.5, Vector2(LATO, LATO) * k), Color(0.6, 0.05, 0.05, 0.55))
		pass
	var b := _blocchi()
	if not b.has("allarmi"):
		return
	var r: Rect2 = b["allarmi"]
	draw_texture_rect(Stile.tex("res://assets/img/moduli/allarmi_plancia.webp"), r, false)
	for a2 in s["allarmi"]:
		var c := _pos_allarme(a2["id"])
		var w := r.size.x * 0.82
		var rr := Rect2(c - Vector2(w, w * 0.52) * 0.5, Vector2(w, w * 0.52))
		match a2["stato"]:
			"coperto":
				draw_texture_rect(Stile.tex("res://assets/img/moduli/allarme_retro.webp"), rr, false)
			"attivo":
				draw_texture_rect(Stile.tex("res://assets/img/moduli/allarme_%s.webp" % a2["id"]), rr, false)
				var pulsa := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
				draw_rect(rr.grow(3), Color(1, 0.2, 0.2, pulsa), false, 4)
			"rimosso":
				Stile.testo_bordato(self, Stile.grassetto(), c, "OK", int(w * 0.25), Stile.VERDE, w)

## Dove sta il gettone di un allarme (casella della plancia Allarmi)
func _pos_allarme(id: String) -> Vector2:
	var b := _blocchi()
	if not b.has("allarmi"):
		return Vector2(-1000, -1000)
	var r: Rect2 = b["allarmi"]
	for i in s["allarmi"].size():
		if s["allarmi"][i]["id"] == id:
			var y: float = [144.0, 308.0, 475.0, 640.0, 804.0, 967.0][i] / 1121.0
			return r.position + Vector2(0.5, y) * r.size
	return Vector2(-1000, -1000)

func _disegna_dadi() -> void:
	for chiave in s["spazi"]:
		var d: Dictionary = s["spazi"][chiave]
		var sp: String = chiave
		if sp.begins_with("insieme") or sp.begins_with("all_"):
			continue
		var c := pos_spazio(sp)
		var col: int = d["c"]
		if d.get("k", "d") == "stag":
			col = -1
		var bordo := Color.TRANSPARENT
		if sp == ultimo_spazio and lampo > 0:
			bordo = Color(1, 1, 1, lampo)
		Stile.dado(self, c, LATO * k * 0.92, int(d["v"]), col, 1.0, bordo)

func _disegna_evidenze() -> void:
	if evidenzia.is_empty():
		return
	var pulsa := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
	for sp in evidenzia:
		var c := pos_spazio(sp)
		var r := Rect2(c - Vector2(LATO, LATO) * k * 0.56, Vector2(LATO, LATO) * k * 1.12)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 0.85, 0.2, 0.25 + 0.2 * pulsa)
		sb.border_color = Color(1, 0.9, 0.25, 0.7 + 0.3 * pulsa)
		sb.set_border_width_all(int(max(4.0, 14 * k)))
		sb.shadow_color = Color(1, 0.8, 0.1, 0.6 * pulsa)
		sb.shadow_size = int(max(4.0, 18 * k))
		sb.set_corner_radius_all(int(16 * k))
		draw_style_box(sb, r)
		if valore_scelto > 0:
			Stile.dado(self, c, LATO * k * 0.7, valore_scelto, io, 0.45)

# ------------------------------------------------------------------ tocco

func _gui_input(e: InputEvent) -> void:
	var p := Vector2(-1, -1)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = e.position
	if p.x < 0:
		return
	var meglio := ""
	var dist := LATO * k * 0.75
	for sp in evidenzia:
		var d := pos_spazio(sp).distance_to(p)
		if d < dist:
			dist = d
			meglio = sp
	if meglio != "":
		accept_event()
		spazio_toccato.emit(meglio)

func segna(sp: String) -> void:
	ultimo_spazio = sp
	lampo = 1.0
