class_name Partita
extends Control
## Una partita in corso: tavolo a sinistra, colonna dei comandi a destra.
## Modalità: "ia" (compagno guidato dal computer), "automa" (Copilota Automa ufficiale),
## "host" (online, chi ospita applica le regole), "ospite" (online, manda le mosse a chi ospita).

signal esci

var s: Dictionary = {}
var io := 0
var modo := "ia"
var rete: Rete
var nome_altro := ""

var tavolo: Tavolo
var colonna: VBoxContainer
var l_titolo: Label
var l_info: Label
var l_turno: Label
var l_aiuto: Label
var l_tempo: Label
var mano: Mano
var riga_caffe: HBoxContainer
var riga_azioni: HFlowContainer
var l_altro: Label
var dadi_altro: Mano
var carta_automa: TextureRect
var registro: VBoxContainer
var scorri_reg: ScrollContainer
var finale: PanelContainer

var scelto := -1
var modifica := 0
var da_rilanciare := {}
var attesa_ia := 0.0
var tempo := 60.0
var round_visto := -1
var ultimo_log := 0

const NOMI_MODULI := {
	"cherosene": "Cherosene", "perdita": "Perdita di cherosene", "ghiaccio": "Freni da ghiaccio",
	"vento": "Vento", "stagista": "Tirocinante", "tempo": "Tempo reale (60 secondi)",
	"allarmi": "Allarmi", "quota5000": "Partenza a 5000 piedi",
}

func avvia(stato: Dictionary, colore: int, modalita: String, r: Rete) -> void:
	s = stato
	io = colore
	modo = modalita
	rete = r
	_costruisci()
	_aggiorna()

func _costruisci() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Stile.FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	tavolo = Tavolo.new()
	tavolo.io = io
	add_child(tavolo)
	tavolo.spazio_toccato.connect(_spazio)
	var pc := PanelContainer.new()
	pc.name = "Colonna"
	add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	colonna = VBoxContainer.new()
	colonna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonna.add_theme_constant_override("separation", 10)
	sc.add_child(colonna)
	l_titolo = Stile.etichetta("", 34, Stile.TESTO, Stile.titolo())
	l_titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonna.add_child(l_titolo)
	l_info = Stile.paragrafo("", 22, Stile.TESTO_DEBOLE)
	colonna.add_child(l_info)
	l_tempo = Stile.etichetta("", 40, Stile.GIALLO, Stile.cifre())
	l_tempo.visible = false
	colonna.add_child(l_tempo)
	l_turno = Stile.paragrafo("", 28, Stile.GIALLO)
	l_turno.add_theme_font_override("font", Stile.grassetto())
	colonna.add_child(l_turno)
	colonna.add_child(Stile.etichetta("I TUOI DADI (%s)" % Motore.nome_ruolo(io).to_upper(), 22, Stile.BLU.lightened(0.4) if io == 0 else Stile.ARANCIO.lightened(0.2), Stile.grassetto()))
	mano = Mano.new()
	mano.colore = io
	mano.custom_minimum_size = Vector2(300, 112)
	mano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mano.toccato.connect(_dado)
	colonna.add_child(mano)
	riga_caffe = HBoxContainer.new()
	riga_caffe.add_theme_constant_override("separation", 8)
	colonna.add_child(riga_caffe)
	riga_azioni = HFlowContainer.new()
	riga_azioni.add_theme_constant_override("h_separation", 8)
	riga_azioni.add_theme_constant_override("v_separation", 8)
	colonna.add_child(riga_azioni)
	l_aiuto = Stile.paragrafo("", 22, Stile.TESTO)
	colonna.add_child(l_aiuto)
	l_altro = Stile.etichetta("", 22, Stile.TESTO_DEBOLE, Stile.grassetto())
	colonna.add_child(l_altro)
	dadi_altro = Mano.new()
	dadi_altro.colore = 1 - io
	dadi_altro.coperti = true
	dadi_altro.custom_minimum_size = Vector2(300, 64)
	dadi_altro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonna.add_child(dadi_altro)
	carta_automa = TextureRect.new()
	carta_automa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carta_automa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	carta_automa.custom_minimum_size = Vector2(160, 226)
	carta_automa.visible = false
	colonna.add_child(carta_automa)
	colonna.add_child(Stile.etichetta("DIARIO DI BORDO", 20, Stile.TESTO_DEBOLE, Stile.grassetto()))
	scorri_reg = ScrollContainer.new()
	scorri_reg.custom_minimum_size = Vector2(260, 220)
	scorri_reg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scorri_reg.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colonna.add_child(scorri_reg)
	registro = VBoxContainer.new()
	registro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorri_reg.add_child(registro)
	var basso := HFlowContainer.new()
	basso.add_theme_constant_override("h_separation", 8)
	basso.add_theme_constant_override("v_separation", 8)
	colonna.add_child(basso)
	var b1 := Stile.bottone("Menu", 22)
	b1.pressed.connect(func(): esci.emit())
	basso.add_child(b1)
	var b2 := Stile.bottone("Regole", 22)
	b2.pressed.connect(_regole)
	basso.add_child(b2)
	if rete and rete.web:
		var b3 := Stile.bottone("Schermo intero", 22)
		b3.pressed.connect(func(): rete.schermo_intero())
		basso.add_child(b3)
	resized.connect(_disponi)
	_disponi.call_deferred()

func _disponi() -> void:
	if tavolo == null:
		return
	var W := size.x
	var H := size.y
	var largo_col := clampf(W * 0.3, 380.0, 560.0)
	tavolo.position = Vector2.ZERO
	tavolo.size = Vector2(W - largo_col, H)
	tavolo._disponi()
	var x := minf(tavolo.larghezza_usata(), W - largo_col)
	var pc: Control = get_node("Colonna")
	pc.position = Vector2(x, 8)
	pc.size = Vector2(W - x - 8, H - 16)
	if finale:
		finale.position = (size - finale.size) * 0.5

# ------------------------------------------------------------------ turni

func chi_deve() -> int:
	if s["fase"] != "piazza":
		return -1
	if s["pendente"][io]:
		return io
	if s["pendente"][1 - io]:
		return 1 - io
	return s["turno"]

func _process(d: float) -> void:
	if s.is_empty() or s["fase"] != "piazza":
		return
	var chi := chi_deve()
	if (modo == "ia" or modo == "automa") and chi == 1 - io:
		attesa_ia -= d
		if attesa_ia <= 0:
			_mossa_ia()
			attesa_ia = 0.9
	else:
		attesa_ia = 0.9 if attesa_ia <= 0 else attesa_ia
	if Motore.ha(s, "tempo") and modo != "ospite":
		if finale == null:
			tempo -= d
		l_tempo.text = "Tempo: %d" % maxi(0, ceili(tempo))
		l_tempo.add_theme_color_override("font_color", Stile.ROSSO if tempo < 10 else Stile.GIALLO)
		if tempo <= 0:
			_esegui({"t": "scaduto", "c": io})

func _mossa_ia() -> void:
	var c := 1 - io
	if modo == "automa" and c == Motore.COPILOTA:
		var copia := s.duplicate(true)
		var carta := Automa.turno(copia)
		s = copia
		if carta >= 0:
			carta_automa.texture = Stile.tex("res://assets/img/automa/c%d.webp" % (carta + 1))
			carta_automa.visible = true
		_dopo()
		return
	var a := IA.scegli(s, c)
	if a.is_empty():
		return
	_esegui(a)

func _esegui(a: Dictionary) -> void:
	if modo == "ospite":
		rete.azione("mossa", a)
		return
	var e := Motore.applica(s, a)
	if e != "":
		_avviso(e)
		return
	_dopo()

func _dopo() -> void:
	for ev in s["eventi"]:
		match ev.get("e"):
			"piazza":
				tavolo.segna(ev["sp"])
				_suono("dado")
			"velocita":
				_suono("motore")
			"fine":
				_suono("arrivo" if ev["esito"] == "vinto" else "botto")
			"allarme":
				_suono("botto")
	s["eventi"] = []
	scelto = -1
	modifica = 0
	if modo == "host" and rete:
		rete.stato({"s": s, "host": io})
	_salva()
	_aggiorna()

func _suono(n: String) -> void:
	if rete:
		rete.suono(n)

func _salva() -> void:
	if rete == null or modo == "ospite":
		return
	var dati := JSON.stringify({"s": s, "io": io, "modo": modo})
	if s["esito"] != "":
		rete.salva("skyteam_partita", "")
		return
	rete.salva("skyteam_partita", dati)
	if s["round"] != round_visto:
		rete.salva_remoto(dati)

## Stato ricevuto da chi ospita (modalità ospite)
func ricevi(stato: Dictionary) -> void:
	var prima: int = s.get("log", []).size()
	s = stato
	if s["log"].size() != prima:
		_suono("dado")
	_aggiorna()

## Mossa arrivata dall'ospite (modalità host)
func mossa_remota(a: Dictionary) -> void:
	if modo != "host":
		return
	a["c"] = 1 - io
	if a.get("t") == "scaduto":
		return
	var e := Motore.applica(s, a)
	if e == "":
		_dopo()
	else:
		rete.stato({"s": s, "host": io, "errore": e})

# ------------------------------------------------------------------ comandi del giocatore

func _dado(i: int) -> void:
	if s["fase"] != "piazza":
		return
	if s["pendente"][io]:
		da_rilanciare[i] = not da_rilanciare.get(i, false)
		_aggiorna()
		return
	if s["turno"] != io:
		_avviso("Aspetta il tuo turno.")
		return
	scelto = -1 if scelto == i else i
	modifica = 0
	_aggiorna()

func _spazio(sp: String) -> void:
	if scelto < 0:
		return
	_esegui({"t": "piazza", "c": io, "i": scelto, "sp": sp, "m": modifica})

func _avviso(t: String) -> void:
	l_aiuto.text = t
	l_aiuto.add_theme_color_override("font_color", Stile.ROSSO)

# ------------------------------------------------------------------ aggiornamento grafico

func _aggiorna() -> void:
	var sc := Motore.scenario(s["scenario"])
	l_titolo.text = "%s  %s" % [sc["codice"], sc["nome"]]
	var nomi_q := ["6000 piedi", "5000 piedi", "4000 piedi", "3000 piedi", "2000 piedi", "1000 piedi", "atterraggio"]
	var info := "Difficoltà %s.  Quota: %s." % [Stile.NOMI_DIFFICOLTA[sc["colore"]].to_lower(), nomi_q[clampi(s["quota"], 0, 6)]]
	var mod := []
	for m in s["moduli"]:
		mod.append(NOMI_MODULI.get(m, m))
	if not mod.is_empty():
		info += "\nModuli: " + ", ".join(mod) + "."
	if not s["abilita"].is_empty():
		var ab := []
		for a in s["abilita"]:
			ab.append(Testi.ABILITA[a][0])
		info += "\nAbilità: " + ", ".join(ab) + "."
	var eff := Motore.effetti_quota(s)
	if "t" in eff:
		info += "\nTURBOLENZA: dopo ogni dado piazzato si rilanciano gli altri."
	if "n" in eff:
		info += "\nSCARSA VISIBILITÀ: 2 dadi alla volta."
	if s["silenzio"]:
		info += "\nRUMORE IN CABINA: non si può parlare nemmeno prima di tirare."
	l_info.text = info
	l_tempo.visible = Motore.ha(s, "tempo") and s["fase"] == "piazza"
	if s["round"] != round_visto and s["fase"] == "piazza":
		round_visto = s["round"]
		tempo = 60.0
	# turno
	var chi := chi_deve()
	var altro := Motore.nome_ruolo(1 - io)
	var chi_altro := altro + (" (IA)" if modo == "ia" else (" Automa" if modo == "automa" else (" (" + nome_altro + ")" if nome_altro != "" else "")))
	if s["fase"] == "fine":
		l_turno.text = "Partita finita."
	elif s["pendente"][io]:
		l_turno.text = "Gettone Rilancio: scegli i dadi da rilanciare."
	elif chi == io:
		l_turno.text = "Tocca a te!"
	else:
		l_turno.text = "Tocca al %s..." % chi_altro
	l_turno.add_theme_color_override("font_color", Stile.GIALLO if chi == io else Stile.TESTO_DEBOLE)
	# la mia mano
	mano.dadi = s["mano"][io]
	mano.scelto = scelto
	mano.segnati = da_rilanciare if s["pendente"][io] else {}
	mano.riserva = int(s["riserva"][io])
	mano.queue_redraw()
	dadi_altro.dadi = s["mano"][1 - io]
	dadi_altro.riserva = int(s["riserva"][1 - io])
	dadi_altro.queue_redraw()
	l_altro.text = "%s: %d dad%s dietro lo schermo" % [chi_altro.to_upper(), s["mano"][1 - io].size(), "o" if s["mano"][1 - io].size() == 1 else "i"]
	# spazi evidenziati e caffè
	for c in riga_caffe.get_children():
		c.queue_free()
	for c in riga_azioni.get_children():
		c.queue_free()
	tavolo.evidenzia = []
	tavolo.valore_scelto = 0
	l_aiuto.add_theme_color_override("font_color", Stile.TESTO)
	l_aiuto.text = ""
	if s["fase"] == "piazza" and s["turno"] == io and not s["pendente"][io] and not s["pendente"][1 - io]:
		var tutte := Motore.mosse(s, io, true)
		if s["obbligo"] >= 0:
			scelto = s["obbligo"]
			mano.scelto = scelto
		if scelto >= s["mano"][io].size():
			scelto = -1
		if scelto >= 0:
			var mod_ok := {}
			for m in tutte:
				if m["i"] == scelto:
					mod_ok[m["m"]] = true
					if m["m"] == modifica:
						tavolo.evidenzia.append(m["sp"])
			tavolo.valore_scelto = int(s["mano"][io][scelto]["v"]) + modifica
			if mod_ok.size() > 1 or modifica != 0:
				riga_caffe.add_child(Stile.etichetta("Caffè:", 22, Stile.TESTO_DEBOLE))
				var lst := mod_ok.keys()
				lst.sort()
				for m in lst:
					var b := Stile.bottone("%+d" % m if m != 0 else "0", 24)
					b.custom_minimum_size = Vector2(64, 50)
					if m == modifica:
						b.add_theme_stylebox_override("normal", Stile.scatola(Color("6b4b10"), Stile.GIALLO, 10, 3))
					b.pressed.connect(func(): modifica = m; _aggiorna())
					riga_caffe.add_child(b)
			if tavolo.evidenzia.is_empty():
				l_aiuto.text = "Con questo valore il dado non ha posto: cambia valore con il caffè o scegli un altro dado."
			else:
				l_aiuto.text = "Tocca uno degli spazi illuminati sulla plancia."
			if s["mano"][io][scelto].get("k", "d") == "stag":
				l_aiuto.text = "Gettone del Tirocinante: piazzalo subito (non sulla Concentrazione)."
			elif s["mano"][io][scelto].get("k", "d") == "sinc":
				l_aiuto.text = "Dado Traffico della Sincronia: piazzalo subito, in uno spazio di qualsiasi colore."
		else:
			l_aiuto.text = "Scegli uno dei tuoi dadi."
		if s["anticipa"] and s["primo"] == io and scelto >= 0:
			var b2 := Stile.bottone("Anticipazione: rilancia questo dado", 22)
			b2.pressed.connect(func(): _esegui({"t": "anticipa", "c": io, "i": scelto}))
			riga_azioni.add_child(b2)
		if Motore.abil(s, "adattamento") and not s["adattamento"][io] and scelto >= 0 and s["mano"][io][scelto].get("k", "d") != "stag":
			var b3 := Stile.bottone("Adattamento: gira il dado", 22)
			b3.pressed.connect(func(): _esegui({"t": "adatta", "c": io, "i": scelto}))
			riga_azioni.add_child(b3)
	if s["fase"] == "piazza" and int(s["rilanci"]) > 0 and not s["pendente"][0] and not s["pendente"][1] and s["turno"] == io:
		var b4 := Stile.bottone("Usa un gettone Rilancio (%d)" % s["rilanci"], 22)
		b4.pressed.connect(func(): da_rilanciare = {}; _esegui({"t": "usa_rilancio", "c": io}))
		riga_azioni.add_child(b4)
	if s["fase"] == "piazza" and s["pendente"][io]:
		var b5 := Stile.bottone("Rilancia i dadi scelti", 22)
		b5.pressed.connect(_rilancia)
		riga_azioni.add_child(b5)
		l_aiuto.text = "Tocca i dadi che vuoi rilanciare (anche nessuno), poi conferma."
	tavolo.io = io
	tavolo.imposta(s)
	_registro()
	if s["fase"] == "fine":
		_mostra_finale()

func _rilancia() -> void:
	var l := []
	for i in da_rilanciare:
		if da_rilanciare[i]:
			l.append(i)
	da_rilanciare = {}
	_esegui({"t": "rilancia", "c": io, "dadi": l})

func _registro() -> void:
	var lg: Array = s["log"]
	if lg.size() == ultimo_log and registro.get_child_count() > 0:
		return
	ultimo_log = lg.size()
	for c in registro.get_children():
		c.queue_free()
	var da := maxi(0, lg.size() - 40)
	for i in range(da, lg.size()):
		var t: String = lg[i]
		var col := Stile.TESTO
		if t.begins_with("---"):
			col = Stile.GIALLO
		elif t.begins_with("SCHIANTO") or t.begins_with("ALLARME"):
			col = Stile.ROSSO
		elif t.begins_with("ATTERRAGGIO"):
			col = Stile.VERDE
		elif t.begins_with("Pilota"):
			col = Color("a9c2ff")
		elif t.begins_with("Copilota"):
			col = Color("ffc29a")
		registro.add_child(Stile.paragrafo(t, 20, col))
	await get_tree().process_frame
	await get_tree().process_frame
	scorri_reg.scroll_vertical = int(scorri_reg.get_v_scroll_bar().max_value)

func _mostra_finale() -> void:
	if finale:
		return
	finale = PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size = Vector2(620, 0)
	finale.add_child(v)
	var vinto: bool = s["esito"] == "vinto"
	var t := Stile.etichetta("ATTERRAGGIO RIUSCITO!" if vinto else "SCHIANTO!", 54, Stile.VERDE if vinto else Stile.ROSSO, Stile.titolo())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var m := Stile.paragrafo(s["motivo"] if not vinto else "Passeggeri ed equipaggio applaudono: ottimo lavoro di squadra.", 28)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	if modo != "ospite":
		var b := Stile.bottone("Rigioca", 28)
		b.pressed.connect(_rigioca)
		h.add_child(b)
	var b2 := Stile.bottone("Menu", 28)
	b2.pressed.connect(func(): esci.emit())
	h.add_child(b2)
	var b3 := Stile.bottone("Guarda il tavolo", 28)
	b3.pressed.connect(func(): finale.visible = false)
	h.add_child(b3)
	add_child(finale)
	finale.reset_size()
	finale.position = (size - finale.size) * 0.5

func _rigioca() -> void:
	var ab: Array = s["abilita"].duplicate()
	var opz := {"abilita": ab}
	s = Motore.nuova(s["scenario"], int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000, opz)
	if finale:
		finale.queue_free()
		finale = null
	round_visto = -1
	ultimo_log = 0
	carta_automa.visible = false
	_dopo()

func _regole() -> void:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(minf(size.x * 0.8, 1100), size.y * 0.75)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var testo := VBoxContainer.new()
	testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(testo)
	for blocco in Testi.regole(s):
		var titolo: String = blocco[0]
		if titolo != "":
			testo.add_child(Stile.etichetta(titolo, 30, Stile.GIALLO, Stile.titolo()))
		testo.add_child(Stile.paragrafo(blocco[1], 24))
	var b := Stile.bottone("Chiudi", 26)
	b.pressed.connect(func(): p.queue_free())
	v.add_child(b)
	add_child(p)
	p.reset_size()
	p.position = (size - p.size) * 0.5
