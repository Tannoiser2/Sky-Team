extends SceneTree
## Fotografie dell'interfaccia: xvfb-run -a godot --path . -s tests/foto.gd -- cartella larghezza altezza [scenario]
func _foto(dir: String, nome: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nome])
	print("foto ", nome)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := a[0] if a.size() else "/tmp/foto"
	if a.size() >= 3:
		root.size = Vector2i(int(a[1]), int(a[2]))
	var scen := a[3] if a.size() >= 4 else "atl2"
	Rete.new().salva("skyteam_vista", "3d")
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	await _foto(dir, "0_home")
	main.online = ""
	main.scelto_id = scen
	main._scelta()
	main._mostra_dettaglio()
	await create_timer(0.4).timeout
	await _foto(dir, "1_scelta")
	var sc := Motore.scenario(scen)
	var ab := Motore.ABILITA.slice(0, int(sc["abilita"]))
	var s := Motore.nuova(scen, 4242, {"abilita": ab})
	main._gioca(s, 0, "ia")
	await create_timer(0.5).timeout
	await _foto(dir, "2_partita")
	var p: Partita = main.partita
	# il giocatore sceglie il primo dado
	if p.s["turno"] == 0:
		p._dado(0)

	await create_timer(0.3).timeout

	await _foto(dir, "3_dado_scelto")
	# lascia giocare l'IA anche per il giocatore umano per qualche round
	var t0 := Time.get_ticks_msec()
	while p.s["fase"] == "piazza" and p.s["quota"] < 3 and Time.get_ticks_msec() - t0 < 60000:
		if p.chi_deve() == 0:
			var mossa := IA.scegli(p.s, 0)
			if not mossa.is_empty():
				p._esegui(mossa)
		await create_timer(0.15).timeout
	await _foto(dir, "4_meta")
	while p.s["fase"] == "piazza" and Time.get_ticks_msec() - t0 < 120000:
		if p.chi_deve() == 0:
			var mossa2 := IA.scegli(p.s, 0)
			if not mossa2.is_empty():
				p._esegui(mossa2)
		await create_timer(0.15).timeout
	await create_timer(0.5).timeout
	await _foto(dir, "5_fine")
	p._regole()
	await create_timer(0.3).timeout
	await _foto(dir, "6_regole")
	quit()
