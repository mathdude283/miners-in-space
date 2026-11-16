extends SceneTree
## One countdown, and hold guidance drawn from the same rules that govern hold, recycle and sequencer lockout.
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	await process_frame
	var GC = load("res://ground_control.gd")
	check("before T-6:00 a hold is free", GC.hold_zone(-500.0, false) == "free")
	check("at T-6:00 a hold is free (the built-in hold)", GC.hold_zone(-360.0, false) == "free")
	check("just after T-6:00 a hold is limited", GC.hold_zone(-300.0, false) == "limited")
	check("at T-3:10 a hold is limited", GC.hold_zone(-190.0, false) == "limited")
	check("at T-1:30 the limit has ended", GC.hold_zone(-90.0, false) == "late")
	check("at T-0:33 a hold is still possible", GC.hold_zone(-33.0, false) == "late")
	check("after the hand-over nothing can be held", GC.hold_zone(-33.0, true) == "locked")
	check("the lockout time is read from the count itself", GC.sequencer_t() == -33.0)
	check("limited guidance says 3 minutes and recycle", GC.hold_guidance("limited").contains("3 minutes") and GC.hold_guidance("limited").contains("recycles"))
	check("late guidance names T-0:33", GC.hold_guidance("late").contains("T-0:33"))
	check("free guidance names T-6:00", GC.hold_guidance("free").contains("T-6:00"))

	var cp = load("res://count_panel.gd").new()
	cp.theme = load("res://assets/themes/moonbound_theme.tres")
	root.add_child(cp)
	var hud := {"text": "T-10:00"}
	cp.clock_changed.connect(func(t): hud["text"] = t)
	var run_result := {"r": ""}
	var coroutine := func(): run_result["r"] = await cp.run()
	coroutine.call()
	var held_once := false
	var recycled := false
	var seen_late := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 150000 and run_result["r"] == "":
		await process_frame
		check_clock(cp, hud)
		# at the T-4:30 flight termination call, hold (limited zone) and wait for the recycle
		if not held_once and cp._go_btn.visible and cp._t <= -269.0 and cp._t > -271.0:
			held_once = true
			check("at T-4:30 the guidance is the limited-hold rule", cp._rule.text == GC.hold_guidance("limited"))
			cp._on_hold()
		if held_once and not recycled and cp._t <= -599.0:
			recycled = true
			check("a hold past 3 minutes recycles the count to T-10:00", cp._status.text.contains("RECYCLED") or cp._t == -600.0)
			check("the HUD clock shows T-10:00 as well", hud["text"] == "T-10:00")
			check("the guidance is the free rule again", cp._rule.text == GC.hold_guidance("free"))
		if recycled and cp._go_btn.visible and cp._t <= -299.0:
			cp._go_pressed = true
		elif recycled and cp._go_btn.visible and cp._t <= -189.0 and cp._t > -191.0:
			cp._go_pressed = true
		elif recycled and cp._go_btn.visible and cp._t <= -32.0 and cp._t > -34.0:
			if not seen_late:
				seen_late = true
				check("at the T-0:33 call the guidance names the hand-over, not the T-6:00 rule", cp._rule.text == GC.hold_guidance("late") and not cp._rule.text.contains("T-6:00"))
				check("the HUD clock reads T-0:33 as well", hud["text"] == "T-0:33")
			cp._go_pressed = true
		elif recycled and cp._go_btn.visible:
			cp._go_pressed = true
	check("the count ends in liftoff", run_result["r"] == "liftoff")
	check("after the hand-over the guidance is the lockout rule", cp._rule.text == GC.hold_guidance("locked"))
	check("the HUD clock ended on the same time as the panel", hud["text"] == cp._clock.text)
	check("the panel clock ended at liftoff", cp._clock.text == "T-0:00")
	print("FAILS: ", fails)
	quit(fails)

func check_clock(cp, hud) -> void:
	if cp._clock.text != hud["text"]:
		check("the two clocks agree (" + cp._clock.text + " vs " + hud["text"] + ")", false)
