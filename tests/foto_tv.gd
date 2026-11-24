extends SceneTree
## Foto delle modalità televisore e telefono:
## xvfb-run -a godot --path . --resolution LxA -s tests/foto_tv.gd -- cartella tv|telefono scenario
func _foto(dir: String, nome: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nome])
	print("foto ", nome)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := a[0]
	var tipo := a[1]
	var scen := a[2]
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var sc := Motore.scenario(scen)
	var s := Motore.nuova(scen, 4242, {"abilita": Motore.ABILITA.slice(0, int(sc["abilita"]))})
	if tipo == "lobby":
		main.compagno = "ia"
		main._apri_tv(s)
		main._tv_entra("abc")
		await create_timer(0.4).timeout
		await _foto(dir, "lobby")
		quit()
		return
	main._pulisci()
	var p := Partita.new()
	main.partita = p
	if tipo == "telefono":
		main._scala_telefono(true)
	else:
		p.posti = {0: "telefono", 1: "ia"}
	main.add_child(p)
	p.avvia(s, 1 if tipo == "telefono" else 0, tipo, null)
	await create_timer(0.6).timeout
	await _foto(dir, tipo + "_1")
	# qualche mossa
	var t0 := Time.get_ticks_msec()
	while p.s["fase"] == "piazza" and p.s["round"] < 3 and Time.get_ticks_msec() - t0 < 30000:
		var c := p.chi_deve()
		if c >= 0:
			var m := IA.scegli(p.s, c)
			if not m.is_empty():
				Motore.applica(p.s, m)
				p._dopo()
		await create_timer(0.1).timeout
	if tipo == "telefono" and p.s["turno"] == 1:
		p._dado(0)
	await create_timer(0.6).timeout
	await _foto(dir, tipo + "_2")
	quit()
