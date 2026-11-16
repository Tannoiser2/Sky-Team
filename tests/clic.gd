extends SceneTree
func _clic(p: Vector2) -> void:
	for pr in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pr
		e.position = p
		e.global_position = p
		root.push_input(e)
		await process_frame
func _init() -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var b: Button = null
	for n in main.find_children("*", "Button", true, false):
		if n.text == "Nuovo volo": b = n
	print("bottone ", b.get_global_rect())
	var m := InputEventMouseMotion.new()
	m.position = b.get_global_rect().get_center()
	root.push_input(m)
	await process_frame
	await _clic(b.get_global_rect().get_center())
	await create_timer(0.3).timeout
	print("schermo dopo: ", main.dettaglio != null)
	quit()
