extends SceneTree
## Mission Control's briefing (new campaign) and debrief (after a contract) show on Mission Select, page by page, once.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _card(n: Node) -> Node:
	for c in n.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == "StoryCard":
			return c
	return null
func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	pd.ai_notice_seen = true
	pd.new_campaign()
	var ms: Node = load("res://mission_select.tscn").instantiate()
	root.add_child(ms)
	current_scene = ms
	await create_timer(2.5).timeout
	var sc := _card(ms)
	check("a new campaign opens with the briefing", sc != null and sc.pages.size() == 3)
	check("and it is marked as shown", bool(pd.campaign["briefed"]))
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "story_briefing.png")
	if sc != null:
		check("page 1 says the mission is fictional", sc._coach.label.text.contains("FICTIONAL"))
		sc.advance()
		sc.advance()
		check("the last page offers GOT IT", sc._btn.text == "GOT IT")
		sc.advance()
	await process_frame
	await process_frame
	check("the card closes after the last page", _card(ms) == null)
	ms.queue_free()
	await process_frame
	var ms2: Node = load("res://mission_select.tscn").instantiate()
	root.add_child(ms2)
	current_scene = ms2
	await create_timer(2.5).timeout
	check("the briefing does not repeat", _card(ms2) == null)
	ms2.queue_free()
	await process_frame
	# a debrief after contract 01
	pd.campaign["log"] = [{"id": 0, "tag": "CONTRACT 01", "name": "Orientale", "headline": "You photographed the Orientale Basin: 2 photos reached Earth.", "detail": "Your best shot scored 3 of 3 stars.", "score": 100}]
	pd.campaign["done"] = [0]
	pd.campaign["locked"] = true
	pd.campaign["debrief"] = 0
	var bs: BuildState = pd.get_build()
	var rooms := ["flight-deck", "life-support", "observation", "communications", "science-lab"]
	for i in rooms.size():
		bs.bays[i] = rooms[i]
	bs.wide = true
	bs.kit = true
	bs.wings = 2
	var ms3: Node = load("res://mission_select.tscn").instantiate()
	root.add_child(ms3)
	current_scene = ms3
	await create_timer(2.5).timeout
	var sd := _card(ms3)
	check("finishing a contract brings a debrief", sd != null and sd.pages.size() == 2 and sd.title_text == "DEBRIEF")
	check("it names what you did and what is next", sd != null and sd.pages[0].contains("Orientale") and sd.pages[1].contains("Glushko"))
	check("and is cleared so it shows once", int(pd.campaign["debrief"]) == -1)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "story_debrief.png")
	print("FAILS: ", fails)
	quit(fails)
