extends SceneTree
## Save and continue: the campaign, the locked ship and the crew survive closing the game; New Campaign wipes the save;
## a damaged save file never crashes the game.
const PATH := "user://test_moonbound_save.json"
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	_run()
func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	SaveGame.erase(PATH)
	check("no save yet", not SaveGame.has_save(PATH))
	# a campaign with a locked ship, one contract done, a hurt crew member
	pd.new_campaign()
	var c: Array[Dictionary] = []
	c.append(CrewData.make("ada", "Maya", "Commander"))
	c.append(CrewData.make("sam", "Jo", "Pilot"))
	c[1]["health"] = 60.0
	pd.crew = c
	pd.campaign["crew_chosen"] = true
	var b: BuildState = pd.get_build()
	var rooms := ["observation", "science-lab", "communications", "life-support"]
	for i in rooms.size():
		b.bays[i] = rooms[i]
	b.wide = true
	b.close = true
	b.set_wings(2)
	pd.complete_contract(0)
	var before_bays := Array(b.bays).duplicate()
	var before_wings: int = b.wings
	check("saving works", SaveGame.save(pd, PATH))
	check("a save exists with a chosen crew", SaveGame.has_save(PATH))
	check("the summary says how far you got", SaveGame.summary(PATH).begins_with("1 contract done") or SaveGame.summary(PATH).begins_with("Finished"))
	# wipe memory like a fresh launch
	pd.new_campaign()
	check("a fresh start has nothing done", pd.campaign["done"].is_empty() and not bool(pd.campaign["locked"]))
	check("loading works", SaveGame.load_into(pd, PATH))
	check("the finished contract is remembered (as a whole number)", pd.campaign["done"].has(0) and pd.campaign["done"][0] is int)
	check("the ship is still locked", bool(pd.campaign["locked"]))
	check("the same rooms are in the same bays", Array(pd.get_build().bays) == before_bays)
	check("the same solar wings", pd.get_build().wings == before_wings)
	check("the crew names, roles and portraits come back", pd.crew.size() == 2 and pd.crew[0]["name"] == "Maya" and pd.crew[1]["role"] == "Pilot" and pd.crew[1]["char"] == "sam")
	check("a hurt crew member stays hurt", is_equal_approx(float(pd.crew[1]["health"]), 60.0))
	check("contract 02 is the next one open", pd.contract_status(1)["open"])
	check("tests never touch the real save", not pd.autosave_enabled)
	# a campaign that is over keeps its reason
	pd.campaign["over"] = true
	pd.campaign["over_reason"] = "The whole crew was lost."
	SaveGame.save(pd, PATH)
	pd.new_campaign()
	SaveGame.load_into(pd, PATH)
	check("campaign over and its reason survive", bool(pd.campaign["over"]) and String(pd.campaign["over_reason"]) == "The whole crew was lost.")
	# New Campaign wipes the save
	SaveGame.erase(PATH)
	check("erasing removes the save", not SaveGame.has_save(PATH) and not SaveGame.load_into(pd, PATH))
	# damaged or foreign files do not crash and do not change progress
	pd.new_campaign()
	pd.campaign["done"] = [0]
	for bad in ["", "not json", "[1,2,3]", "{\"version\": 99}", "{\"version\": 1, \"campaign\": 5, \"crew\": []}", "{\"version\": 1, \"campaign\": {}, \"crew\": [7]}"]:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		check("a damaged save is refused: " + bad.left(24), not SaveGame.load_into(pd, PATH) and pd.campaign["done"] == [0])
	# names from a hand-edited save are cleaned like names from the keyboard
	var evil := {"version": 1, "campaign": {"done": [], "crew_chosen": true}, "crew": [{"name": "[b]Bad\n[/b]Name_that_is_far_too_long_to_fit_anywhere", "role": "Commander", "char": "ada"}], "ship": {}}
	check("a hand-edited save loads", SaveGame.apply(pd, evil))
	var nm := String(pd.crew[0]["name"])
	check("and its name is cleaned and shortened", not nm.contains("[") and not nm.contains("\n") and nm.length() <= CrewData.MAX_NAME)
	SaveGame.erase(PATH)
	pd.new_campaign()
	print("FAILS: ", fails)
	quit(fails)
