extends SceneTree

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _initialize() -> void:
	# Keep the test window from taking focus or input from whoever is using the computer.
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.scenario = 0
	pd.build = null
	var scene: Node = load("res://build_screen.tscn").instantiate()
	root.add_child(scene)
	await _wait(1.5)
	var st = scene.state

	# ---- calm: nothing drifts ----
	var s0 = scene.background.scale
	var p0 = scene.background.position
	var rects0 := [scene.detail_panel.get_global_rect(), scene.lower.get_global_rect(), scene.footer.get_global_rect(), scene.top.get_global_rect()]
	await _wait(2.0)
	check("background scale holds still", scene.background.scale == s0)
	check("background position holds still", scene.background.position == p0)
	check("stars are off", not scene.stars.visible and not scene.stars.emitting)

	# ---- build something, then take parts out every way ----
	for id in ["flight-deck", "life-support", "communications", "observation"]:
		scene._activate(scene._room_cards[id].part)
	await _wait(0.4)
	check("4 rooms placed", st.used_bays() == 4)
	var slot0 = scene.ship.bay_slot(0)
	check("remove button is visible on a filled bay (no hover needed)", slot0._x.visible)
	check("remove button hidden on an empty bay", not scene.ship.bay_slot(5)._x.visible)

	# 1) the x button on the ship
	slot0._x.pressed.emit()
	await _wait(0.2)
	check("x button removes the room", st.bays[0] == "" and st.used_bays() == 3)

	# 2) click the tile again
	scene._activate(scene._room_cards["life-support"].part)
	await _wait(0.2)
	check("clicking an IN SHIP tile takes it out", not st.has_room("life-support") and st.used_bays() == 2)
	check("tile is clickable again afterwards", not scene._room_cards["life-support"].disabled)

	# 3) Delete key on a focused bay
	var slot_c = scene.ship.bay_slot(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_DELETE
	ev.pressed = true
	slot_c._gui_input(ev)
	await _wait(0.2)
	check("Delete key removes the room in that bay", st.bays[2] == "")

	# 4) undo brings things back
	scene._undo()
	await _wait(0.2)
	check("undo restores the removed room", st.bays[2] != "")

	# 5) equipment toggles off
	scene._on_equipment_chosen({}, "kit")
	check("kit on", st.kit)
	scene._on_equipment_chosen({}, "kit")
	check("kit off again", not st.kit)
	scene._on_equipment_chosen({}, "wing1")
	scene._on_equipment_chosen({}, "wing2")
	check("two wings on", st.wings == 2)
	scene._on_equipment_chosen({}, "wing2")
	check("wing 2 off leaves one", st.wings == 1)
	scene._on_equipment_chosen({}, "wing1")
	check("wing 1 off leaves none", st.wings == 0)

	# ---- layout does not shift while hovering things ----
	var tile = scene._room_cards["galley"]
	tile.hovered.emit(tile.part)
	await _wait(0.3)
	var rects1 := [scene.detail_panel.get_global_rect(), scene.lower.get_global_rect(), scene.footer.get_global_rect(), scene.top.get_global_rect()]
	tile.hovered.emit({})
	scene.ship.bay_hovered.emit(1)
	await _wait(0.3)
	var rects2 := [scene.detail_panel.get_global_rect(), scene.lower.get_global_rect(), scene.footer.get_global_rect(), scene.top.get_global_rect()]
	scene._say("A short message.")
	await _wait(0.2)
	var rects3 := [scene.detail_panel.get_global_rect(), scene.lower.get_global_rect(), scene.footer.get_global_rect(), scene.top.get_global_rect()]
	var stable := true
	for i in 4:
		for r in [rects1, rects2, rects3]:
			if r[i] != rects0[i]:
				stable = false
				print("   moved: panel ", i, " ", rects0[i], " -> ", r[i])
	check("panels do not move when hovering or when messages change", stable)

	# ---- continue is never locked ----
	st.clear()
	await _wait(0.2)
	check("empty (failing) ship can still continue", not scene.continue_button.disabled)
	check("button says FLY ANYWAY", scene.continue_button.text == "FLY ANYWAY")
	check("consequence is stated", scene.note_label.text.contains("mission data"))
	scene._load_starter(0)
	await _wait(0.2)
	scene._on_fix("fn:comms")  # hint only: must NOT change the ship
	check("hint does not change the ship", not st.has_room("communications"))
	scene._activate(scene._room_cards["communications"].part)
	await _wait(0.2)
	check("now ready and button says CONTINUE", st.is_ready() and scene.continue_button.text == "CONTINUE")
	check("lunar evidence starter now has a flaw to find", not _ready_starter(1))

	# ---- pick first, then add ----
	scene.ship.bay_hovered.emit(-1)
	scene._on_part_hovered({})
	var c1 = scene._room_cards["galley"]
	var before: int = st.used_bays()
	c1.pressed.emit()
	await _wait(0.2)
	check("clicking a tile only picks it (nothing is added)", st.used_bays() == before and scene._inspect.get("id", "") == "galley")
	check("picked tile is highlighted", c1._picked)
	check("inspector shows a WHY line for it", scene.inspector._why.text.length() > 10)
	check("inspector shows a DO line for it", scene.inspector._do.text.length() > 5)
	check("inspector says NASA for a room NASA supports", scene.inspector._fact_tag.text == "NASA" and scene.inspector._fact.text.contains("food warmer"))
	check("action button offers to add it", scene.inspector._action.visible and scene.inspector._action.text.begins_with("ADD TO BAY"))
	scene.inspector._action.pressed.emit()
	await _wait(0.2)
	check("pressing the button adds the picked room", st.has_room("galley"))
	check("button now offers TAKE OUT", scene.inspector._action.text == "TAKE OUT")
	scene.inspector._action.pressed.emit()
	await _wait(0.2)
	check("pressing it again takes the room out", not st.has_room("galley"))
	var c2 = scene._room_cards["cargo"]
	c2.activated.emit(c2.part)
	await _wait(0.2)
	check("double-click shortcut adds straight away", st.has_room("cargo"))
	scene._on_part_picked(scene._room_cards["communications"].part)
	check("Communications has no NASA claim and says GAME", scene.inspector._fact_tag.text == "GAME")
	for r in ShipData.ROOMS:
		var info := ShipData.info(r["id"])
		check("room has why/do text: " + String(r["id"]), String(info.get("why", "")).length() > 10 and String(info.get("do", "")).length() > 5 and (info.has("nasa") or info.has("game")))
		check("lines short enough to fit: " + String(r["id"]), String(info.get("why", "")).length() <= 100 and String(info.get("nasa", info.get("game", ""))).length() <= 135)

	# ---- budget is the one hard stop ----
	st.clear()
	for id in ["flight-deck", "life-support", "science-lab", "airlock", "crew-quarters", "observation"]:
		scene._activate(scene._room_cards[id].part)
	st.toggle_kit(); st.toggle_wide(); st.toggle_close(); st.set_wings(2)
	await _wait(0.3)
	check("over budget: ship cannot launch", scene.continue_button.disabled and scene.continue_button.text == "OVER BUDGET")
	st.remove_bay(2); st.remove_bay(3)
	await _wait(0.3)
	var cost_now := int(st.totals()["cost"])
	print("  cost after removing two rooms: ", cost_now)
	check("back under budget: can launch even though the ship has problems", not scene.continue_button.disabled and cost_now <= 45)

	# ---- fly anyway ----
	st.clear()
	scene.continue_button.pressed.emit()
	await _wait(1.0)
	var cs = current_scene
	check("goes to the Fly screen", cs != null and cs.scene_file_path == "res://flight.tscn")
	print("  flight verdict text present: ", cs != null and cs.get_child_count() > 0)
	print("FAILS: ", fails)
	quit(fails)

func _ready_starter(i: int) -> bool:
	var b := BuildState.new()
	b.load_starter(ShipData.STARTERS[i])
	return b.is_ready()
