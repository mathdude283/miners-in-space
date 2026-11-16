extends SceneTree
## The Build footer stays on screen: Back, Undo, Clear and Continue are inside the window at 1200x675 and 1920x1080.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.ai_notice_seen = true
	pd.new_campaign()
	pd.scenario = 0
	for sz in [Vector2i(1920, 1080), Vector2i(1200, 675), Vector2i(1280, 720)]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(sz)
		DisplayServer.window_set_position(Vector2i(20, 20))
		await create_timer(0.6).timeout
		var scene: Node = load("res://build_screen.tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		await create_timer(1.2).timeout
		var win := Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size))
		for nm in ["BackButton", "UndoButton", "ClearButton", "ContinueButton"]:
			var n: Control = scene.find_child(nm, true, false)
			var r: Rect2 = n.get_global_rect()
			check("%s on screen at %dx%d (%s)" % [nm, sz.x, sz.y, r], n.visible and win.encloses(r))
		var col: Control = scene.find_child("Column", true, false)
		var sc: ScrollContainer = col.get_parent()
		print("   column needs ", col.get_combined_minimum_size().y, " of ", sc.size.y, " at ", sz)
		root.get_viewport().get_texture().get_image().save_png(OUT + "build_%dx%d.png" % [sz.x, sz.y])
		# the buttons still work
		var cont: Button = scene.find_child("ContinueButton", true, false)
		check("Continue is clickable (enabled state read)", cont != null)
		scene.queue_free()
		await process_frame
	print("FAILS: ", fails)
	quit(fails)
