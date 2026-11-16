class_name Mano
extends Control
## I dadi in mano a un giocatore (o quelli coperti del compagno).

signal toccato(i: int)

var dadi: Array = []
var colore := 0
var coperti := false
var scelto := -1
var segnati := {}
var riserva := 0

func _lato() -> float:
	var n := maxi(1, dadi.size() + riserva)
	return minf(size.y * 0.86, (size.x - 10) / (n * 1.18))

func _centro(i: int) -> Vector2:
	var l := _lato()
	return Vector2(l * 0.62 + i * l * 1.18, size.y * 0.5)

func _draw() -> void:
	var l := _lato()
	for i in dadi.size():
		var d: Dictionary = dadi[i]
		var c := _centro(i)
		if coperti:
			Stile.dado_coperto(self, c, l * 0.9, colore)
			continue
		var bordo := Color.TRANSPARENT
		if i == scelto:
			bordo = Stile.GIALLO
			c.y -= l * 0.06
		if segnati.get(i, false):
			bordo = Color.WHITE
		var col := colore
		if d.get("k", "d") == "stag":
			col = -1
		Stile.dado(self, c, l * 0.9, int(d["v"]), col, 1.0, bordo)
		if segnati.get(i, false):
			Stile.testo_bordato(self, Stile.grassetto(), c + Vector2(0, l * 0.62), "rilancia", int(l * 0.22), Color.WHITE, l * 1.4)
	for j in riserva:
		var c2 := _centro(dadi.size() + j)
		Stile.dado_coperto(self, c2, l * 0.7, colore)
	if dadi.is_empty() and riserva == 0:
		Stile.testo_centrato(self, Stile.testo(), Vector2(size.x * 0.5, size.y * 0.5), "nessun dado", int(size.y * 0.3), Stile.TESTO_DEBOLE, size.x)

func _gui_input(e: InputEvent) -> void:
	if coperti:
		return
	var p := Vector2(-1, -1)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = e.position
	if p.x < 0:
		return
	var l := _lato()
	for i in dadi.size():
		if _centro(i).distance_to(p) < l * 0.6:
			accept_event()
			toccato.emit(i)
			return
