extends SceneTree
## Tavi is selectable and appears on the ship; both idle poses render; switching crew mid-stride stops the walk.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.ai_notice_seen = true
	pd.new_campaign()
	# ---- crew screen: Tavi can be picked for the scientist seat
	var cs: Node = load("res://crew_screen.tscn").instantiate()
	root.add_child(cs)
	current_scene = cs
	await create_timer(0.5).timeout
	check("Tavi is in the roster", cs._roster.any(func(r): return r["id"] == "tavi"))
	cs._select(2)
	cs._assign("tavi")
	await create_timer(0.3).timeout
	check("Tavi sits in seat 3 with his own name", cs._slots[2]["char"] == "tavi" and cs._slots[2]["field"].text == "Tavi")
	check("the three roles and default seats are unchanged", cs._slots[0]["char"] == "ada" and cs._slots[1]["char"] == "sam")
	await _snap("crew_screen")
	cs._on_continue()
	await create_timer(1.0).timeout
	check("Tavi is the saved scientist", pd.crew[2]["char"] == "tavi" and pd.crew[2]["role"] == "SCIENTIST")
	# ---- the ship
	var bs: BuildState = pd.get_build()
	bs.load_starter(ShipData.STARTERS[0])
	bs.place_room("communications")
	bs.place_room("science-lab")
	bs.set_wings(2)
	pd.scenario = 1
	var run = pd.start_run()
	var op = load("res://ship_interior.gd").new()
	op.state = bs
	op.run = run
	op.mission_id = 1
	root.add_child(op)
	current_scene = op
	await create_timer(0.8).timeout
	var tavi = op._astros[2]
	check("Tavi is on the ship", tavi.char_id == "tavi" and tavi.visible)
	check("everyone starts facing us (front idle)", not tavi._has_walked and tavi._idle_front != null and tavi._idle != null and tavi._idle_front != tavi._idle)
	await _snap("ship_front_idle")
	# ---- walk Tavi (keyboard-style walk), then switch away mid-stride with a key
	op._select(2)
	var t0: float = tavi.position.x
	op._target_x = tavi.position.x + Astronaut.W * 0.5 + 400.0
	await create_timer(0.35).timeout
	check("the walker is walking", tavi.walking and tavi.position.x > t0)
	await _snap("ship_walking")
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	op._unhandled_input(key)
	await process_frame
	check("switching with a key stops the outgoing walk", not tavi.walking)
	check("and the new person is selected", op._sel == 0 and op._astros[0].selected and not tavi.selected)
	await create_timer(0.3).timeout
	check("Tavi stands in the side-facing idle after walking", tavi._has_walked)
	await _snap("ship_side_idle")
	# ---- click a portrait mid-walk
	op._select(1)
	op._target_x = op._astros[1].position.x + Astronaut.W * 0.5 - 300.0
	await create_timer(0.3).timeout
	var sam = op._astros[1]
	check("Sam is walking left", sam.walking)
	var chip_btn: Button = null
	for b in op._chips[2]["panel"].get_children():
		if b is Button:
			chip_btn = b
	chip_btn.pressed.emit()          # what a click on Tavi's portrait does
	await process_frame
	check("clicking a portrait while moving stops the outgoing walk", not sam.walking and op._sel == 2)
	await create_timer(0.4).timeout
	check("the stopped walker shows the side idle", sam._has_walked and not sam.walking)
	# ---- left-facing is mirrored (forced, so the picture can be checked)
	op._select(0)
	sam.facing = -1.0
	op._astros[0].facing = -1.0
	op._astros[0].walking = true
	sam.walking = true
	await create_timer(0.3).timeout
	await _snap("ship_left_facing")
	print("FAILS: ", fails)
	quit(fails)
