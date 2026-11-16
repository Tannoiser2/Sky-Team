extends SceneTree
func _init() -> void:
	var s := Motore.nuova("atl2", 4242, {"abilita": ["anticipazione"]})
	print(s["turno"], " ", s["mano"][0], " pend ", s["pendente"], " fase ", s["fase"])
	var m := Motore.mosse(s, 0, true)
	print(m.size(), " ", m.slice(0, 5))
	quit()
