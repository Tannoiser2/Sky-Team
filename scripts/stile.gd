class_name Stile
extends RefCounted
## Colori, font e piccoli aiuti grafici condivisi.

const BLU := Color("2f5bd3")
const BLU_SCURO := Color("1a2f74")
const ARANCIO := Color("f07a1e")
const ARANCIO_SCURO := Color("8a3a0a")
const FONDO := Color("0b1220")
const PANNELLO := Color("152035")
const BORDO := Color("3c5378")
const TESTO := Color("e9eef7")
const TESTO_DEBOLE := Color("9aa8bf")
const GIALLO := Color("ffcb2f")
const VERDE := Color("49d17c")
const ROSSO := Color("ff4b4b")

const DIFFICOLTA := {
	"verde": Color("5bbf3a"),
	"giallo": Color("f2c21b"),
	"rosso": Color("e0342b"),
	"nero": Color("1c1c1c"),
}
const NOMI_DIFFICOLTA := {"verde": "Facile", "giallo": "Media", "rosso": "Difficile", "nero": "Estrema"}

static var _font := {}

static func font(nome: String) -> Font:
	if not _font.has(nome):
		_font[nome] = load("res://assets/font/%s.ttf" % nome)
	return _font[nome]

static func titolo() -> Font:
	return font("Montserrat-ExtraBold")

static func testo() -> Font:
	return font("BarlowCondensed-SemiBold")

static func grassetto() -> Font:
	return font("BarlowCondensed-Bold")

static func cifre() -> Font:
	return font("Montserrat-Bold")

static var _tex := {}

static func tex(percorso: String) -> Texture2D:
	if not _tex.has(percorso):
		_tex[percorso] = load(percorso)
	return _tex[percorso]

static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = testo()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TESTO)
	for k in ["Button", "CheckBox", "CheckButton", "OptionButton"]:
		t.set_color("font_color", k, TESTO)
		t.set_color("font_hover_color", k, Color.WHITE)
		t.set_color("font_pressed_color", k, Color.WHITE)
		t.set_color("font_disabled_color", k, Color(1, 1, 1, 0.35))
		t.set_font("font", k, grassetto())
		t.set_font_size("font_size", k, 26)
	t.set_stylebox("normal", "Button", scatola(Color("23406f"), Color("5d82c4"), 10, 2))
	t.set_stylebox("hover", "Button", scatola(Color("2d5290"), Color("8fb1ef"), 10, 2))
	t.set_stylebox("pressed", "Button", scatola(Color("1b3157"), GIALLO, 10, 3))
	t.set_stylebox("disabled", "Button", scatola(Color("1a2438"), Color("2c3950"), 10, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", scatola(Color(0.08, 0.12, 0.2, 0.94), BORDO, 14, 2))
	t.set_icon("unchecked", "CheckBox", _casella(false))
	t.set_icon("checked", "CheckBox", _casella(true))
	t.set_stylebox("normal", "LineEdit", scatola(Color("0e1729"), BORDO, 8, 2))
	t.set_stylebox("focus", "LineEdit", scatola(Color("0e1729"), GIALLO, 8, 2))
	t.set_color("font_color", "LineEdit", TESTO)
	t.set_font_size("font_size", "LineEdit", 30)
	t.set_font("font", "LineEdit", cifre())
	return t

## Casella di spunta disegnata (niente simboli dei font)
static func _casella(piena: bool) -> ImageTexture:
	var n := 34
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var bordo := x < 3 or y < 3 or x >= n - 3 or y >= n - 3
			if bordo:
				img.set_pixel(x, y, Color.WHITE)
			elif piena and x >= 7 and y >= 7 and x < n - 7 and y < n - 7:
				img.set_pixel(x, y, GIALLO)
			else:
				img.set_pixel(x, y, Color(0.05, 0.08, 0.14, 1))
	return ImageTexture.create_from_image(img)

static func scatola(fondo: Color, bordo: Color, raggio := 10, spessore := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func etichetta(t: String, dim := 24, col := TESTO, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", col)
	if f:
		l.add_theme_font_override("font", f)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120
	return l

static func paragrafo(t: String, dim := 22, col := TESTO) -> Label:
	var l := etichetta(t, dim, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 260
	return l

static func bottone(t: String, dim := 26) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", dim)
	b.custom_minimum_size = Vector2(max(140, t.length() * dim * 0.55 + 40), dim + 30)
	b.focus_mode = Control.FOCUS_NONE
	return b

## Disegna un dado (colore 0 blu, 1 arancio, -1 gettone bianco)
static func dado(ci: CanvasItem, centro: Vector2, lato: float, valore: int, colore: int, alfa := 1.0, bordo_col := Color.TRANSPARENT) -> void:
	var r := Rect2(centro - Vector2(lato, lato) * 0.5, Vector2(lato, lato))
	var fondo := BLU if colore == 0 else (ARANCIO if colore == 1 else Color("eef1f4"))
	var bordo := BLU_SCURO if colore == 0 else (ARANCIO_SCURO if colore == 1 else Color("6d7a8c"))
	var punti := Color(1, 1, 1, alfa) if colore >= 0 else Color(0.1, 0.12, 0.16, alfa)
	fondo.a = alfa
	bordo.a = alfa
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = bordo
	sb.set_border_width_all(maxi(2, int(lato * 0.05)))
	sb.set_corner_radius_all(int(lato * 0.2))
	sb.shadow_color = Color(0, 0, 0, 0.45 * alfa)
	sb.shadow_size = int(lato * 0.08)
	sb.shadow_offset = Vector2(0, lato * 0.05)
	ci.draw_style_box(sb, r)
	if bordo_col.a > 0:
		var hb := StyleBoxFlat.new()
		hb.draw_center = false
		hb.border_color = bordo_col
		hb.set_border_width_all(maxi(3, int(lato * 0.07)))
		hb.set_corner_radius_all(int(lato * 0.24))
		ci.draw_style_box(hb, r.grow(lato * 0.08))
	if valore < 1 or valore > 6:
		return
	var p := lato * 0.27
	var rr := lato * 0.09
	var pos := {
		1: [Vector2.ZERO],
		2: [Vector2(-p, -p), Vector2(p, p)],
		3: [Vector2(-p, -p), Vector2.ZERO, Vector2(p, p)],
		4: [Vector2(-p, -p), Vector2(p, -p), Vector2(-p, p), Vector2(p, p)],
		5: [Vector2(-p, -p), Vector2(p, -p), Vector2.ZERO, Vector2(-p, p), Vector2(p, p)],
		6: [Vector2(-p, -p), Vector2(p, -p), Vector2(-p, 0), Vector2(p, 0), Vector2(-p, p), Vector2(p, p)],
	}
	for d in pos[valore]:
		ci.draw_circle(centro + d, rr, punti)

## Dado coperto (dietro lo schermo)
static func dado_coperto(ci: CanvasItem, centro: Vector2, lato: float, colore: int) -> void:
	var r := Rect2(centro - Vector2(lato, lato) * 0.5, Vector2(lato, lato))
	var sb := StyleBoxFlat.new()
	sb.bg_color = (BLU_SCURO if colore == 0 else ARANCIO_SCURO).lerp(Color.BLACK, 0.2)
	sb.border_color = BLU if colore == 0 else ARANCIO
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(lato * 0.2))
	ci.draw_style_box(sb, r)
	var f := cifre()
	ci.draw_string(f, centro + Vector2(-lato * 0.5, lato * 0.18), "?", HORIZONTAL_ALIGNMENT_CENTER, lato, int(lato * 0.5), Color(1, 1, 1, 0.5))

static func testo_centrato(ci: CanvasItem, f: Font, centro: Vector2, t: String, dim: int, col: Color, larg := 600.0) -> void:
	var h := f.get_height(dim)
	ci.draw_string(f, Vector2(centro.x - larg * 0.5, centro.y + h * 0.5 - f.get_descent(dim)), t, HORIZONTAL_ALIGNMENT_CENTER, larg, dim, col)

static func testo_bordato(ci: CanvasItem, f: Font, centro: Vector2, t: String, dim: int, col: Color, larg := 600.0) -> void:
	var h := f.get_height(dim)
	var p := Vector2(centro.x - larg * 0.5, centro.y + h * 0.5 - f.get_descent(dim))
	ci.draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_CENTER, larg, dim, maxi(3, dim / 6), Color(0, 0, 0, 0.85))
	ci.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_CENTER, larg, dim, col)
