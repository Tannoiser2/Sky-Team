extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0])
	for id in args.slice(1):
		for k in n:
			var s := Motore.nuova(id, 1000 + k * 7919, {})
			var passi := 0
			while s["fase"] == "piazza" and passi < 400:
				passi += 1
				var c: int = s["turno"]
				if s["pendente"][0]: c = 0
				elif s["pendente"][1]: c = 1
				var a := IA.scegli(s, c)
				if a.is_empty(): break
				Motore.applica(s, a)
			print(id, " ", 1000 + k * 7919, " q", s["quota"], " pos", s["pos"], "/", s["ultima"], " ", s["esito"], " ", s["motivo"])
	quit()
