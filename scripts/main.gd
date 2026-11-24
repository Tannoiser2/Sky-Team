extends Control
## Menu iniziale, scelta dello scenario e collegamento online.

var rete: Rete
var schermo: Control
var partita: Partita
var lista_aeroporti: VBoxContainer
var bottoni_schede := {}
var fonte_scelta := ""
var scelto_id := "yul"
var ruolo := 0
var compagno := "ia"
var tempo_reale := false
var abilita_scelte := {}
var online := ""            # "" locale, "crea" per chi ospita
var dettaglio: VBoxContainer
var stato_rete: Label
var salvataggio_remoto := ""

func _ready() -> void:
	theme = Stile.tema()
	# i pulsanti scattano appena toccati (più affidabile con il tocco su iPad e nel browser)
	get_tree().node_added.connect(func(n):
		if n is BaseButton and not n is CheckBox:
			n.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS)
	rete = Rete.new()
	add_child(rete)
	rete.evento.connect(_evento_rete)
	get_viewport().gui_embed_subwindows = true
	var p := rete.parametri()
	if p.has("stanza"):
		_entra_codice(str(p["stanza"]))
		return
	_home()

func _pulisci() -> void:
	if schermo:
		schermo.queue_free()
		schermo = null
	if partita:
		partita.queue_free()
		partita = null

func _fondo(c: Control) -> void:
	var f := TextureRect.new()
	f.texture = Stile.tex("res://assets/img/copertina.webp")
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.modulate = Color(0.55, 0.6, 0.7)
	c.add_child(f)
	var v := ColorRect.new()
	v.color = Color(0.02, 0.05, 0.12, 0.55)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(v)

# ------------------------------------------------------------------ home

func _home() -> void:
	_pulisci()
	online = ""
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schermo)
	_fondo(schermo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.custom_minimum_size = Vector2(640, 0)
	cc.add_child(v)
	var t := Stile.etichetta("SKY TEAM", 120, Color.WHITE, Stile.titolo())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", Color("0b2a5c"))
	v.add_child(t)
	var st := Stile.etichetta("con l'espansione Turbolenze", 34, Stile.GIALLO, Stile.grassetto())
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var spazio := Control.new()
	spazio.custom_minimum_size = Vector2(0, 20)
	v.add_child(spazio)
	var b1 := Stile.bottone("Nuovo volo", 34)
	b1.pressed.connect(func(): online = ""; _scelta())
	v.add_child(b1)
	var salvato := rete.carica("skyteam_partita")
	if salvato != "":
		var b2 := Stile.bottone("Riprendi il volo salvato", 30)
		b2.pressed.connect(func(): _riprendi(salvato))
		v.add_child(b2)
	var b3 := Stile.bottone("Online: crea una stanza", 30)
	b3.pressed.connect(func(): online = "crea"; _scelta())
	v.add_child(b3)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var le := LineEdit.new()
	le.placeholder_text = "CODICE"
	le.max_length = 4
	le.custom_minimum_size = Vector2(200, 64)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(le)
	var b4 := Stile.bottone("Online: entra nella stanza", 28)
	b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b4.pressed.connect(func(): _entra_codice(le.text))
	h.add_child(b4)
	if rete.web:
		var b5 := Stile.bottone("Recupera il volo salvato online", 26)
		b5.pressed.connect(func(): stato_rete.text = "Cerco il salvataggio..."; rete.chiedi_remoto())
		v.add_child(b5)
	stato_rete = Stile.paragrafo("", 24, Stile.GIALLO)
	stato_rete.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stato_rete)
	var cr := Stile.paragrafo("Sky Team è un gioco di Luc Rémond, illustrato da Eric Hibbeler e Adrien Rives, pubblicato da Le Scorpion Masqué. Versione digitale per la ludoteca.", 18, Stile.TESTO_DEBOLE)
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cr)

# ------------------------------------------------------------------ scelta dello scenario

func _scelta() -> void:
	_pulisci()
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schermo)
	_fondo(schermo)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 20)
	schermo.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	m.add_child(h)
	# elenco
	var pl := PanelContainer.new()
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.size_flags_stretch_ratio = 1.0
	h.add_child(pl)
	var vl := VBoxContainer.new()
	pl.add_child(vl)
	var tit := Stile.etichetta("SCEGLI L'AEROPORTO" if online == "" else "ONLINE: SCEGLI L'AEROPORTO", 34, Color.WHITE, Stile.titolo())
	vl.add_child(tit)
	# schede: gioco base, Turbolenze, promozionali
	var schede := HBoxContainer.new()
	schede.add_theme_constant_override("separation", 8)
	vl.add_child(schede)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vl.add_child(sc)
	lista_aeroporti = VBoxContainer.new()
	lista_aeroporti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_aeroporti.add_theme_constant_override("separation", 8)
	sc.add_child(lista_aeroporti)
	if fonte_scelta == "":
		fonte_scelta = Motore.scenario(scelto_id).get("fonte", "base")
	var gruppi := {"base": "Gioco base", "turbolenze": "Turbolenze", "promo": "Promozionali"}
	bottoni_schede = {}
	for g in gruppi:
		var b := Button.new()
		b.text = gruppi[g]
		b.custom_minimum_size = Vector2(150, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Stile.grassetto())
		b.add_theme_font_size_override("font_size", 22)
		var gg: String = g
		b.pressed.connect(func():
			fonte_scelta = gg
			_riempi_aeroporti())
		schede.add_child(b)
		bottoni_schede[g] = b
	_riempi_aeroporti()
	# dettaglio
	var pd := PanelContainer.new()
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pd.size_flags_stretch_ratio = 1.4
	h.add_child(pd)
	var sd := ScrollContainer.new()
	sd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pd.add_child(sd)
	dettaglio = VBoxContainer.new()
	dettaglio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dettaglio.add_theme_constant_override("separation", 12)
	sd.add_child(dettaglio)
	_mostra_dettaglio()

## Una scheda per aeroporto, con i suoi voli colorati per difficoltà
func _riempi_aeroporti() -> void:
	for g in bottoni_schede:
		var attiva: bool = g == fonte_scelta
		var b: Button = bottoni_schede[g]
		b.add_theme_stylebox_override("normal", Stile.scatola(Color("2a3f66") if attiva else Color("141c2b"), Stile.GIALLO if attiva else Color("3a4a66"), 8, 3 if attiva else 2))
		b.add_theme_stylebox_override("hover", Stile.scatola(Color("2f4874"), Color.WHITE, 8, 3))
		b.add_theme_stylebox_override("pressed", Stile.scatola(Color("2a3f66"), Stile.GIALLO, 8, 3))
		b.add_theme_color_override("font_color", Color.WHITE if attiva else Stile.TESTO_DEBOLE)
	for c in lista_aeroporti.get_children():
		lista_aeroporti.remove_child(c)
		c.queue_free()
	var ordine: Array = []
	var voli := {}
	for sc2 in Motore.scenari():
		if sc2["fonte"] != fonte_scelta:
			continue
		var k: String = sc2["codice"]
		if not voli.has(k):
			voli[k] = []
			ordine.append(k)
		voli[k].append(sc2)
	for k in ordine:
		var primo: Dictionary = voli[k][0]
		var scheda := PanelContainer.new()
		var dentro: bool = Motore.scenario(scelto_id).get("codice", "") == k and Motore.scenario(scelto_id).get("fonte", "") == fonte_scelta
		scheda.add_theme_stylebox_override("panel", Stile.scatola(Color("16223a") if dentro else Color("111827"), Stile.GIALLO if dentro else Color("2c3a55"), 10, 2))
		lista_aeroporti.add_child(scheda)
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 12)
		scheda.add_child(riga)
		var nomi := VBoxContainer.new()
		nomi.custom_minimum_size = Vector2(170, 0)
		nomi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nomi.add_theme_constant_override("separation", 0)
		riga.add_child(nomi)
		nomi.add_child(Stile.etichetta(k, 30, Color.WHITE, Stile.titolo()))
		var ln := Stile.etichetta(primo["nome"], 20, Stile.TESTO_DEBOLE)
		ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ln.custom_minimum_size = Vector2(150, 0)
		nomi.add_child(ln)
		var tasti := HFlowContainer.new()
		tasti.add_theme_constant_override("h_separation", 6)
		tasti.add_theme_constant_override("v_separation", 6)
		tasti.alignment = FlowContainer.ALIGNMENT_END
		tasti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tasti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		riga.add_child(tasti)
		for sc2 in voli[k]:
			var b := Button.new()
			var suff: String = sc2["id"].substr(k.length()).to_upper()
			b.text = "Volo %s" % suff if suff != "" else "Volo"
			b.custom_minimum_size = Vector2(104, 50)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_override("font", Stile.grassetto())
			b.add_theme_font_size_override("font_size", 20)
			var col: Color = Stile.DIFFICOLTA[sc2["colore"]]
			var nero: bool = sc2["colore"] == "nero"
			var bordo := col if not nero else Color("8a8f99")
			var sel: bool = sc2["id"] == scelto_id
			b.add_theme_stylebox_override("normal", Stile.scatola(col.darkened(0.45) if not nero else Color("101114"), Stile.GIALLO if sel else bordo, 8, 4 if sel else 3))
			b.add_theme_stylebox_override("hover", Stile.scatola(col.darkened(0.25) if not nero else Color("24262b"), Color.WHITE, 8, 3))
			b.add_theme_stylebox_override("pressed", Stile.scatola(col.darkened(0.2), Stile.GIALLO, 8, 4))
			b.tooltip_text = "%s %s" % [sc2["codice"], sc2["nome"]]
			var id: String = sc2["id"]
			b.pressed.connect(func():
				scelto_id = id
				abilita_scelte = {}
				_riempi_aeroporti.call_deferred()
				_mostra_dettaglio())
			tasti.add_child(b)
	var nota := Stile.etichetta("Colore del volo = difficoltà: verde facile, giallo media, rosso difficile, nero estrema.", 18, Stile.TESTO_DEBOLE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(250, 0)
	lista_aeroporti.add_child(nota)

func _mostra_dettaglio() -> void:
	for c in dettaglio.get_children():
		c.queue_free()
	var sc := Motore.scenario(scelto_id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	dettaglio.add_child(h)
	var img := TextureRect.new()
	img.texture = Stile.tex("res://assets/img/piste/%s.webp" % sc["pista"])
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	img.custom_minimum_size = Vector2(130, 520)
	h.add_child(img)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	h.add_child(v)
	var t := Stile.etichetta("%s  %s" % [sc["codice"], sc["nome"]], 40, Color.WHITE, Stile.titolo())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(Stile.etichetta("Difficoltà: " + Stile.NOMI_DIFFICOLTA[sc["colore"]], 26, Stile.DIFFICOLTA[sc["colore"]].lightened(0.25 if sc["colore"] != "nero" else 0.6), Stile.grassetto()))
	v.add_child(Stile.paragrafo(sc["testo"], 24))
	var mod := []
	for m in sc["moduli"]:
		mod.append(Partita.NOMI_MODULI.get(m, m))
	v.add_child(Stile.paragrafo("Moduli: " + (", ".join(mod) if not mod.is_empty() else "nessuno") + ".", 22, Stile.TESTO_DEBOLE))
	# opzioni
	var opz := VBoxContainer.new()
	opz.add_theme_constant_override("separation", 10)
	dettaglio.add_child(opz)
	opz.add_child(Stile.etichetta("IL TUO POSTO", 24, Stile.GIALLO, Stile.grassetto()))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	opz.add_child(hr)
	for c in 2:
		var b := Stile.bottone(Motore.nome_ruolo(c), 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ruolo == c:
			b.add_theme_stylebox_override("normal", Stile.scatola(Stile.BLU_SCURO if c == 0 else Stile.ARANCIO_SCURO, Stile.GIALLO, 10, 4))
		b.pressed.connect(func():
			ruolo = c
			if c == 1 and compagno == "automa":
				compagno = "ia"
			_mostra_dettaglio())
		hr.add_child(b)
	if online == "":
		opz.add_child(Stile.etichetta("IL TUO COMPAGNO", 24, Stile.GIALLO, Stile.grassetto()))
		var hc := HBoxContainer.new()
		hc.add_theme_constant_override("separation", 10)
		opz.add_child(hc)
		var bi := Stile.bottone("Compagno IA", 26)
		bi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if compagno == "ia":
			bi.add_theme_stylebox_override("normal", Stile.scatola(Color("23406f"), Stile.GIALLO, 10, 4))
		bi.pressed.connect(func(): compagno = "ia"; _mostra_dettaglio())
		hc.add_child(bi)
		var ba := Stile.bottone("Copilota Automa", 26)
		ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ba.disabled = ruolo == 1
		if compagno == "automa":
			ba.add_theme_stylebox_override("normal", Stile.scatola(Color("23406f"), Stile.GIALLO, 10, 4))
		ba.pressed.connect(func(): compagno = "automa"; _mostra_dettaglio())
		hc.add_child(ba)
		var nota := "Il compagno IA gioca come un giocatore vero: conosce solo i propri dadi e non comunica." if compagno == "ia" else "Variante solitario ufficiale: tu sei il Pilota, il Copilota segue le carte Automa (rilancia i suoi dadi e fa la prima azione possibile della carta)."
		opz.add_child(Stile.paragrafo(nota, 20, Stile.TESTO_DEBOLE))
	if not sc["moduli"].has("tempo"):
		var ct := CheckBox.new()
		ct.text = "Tempo reale: 60 secondi per round"
		ct.button_pressed = tempo_reale
		ct.focus_mode = Control.FOCUS_NONE
		ct.toggled.connect(func(v2): tempo_reale = v2)
		opz.add_child(ct)
	var n_ab: int = sc["abilita"]
	if n_ab > 0:
		opz.add_child(Stile.etichetta("ABILITÀ SPECIALI: SCEGLINE %d" % n_ab, 24, Stile.GIALLO, Stile.grassetto()))
		for a in Motore.ABILITA:
			var cb := CheckBox.new()
			cb.text = Testi.ABILITA[a][0]
			cb.button_pressed = abilita_scelte.get(a, false)
			cb.focus_mode = Control.FOCUS_NONE
			cb.toggled.connect(func(v3): abilita_scelte[a] = v3; _mostra_dettaglio())
			opz.add_child(cb)
			var hc2 := HBoxContainer.new()
			hc2.add_theme_constant_override("separation", 10)
			var tr := TextureRect.new()
			tr.texture = Stile.tex("res://assets/img/abilita/%s.webp" % a)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			tr.custom_minimum_size = Vector2(170, 112)
			hc2.add_child(tr)
			hc2.add_child(Stile.paragrafo(Testi.ABILITA[a][1], 19, Stile.TESTO_DEBOLE))
			opz.add_child(hc2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	dettaglio.add_child(hb)
	var indietro := Stile.bottone("Indietro", 28)
	indietro.pressed.connect(_home)
	hb.add_child(indietro)
	var scelte := []
	for a in abilita_scelte:
		if abilita_scelte[a]:
			scelte.append(a)
	var via := Stile.bottone("DECOLLA!" if online == "" else "CREA LA STANZA", 34)
	via.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	via.disabled = n_ab > 0 and scelte.size() != n_ab
	if via.disabled:
		via.text = "Scegli %d abilità" % n_ab
	via.pressed.connect(_parti)
	hb.add_child(via)
	if n_ab > 0:
		var caso := Stile.bottone("A caso", 26)
		caso.pressed.connect(func():
			abilita_scelte = {}
			var l: Array = Motore.ABILITA.duplicate()
			l.shuffle()
			for i in n_ab:
				abilita_scelte[l[i]] = true
			_mostra_dettaglio())
		hb.add_child(caso)

func _parti() -> void:
	var ab := []
	for a in abilita_scelte:
		if abilita_scelte[a]:
			ab.append(a)
	var seme := int(Time.get_unix_time_from_system()) % 1000000 + randi() % 100000
	var s := Motore.nuova(scelto_id, seme, {"abilita": ab, "tempo": tempo_reale})
	if online == "crea":
		_apri_stanza(s)
		return
	_gioca(s, ruolo, compagno)

func _gioca(s: Dictionary, colore: int, modo: String) -> void:
	_pulisci()
	partita = Partita.new()
	add_child(partita)
	partita.esci.connect(_esci_partita)
	partita.avvia(s, colore, modo, rete)
	partita._dopo()

func _esci_partita() -> void:
	if partita and (partita.modo == "host" or partita.modo == "ospite"):
		rete.chiudi()
	_home()

func _riprendi(j: String) -> void:
	var d = JSON.parse_string(j)
	if not d is Dictionary or not d.has("s"):
		stato_rete.text = "Il salvataggio non si legge."
		return
	var modo: String = d.get("modo", "ia")
	if modo == "host" or modo == "ospite":
		modo = "ia"
	_gioca(d["s"], int(d.get("io", 0)), modo)

# ------------------------------------------------------------------ online

var stanza_attesa: Dictionary = {}

func _apri_stanza(s: Dictionary) -> void:
	stanza_attesa = s
	_pulisci()
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schermo)
	_fondo(schermo)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(cc)
	var p := PanelContainer.new()
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(620, 0)
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	v.add_child(Stile.etichetta("STANZA ONLINE", 40, Color.WHITE, Stile.titolo()))
	stato_rete = Stile.paragrafo("Apro la stanza...", 30, Stile.GIALLO)
	v.add_child(stato_rete)
	v.add_child(Stile.paragrafo("Il tuo compagno apre Sky Team, scrive il codice e preme «Online: entra nella stanza». Oppure gli mandi il collegamento.", 22, Stile.TESTO_DEBOLE))
	var b := Stile.bottone("Annulla", 26)
	b.pressed.connect(func(): rete.chiudi(); _home())
	v.add_child(b)
	if not rete.web:
		stato_rete.text = "Il gioco online funziona solo nella versione per browser."
		return
	rete.avvia()

func _entra_codice(c: String) -> void:
	c = c.strip_edges().to_upper()
	if c.length() != 4:
		if stato_rete:
			stato_rete.text = "Il codice della stanza ha 4 lettere."
		return
	if not rete.web:
		if stato_rete:
			stato_rete.text = "Il gioco online funziona solo nella versione per browser."
		return
	if stato_rete:
		stato_rete.text = "Entro nella stanza %s..." % c
	rete.entra(c, "Compagno")

func _evento_rete(e: Dictionary) -> void:
	match e.get("e"):
		"stanza":
			if stato_rete:
				var link: String = str(e.get("url", "")).replace("telefono.html?s=", "?stanza=")
				stato_rete.text = "Codice della stanza: %s\n%s\nIn attesa del compagno..." % [e.get("codice", ""), link]
		"entra":
			if not stanza_attesa.is_empty() and partita == null:
				var s := stanza_attesa
				stanza_attesa = {}
				_pulisci()
				partita = Partita.new()
				add_child(partita)
				partita.nome_altro = str(e.get("nome", ""))
				partita.esci.connect(_esci_partita)
				partita.avvia(s, ruolo, "host", rete)
				partita._dopo()
		"azione":
			if partita and partita.modo == "host":
				var a = JSON.parse_string(str(e.get("p", "")))
				if a is Dictionary:
					partita.mossa_remota(a)
		"dentro":
			if stato_rete:
				stato_rete.text = "Dentro! Aspetto il tavolo..."
		"stato":
			var d = JSON.parse_string(str(e.get("j", "")))
			if not d is Dictionary or not d.has("s"):
				return
			if partita == null:
				var st: Dictionary = d["s"]
				_pulisci()
				partita = Partita.new()
				add_child(partita)
				partita.esci.connect(_esci_partita)
				# l'ospite prende il posto lasciato libero da chi ospita
				var colore_host: int = int(d.get("host", 0))
				partita.avvia(st, 1 - colore_host, "ospite", rete)
			else:
				partita.ricevi(d["s"])
			if d.has("errore"):
				partita._avviso(str(d["errore"]))
		"salvataggio":
			var j := str(e.get("j", ""))
			if j == "":
				if stato_rete:
					stato_rete.text = "Nessun volo salvato online."
			else:
				_riprendi(j)
		"errore":
			if stato_rete:
				stato_rete.text = "Errore: " + str(e.get("msg", ""))
			elif partita:
				partita._avviso("Rete: " + str(e.get("msg", "")))
