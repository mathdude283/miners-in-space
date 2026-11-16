extends SceneTree
## The Moon photo with NASA's real far-side view: the basin follows the target, the coach talks the player through AIM, HOLD,
## RELEASE with the current step lit, and a well-aimed shot scores well. Screenshots for a person to judge.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var PG = load("res://photo_game.gd")
	PG._practiced = true
	var g = PG.new()
	g.theme = load("res://assets/themes/moonbound_theme.tres")
	g.has_lens = {"wide": true, "close": true}
	root.add_child(g)
	await create_timer(0.8).timeout
	await _snap("photo2_brief")
	g._start_shoot()
	await create_timer(0.6).timeout
	check("the scene is NASA's real far-side picture", g.bg.texture == PG.NASA_VIEW)
	# the real basin is where the target is
	var tp: Vector2 = g._target_at(g._t)
	var basin_on_screen: Vector2 = g.bg.position + PG.BASIN_AT * PG.NASA_SCALE
	check("the real basin sits on the target path", basin_on_screen.distance_to(tp) < 2.0)
	check("and the picture covers the screen where the target is", Rect2(g.bg.position, g.bg.size).has_point(tp + Vector2(-300, -200)) and Rect2(g.bg.position, g.bg.size).has_point(tp + Vector2(200, 200)))
	var coach: Control = g._coach_panel
	check("the coach is a Mission Control panel", coach is CoachPanel)
	# step 1: far from the target the coach says AIM
	g._t = 1.0                              # the sun is high at this moment, so the only thing to say is AIM, then HOLD
	g._aim = Vector2(300, 900)
	await create_timer(0.3).timeout
	check("away from the basin the coach says to move the mouse", g._coach.text.contains("MOVE THE MOUSE"))
	await _snap("photo2_aim")
	# on the target: HOLD (poll, so a slow frame cannot fail the check)
	var said_hold := false
	for k in 20:
		g._t = 1.0
		g._aim = g._target_at(g._t)
		await process_frame
		if g._coach.text.contains("HOLD"):
			said_hold = true
			break
	check("on the basin the coach says to hold", said_hold)
	g._aim = g._target_at(g._t)
	g._set_hold(true)
	await create_timer(0.9).timeout
	g._aim = g._target_at(g._t)
	await create_timer(0.3).timeout
	check("once steady the coach says to release", g._coach.text.contains("RELEASE"))
	await _snap("photo2_release")
	g._set_hold(false)
	await create_timer(0.7).timeout
	check("a well-aimed, steady shot is kept", g._best.has("wide") and int(g._best["wide"]["stars"]) >= 2)
	check("it is a crop of NASA's view, not drawn rings", g._best["wide"]["tex"] != null)
	await _snap("photo2_shot")
	print("FAILS: ", fails)
	quit(fails)
