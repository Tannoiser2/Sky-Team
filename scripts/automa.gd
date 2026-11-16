class_name Automa
extends RefCounted
## Copilota Automa per il gioco in solitario (variante «Sky Team Solo» di Christian Bergeron, Créa/on ludique).
## A ogni suo turno il Copilota rilancia i dadi rimasti, pesca una carta e la legge riga per riga,
## da sinistra a destra: esegue la prima azione possibile. Il simbolo Rilancio non è un'azione:
## rilancia i dadi e prosegue con le azioni successive della stessa riga.
## Se nessuna riga funziona, il Pilota fa una «scelta responsabile» (qui: la sceglie l'IA).

# Azioni: m = motori, a = asse, f = flap (con i valori), r = radio, c = concentrazione, k = cherosene,
# g = freni da ghiaccio, R = rilancio. Criteri separati da "/": "v45" = valore 4 o 5, "x" = qualsiasi,
# "=" uguale al dado blu, "+-2" blu più o meno 2, "+1" / "-1" / "+2" blu più quel numero.
# Una "c" finale nel criterio vuol dire che si possono usare i caffè.
const CARTE := [
	[["m:+-2/v45"], ["a:-1/=c"], ["R", "f45"], ["r:xc"]],
	[["f56", "m:v3c"], ["a:+-1", "R"], ["c:v24"], ["k:x"]],
	[["f23", "R"], ["m:=", "R"], ["a:+1/v4c"], ["k:v45"]],
	[["a:v5c/="], ["m:+-1/v4c"], ["R", "f12", "f23"], ["r:xc"]],
	[["g:x", "R", "f45"], ["a:=c/+-1"], ["m:+-2/v16"], ["k:v2", "c:x"]],
	[["a:v3c", "R"], ["f23", "R"], ["m:v456"], ["g:=", "r:x"]],
	[["f56", "k:v1"], ["m:=", "R"], ["a:+2/v2c"], ["f12", "r:x"]],
	[["a:=", "R"], ["k:v2"], ["f23", "R"], ["m:v13/+-1"]],
	[["a:=/v5c"], ["m:v2c", "f45"], ["R", "c:v36"], ["r:x"]],
	[["m:+-1", "R"], ["a:v34c"], ["f12", "R", "f45"], ["c:x"]],
	[["a:=", "R"], ["g:="], ["m:v56c", "R"], ["k:v36c"]],
	[["m:+-1/v23"], ["f12", "R"], ["a:v35c"], ["f45", "r:x"]],
]

## Mescola il mazzo (indici delle carte) dentro lo stato
static func mazzo(s: Dictionary) -> Array:
	if not s.has("automa_mazzo") or s["automa_mazzo"].is_empty():
		var m := range(12)
		for i in range(11, 0, -1):
			var j := Motore.caso(s, i + 1)
			var t = m[i]
			m[i] = m[j]
			m[j] = t
		s["automa_mazzo"] = m
	return s["automa_mazzo"]

## Gioca un turno completo del Copilota Automa (colore 1). Modifica lo stato.
## Restituisce l'indice della carta pescata (o -1).
static func turno(s: Dictionary) -> int:
	var c := Motore.COPILOTA
	if s["pendente"][c]:
		Motore.rilancia(s, c, [])
		return -1
	if s["turno"] != c or s["fase"] != "piazza":
		return -1
	# un gettone da piazzare subito (Tirocinante, Sincronia): sceglie l'IA
	if s["obbligo"] >= 0:
		_ripiego(s)
		return -1
	Motore.rilancia_tutti(s, c)
	var carta: int = mazzo(s).pop_front()
	s["automa_carta"] = carta
	# azioni obbligatorie: con gli ultimi dadi bisogna coprire Asse e Motori
	var mancano := []
	if not s["spazi"].has("asse1"): mancano.append("asse1")
	if s["speciale"] != "ter" and not s["spazi"].has("mot1"): mancano.append("mot1")
	if mancano.size() > 0 and IA._dadi_rimasti(s, c) <= mancano.size():
		var l := Motore.mosse(s, c, true)
		var meglio := {}
		var punti := -INF
		for m in l:
			if not mancano.has(m["sp"]):
				continue
			var t: Dictionary = IA.copia_leggera(s).duplicate(true)
			Motore.piazza(t, c, m["i"], m["sp"], m["m"])
			var p := IA.valuta(t, c) - 25.0 * absi(m["m"])
			if p > punti:
				punti = p
				meglio = m
		if not meglio.is_empty():
			Motore._log(s, "Copilota Automa: azione obbligatoria.")
			Motore.piazza(s, c, meglio["i"], meglio["sp"], meglio["m"], true)
			return carta
	for riga in CARTE[carta]:
		var i := 0
		while i < riga.size():
			var az: String = riga[i]
			if az == "R":
				Motore.rilancia_tutti(s, c)
				Motore._log(s, "Copilota Automa: rilancia i suoi dadi.")
				i += 1
				continue
			var m := _prova(s, az)
			if not m.is_empty():
				Motore._log(s, "Copilota Automa (carta %d): %s." % [carta + 1, _testo(az)])
				Motore.piazza(s, c, m["i"], m["sp"], m["m"], true)
				return carta
			i += 1
	Motore._log(s, "La carta %d non basta: il Pilota fa una scelta responsabile per il Copilota." % (carta + 1))
	_ripiego(s)
	return carta

static func _ripiego(s: Dictionary) -> void:
	var a := IA.scegli(s, Motore.COPILOTA)
	if a.is_empty():
		return
	if a["t"] == "usa_rilancio" or a["t"] == "anticipa" or a["t"] == "adatta":
		var l := Motore.mosse(s, Motore.COPILOTA, true)
		if l.is_empty():
			return
		a = {"t": "piazza", "c": 1, "i": l[0]["i"], "sp": l[0]["sp"], "m": l[0]["m"]}
	a["automa"] = true
	Motore.applica(s, a)

static func _testo(az: String) -> String:
	var t := az.split(":")[0]
	match t[0]:
		"m": return "Motori"
		"a": return "Asse"
		"f": return "Flap"
		"r": return "Radio"
		"c": return "Concentrazione"
		"k": return "Cherosene"
		"g": return "Freni da ghiaccio"
	return az

## Cerca una mossa che soddisfi l'azione della carta
static func _prova(s: Dictionary, az: String) -> Dictionary:
	var c := Motore.COPILOTA
	var parti := az.split(":")
	var tipo := parti[0]
	var criteri: Array = []
	if parti.size() > 1:
		criteri = Array(parti[1].split("/"))
	var spazi := []
	match tipo[0]:
		"m": spazi = ["mot1"]
		"a": spazi = ["asse1"]
		"r": spazi = ["radio1a", "radio1b"]
		"c": spazi = ["conc0", "conc1", "conc2"]
		"k":
			if not Motore.ha(s, "cherosene"): return {}
			spazi = ["kero"]
		"g":
			if not Motore.ha(s, "ghiaccio"): return {}
			spazi = ["gi%d" % int(s["ghiaccio"])]
			criteri = ["=" if criteri.has("=") else "x"]
		"f":
			# valori del flap indicato; se è già esteso vale qualsiasi flap non esteso con quei valori
			var vals := []
			for ch in tipo.substr(1):
				vals.append(int(ch))
			var cand := []
			for k in 4:
				var vk := Motore.valori_spazio(s, "flap%d" % k)
				if vk == vals:
					cand.push_front(k)
				elif not s["flap"][k]:
					cand.append(k)
			for k in cand:
				if s["flap"][k]:
					continue
				for i in s["mano"][c].size():
					var v: int = s["mano"][c][i]["v"]
					if vals.has(v) and Motore.valori_spazio(s, "flap%d" % k).has(v):
						if Motore.controlla(s, c, i, "flap%d" % k, 0, true) == "":
							return {"i": i, "sp": "flap%d" % k, "m": 0}
			return {}
	var scelte := []
	for sp in spazi:
		if s["spazi"].has(sp):
			continue
		for cr in criteri:
			var caffe: bool = cr.ends_with("c") and not cr.begins_with("c")
			var crit: String = cr.substr(0, cr.length() - 1) if caffe else cr
			for i in s["mano"][c].size():
				var d: Dictionary = s["mano"][c][i]
				if d.get("k", "d") == "stag":
					continue
				var max_m: int = int(s["caffe"]) if caffe else 0
				for m in _ordine_mod(max_m):
					var v: int = int(d["v"]) + m
					if v < 1 or v > 6:
						continue
					if not _soddisfa(s, sp, crit, v):
						continue
					if Motore.controlla(s, c, i, sp, m, true) == "":
						scelte.append({"i": i, "sp": sp, "m": m})
						break
			if not scelte.is_empty():
				break
		if not scelte.is_empty():
			break
	if scelte.is_empty():
		return {}
	# per Radio e Concentrazione con "x" sceglie il dado più utile
	if tipo[0] in ["r", "c"] and scelte.size() > 1:
		var meglio = scelte[0]
		var punti := -INF
		for m in scelte:
			var t: Dictionary = IA.copia_leggera(s).duplicate(true)
			Motore.piazza(t, c, m["i"], m["sp"], m["m"], true)
			var p := IA.valuta(t, c)
			if p > punti:
				punti = p
				meglio = m
		return meglio
	return scelte[0]

static func _ordine_mod(n: int) -> Array:
	var r := [0]
	for k in range(1, n + 1):
		r.append(k)
		r.append(-k)
	return r

static func _soddisfa(s: Dictionary, sp: String, crit: String, v: int) -> bool:
	if crit == "x" or crit == "":
		return true
	if crit.begins_with("v"):
		for ch in crit.substr(1):
			if int(ch) == v:
				return true
		return false
	# criteri relativi al dado blu sulla stessa azione
	var blu := -1
	match sp:
		"mot1": blu = int(s["spazi"]["mot0"]["v"]) if s["spazi"].has("mot0") else -1
		"asse1": blu = int(s["spazi"]["asse0"]["v"]) if s["spazi"].has("asse0") else -1
		_:
			if sp.begins_with("gi"):
				var g := "gs" + sp.substr(2)
				blu = int(s["spazi"][g]["v"]) if s["spazi"].has(g) else -1
	if blu < 0:
		return false
	match crit:
		"=": return v == blu
		"+-1": return absi(v - blu) == 1
		"+-2": return absi(v - blu) == 2
		"+1": return v == blu + 1
		"-1": return v == blu - 1
		"+2": return v == blu + 2
	return false
