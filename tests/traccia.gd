extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sc := args[0] if args.size() > 0 else "yul"
	var seme := int(args[1]) if args.size() > 1 else 1000
	var s := Motore.nuova(sc, seme, {})
	var passi := 0
	while s["fase"] == "piazza" and passi < 400:
		passi += 1
		var c: int = s["turno"]
		if s["pendente"][0]: c = 0
		elif s["pendente"][1]: c = 1
		var mani := "P%s C%s ax%d pos%d caf%d" % [s["mano"][0].map(func(d): return d["v"]), s["mano"][1].map(func(d): return d["v"]), s["asse"], s["pos"], s["caffe"]]
		var a := IA.scegli(s, c)
		print(mani, "  -> ", a)
		Motore.applica(s, a)
	for l in s["log"]: print("  ", l)
	quit()
