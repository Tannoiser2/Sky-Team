class_name IA
extends RefCounted
## Il compagno guidato dal computer. Gioca onestamente: conosce i propri dadi e il pannello,
## non i dadi dietro lo schermo dell'altro. Per ogni mossa possibile simula l'effetto
## con il motore delle regole e valuta la situazione che ne risulta.

const PERSO := -100000.0

## Sceglie l'azione per il colore c. Restituisce un Dictionary da passare a Motore.applica().
static func scegli(s: Dictionary, c: int) -> Dictionary:
	if s["fase"] != "piazza":
		return {}
	if s["pendente"][c]:
		return {"t": "rilancia", "c": c, "dadi": dadi_da_rilanciare(s, c)}
	if s["turno"] != c:
		return {}
	# Anticipazione: rilancia il dado peggiore se è davvero inutile
	if s["anticipa"] and s["primo"] == c:
		var peggiore := _dado_inutile(s, c)
		if peggiore >= 0:
			return {"t": "anticipa", "c": c, "i": peggiore}
	var l := Motore.mosse(s, c, true)
	if l.is_empty():
		return {}
	var leggero := copia_leggera(s)
	var base := valuta(s, c)
	var meglio := {}
	var punti := -INF
	for m in l:
		var t: Dictionary = leggero.duplicate(true)
		Motore.piazza(t, c, m["i"], m["sp"], m["m"])
		var p := valuta(t, c) - base
		p -= 25.0 * absi(m["m"])
		if p > punti:
			punti = p
			meglio = m
	# Gettone Rilancio: se la mossa migliore è pessima e ci sono gettoni, rilancia
	if punti < -2500.0 and int(s["rilanci"]) > 0 and not s["pendente"][0] and not s["pendente"][1]:
		return {"t": "usa_rilancio", "c": c}
	# Adattamento: se girare un dado migliora molto la situazione
	if Motore.abil(s, "adattamento") and not s["adattamento"][c] and punti < -800.0:
		for i in s["mano"][c].size():
			if s["mano"][c][i].get("k", "d") == "stag":
				continue
			var t2: Dictionary = leggero.duplicate(true)
			if Motore.adatta(t2, c, i) != "":
				continue
			var l2 := Motore.mosse(t2, c, true)
			for m in l2:
				var t3: Dictionary = t2.duplicate(true)
				Motore.piazza(t3, c, m["i"], m["sp"], m["m"])
				if valuta(t3, c) - base - 25.0 * absi(m["m"]) > punti + 600.0:
					return {"t": "adatta", "c": c, "i": i}
	return {"t": "piazza", "c": c, "i": meglio["i"], "sp": meglio["sp"], "m": meglio["m"]}

## Copia dello stato senza diario, segnata come simulazione (più veloce da duplicare)
static func copia_leggera(s: Dictionary) -> Dictionary:
	var t := s.duplicate()
	t["log"] = []
	t["eventi"] = []
	t["_sim"] = true
	return t

## Dopo un gettone Rilancio: rilancia i dadi che non servono a niente di buono.
static func dadi_da_rilanciare(s: Dictionary, c: int) -> Array:
	var r := []
	for i in s["mano"][c].size():
		var d: Dictionary = s["mano"][c][i]
		if d.get("k", "d") != "d":
			continue
		if _utilita_dado(s, c, int(d["v"])) < 100.0:
			r.append(i)
	return r

static func _dado_inutile(s: Dictionary, c: int) -> int:
	var peggio := -1
	var minimo := 1e9
	for i in s["mano"][c].size():
		var d: Dictionary = s["mano"][c][i]
		if d.get("k", "d") != "d":
			continue
		var u := _utilita_dado(s, c, int(d["v"]))
		if u < minimo:
			minimo = u
			peggio = i
	return peggio if minimo < 60.0 else -1

## Quanto può servire un valore (stima rapida, senza simulare tutto)
static func _utilita_dado(s: Dictionary, c: int, v: int) -> float:
	var u := 0.0
	if c == 0:
		for k in 3:
			if s["speciale"] != "waw" and not s["carrello"][k] and Motore.valori_spazio(s, "car%d" % k).has(v):
				u = max(u, 300.0)
		for k in 3:
			if not Motore.ha(s, "ghiaccio") and not s["freni"][k] and Motore.valori_spazio(s, "fre%d" % k).has(v) and (k == 0 or s["freni"][k - 1]):
				u = max(u, 220.0)
	else:
		for k in 4:
			if not s["flap"][k] and Motore.valori_spazio(s, "flap%d" % k).has(v) and (k == 0 or s["flap"][k - 1]):
				u = max(u, 300.0)
	var dest: int = int(s["pos"]) + v - 1
	if dest <= int(s["ultima"]) and s["aerei"][dest] > 0:
		u = max(u, 260.0 - 20.0 * (v - 1))
	if v >= 3 and v <= 4:
		u = max(u, 120.0)
	return u

# ------------------------------------------------------------------ valutazione della situazione

static func valuta(s: Dictionary, c: int) -> float:
	if s["esito"] == "perso":
		return PERSO
	if s["esito"] == "vinto":
		return -PERSO
	var p := 0.0
	var fine := Motore.ultimo_round(s)
	var spazi: Dictionary = s["spazi"]
	var altro := 1 - c
	# --- azioni obbligatorie: devono restare abbastanza dadi
	for col in 2:
		var mancano := 0
		if not spazi.has("asse%d" % col):
			mancano += 1
		if s["speciale"] != "ter" and not spazi.has("mot%d" % col):
			mancano += 1
		var dadi := _dadi_rimasti(s, col)
		if dadi < mancano:
			p -= 50000.0
		elif dadi == mancano and mancano > 0 and col == c:
			p -= 30.0
	# --- asse
	var a: int = s["asse"]
	if spazi.has("asse0") and spazi.has("asse1"):
		p -= _pena_asse(s, a, fine)
	else:
		p -= _coppia(s, c, "asse", func(v0, v1): return _pena_asse(s, a + v1 - v0, fine))
	# --- motori e avanzamento
	if s["speciale"] != "ter":
		if spazi.has("mot0") and spazi.has("mot1"):
			p += _qualita_pos(s, int(s["pos"]), true)
			if fine and int(s["vel_finale"]) >= Motore.limite_freni(s):
				p -= 6000.0 if _freni_ancora_possibili(s) else 40000.0
		else:
			p -= _coppia(s, c, "mot", func(v0, v1): return -_qualita_velocita(s, v0 + v1))
	else:
		p += _qualita_pos(s, int(s["pos"]), true)
	# --- traffico ancora in volo
	var giri_t: int = Motore.ULTIMA_QUOTA - int(s["quota"]) + 1
	var motori_fatti: bool = spazi.has("mot0") and spazi.has("mot1")
	for i in range(int(s["pos"]), int(s["ultima"]) + 1):
		var n: int = s["aerei"][i]
		if n > 0:
			var d := i - int(s["pos"])
			var pena: float = 150.0 + 500.0 / giri_t + max(0.0, 300.0 - 100.0 * d)
			if d == 0 and not fine:
				pena += 700.0 if not motori_fatti else 450.0
			elif d == 1 and not fine:
				pena += 300.0 if not motori_fatti else 150.0
			p -= n * pena
	# --- carrello, flap, freni
	var giri_rimasti: int = Motore.ULTIMA_QUOTA - int(s["quota"]) + 1
	var car_mancanti := 0
	if s["speciale"] != "waw":
		for x in s["carrello"]:
			if x: p += 260.0
			else: car_mancanti += 1
	var flap_mancanti := 0
	for x in s["flap"]:
		if x: p += 260.0
		else: flap_mancanti += 1
	if car_mancanti > giri_rimasti * 2: p -= 3000.0
	if flap_mancanti > giri_rimasti * 2: p -= 3000.0
	if Motore.ha(s, "ghiaccio"):
		p += 320.0 * int(s["ghiaccio"])
		# coppia lasciata a metà
		var n2: int = s["ghiaccio"]
		if n2 < 4 and (spazi.has("gs%d" % n2) != spazi.has("gi%d" % n2)):
			p += 120.0
	else:
		var nf := 0
		for x in s["freni"]:
			if x: nf += 1
		p += [0.0, 260.0, 420.0, 500.0][nf]
	if fine:
		if s["asse"] != 0 and spazi.has("asse0") and spazi.has("asse1"):
			p -= 40000.0
		if s["speciale"] != "waw" and car_mancanti > 0:
			p -= 2500.0 * car_mancanti
		p -= 2500.0 * flap_mancanti
		if Motore.ha(s, "ghiaccio") and int(s["ghiaccio"]) < 4:
			p -= 2500.0 * (4 - int(s["ghiaccio"]))
		if Motore.ha(s, "stagista"):
			p -= 2500.0 * s["stagisti"].size()
	# --- bilancio: dadi liberi ancora disponibili contro cose ancora da fare
	p += _bilancio(s, fine)
	# --- potenziale dei dadi che mi restano
	for d in s["mano"][c]:
		if d.get("k", "d") == "d":
			p += 0.35 * _utilita_dado(s, c, int(d["v"]))
	# --- risorse
	p += 70.0 * int(s["caffe"])
	p += 60.0 * int(s["rilanci"])
	if Motore.ha(s, "cherosene") or Motore.ha(s, "perdita"):
		var k: int = int(s["cherosene"]) + 2
		if Motore.ha(s, "cherosene") and not spazi.has("kero"):
			k -= 6
		if Motore.ha(s, "perdita") and not (spazi.has("mot0") and spazi.has("mot1")):
			k -= 2
		var futuri := giri_rimasti - 1
		var serve := futuri * (2 if Motore.ha(s, "cherosene") else 2)
		if k < 0:
			p -= 30000.0
		elif k < serve:
			p -= 2500.0 * (serve - k)
		p += 60.0 * min(k, 20)
	if Motore.ha(s, "stagista"):
		p += 200.0 * (6 - s["stagisti"].size())
		if s["stagisti"].size() > giri_rimasti * 2:
			p -= 2000.0
	for al in s["allarmi"]:
		if al["stato"] == "attivo":
			p -= 220.0
	return p

static func _bilancio(s: Dictionary, fine: bool) -> float:
	var spazi: Dictionary = s["spazi"]
	var futuri: int = Motore.ULTIMA_QUOTA - int(s["quota"])
	var per_round := 1 if s["speciale"] == "ter" else 2
	if s["speciale"] == "ter":
		per_round = 2
	var libero := [0.0, 0.0]
	for col in 2:
		var obbl := 0
		if not spazi.has("asse%d" % col): obbl += 1
		if s["speciale"] != "ter" and not spazi.has("mot%d" % col): obbl += 1
		libero[col] = maxf(0.0, _dadi_rimasti(s, col) - obbl) + 0.75 * futuri * per_round
	var bisogno := [0.0, 0.0]
	var comune := 0.0
	if s["speciale"] != "waw":
		for x in s["carrello"]:
			if not x: bisogno[0] += 1.3
	for x in s["flap"]:
		if not x: bisogno[1] += 1.3
	if Motore.ha(s, "ghiaccio"):
		var g: int = 4 - int(s["ghiaccio"])
		bisogno[0] += g * 1.3
		comune += g * 1.3
	elif s["speciale"] != "ter":
		var nf := 0
		for x in s["freni"]:
			if x: nf += 1
		bisogno[0] += maxi(0, 3 - nf) * 1.2
	comune += Motore.aerei_totali(s) * 1.1
	if Motore.ha(s, "stagista"):
		comune += s["stagisti"].size() * 1.2
	if Motore.ha(s, "cherosene"):
		comune += (futuri + (0 if spazi.has("kero") else 1)) * 0.8
	for al in s["allarmi"]:
		if al["stato"] == "attivo":
			comune += 1.0
	var p := 0.0
	var marg := [libero[0] - bisogno[0], libero[1] - bisogno[1]]
	var tot: float = marg[0] + marg[1] - comune
	var peso := 1.0 + 3.0 / (futuri + 1)
	for col in 2:
		if marg[col] < 0:
			p -= 900.0 * peso * (-marg[col])
		elif marg[col] < 1.5:
			p -= 250.0 * peso * (1.5 - marg[col])
	if tot < 0:
		p -= 900.0 * peso * (-tot)
	elif tot < 2.0:
		p -= 250.0 * peso * (2.0 - tot)
	p += 120.0 * tot
	return p

## Penalità attesa per una coppia di spazi (asse o motori) non ancora completa.
## f(v0, v1) = penalità con il dado del Pilota v0 e del Copilota v1.
static func _coppia(s: Dictionary, io: int, nome: String, f: Callable) -> float:
	var spazi: Dictionary = s["spazi"]
	var h0: bool = spazi.has(nome + "0")
	var h1: bool = spazi.has(nome + "1")
	if h0 or h1:
		var chi_manca := 1 if h0 else 0
		var vp: int = spazi[nome + "0"]["v"] if h0 else spazi[nome + "1"]["v"]
		var g := []
		for x in range(1, 7):
			g.append(f.call(vp, x) if chi_manca == 1 else f.call(x, vp))
		return _attesa(s, chi_manca, io, g)
	# nessun dado: io scelgo uno dei miei, l'altro risponde con il migliore dei suoi
	var altro := 1 - io
	var meglio := INF
	var miei := []
	for d in s["mano"][io]:
		if d.get("k", "d") != "stag":
			miei.append(int(d["v"]))
	if int(s["riserva"][io]) > 0 or miei.is_empty():
		miei = [1, 2, 3, 4, 5, 6] if miei.is_empty() else miei + [3, 4]
	var k := maxi(1, _dadi_rimasti(s, altro))
	for x in miei:
		var g := []
		for y in range(1, 7):
			g.append(f.call(x, y) if io == 0 else f.call(y, x))
		meglio = min(meglio, _min_atteso(_con_caffe(s, g), k))
	return meglio

static func _con_caffe(s: Dictionary, f: Array) -> Array:
	var caffe: int = s["caffe"]
	var g := []
	for x in 6:
		var best: float = f[x]
		for m in range(1, caffe + 1):
			if x - m >= 0: best = min(best, f[x - m] + 70.0 * m)
			if x + m < 6: best = min(best, f[x + m] + 70.0 * m)
		g.append(best)
	return g

static func _dadi_rimasti(s: Dictionary, col: int) -> int:
	var n := int(s["riserva"][col])
	for d in s["mano"][col]:
		if d.get("k", "d") != "stag":
			n += 1
	if s["speciale"] == "ter":
		n = mini(n, 3 - int(s["piazzati"][col]))
	return n

static func _freni_ancora_possibili(s: Dictionary) -> bool:
	if Motore.ha(s, "ghiaccio"):
		return false
	for k in 3:
		if not s["freni"][k] and not s["spazi"].has("fre%d" % k):
			for d in s["mano"][0]:
				if Motore.valori_spazio(s, "fre%d" % k).has(int(d["v"])):
					return true
	return false

## Valore atteso quando manca il dado di chi_manca: se sono io conosco i miei dadi,
## altrimenti l'altro sceglierà il migliore tra quelli che ha (dadi casuali).
static func _attesa(s: Dictionary, chi_manca: int, io: int, f: Array) -> float:
	var g := _con_caffe(s, f)
	if chi_manca == io:
		var meglio := INF
		for d in s["mano"][io]:
			if d.get("k", "d") == "stag":
				continue
			meglio = min(meglio, g[int(d["v"]) - 1])
		if meglio == INF:
			return 30000.0
		if int(s["riserva"][io]) > 0:
			meglio = min(meglio, _min_atteso(g, 1))
		return meglio
	var k := maxi(1, _dadi_rimasti(s, chi_manca))
	return _min_atteso(g, k)

## Valore atteso del minimo di k dadi casuali
static func _min_atteso(g: Array, k: int) -> float:
	var o := g.duplicate()
	o.sort()
	var e := 0.0
	for i in 6:
		var pr := pow((6.0 - i) / 6.0, k) - pow((5.0 - i) / 6.0, k)
		e += o[i] * pr
	return e

static func _pena_asse(s: Dictionary, a: int, fine: bool) -> float:
	if absi(a) >= 3:
		return 60000.0
	var p := 260.0 * a * a
	if absi(a) == 2:
		p += 900.0
	if fine and a != 0:
		p += 20000.0
	# virate in arrivo
	for d in [1, 2]:
		var c := Motore.casella(s, int(s["pos"]) + d - 1)
		var v: String = c.get("v", "")
		if v != "" and v[a + 2] == "x":
			p += 2600.0 / d
	return p

## Qualità di una velocità (somma dei motori) in questo round
static func _qualita_velocita(s: Dictionary, somma: int) -> float:
	var vel := somma + Motore.vento_valore(s)
	if Motore.ultimo_round(s):
		return 0.0 if vel < Motore.limite_freni(s) else (-4000.0 if _freni_ancora_possibili(s) else -30000.0)
	var passi := 1
	if vel <= int(s["blu"]):
		passi = 0
	elif vel > int(s["ara"]):
		passi = 2
	var pos: int = s["pos"]
	for k in passi:
		if s["aerei"][pos] > 0:
			return -30000.0
		if pos >= int(s["ultima"]):
			return -30000.0
		var v: String = Motore.casella(s, pos).get("v", "")
		if v != "" and v[int(s["asse"]) + 2] == "x":
			return -12000.0
		pos += 1
	return _qualita_pos(s, pos, true)

## Quanto è buona la posizione pos a fine di questo round
static func _qualita_pos(s: Dictionary, pos: int, questo_round: bool) -> float:
	var dist: int = int(s["ultima"]) - pos
	var giri: int = Motore.ULTIMA_QUOTA - int(s["quota"]) - (1 if questo_round else 0)
	if Motore.ultimo_round(s):
		return 0.0
	if s["speciale"] == "ter":
		return 0.0
	if dist > 2 * giri:
		return -30000.0
	var q := 0.0
	var scorta := giri - dist
	if scorta < 0:
		q -= 2500.0 * (-scorta)
	elif scorta == 0 and dist > 0:
		q -= 700.0
	elif dist == 0 and giri > 0:
		q -= 220.0 * giri
	elif scorta >= 2:
		q -= 140.0 * (scorta - 1)
	# traffico ancora davanti: meglio non trovarselo addosso
	if pos <= int(s["ultima"]) and s["aerei"][pos] > 0 and giri > 0:
		q -= 350.0 * s["aerei"][pos]
	return q
