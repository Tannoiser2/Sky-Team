extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var s := Motore.nuova(args[0], int(args[1]), {})
	var passi := 0
	while s["fase"] == "piazza" and passi < 400:
		passi += 1
		var c: int = s["turno"]
		if s["pendente"][0]: c = 0
		elif s["pendente"][1]: c = 1
		if c == 1:
			var prima: Array = s["mano"][1].duplicate(true)
			var carta := Automa.turno(s)
			print("AUTOMA carta ", carta + 1, " mano ", prima.map(func(d): return d["v"]))
		else:
			Motore.applica(s, IA.scegli(s, 0))
	for l in s["log"]: print("  ", l)
	quit()
