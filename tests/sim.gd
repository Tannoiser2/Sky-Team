extends SceneTree
## Partite automatiche: IA contro IA (e Automa) su tutti gli scenari.
## godot --headless --path . -s tests/sim.gd -- [partite] [scenario] [automa]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 10
	var solo := args[1] if args.size() > 1 else ""
	var usa_automa := args.size() > 2 and args[2] == "automa"
	var tot_v := 0
	var tot := 0
	var motivi := {}
	var t0 := Time.get_ticks_msec()
	for sc in Motore.scenari():
		if solo != "" and solo != "tutti" and sc["id"] != solo:
			continue
		var v := 0
		for k in n:
			var ab := []
			var tutte := Motore.ABILITA.duplicate()
			for j in int(sc["abilita"]):
				ab.append(tutte[(k + j * 2) % 6])
			var s := Motore.nuova(sc["id"], 1000 + k * 7919, {"abilita": ab})
			var passi := 0
			while s["fase"] == "piazza" and passi < 400:
				passi += 1
				var c: int = s["turno"]
				if s["pendente"][0]:
					c = 0
				elif s["pendente"][1]:
					c = 1
				if usa_automa and c == 1:
					Automa.turno(s)
					continue
				var a := IA.scegli(s, c)
				if a.is_empty():
					print("BLOCCO ", sc["id"], " ", s["turno"], " ", s["mano"])
					break
				var e := Motore.applica(s, a)
				if e != "":
					print("ERRORE ", sc["id"], " ", a, " ", e)
					break
			if s["esito"] == "vinto":
				v += 1
			else:
				var m: String = s["motivo"].split(":")[0]
				motivi[m] = motivi.get(m, 0) + 1
		tot_v += v
		tot += n
		print("%-6s %-24s %-7s %d/%d" % [sc["id"], sc["nome"], sc["colore"], v, n])
	print("TOTALE %d/%d (%.0f%%) in %d ms" % [tot_v, tot, 100.0 * tot_v / max(1, tot), Time.get_ticks_msec() - t0])
	for m in motivi:
		print("  ", motivi[m], "  ", m)
	quit()
