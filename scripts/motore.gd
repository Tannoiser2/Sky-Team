class_name Motore
extends RefCounted
## Regole di Sky Team (gioco base, moduli del Carnet di volo, Turbolenze e scenari promozionali).
## Lo stato della partita è un Dictionary fatto solo di dati JSON (si salva e si manda online così com'è).
## Colori: 0 = Pilota (blu, a sinistra), 1 = Copilota (arancione, a destra).
## Asse: numero da -3 a +3; negativo = aereo inclinato verso il Pilota.

const PILOTA := 0
const COPILOTA := 1
const ULTIMA_QUOTA := 6          # 0 = 6000 piedi ... 6 = atterraggio
const ANELLO_VENTO := [3, 3, 2, 2, 1, 0, -1, -2, -2, -3, -3, -3, -2, -2, -1, 0, 1, 2, 2, 3]
const LIMITE_FRENI := [2, 3, 5, 7]   # la velocità finale deve essere minore di questo valore
const MAX_AEREI := 12
const MAX_PINGUINI := 6

## Effetti delle quote: r = rilancio, t = turbolenza, n = nebbia (scarsa visibilità). Primo giocatore: pari = Pilota.
const QUOTE := {
	"verde": ["r", "", "", "", "r", "", ""],
	"rossa": ["r", "", "", "", "", "", ""],
	"A": ["r", "", "n", "n", "nr", "n", ""],
	"B": ["r", "t", "t", "t", "tr", "", ""],
	"C": ["r", "t", "t", "n", "n", "n", ""],
	"D": ["r", "t", "t", "tn", "tn", "", "n"],
}

## Gettoni Allarme: azione bloccata, colore del dado che la ripristina (-1 = qualsiasi) e valore.
const ALLARMI := {
	"conc": {"col": -1, "v": 1},
	"flap": {"col": 0, "v": 4},
	"car": {"col": 1, "v": 3},
	"radio0": {"col": 1, "v": 5},
	"fre": {"col": 1, "v": 2},
	"radio1": {"col": 0, "v": 6},
}

const ABILITA := ["anticipazione", "adattamento", "padronanza", "controllo", "insieme", "sincronia"]

static var _dati_piste := {}
static var _dati_scenari := []

# ------------------------------------------------------------------ dati

static var _dati_aeroporti: Dictionary = {}

static func piste() -> Dictionary:
	if _dati_piste.is_empty():
		_dati_piste = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dati/piste.json"))
	return _dati_piste

static func scenari() -> Array:
	if _dati_scenari.is_empty():
		_dati_scenari = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dati/scenari.json"))
	return _dati_scenari

## Dati veri dell'aeroporto (OurAirports): pista, soglia, direzione, lunghezza, quota
static func aeroporto(codice: String) -> Dictionary:
	if _dati_aeroporti.is_empty():
		_dati_aeroporti = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dati/aeroporti.json"))
	return _dati_aeroporti.get(codice, {})

static func scenario(id: String) -> Dictionary:
	for s in scenari():
		if s["id"] == id:
			return s
	return {}

# ------------------------------------------------------------------ caso (riproducibile)

static func caso(s: Dictionary, n: int) -> int:
	var x: int = int(s["seme"])
	x = (x * 1103515245 + 12345) % 2147483648
	s["seme"] = x
	return int((x >> 8) % n)

static func dado(s: Dictionary) -> int:
	return caso(s, 6) + 1

# ------------------------------------------------------------------ nuova partita

## opzioni: abilita (Array di id), tempo (bool: tempo reale anche se lo scenario non lo chiede)
static func nuova(id_scenario: String, seme: int, opzioni := {}) -> Dictionary:
	var sc := scenario(id_scenario)
	var p: Dictionary = piste()[sc["pista"]]
	var mod: Array = sc["moduli"].duplicate()
	if opzioni.get("tempo", false) and not mod.has("tempo"):
		mod.append("tempo")
	var s := {
		"v": 1,
		"scenario": id_scenario,
		"pista": sc["pista"],
		"quota_tipo": sc["quota"],
		"moduli": mod,
		"speciale": sc["speciale"],
		"seme": (seme % 2147483000) + 1,
		"quota": 1 if mod.has("quota5000") else 0,
		"pos": 0,
		"ultima": p["caselle"].size() - 1,
		"aerei": [],
		"pinguini": sc["speciale"] == "nzir",
		"asse": 0,
		"blu": 4,
		"ara": 8,
		"carrello": [false, false, false],
		"flap": [false, false, false, false],
		"freni": [false, false, false],
		"ghiaccio": 0,
		"caffe": 0,
		"rilanci": 0,
		"rilanci_pista": [],
		"cherosene": 20,
		"vento": 0,
		"stagisti": [],
		"allarmi": [],
		"abilita": opzioni.get("abilita", []).duplicate(),
		"adattamento": [false, false],
		"round": 0,
		"fase": "piazza",
		"turno": 0,
		"primo": 0,
		"mano": [[], []],
		"riserva": [0, 0],
		"spazi": {},
		"piazzati": [0, 0],
		"obbligo": -1,
		"pendente": [false, false],
		"anticipa": false,
		"insieme_usato": false,
		"sincronia_usata": false,
		"silenzio": false,
		"vel_finale": -1,
		"esito": "",
		"motivo": "",
		"log": [],
		"eventi": [],
	}
	for c in p["caselle"]:
		s["aerei"].append(int(c["g"]) if s["pinguini"] else int(c["p"]))
	# gettoni Rilancio sulle quote
	var q: Array = QUOTE[s["quota_tipo"]]
	for i in q.size():
		if "r" in q[i] and i >= s["quota"]:
			s["rilanci_pista"].append(i)
	# Tirocinante: 6 gettoni in ordine casuale
	if mod.has("stagista"):
		var t := [1, 2, 3, 4, 5, 6]
		for i in range(5, 0, -1):
			var j := caso(s, i + 1)
			var k = t[i]
			t[i] = t[j]
			t[j] = k
		s["stagisti"] = t
	# Allarmi: gettoni coperti in ordine casuale
	if mod.has("allarmi"):
		var a := ["conc", "flap", "car", "radio0", "fre", "radio1"]
		if s["speciale"] == "waw":
			a = ["conc", "flap", "radio1"]
		for i in range(a.size() - 1, 0, -1):
			var j := caso(s, i + 1)
			var k = a[i]
			a[i] = a[j]
			a[j] = k
		for x in a:
			s["allarmi"].append({"id": x, "stato": "coperto"})
	if mod.has("vento"):
		s["vento"] = 0
	_log(s, "Decollo per %s %s." % [sc["codice"], sc["nome"]])
	inizia_round(s)
	return s

# ------------------------------------------------------------------ utilità

static func _log(s: Dictionary, t: String) -> void:
	s["log"].append(t)
	if s["log"].size() > 200:
		s["log"].remove_at(0)

static func _evento(s: Dictionary, e: Dictionary) -> void:
	s["eventi"].append(e)

static func ha(s: Dictionary, m: String) -> bool:
	return s["moduli"].has(m)

static func abil(s: Dictionary, a: String) -> bool:
	return s["abilita"].has(a)

static func casella(s: Dictionary, i: int) -> Dictionary:
	var c: Array = piste()[s["pista"]]["caselle"]
	if i < 0 or i >= c.size():
		return {}
	return c[i]

static func effetti_quota(s: Dictionary) -> String:
	var q: Array = QUOTE[s["quota_tipo"]]
	return q[clampi(s["quota"], 0, 6)]

static func ultimo_round(s: Dictionary) -> bool:
	return s["quota"] >= ULTIMA_QUOTA

static func nome_ruolo(c: int) -> String:
	return "Pilota" if c == PILOTA else "Copilota"

static func vento_valore(s: Dictionary) -> int:
	if not ha(s, "vento"):
		return 0
	var v: int = ANELLO_VENTO[posmod(int(s["vento"]), 20)]
	return -v if s["speciale"] == "nzir" else v

static func aerei_totali(s: Dictionary) -> int:
	var n := 0
	for a in s["aerei"]:
		n += int(a)
	return n

static func allarme_attivo(s: Dictionary, azione: String) -> bool:
	for a in s["allarmi"]:
		if a["id"] == azione and a["stato"] == "attivo":
			return true
	return false

static func stagista_successivo(s: Dictionary, c: int) -> int:
	if s["stagisti"].is_empty():
		return 0
	return s["stagisti"][0] if c == PILOTA else s["stagisti"][-1]

static func limite_freni(s: Dictionary) -> int:
	if ha(s, "ghiaccio"):
		return int(s["ghiaccio"]) + 2
	var n := 0
	for f in s["freni"]:
		if f:
			n += 1
	return LIMITE_FRENI[n]

## Gruppo di un'azione (per gli allarmi e i testi)
static func gruppo(sp: String) -> String:
	if sp.begins_with("asse"): return "asse"
	if sp.begins_with("mot"): return "motori"
	if sp == "radio0": return "radio0"
	if sp.begins_with("radio1"): return "radio1"
	if sp.begins_with("car"): return "car"
	if sp.begins_with("flap"): return "flap"
	if sp.begins_with("fre"): return "fre"
	if sp.begins_with("conc"): return "conc"
	if sp == "kero": return "kero"
	if sp.begins_with("stag"): return "stag"
	if sp.begins_with("g"): return "ghiaccio"
	if sp.begins_with("all_"): return "allarme"
	if sp == "insieme": return "insieme"
	return ""

## Tutti gli spazi esistenti in questa partita
static func elenco_spazi(s: Dictionary) -> Array:
	var l := ["asse0", "asse1", "mot0", "mot1", "radio0", "radio1a", "radio1b", "conc0", "conc1", "conc2"]
	if s["speciale"] != "waw":
		l += ["car0", "car1", "car2"]
	l += ["flap0", "flap1", "flap2", "flap3"]
	if ha(s, "ghiaccio"):
		l += ["gs0", "gs1", "gs2", "gs3", "gi0", "gi1", "gi2", "gi3"]
	else:
		l += ["fre0", "fre1", "fre2"]
	if ha(s, "cherosene"):
		l.append("kero")
	if ha(s, "stagista"):
		l += ["stag0", "stag1"]
	if abil(s, "insieme"):
		l.append("insieme")
	for a in s["allarmi"]:
		if a["stato"] == "attivo":
			l.append("all_" + a["id"])
	return l

## Colore richiesto da uno spazio: 0, 1 oppure -1 (chiunque)
static func colore_spazio(s: Dictionary, sp: String) -> int:
	match sp:
		"asse0", "mot0", "radio0", "car0", "car1", "car2", "fre0", "fre1", "fre2", "stag0", "gs0", "gs1", "gs2", "gs3":
			return 0
		"asse1", "mot1", "radio1a", "radio1b", "flap0", "flap1", "flap2", "flap3", "stag1":
			return 1
	if sp.begins_with("all_"):
		return ALLARMI[sp.substr(4)]["col"]
	return -1

## Valori ammessi (vuoto = qualsiasi)
static func valori_spazio(s: Dictionary, sp: String) -> Array:
	match sp:
		"car0", "flap0": return [1, 2]
		"car1": return [3, 4]
		"car2", "flap3": return [5, 6]
		"flap1": return [2, 3]
		"flap2": return [4, 5]
		"fre0": return [2]
		"fre1": return [4]
		"fre2": return [6]
	if sp.begins_with("gs") or sp.begins_with("gi"):
		return [int(sp.substr(2)) + 2]
	if sp.begins_with("all_"):
		return [ALLARMI[sp.substr(4)]["v"]]
	return []

# ------------------------------------------------------------------ inizio del round

static func inizia_round(s: Dictionary) -> void:
	s["spazi"] = {}
	s["piazzati"] = [0, 0]
	s["obbligo"] = -1
	s["pendente"] = [false, false]
	s["insieme_usato"] = false
	s["sincronia_usata"] = false
	s["fase"] = "piazza"
	var a: int = s["quota"]
	var nomi_q := ["6000", "5000", "4000", "3000", "2000", "1000", "0"]
	_log(s, "--- Quota %s piedi ---" % nomi_q[a] if a < 6 else "--- Atterraggio: ultimo round ---")
	# gettone Rilancio
	if s["rilanci_pista"].has(a):
		s["rilanci_pista"].erase(a)
		s["rilanci"] += 1
		_log(s, "Prendete un gettone Rilancio.")
	var c := casella(s, s["pos"])
	# dado Traffico
	var t: int = int(c.get("t", 0))
	s["traffico_tirato"] = {"casella": int(s["pos"]), "dadi": []}
	for k in t:
		var d := dado(s)
		s["traffico_tirato"]["dadi"].append(d)
		var dest: int = mini(int(s["pos"]) + d - 1, int(s["ultima"]))
		var limite := MAX_PINGUINI if s["pinguini"] else MAX_AEREI
		if aerei_totali(s) < limite:
			s["aerei"][dest] += 1
			_log(s, "Traffico: esce %d, un %s compare %s." % [d, "pinguino" if s["pinguini"] else "aereo", _dove(s, dest)])
			_evento(s, {"e": "traffico", "d": d, "casella": dest})
		else:
			_log(s, "Traffico: esce %d, ma non ci sono più segnalini." % d)
	# Allarmi
	for k in int(c.get("a", 0)):
		var coperti := []
		for i in s["allarmi"].size():
			if s["allarmi"][i]["stato"] == "coperto":
				coperti.append(i)
		if coperti.is_empty():
			break
		var i: int = coperti[caso(s, coperti.size())]
		s["allarmi"][i]["stato"] = "attivo"
		_log(s, "ALLARME: %s fuori uso finché non lo ripristinate." % testo_allarme(s["allarmi"][i]["id"]))
		_evento(s, {"e": "allarme", "id": s["allarmi"][i]["id"]})
	s["silenzio"] = int(c.get("m", 0)) == 1
	# dadi
	var eff := effetti_quota(s)
	for col in 2:
		s["mano"][col] = []
		var n := 4
		if "n" in eff:
			n = 2
			s["riserva"][col] = 2
		else:
			s["riserva"][col] = 0
		for k in n:
			s["mano"][col].append({"v": dado(s)})
	if "t" in eff:
		_log(s, "Turbolenza: ogni volta che piazzate un dado, rilanciate quelli rimasti.")
	if "n" in eff:
		_log(s, "Scarsa visibilità: si gioca con 2 dadi alla volta.")
	s["primo"] = PILOTA if a % 2 == 0 else COPILOTA
	s["turno"] = s["primo"]
	s["anticipa"] = abil(s, "anticipazione")
	_controlla_turno(s)

static func _dove(s: Dictionary, i: int) -> String:
	var d: int = i - int(s["pos"])
	if i == s["ultima"]:
		return "sull'aeroporto"
	if d == 0:
		return "nella posizione attuale"
	return "%d casell%s più avanti" % [d, "a" if d == 1 else "e"]

static func testo_allarme(id: String) -> String:
	match id:
		"conc": return "Concentrazione"
		"flap": return "Flap"
		"car": return "Carrello"
		"radio0": return "Radio del Pilota"
		"fre": return "Freni"
		"radio1": return "Radio del Copilota"
	return id

# ------------------------------------------------------------------ mosse

## Il valore che avrà il dado dopo il caffè
static func valore_finale(s: Dictionary, c: int, i: int, m: int) -> int:
	return int(s["mano"][c][i]["v"]) + m

## Controlla se una mossa è valida. Restituisce "" se va bene, altrimenti il motivo.
static func controlla(s: Dictionary, c: int, i: int, sp: String, m: int = 0, automa := false, lista: Array = []) -> String:
	if s["fase"] != "piazza":
		return "Non è il momento di piazzare dadi."
	if s["turno"] != c:
		return "Non è il tuo turno."
	if s["pendente"][c]:
		return "Prima decidi quali dadi rilanciare."
	if i < 0 or i >= s["mano"][c].size():
		return "Dado inesistente."
	if s["obbligo"] >= 0 and s["obbligo"] != i:
		return "Devi prima piazzare il gettone appena ottenuto."
	var dd: Dictionary = s["mano"][c][i]
	var k: String = dd.get("k", "d")
	if s["spazi"].has("insieme_a") and int(s["spazi"]["insieme_a"]["c"]) != c and sp != "insieme" and k == "d":
		return "Devi rispondere su «Lavorare insieme»."
	if m != 0:
		if k == "stag":
			return "Il gettone Tirocinante non si modifica con il caffè."
		if absi(m) > int(s["caffe"]):
			return "Non avete abbastanza caffè."
	var v: int = int(dd["v"]) + m
	if v < 1 or v > 6:
		return "Il valore deve restare tra 1 e 6."
	if not (lista if not lista.is_empty() else elenco_spazi(s)).has(sp):
		return "Spazio non disponibile."
	if s["spazi"].has(sp):
		return "Spazio già occupato."
	var col := colore_spazio(s, sp)
	if col >= 0 and col != c and k != "sinc":
		return "Questo spazio è del %s." % nome_ruolo(col)
	var vals := valori_spazio(s, sp)
	if not vals.is_empty() and not vals.has(v):
		return "Qui serve un dado %s." % "/".join(vals.map(func(x): return str(x)))
	var g := gruppo(sp)
	match g:
		"motori":
			if s["speciale"] == "ter":
				return "I motori sono spenti: si plana."
		"car":
			if allarme_attivo(s, "car"):
				return "Il carrello è in allarme."
		"flap":
			if allarme_attivo(s, "flap"):
				return "I flap sono in allarme."
			var n := int(sp.substr(4))
			if not automa and n > 0 and not s["flap"][n - 1]:
				return "I flap si estendono in ordine, dall'alto in basso."
		"fre":
			if allarme_attivo(s, "fre"):
				return "I freni sono in allarme."
			var n2 := int(sp.substr(3))
			if n2 > 0 and not s["freni"][n2 - 1]:
				return "I freni si attivano in ordine: 2, poi 4, poi 6."
		"radio0":
			if allarme_attivo(s, "radio0"):
				return "La radio del Pilota è in allarme."
		"radio1":
			if allarme_attivo(s, "radio1"):
				return "La radio del Copilota è in allarme."
		"conc":
			if allarme_attivo(s, "conc"):
				return "La concentrazione è in allarme."
			if k == "stag":
				return "Il gettone Tirocinante non va sulla Concentrazione."
		"stag":
			if k != "d":
				return "Qui va un dado."
			if s["stagisti"].is_empty():
				return "Il Tirocinante ha già finito l'addestramento."
			if v == stagista_successivo(s, c):
				return "Il dado deve essere diverso dal prossimo gettone (%d)." % stagista_successivo(s, c)
		"ghiaccio":
			var n3 := int(sp.substr(2))
			if n3 != int(s["ghiaccio"]):
				return "I freni da ghiaccio si attivano in ordine, da sinistra a destra."
			if allarme_attivo(s, "fre"):
				return "I freni sono in allarme."
		"allarme":
			if k == "stag":
				return "Per ripristinare un sistema serve un dado."
		"insieme":
			if s["insieme_usato"]:
				return "«Lavorare insieme» è già stato usato in questo round."
			if s["spazi"].has("insieme_a") and int(s["spazi"]["insieme_a"]["c"]) == c:
				return "Ora tocca all'altro giocatore."
	if s["speciale"] == "ter" and k == "d" and s["piazzati"][c] >= 3:
		return "Si usano solo 3 dadi per round."
	return ""

## Tutte le mosse valide per il giocatore c (senza caffè se con_caffe = false)
static func mosse(s: Dictionary, c: int, con_caffe := true, automa := false) -> Array:
	var r := []
	if s["fase"] != "piazza" or s["turno"] != c or s["pendente"][c]:
		return r
	var sp_list := elenco_spazi(s)
	var caffe: int = int(s["caffe"]) if con_caffe else 0
	for i in s["mano"][c].size():
		if s["obbligo"] >= 0 and s["obbligo"] != i:
			continue
		var gia := {}
		var kk: String = s["mano"][c][i].get("k", "d")
		for sp in sp_list:
			if s["spazi"].has(sp):
				continue
			var col := colore_spazio(s, sp)
			if col >= 0 and col != c and kk != "sinc":
				continue
			var mm := caffe if kk != "stag" else 0
			for m in range(-mm, mm + 1):
				if controlla(s, c, i, sp, m, automa, sp_list) == "":
					var chiave := "%s|%d" % [sp, int(s["mano"][c][i]["v"]) + m]
					if gia.has(chiave):
						continue
					gia[chiave] = true
					r.append({"i": i, "sp": sp, "m": m})
	return r

## Piazza un dado. Restituisce "" se fatto, altrimenti il motivo.
static func piazza(s: Dictionary, c: int, i: int, sp: String, m: int = 0, automa := false) -> String:
	var e := controlla(s, c, i, sp, m, automa)
	if e != "":
		return e
	s["eventi"] = []
	var dd: Dictionary = s["mano"][c][i]
	var k: String = dd.get("k", "d")
	var v: int = int(dd["v"]) + m
	if m != 0:
		s["caffe"] -= absi(m)
		_log(s, "%s usa %d caffè: %d diventa %d." % [nome_ruolo(c), absi(m), int(dd["v"]), v])
	s["mano"][c].remove_at(i)
	s["obbligo"] = -1
	s["anticipa"] = false
	if k == "d":
		s["piazzati"][c] += 1
	var chiave := sp
	if sp == "insieme" and s["spazi"].has("insieme_a"):
		chiave = "insieme_b"
	elif sp == "insieme":
		chiave = "insieme_a"
	s["spazi"][chiave] = {"v": v, "c": c, "k": k}
	_evento(s, {"e": "piazza", "c": c, "sp": sp, "v": v})
	_effetto(s, c, sp, v, k)
	if s["esito"] != "":
		return ""
	# Turbolenza e scarsa visibilità
	var eff := effetti_quota(s)
	if k == "d" or k == "sinc":
		if s["riserva"][c] > 0:
			s["riserva"][c] -= 1
			s["mano"][c].append({"v": dado(s)})
			if "t" in eff:
				for d in s["mano"][c]:
					if d.get("k", "d") == "d":
						d["v"] = dado(s)
		elif "t" in eff:
			for d in s["mano"][c]:
				if d.get("k", "d") == "d":
					d["v"] = dado(s)
	# TER: solo 3 dadi su 4
	if s["speciale"] == "ter" and s["piazzati"][c] >= 3:
		var resto := []
		for d in s["mano"][c]:
			if d.get("k", "d") != "d":
				resto.append(d)
		s["mano"][c] = resto
	_dopo_mossa(s, c)
	return ""

static func _effetto(s: Dictionary, c: int, sp: String, v: int, k: String) -> void:
	var g := gruppo(sp)
	var chi := nome_ruolo(c)
	match g:
		"asse":
			_log(s, "%s mette %d sull'Asse." % [chi, v])
			if s["spazi"].has("asse0") and s["spazi"].has("asse1"):
				var v0: int = s["spazi"]["asse0"]["v"]
				var v1: int = s["spazi"]["asse1"]["v"]
				s["asse"] += v1 - v0
				if v0 == v1:
					_log(s, "Asse: dadi uguali, l'aereo non si inclina.")
					if abil(s, "controllo"):
						if s["caffe"] < 3:
							s["caffe"] += 1
						_log(s, "Controllo: guadagnate un caffè.")
				else:
					_log(s, "Asse: l'aereo si inclina di %d verso il %s." % [absi(v1 - v0), "Pilota" if v0 > v1 else "Copilota"])
				_evento(s, {"e": "asse", "asse": s["asse"]})
				if absi(s["asse"]) >= 3:
					_perdi(s, "L'aereo è andato in vite: l'asse ha raggiunto la X.")
					return
				if ha(s, "vento"):
					s["vento"] = posmod(int(s["vento"]) + int(s["asse"]), 20)
					if s["asse"] != 0:
						_log(s, "Vento: l'aereo ruota di %d, ora il vento vale %+d." % [absi(s["asse"]), vento_valore(s)])
		"motori":
			_log(s, "%s mette %d sui Motori." % [chi, v])
			if s["spazi"].has("mot0") and s["spazi"].has("mot1"):
				_motori(s)
		"radio0", "radio1":
			var dest: int = int(s["pos"]) + v - 1
			if dest <= s["ultima"] and s["aerei"][dest] > 0:
				s["aerei"][dest] -= 1
				_log(s, "%s chiama la torre (%d): via un %s %s." % [chi, v, "pinguino" if s["pinguini"] else "aereo", _dove(s, dest)])
				_evento(s, {"e": "radio", "casella": dest})
			else:
				_log(s, "%s usa la Radio con %d: nessun %s là." % [chi, v, "pinguino" if s["pinguini"] else "aereo"])
		"car":
			var n := int(sp.substr(3))
			if not s["carrello"][n]:
				s["carrello"][n] = true
				s["blu"] += 1
				_log(s, "Carrello estratto (%d): il segnalino blu avanza." % v)
			else:
				_log(s, "%s mette %d sul Carrello già estratto: nessun effetto." % [chi, v])
		"flap":
			var n := int(sp.substr(4))
			if not s["flap"][n]:
				s["flap"][n] = true
				s["ara"] += 1
				_log(s, "Flap esteso (%d): il segnalino arancione avanza." % v)
			else:
				_log(s, "%s mette %d sul Flap già esteso: nessun effetto." % [chi, v])
		"fre":
			var n := int(sp.substr(3))
			if not s["freni"][n]:
				s["freni"][n] = true
				_log(s, "Freno %d attivato: il segnalino rosso avanza." % v)
			else:
				_log(s, "Freno già attivo: nessun effetto.")
		"conc":
			if s["caffe"] < 3:
				s["caffe"] += 1
				_log(s, "%s si concentra (%d): un caffè pronto." % [chi, v])
			else:
				_log(s, "%s si concentra (%d), ma i caffè sono già 3." % [chi, v])
		"kero":
			s["cherosene"] -= v
			_log(s, "%s gestisce il cherosene: -%d (restano %d)." % [chi, v, s["cherosene"]])
			if s["cherosene"] <= -3:
				_perdi(s, "Cherosene finito.")
		"stag":
			var t: int
			if c == PILOTA:
				t = s["stagisti"].pop_front()
			else:
				t = s["stagisti"].pop_back()
			_log(s, "%s addestra il Tirocinante (%d) e prende il gettone %d." % [chi, v, t])
			s["mano"][c].append({"v": t, "k": "stag"})
			s["obbligo"] = s["mano"][c].size() - 1
			if mosse(s, c, false).is_empty():
				s["mano"][c].remove_at(s["obbligo"])
				s["obbligo"] = -1
				_log(s, "Il gettone %d non trova posto e viene scartato." % t)
		"ghiaccio":
			var n := int(sp.substr(2))
			_log(s, "%s mette %d sui Freni da ghiaccio." % [chi, v])
			if s["spazi"].has("gs%d" % n) and s["spazi"].has("gi%d" % n):
				s["ghiaccio"] = n + 1
				_log(s, "Freni da ghiaccio: il segnalino rosso supera il %d." % (n + 2))
		"allarme":
			var id := sp.substr(4)
			for a in s["allarmi"]:
				if a["id"] == id:
					a["stato"] = "rimosso"
			_log(s, "%s ripristina %s." % [chi, testo_allarme(id)])
		"insieme":
			if s["spazi"].has("insieme_a") and s["spazi"].has("insieme_b"):
				var a: Dictionary = s["spazi"]["insieme_a"]
				var b: Dictionary = s["spazi"]["insieme_b"]
				s["mano"][int(a["c"])].append({"v": b["v"]})
				s["mano"][int(b["c"])].append({"v": a["v"]})
				s["piazzati"][int(a["c"])] -= 1
				s["piazzati"][int(b["c"])] -= 1
				s["spazi"].erase("insieme_a")
				s["spazi"].erase("insieme_b")
				s["insieme_usato"] = true
				_log(s, "Lavorare insieme: i due dadi si scambiano i valori (%d e %d)." % [a["v"], b["v"]])
			else:
				_log(s, "%s mette %d su «Lavorare insieme»: ora l'altro deve rispondere." % [chi, v])
	# Sincronia
	if abil(s, "sincronia") and not s["sincronia_usata"] and s["esito"] == "":
		var ha_car := false
		var ha_flap := false
		for x in s["spazi"]:
			if x.begins_with("car"): ha_car = true
			if x.begins_with("flap"): ha_flap = true
		if ha_car and ha_flap:
			s["sincronia_usata"] = true
			var d := dado(s)
			_log(s, "Sincronia: il dado Traffico dà %d, da piazzare subito." % d)
			s["mano"][c].append({"v": d, "k": "sinc"})
			s["obbligo"] = s["mano"][c].size() - 1
			if mosse(s, c, false).is_empty():
				s["mano"][c].remove_at(s["obbligo"])
				s["obbligo"] = -1

static func _motori(s: Dictionary) -> void:
	var v0: int = s["spazi"]["mot0"]["v"]
	var v1: int = s["spazi"]["mot1"]["v"]
	var vel := v0 + v1
	var w := vento_valore(s)
	if w != 0:
		vel += w
		_log(s, "Vento %+d." % w)
	if ha(s, "perdita"):
		var p := absi(v0 - v1) + 1
		s["cherosene"] -= p
		_log(s, "Perdita: -%d cherosene (restano %d)." % [p, s["cherosene"]])
		if s["cherosene"] <= -3:
			_perdi(s, "Cherosene finito per la perdita.")
			return
	if v0 == v1 and abil(s, "padronanza"):
		var disp: int = 3 - int(s["rilanci"]) - s["rilanci_pista"].size()
		if disp > 0:
			s["rilanci"] += 1
			_log(s, "Padronanza: guadagnate un gettone Rilancio.")
	if ultimo_round(s):
		s["vel_finale"] = vel
		_log(s, "Velocità all'atterraggio: %d (i freni reggono fino a %d)." % [vel, limite_freni(s) - 1])
		_evento(s, {"e": "velocita", "vel": vel})
		return
	var passi := 1
	if vel <= int(s["blu"]):
		passi = 0
	elif vel > int(s["ara"]):
		passi = 2
	_log(s, "Velocità %d: l'aereo avanza di %d." % [vel, passi])
	_evento(s, {"e": "velocita", "vel": vel, "passi": passi})
	_avanza(s, passi)

static func _avanza(s: Dictionary, passi: int) -> void:
	for k in passi:
		if s["aerei"][s["pos"]] > 0:
			_perdi(s, "Collisione con un %s in posizione attuale!" % ("pinguino" if s["pinguini"] else "aereo"))
			return
		if s["pos"] >= s["ultima"]:
			_perdi(s, "Avete sorvolato l'aeroporto senza atterrare.")
			return
		# il simbolo della virata sta tra la casella attuale e la successiva
		var vir: String = casella(s, s["pos"]).get("v", "")
		if vir != "" and vir[int(s["asse"]) + 2] == "x":
			_perdi(s, "Virata mancata: l'asse non era nella posizione richiesta.")
			return
		s["pos"] += 1

static func _perdi(s: Dictionary, motivo: String) -> void:
	if s["esito"] != "":
		return
	s["esito"] = "perso"
	s["motivo"] = motivo
	s["fase"] = "fine"
	_log(s, "SCHIANTO: " + motivo)
	_evento(s, {"e": "fine", "esito": "perso"})

# ------------------------------------------------------------------ turni

static func _dopo_mossa(s: Dictionary, c: int) -> void:
	if s["esito"] != "":
		return
	if s["obbligo"] >= 0:
		return
	# «Lavorare insieme»: tocca all'altro rispondere
	var altro := 1 - c
	if s["spazi"].has("insieme_a") and not s["mano"][altro].is_empty():
		s["turno"] = altro
	elif not s["mano"][altro].is_empty():
		s["turno"] = altro
	else:
		s["turno"] = c
	_controlla_turno(s)

## Se chi deve giocare non ha mosse valide, scarta i dadi rimasti; se nessuno ha dadi chiude il round.
static func _controlla_turno(s: Dictionary) -> void:
	for giro in 4:
		if s["esito"] != "" or s["fase"] != "piazza":
			return
		var c: int = s["turno"]
		if s["mano"][0].is_empty() and s["mano"][1].is_empty():
			fine_round(s)
			return
		if s["mano"][c].is_empty():
			s["turno"] = 1 - c
			continue
		if s["pendente"][c]:
			return
		if not s.has("_sim") and mosse(s, c, true).is_empty():
			_log(s, "%s non può piazzare i dadi rimasti: vengono scartati." % nome_ruolo(c))
			s["mano"][c] = []
			s["riserva"][c] = 0
			if s["spazi"].has("insieme_a"):
				s["spazi"].erase("insieme_a")
			s["turno"] = 1 - c
			continue
		return

## Tempo scaduto (modulo Tempo reale): i dadi non piazzati si perdono.
static func tempo_scaduto(s: Dictionary) -> void:
	if s["fase"] != "piazza" or s["esito"] != "":
		return
	_log(s, "Tempo scaduto! I dadi non piazzati si perdono.")
	s["mano"] = [[], []]
	s["riserva"] = [0, 0]
	s["obbligo"] = -1
	fine_round(s)

## Gettone Rilancio: tutti e due i giocatori possono rilanciare una volta i propri dadi.
static func usa_rilancio(s: Dictionary, c: int) -> String:
	if s["fase"] != "piazza" or int(s["rilanci"]) <= 0:
		return "Nessun gettone Rilancio disponibile."
	if s["pendente"][0] or s["pendente"][1]:
		return "C'è già un rilancio in corso."
	s["rilanci"] -= 1
	s["pendente"] = [not s["mano"][0].is_empty(), not s["mano"][1].is_empty()]
	_log(s, "%s usa un gettone Rilancio: tutti e due possono rilanciare." % nome_ruolo(c))
	return ""

## Rilancia i dadi scelti (indici) dopo un gettone Rilancio.
static func rilancia(s: Dictionary, c: int, indici: Array) -> String:
	if not s["pendente"][c]:
		return "Nessun rilancio da fare."
	var n := 0
	for i in indici:
		if int(i) >= 0 and int(i) < s["mano"][c].size() and s["mano"][c][int(i)].get("k", "d") == "d":
			s["mano"][c][int(i)]["v"] = dado(s)
			n += 1
	s["pendente"][c] = false
	_log(s, "%s rilancia %d dad%s." % [nome_ruolo(c), n, "o" if n == 1 else "i"])
	_controlla_turno(s)
	return ""

## Anticipazione: il primo giocatore, prima del primo dado, può rilanciarne uno.
static func anticipa(s: Dictionary, c: int, i: int) -> String:
	if not s["anticipa"] or c != s["primo"] or s["turno"] != c:
		return "Ora non puoi usare Anticipazione."
	if i < 0 or i >= s["mano"][c].size():
		return "Dado inesistente."
	var prima: int = s["mano"][c][i]["v"]
	s["mano"][c][i]["v"] = dado(s)
	s["anticipa"] = false
	_log(s, "Anticipazione: %s rilancia un %d e ottiene %d." % [nome_ruolo(c), prima, s["mano"][c][i]["v"]])
	_controlla_turno(s)
	return ""

## Adattamento: una volta a partita, un dado si gira sulla faccia opposta.
static func adatta(s: Dictionary, c: int, i: int) -> String:
	if not abil(s, "adattamento") or s["adattamento"][c]:
		return "Adattamento non disponibile."
	if s["turno"] != c or s["fase"] != "piazza":
		return "Non è il tuo turno."
	if i < 0 or i >= s["mano"][c].size() or s["mano"][c][i].get("k", "d") == "stag":
		return "Dado non valido."
	var prima: int = s["mano"][c][i]["v"]
	s["mano"][c][i]["v"] = 7 - prima
	s["adattamento"][c] = true
	_log(s, "Adattamento: %s gira un %d e diventa %d." % [nome_ruolo(c), prima, 7 - prima])
	_controlla_turno(s)
	return ""

## Rilancia tutti i dadi rimasti (usato dal Copilota Automa).
static func rilancia_tutti(s: Dictionary, c: int) -> void:
	for d in s["mano"][c]:
		if d.get("k", "d") == "d":
			d["v"] = dado(s)

# ------------------------------------------------------------------ fine del round

static func fine_round(s: Dictionary) -> void:
	if s["esito"] != "":
		return
	s["fase"] = "fine_round"
	# azioni obbligatorie
	var manca := []
	for x in ["asse0", "asse1"]:
		if not s["spazi"].has(x): manca.append("Asse")
	if s["speciale"] != "ter":
		for x in ["mot0", "mot1"]:
			if not s["spazi"].has(x): manca.append("Motori")
	if not manca.is_empty():
		_perdi(s, "A fine round mancava un dado di ogni colore su %s." % " e ".join(_unici(manca)))
		return
	# cherosene
	if ha(s, "cherosene") and not s["spazi"].has("kero"):
		s["cherosene"] -= 6
		_log(s, "Nessun dado sul cherosene: -6 (restano %d)." % s["cherosene"])
		if s["cherosene"] <= -3:
			_perdi(s, "Cherosene finito.")
			return
	if ultimo_round(s):
		_verdetto(s)
		return
	# TER: si plana, l'aereo avanza da solo
	if s["speciale"] == "ter":
		_log(s, "Si plana: l'aereo avanza di una casella.")
		_avanza(s, 1)
		if s["esito"] != "":
			return
	s["quota"] += 1
	if s["quota"] >= ULTIMA_QUOTA and s["pos"] != s["ultima"]:
		_perdi(s, "Avete toccato terra prima di raggiungere l'aeroporto.")
		return
	if s["pos"] == s["ultima"] and s["quota"] < ULTIMA_QUOTA:
		_log(s, "Siete sopra l'aeroporto troppo presto: circuito d'attesa, non avanzate!")
	s["round"] += 1
	inizia_round(s)

static func _unici(a: Array) -> Array:
	var r := []
	for x in a:
		if not r.has(x):
			r.append(x)
	return r

static func _verdetto(s: Dictionary) -> void:
	var errori := []
	if s["asse"] != 0:
		errori.append("l'aereo non era orizzontale")
	if s["speciale"] != "waw" and s["carrello"].has(false):
		errori.append("il carrello non era tutto estratto")
	if s["flap"].has(false):
		errori.append("i flap non erano tutti estesi")
	if ha(s, "ghiaccio") and int(s["ghiaccio"]) < 4:
		errori.append("i freni da ghiaccio non erano tutti attivati")
	if s["speciale"] != "ter":
		if int(s["vel_finale"]) >= limite_freni(s):
			errori.append("i freni non bastavano a fermare l'aereo")
	if aerei_totali(s) > 0:
		errori.append("c'era ancora traffico sulla rotta")
	if ha(s, "stagista") and not s["stagisti"].is_empty():
		errori.append("il Tirocinante non aveva finito l'addestramento")
	if errori.is_empty():
		s["esito"] = "vinto"
		s["fase"] = "fine"
		s["motivo"] = "Atterraggio perfetto!"
		_log(s, "ATTERRAGGIO RIUSCITO!")
		_evento(s, {"e": "fine", "esito": "vinto"})
	else:
		_perdi(s, "Atterraggio fallito: " + ", ".join(errori) + ".")

# ------------------------------------------------------------------ azioni generiche (per online e salvataggi)

## Applica un'azione descritta da un Dictionary. Restituisce "" se fatta.
static func applica(s: Dictionary, a: Dictionary) -> String:
	var c: int = int(a.get("c", 0))
	match a.get("t", ""):
		"piazza":
			return piazza(s, c, int(a["i"]), a["sp"], int(a.get("m", 0)), a.get("automa", false))
		"usa_rilancio":
			return usa_rilancio(s, c)
		"rilancia":
			return rilancia(s, c, a.get("dadi", []))
		"anticipa":
			return anticipa(s, c, int(a["i"]))
		"adatta":
			return adatta(s, c, int(a["i"]))
		"rilancia_tutti":
			rilancia_tutti(s, c)
			return ""
		"scaduto":
			tempo_scaduto(s)
			return ""
	return "Azione sconosciuta."
