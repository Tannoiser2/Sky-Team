class_name Vista3D
extends SubViewportContainer
## Vista 3D dell'avvicinamento: in alto l'aereo (modellino del modulo, con flap e carrello che si muovono),
## sotto la rotta che scende fino alla pista. La rotta piega a destra o a sinistra dove c'è una virata
## e lì mostra un arco con le inclinazioni permesse (verdi) e vietate (rosse).
## Sul traguardo di ogni casella ci sono gli aerei del traffico (o i pinguini).
## Sotto l'aereo c'è un basamento con gli indicatori: caffè, carrello, flap, freni, rilanci, cherosene.
## Comandi: mouse (sinistro ruota, destro sposta, rotella zoom) e tocco (un dito sposta, due dita pizzicano e ruotano).

const D := 3.0              # distanza tra due caselle
const HMAX := 8.0          # altezza a 6000 piedi
const SCALA_AEREO := 0.5
const GRADI_VIRATA := 28.0   # gradi di curva per ogni tacca di inclinazione richiesta

var vp: SubViewport
var mondo: Node3D
var cam: Camera3D
var aereo: Node3D
var flap_nodi: Array = []
var ruote: Array = []
var basamento: Node3D
var nodo_rotta: Node3D
var nodo_traffico: Node3D
var filo: MeshInstance3D
var env: Environment

var s: Dictionary = {}
var pista_attuale := ""
var punti: Array = []        # per ogni segmento i -> i+1: Array di Vector3 (curva campionata)
var nodi_casella: Array = [] # posizione del traguardo di ogni casella
var rotte_ang: Array = []    # direzione (radianti) all'arrivo in ogni casella
var ultima := 0

# animazione dell'aereo
var t_attuale := 0.0         # posizione lungo la rotta (in caselle, frazionaria)
var t_meta := 0.0
var rollio := 0.0
var quota_vis := 0.0
var scossa := 0.0

# telecamera
var yaw := 0.0
var pitch := -0.16
var zoom := 1.0
var h_cam := 0.0
var dist_fit := 0.0
var bersaglio := Vector3.ZERO
var spost := Vector3.ZERO
var tocchi := {}
var segue := true

var mat_cache := {}
var lampade := {}
var tazzine: Array = []
var gettoni: Array = []
var barra_kero: MeshInstance3D
var et_kero: Label3D
var et_quota: Label3D

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	add_child(vp)
	mondo = Node3D.new()
	vp.add_child(mondo)
	_ambiente()
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 900
	mondo.add_child(cam)
	nodo_rotta = Node3D.new()
	mondo.add_child(nodo_rotta)
	nodo_traffico = Node3D.new()
	mondo.add_child(nodo_traffico)
	_crea_aereo()
	_crea_basamento()
	filo = MeshInstance3D.new()
	mondo.add_child(filo)

# ------------------------------------------------------------------ materiali

func _mat(col: Color, luce := false, trasp := false) -> StandardMaterial3D:
	var k := "%s%s%s" % [col.to_html(), luce, trasp]
	if mat_cache.has(k):
		return mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	if luce:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if trasp or col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cache[k] = m
	return m

func _box(dim: Vector3, col: Color, luce := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = dim
	mi.mesh = b
	mi.material_override = _mat(col, luce)
	return mi

func _sfera(r: float, col: Color, luce := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2
	b.radial_segments = 16
	b.rings = 8
	mi.mesh = b
	mi.material_override = _mat(col, luce)
	return mi

func _cilindro(r: float, h: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = r
	b.bottom_radius = r
	b.height = h
	b.radial_segments = 24
	mi.mesh = b
	mi.material_override = _mat(col)
	return mi

func _etichetta(t: String, dim := 48, col := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = Stile.grassetto()
	l.font_size = dim
	l.pixel_size = 0.0065
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	return l

# ------------------------------------------------------------------ scena fissa

func _ambiente() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2f5f9e")
	sm.sky_horizon_color = Color("a9c4df")
	sm.ground_horizon_color = Color("8aa0b4")
	sm.ground_bottom_color = Color("3c4a3a")
	sm.sun_angle_max = 20
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = false
	env.fog_light_color = Color("a9bfd6")
	env.fog_density = 0.004
	we.environment = env
	mondo.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 0.75
	sole.rotation_degrees = Vector3(-50, 35, 0)
	sole.shadow_enabled = false
	mondo.add_child(sole)

func _crea_aereo() -> void:
	aereo = Node3D.new()
	mondo.add_child(aereo)
	var corpo := Node3D.new()
	corpo.rotation_degrees.y = 180          # il modello ha il muso verso +z
	corpo.scale = Vector3.ONE * SCALA_AEREO
	aereo.add_child(corpo)
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://assets/modelli/aereo.obj")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("e9edf2")
	m.roughness = 0.55
	m.metallic = 0.15
	mi.material_override = m
	corpo.add_child(mi)
	# fascia blu e arancione sulla fusoliera (i colori di Pilota e Copilota)
	var f1 := _box(Vector3(0.08, 0.07, 4.6), Stile.BLU)
	f1.position = Vector3(-0.27, -0.2, 0.2)
	corpo.add_child(f1)
	var f2 := _box(Vector3(0.08, 0.07, 4.6), Stile.ARANCIO)
	f2.position = Vector3(0.27, -0.2, 0.2)
	corpo.add_child(f2)
	# flap: 4 per ala, dall'esterno all'interno; si abbassano quando sono estesi
	var flap_dati := [[2.675, -1.055], [2.5, -0.925], [2.325, -0.8], [2.155, -0.685]]
	for k in 4:
		var coppia := []
		for lato in [-1.0, 1.0]:
			var perno := Node3D.new()
			perno.position = Vector3(lato * flap_dati[k][0], -0.215, flap_dati[k][1] + 0.17)
			var b := _box(Vector3(0.09, 0.07, 0.34), Color("c9d0d8"))
			b.position = Vector3(0, 0, -0.17)
			perno.add_child(b)
			corpo.add_child(perno)
			coppia.append(perno)
		flap_nodi.append(coppia)
	# carrello: anteriore, sinistro, destro (nasce dentro e scende quando è estratto)
	var posti := [Vector3(0, -0.55, 2.3), Vector3(-0.42, -0.55, -0.15), Vector3(0.42, -0.55, -0.15)]
	for k in 3:
		var g := Node3D.new()
		g.position = posti[k]
		var gamba := _box(Vector3(0.05, 0.38, 0.05), Color("7c838c"))
		gamba.position = Vector3(0, -0.19, 0)
		g.add_child(gamba)
		for dx in ([-0.07, 0.07] if k == 0 else [-0.09, 0.09]):
			var r := _cilindro(0.09, 0.07, Color("1d1f22"))
			r.rotation_degrees.z = 90
			r.position = Vector3(dx, -0.4, 0)
			g.add_child(r)
		g.scale = Vector3(1, 0.01, 1)
		g.visible = false
		corpo.add_child(g)
		ruote.append(g)

func _crea_basamento() -> void:
	# plinto rettangolare sotto l'aereo, sempre girato verso la telecamera:
	# fila davanti carrello, flap e freni; fila dietro (più alta) caffè, rilanci e cherosene
	basamento = Node3D.new()
	basamento.scale = Vector3.ONE * 0.8
	mondo.add_child(basamento)
	var lastra := _box(Vector3(3.3, 0.16, 0.7), Color("56627a"))
	lastra.position = Vector3(0, 0, 0.35)
	basamento.add_child(lastra)
	var gradino := _box(Vector3(3.3, 0.36, 0.7), Color("47526a"))
	gradino.position = Vector3(0, 0.1, -0.35)
	basamento.add_child(gradino)
	var filetto := _box(Vector3(3.34, 0.04, 0.04), Color("b48a1c"))
	filetto.position = Vector3(0, 0.08, 0.71)
	basamento.add_child(filetto)
	var asta := _cilindro(0.04, 1.0, Color(0.85, 0.9, 1.0, 0.5))
	asta.name = "Asta"
	basamento.add_child(asta)
	var y1 := 0.1
	var z1 := 0.38
	_gruppo("CARRELLO", Vector3(-1.05, -0.24, 0.78))
	for i in 3:
		_lampada("car%d" % i, Vector3(-1.3 + i * 0.25, y1, z1))
	_gruppo("FLAP", Vector3(0.0, -0.24, 0.78))
	for i in 4:
		_lampada("flap%d" % i, Vector3(-0.375 + i * 0.25, y1, z1))
	_gruppo("FRENI", Vector3(1.05, -0.24, 0.78))
	for i in 3:
		_lampada("fre%d" % i, Vector3(0.8 + i * 0.25, y1, z1), Stile.ROSSO)
	var y2 := 0.3
	var z2 := -0.35
	_gruppo("CAFFÈ", Vector3(-1.05, 0.78, z2))
	for i in 3:
		var t := MeshInstance3D.new()
		t.mesh = load("res://assets/modelli/tazzina.obj")
		var mt := StandardMaterial3D.new()
		mt.albedo_texture = load("res://assets/modelli/tazzina.webp")
		mt.roughness = 0.6
		t.material_override = mt
		t.scale = Vector3.ONE * 0.055
		t.position = Vector3(-1.32 + i * 0.27, y2, z2)
		basamento.add_child(t)
		tazzine.append(t)
	_gruppo("RILANCI", Vector3(0.0, 0.78, z2))
	var tex_r := load("res://assets/img/moduli/rilancio.webp")
	for i in 3:
		var g := _cilindro(0.11, 0.05, Color("1b2a44"))
		g.position = Vector3(-0.27 + i * 0.27, y2 + 0.03, z2)
		var cima := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.21, 0.21)
		cima.mesh = q
		var mq := StandardMaterial3D.new()
		mq.albedo_texture = tex_r
		mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		cima.material_override = mq
		cima.rotation_degrees.x = -90
		cima.position.y = 0.03
		g.add_child(cima)
		basamento.add_child(g)
		gettoni.append(g)
	barra_kero = _box(Vector3(0.5, 0.12, 0.12), Color("49d17c"))
	basamento.add_child(barra_kero)
	et_kero = _etichetta("", 30, Stile.GIALLO)
	basamento.add_child(et_kero)
	et_quota = _etichetta("", 44, Color.WHITE)
	mondo.add_child(et_quota)

func _gruppo(t: String, p: Vector3) -> void:
	var l := _etichetta(t, 30, Color("dfe7f5"))
	l.position = p
	basamento.add_child(l)

func _lampada(nome: String, p: Vector3, col := Color("49d17c")) -> void:
	var zoccolo := _cilindro(0.1, 0.05, Color("15181c"))
	zoccolo.position = p - Vector3(0, 0.03, 0)
	basamento.add_child(zoccolo)
	var sf := _sfera(0.075, col, true)
	sf.position = p + Vector3(0, 0.04, 0)
	basamento.add_child(sf)
	lampade[nome] = [sf, col]

# ------------------------------------------------------------------ rotta

func _dir(h: float) -> Vector3:
	return Vector3(sin(h), 0, -cos(h))

## Inclinazione media permessa dalla virata (da -2 a +2) e se c'è una virata
func _virata(v: String) -> Array:
	if v == "" or not "x" in v:
		return [0.0, false]
	var somma := 0.0
	var n := 0
	for k in 5:
		if v[k] == "o":
			somma += k - 2
			n += 1
	return [somma / max(1, n), true]

func _costruisci_rotta() -> void:
	for c in nodo_rotta.get_children():
		nodo_rotta.remove_child(c)
		c.queue_free()
	var dp: Dictionary = Motore.piste()[s["pista"]]
	var cas: Array = dp["caselle"]
	ultima = cas.size() - 1
	punti = []
	nodi_casella = []
	rotte_ang = []
	var h := 0.0
	var p := Vector3(0, HMAX, 0)
	# la rotta parte dalla quota attuale dell'aereo e scende fino alla pista:
	# più è ripida, più in fretta bisogna perdere quota
	var pos0 := int(s["pos"])
	var alt0 := HMAX * (6 - clampi(int(s["quota"]), 0, 6)) / 6.0
	nodi_casella.append(Vector3(0, alt0, 0))
	rotte_ang.append(0.0)
	for i in ultima:
		var vi := _virata(cas[i].get("v", ""))
		# la rotta curva verso l'inclinazione richiesta dalla virata (almeno 25 gradi)
		var giro: float = 0.0
		if absf(vi[0]) > 0.01:
			giro = signf(vi[0]) * maxf(25.0, GRADI_VIRATA * absf(vi[0]))
		var h2: float = h + deg_to_rad(giro)
		var y0: float = alt0 if i <= pos0 else alt0 * (1.0 - float(i - pos0) / maxi(1, ultima - pos0))
		var y1: float = alt0 if i + 1 <= pos0 else alt0 * (1.0 - float(i + 1 - pos0) / maxi(1, ultima - pos0))
		var a := Vector3(p.x, y0, p.z)
		var ctrl := a + _dir(h) * D * 0.5
		var b := ctrl + _dir(h2) * D * 0.5
		b.y = y1
		var pts := []
		for k in 13:
			var t := k / 12.0
			var q := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			q.y = lerp(y0, y1, t)
			pts.append(q)
		punti.append(pts)
		var seg := Node3D.new()
		seg.name = "Segmento%d" % i
		nodo_rotta.add_child(seg)
		_nastro(seg, pts, vi[0] if vi[1] else 0.0)
		if vi[1]:
			_arco_virata(seg, pts[6], (pts[7] - pts[5]).normalized(), cas[i]["v"])
		p = b
		h = h2
		nodi_casella.append(b)
		rotte_ang.append(h)
	for i in nodi_casella.size():
		_traguardo(i, cas[i])
	_terreno_e_pista(nodi_casella[-1], h)

func _nastro(dove: Node3D, pts: Array, banca: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var largo := 0.7
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var tan := (b - a).normalized()
		var lat := tan.cross(Vector3.UP).normalized()
		var r1 := sin(PI * k / 12.0) * deg_to_rad(18.0) * banca
		var r2 := sin(PI * (k + 1) / 12.0) * deg_to_rad(18.0) * banca
		var la := lat.rotated(tan, r1) * largo
		var lb := lat.rotated(tan, r2) * largo
		for v in [a - la, a + la, b + lb, a - la, b + lb, b - lb]:
			st.set_color(Color(0.35, 0.85, 1.0, 0.28))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	dove.add_child(mi)
	# linea centrale tratteggiata
	for k in range(0, pts.size() - 1, 2):
		var a2: Vector3 = pts[k]
		var b2: Vector3 = pts[k + 1]
		var tr := _box(Vector3(0.08, 0.04, a2.distance_to(b2) * 0.9), Color(1, 1, 1, 0.8), true)
		tr.position = (a2 + b2) * 0.5
		dove.add_child(tr)
		tr.look_at_from_position(tr.position, b2, Vector3.UP)

func _arco_virata(dove: Node3D, c: Vector3, tan: Vector3, v: String) -> void:
	var n := Node3D.new()
	n.position = c
	dove.add_child(n)
	n.look_at_from_position(c, c + tan, Vector3.UP)
	for k in 5:
		var ok: bool = v[k] == "o"
		var ang := deg_to_rad((k - 2) * 25.0)
		var bar := _box(Vector3(0.1, 0.5, 0.08), Color("49d17c") if ok else Color("e2392f"), true)
		var r := 1.25
		bar.position = Vector3(sin(ang) * r, cos(ang) * r - 0.3, 0)
		bar.rotation.z = -ang
		n.add_child(bar)
	var l := _etichetta("VIRATA", 60, Color("ffcb2f"))
	l.position = Vector3(0, 1.55, 0)
	n.add_child(l)

func _traguardo(i: int, c: Dictionary) -> void:
	var p: Vector3 = nodi_casella[i]
	var n := Node3D.new()
	n.name = "Traguardo%d" % i
	n.position = p
	n.rotation.y = -rotte_ang[i]
	nodo_rotta.add_child(n)
	var col := Color(0.8, 0.95, 1.0, 0.55)
	if i == ultima:
		col = Color(1, 0.8, 0.2, 0.8)
	for parte in [[Vector3(0, 0.6, 0), Vector3(1.7, 0.06, 0.06)], [Vector3(0, -0.1, 0), Vector3(1.7, 0.06, 0.06)],
			[Vector3(-0.85, 0.25, 0), Vector3(0.06, 0.76, 0.06)], [Vector3(0.85, 0.25, 0), Vector3(0.06, 0.76, 0.06)]]:
		var b := _box(parte[1], col, true)
		b.position = parte[0]
		n.add_child(b)
	var testi := []
	var t := int(c.get("t", 0))
	if t > 0:
		testi.append("traffico +%d" % t if t > 1 else "traffico")
	if int(c.get("a", 0)) > 0:
		testi.append("allarme")
	if int(c.get("m", 0)) == 1:
		testi.append("rumore")
	if i == ultima:
		testi.append(Motore.scenario(s["scenario"]).get("codice", ""))
	if not testi.is_empty():
		var l := _etichetta("  ".join(testi), 64, Color("ffd36b") if i < ultima else Color.WHITE)
		l.position = Vector3(0, -0.38, 0)
		l.name = "Info"
		n.add_child(l)

func _terreno_e_pista(fine: Vector3, h: float) -> void:
	var ghiaccio: bool = Motore.ha(s, "ghiaccio") or s["speciale"] == "nzir"
	var t := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	t.mesh = pm
	t.material_override = _mat(Color("dfe8ef") if ghiaccio else Color("4f6b43"))
	t.position = Vector3(fine.x, -0.05, fine.z - 100)
	nodo_rotta.add_child(t)
	# campi e strade, per dare profondità
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(s["pista"])
	for k in 70:
		var c := Color("5d7a4c") if k % 3 else Color("6b7f4a")
		if ghiaccio:
			c = Color("c9d6e0") if k % 2 else Color("eef3f7")
		var b := _box(Vector3(rng.randf_range(6, 22), 0.02, rng.randf_range(6, 22)), c)
		b.position = Vector3(rng.randf_range(-90, 90), -0.03, rng.randf_range(-140, 40)) + Vector3(fine.x, 0, fine.z * 0.5)
		b.rotation.y = rng.randf_range(0, PI)
		nodo_rotta.add_child(b)
	# pista d'atterraggio
	var n := Node3D.new()
	n.position = Vector3(fine.x, 0, fine.z)
	n.rotation.y = -h
	nodo_rotta.add_child(n)
	var asfalto := _box(Vector3(1.6, 0.06, 6), Color("3a3d42") if not ghiaccio else Color("b8c7d3"))
	asfalto.position = Vector3(0, 0, -2.3)
	n.add_child(asfalto)
	for k in 5:
		var r := _box(Vector3(0.1, 0.02, 0.6), Color.WHITE)
		r.position = Vector3(0, 0.05, 0.3 - k * 1.15)
		n.add_child(r)
	for lato in [-1.0, 1.0]:
		for k in 4:
			var lu := _sfera(0.05, Color("ffcb2f"), true)
			lu.position = Vector3(lato * 1.0, 0.08, 0.8 - k * 2.0)
			n.add_child(lu)
	var cod := _etichetta(Motore.scenario(s["scenario"]).get("codice", ""), 120, Color.WHITE)
	cod.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	cod.rotation_degrees.x = -90
	cod.position = Vector3(0, 0.06, -4.6)
	cod.pixel_size = 0.006
	n.add_child(cod)

# ------------------------------------------------------------------ stato

func imposta(stato: Dictionary) -> void:
	var nuova: bool = s.is_empty() or s.get("pista") != stato.get("pista") or s.get("scenario") != stato.get("scenario")
	var pos_prima: int = int(s.get("pos", 0))
	var quota_prima: int = int(s.get("quota", -1))
	s = stato
	if nuova or int(s["pos"]) != pos_prima or int(s["quota"]) != quota_prima:
		_costruisci_rotta()
	if nuova:
		t_attuale = float(s["pos"])
		t_meta = t_attuale
		quota_vis = float(s["quota"])
		centra()
		bersaglio = Vector3.ZERO
		dist_fit = 0.0
		h_cam = 0.0
	elif int(s["pos"]) != pos_prima:
		t_meta = float(s["pos"])
	_traffico()
	_indicatori()
	for i in nodi_casella.size():
		var tr := nodo_rotta.get_node_or_null("Traguardo%d" % i)
		if tr:
			tr.visible = i >= int(s["pos"])
		var sg := nodo_rotta.get_node_or_null("Segmento%d" % i)
		if sg:
			sg.visible = i >= int(s["pos"])
		var info := nodo_rotta.get_node_or_null("Traguardo%d/Info" % i)
		if info:
			info.visible = i != int(s["pos"]) or i == ultima
	var eff := Motore.effetti_quota(s)
	env.fog_enabled = "n" in eff
	env.fog_density = 0.02
	scossa = 1.0 if "t" in eff else 0.0

func _traffico() -> void:
	for c in nodo_traffico.get_children():
		c.queue_free()
	var mesh: Mesh = load("res://assets/modelli/aereo.obj")
	var tex_p: Texture2D = Stile.tex("res://assets/img/moduli/pinguino.webp")
	for i in s["aerei"].size():
		var n: int = s["aerei"][i]
		if n <= 0:
			continue
		var base: Vector3 = nodi_casella[i]
		var h: float = rotte_ang[i]
		var lat := _dir(h).cross(Vector3.UP).normalized()
		for j in n:
			var off: float = (j - (n - 1) * 0.5) * 0.6
			var p := base + lat * off + Vector3(0, 0.25, 0)
			if s["pinguini"]:
				var sp := Sprite3D.new()
				sp.texture = tex_p
				sp.pixel_size = 0.005
				sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				sp.position = Vector3(p.x, 0.45, p.z) if i == ultima else p
				nodo_traffico.add_child(sp)
			else:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = _mat(Color("8d96a3"))
				mi.scale = Vector3.ONE * 0.12
				mi.position = p
				mi.rotation.y = -h
				nodo_traffico.add_child(mi)

func _indicatori() -> void:
	for i in 3:
		_accendi("car%d" % i, s["carrello"][i])
		_accendi("fre%d" % i, s["freni"][i] if not Motore.ha(s, "ghiaccio") else i < int(s["ghiaccio"]))
		tazzine[i].visible = i < int(s["caffe"])
		gettoni[i].visible = i < int(s["rilanci"])
	for i in 4:
		_accendi("flap%d" % i, s["flap"][i])
	var kero_on: bool = Motore.ha(s, "cherosene") or Motore.ha(s, "perdita")
	barra_kero.visible = kero_on
	et_kero.visible = kero_on
	if kero_on:
		var v: int = s["cherosene"]
		var h := maxf(0.04, (v + 3) / 23.0)
		barra_kero.scale = Vector3(h, 1, 1)
		barra_kero.position = Vector3(0.8 + h * 0.25, 0.34, -0.35)
		barra_kero.material_override = _mat(Color("49d17c").lerp(Stile.ROSSO, clampf(1.0 - v / 14.0, 0, 1)))
		et_kero.text = "CHEROSENE %d" % v
		et_kero.position = Vector3(1.05, 0.78, -0.35)
	var nomi_q := ["6000 piedi", "5000 piedi", "4000 piedi", "3000 piedi", "2000 piedi", "1000 piedi", "atterraggio"]
	et_quota.text = nomi_q[clampi(s["quota"], 0, 6)]

func _accendi(nome: String, acceso: bool) -> void:
	var l: Array = lampade[nome]
	var col: Color = l[1]
	l[0].material_override = _mat(col if acceso else Color("8a93a3"), acceso)

# ------------------------------------------------------------------ movimento

func _posizione_rotta(t: float) -> Vector3:
	if punti.is_empty():
		return Vector3.ZERO
	var i := clampi(int(floor(t)), 0, punti.size() - 1)
	var f := clampf(t - i, 0.0, 1.0)
	if t >= punti.size():
		return punti[-1][-1]
	var pts: Array = punti[i]
	var x := f * 12.0
	var k := clampi(int(x), 0, 11)
	return (pts[k] as Vector3).lerp(pts[k + 1], x - k)

func _angolo_rotta(t: float) -> float:
	var a := _posizione_rotta(maxf(0.0, t - 0.05))
	var b := _posizione_rotta(t + 0.05)
	var d := b - a
	d.y = 0
	if d.length() < 0.001:
		return rotte_ang[clampi(int(round(t)), 0, rotte_ang.size() - 1)] if not rotte_ang.is_empty() else 0.0
	return atan2(d.x, -d.z)

func _process(dt: float) -> void:
	if s.is_empty() or not is_visible_in_tree():
		return
	t_attuale = move_toward(t_attuale, t_meta, dt * 1.4)
	quota_vis = move_toward(quota_vis, float(s["quota"]), dt * 0.8)
	var a: int = s["asse"]
	rollio = lerp(rollio, deg_to_rad(a * 13.0), clampf(dt * 3.0, 0, 1))
	var p := _posizione_rotta(t_attuale)
	var y := HMAX * (6.0 - quota_vis) / 6.0
	if quota_vis >= 5.99:
		y = 0.75
	var tm := Time.get_ticks_msec() / 1000.0
	var bob := sin(tm * 1.3) * 0.06 + scossa * (sin(tm * 17.0) * 0.05 + sin(tm * 11.0) * 0.04)
	var pa := Vector3(p.x, y + 0.9 + bob, p.z)
	aereo.position = pa
	var h := _angolo_rotta(t_attuale)
	aereo.rotation = Vector3(0, -h, 0)
	aereo.rotate_object_local(Vector3(0, 0, 1), -rollio)
	# flap e carrello
	for k in 4:
		var target := deg_to_rad(28.0) if s["flap"][k] else 0.0
		for perno in flap_nodi[k]:
			perno.rotation.x = lerp(perno.rotation.x, target, clampf(dt * 3.0, 0, 1))
	for k in 3:
		var g: Node3D = ruote[k]
		var giu: bool = s["carrello"][k] if s["speciale"] != "waw" else false
		g.scale.y = move_toward(g.scale.y, 1.0 if giu else 0.01, dt * 1.5)
		g.visible = g.scale.y > 0.05
	# basamento sotto l'aereo
	basamento.position = pa - Vector3(0, 1.3, 0) - _dir(h).cross(Vector3.UP).normalized() * 3.0
	var vc := cam.global_position - basamento.position
	basamento.rotation = Vector3(0, atan2(vc.x, vc.z), 0)
	basamento.rotate_object_local(Vector3.RIGHT, deg_to_rad(30))
	var asta := basamento.get_node("Asta") as MeshInstance3D
	asta.visible = false
	et_quota.position = pa + Vector3(0, 1.1, 0)
	# telecamera: dietro l'aereo, guarda verso la pista; l'aereo resta in alto e la pista in basso
	var arrivo: Vector3 = nodi_casella[-1]
	var verso := arrivo - pa
	verso.y = 0
	var hv := atan2(verso.x, -verso.z) if verso.length() > 1.0 else h
	if segue:
		# sempre alle spalle dell'aereo: destra e sinistra dello schermo sono quelle del pilota
		var hm := lerp_angle(h, hv, 0.35)
		h_cam = hm if dist_fit <= 0.0 else lerp_angle(h_cam, hm, clampf(dt * 1.5, 0, 1))
	# su schermi stretti si guarda più da dietro, così la discesa resta verticale
	var asp := size.x / maxf(1.0, size.y)
	var k := clampf((asp - 0.4) / 0.35, 0.0, 1.0)
	var ya := yaw + lerpf(0.18, 0.3, k)
	var pi_ := clampf(pitch - lerpf(0.06, 0.0, k), -1.45, 0.25)
	var dir := Vector3(-sin(h_cam - ya) * cos(pi_), -sin(pi_), cos(h_cam - ya) * cos(pi_))
	var fit := _inquadra(pa, dir)
	if segue:
		bersaglio = bersaglio.lerp(fit[0], clampf(dt * 2.5, 0, 1)) if bersaglio != Vector3.ZERO else fit[0]
		dist_fit = lerpf(dist_fit, fit[1], clampf(dt * 2.5, 0, 1)) if dist_fit > 0 else fit[1]
	var centro := bersaglio + spost
	cam.position = centro + dir * dist_fit * zoom
	cam.look_at(centro, Vector3.UP)

## Centro e distanza perché aereo, basamento, rotta e pista stiano tutti nell'inquadratura
func _inquadra(pa: Vector3, dir: Vector3) -> Array:
	var pts: Array = []
	var dx := dir.cross(Vector3.UP).normalized()
	pts.append(pa + Vector3(0, 1.3, 0))
	pts.append(pa + dx * 1.6)
	pts.append(pa - dx * 1.6)
	pts.append(pa - _dir(rotte_ang[0]) * 1.8)
	pts.append(basamento.position + Vector3(0, -0.5, 0) + dx * 1.45)
	pts.append(basamento.position + Vector3(0, -0.5, 0) - dx * 1.45)
	pts.append(basamento.position + Vector3(0, 0.9, 0))
	for i in range(int(s["pos"]), nodi_casella.size()):
		var lat := _dir(rotte_ang[i]).cross(Vector3.UP).normalized()
		pts.append(nodi_casella[i] + lat * 1.4 + Vector3(0, 0.8, 0))
		pts.append(nodi_casella[i] - lat * 1.4 + Vector3(0, 0.8, 0))
	var fine: Vector3 = nodi_casella[-1]
	pts.append(fine + _dir(rotte_ang[-1]) * 4.0)
	var c := Vector3.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	var avanti := -dir
	var destra := avanti.cross(Vector3.UP).normalized()
	var su := destra.cross(avanti).normalized()
	var aspetto := size.x / maxf(1.0, size.y)
	var tv := tan(deg_to_rad(cam.fov * 0.5)) * 0.88
	var to := tv * aspetto
	# due passate: la prima trova la distanza, la seconda centra il riquadro e la ricalcola
	var d := 1.0
	for passata in 2:
		d = 1.0
		var minx := INF
		var maxx := -INF
		var miny := INF
		var maxy := -INF
		for q in pts:
			var r: Vector3 = q - c
			var x := r.dot(destra)
			var y := r.dot(su)
			var z := r.dot(avanti)
			d = maxf(d, maxf(absf(x) / to, absf(y) / tv) - z)
		for q in pts:
			var r: Vector3 = q - c
			var prof := d + r.dot(avanti)
			var x := r.dot(destra) / prof
			var y := r.dot(su) / prof
			minx = minf(minx, x)
			maxx = maxf(maxx, x)
			miny = minf(miny, y)
			maxy = maxf(maxy, y)
		if passata == 0:
			c += destra * (minx + maxx) * 0.5 * d + su * (miny + maxy) * 0.5 * d
	return [c, d]

# ------------------------------------------------------------------ comandi

func centra() -> void:
	yaw = 0.0
	pitch = -0.16
	zoom = 1.0
	spost = Vector3.ZERO
	segue = true

func _sposta(d: Vector2) -> void:
	var dx := cam.global_transform.basis.x
	var dz := cam.global_transform.basis.z
	dz.y = 0
	dz = dz.normalized()
	spost += (-dx * d.x + -dz * d.y) * zoom * 0.03

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 0.9, 0.15, 3.0)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom * 1.1, 0.15, 3.0)
			accept_event()
		elif e.double_click:
			centra()
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION:
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= e.relative.x * 0.006
			pitch = clampf(pitch + e.relative.y * 0.005, -1.45, 0.25)
			accept_event()
		elif e.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_sposta(e.relative)
			accept_event()
	elif e is InputEventMagnifyGesture:
		zoom = clampf(zoom / e.factor, 0.15, 3.0)
	elif e is InputEventPanGesture:
		zoom = clampf(zoom * (1.0 + e.delta.y * 0.05), 0.15, 3.0)
	elif e is InputEventScreenTouch:
		if e.pressed:
			tocchi[e.index] = e.position
			if e.double_tap:
				centra()
		else:
			tocchi.erase(e.index)
		accept_event()
	elif e is InputEventScreenDrag:
		if not tocchi.has(e.index):
			tocchi[e.index] = e.position
		var prima: Vector2 = tocchi[e.index]
		if tocchi.size() == 1:
			# un dito: sposta la vista
			_sposta(e.relative)
		elif tocchi.size() >= 2:
			var altro := -1
			for k in tocchi:
				if k != e.index:
					altro = k
					break
			var q: Vector2 = tocchi[altro]
			var d0 := prima.distance_to(q)
			var d1: float = e.position.distance_to(q)
			if d0 > 10 and d1 > 10:
				# pizzico: zoom
				zoom = clampf(zoom * d0 / d1, 0.15, 3.0)
				# rotazione con due dita
				var a0 := (prima - q).angle()
				var a1: float = (e.position - q).angle()
				yaw += wrapf(a1 - a0, -PI, PI)
				# due dita su e giù: inclinazione
				pitch = clampf(pitch + e.relative.y * 0.0025, -1.45, 0.25)
		tocchi[e.index] = e.position
		accept_event()
