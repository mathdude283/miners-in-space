extends SceneTree
## Every script in the project parses and can be created (catches typos in files no other test touches).
func _initialize() -> void:
	var bad := 0
	var n := 0
	var dir := DirAccess.open("res://")
	for f in dir.get_files():
		if f.ends_with(".gd"):
			n += 1
			var s = load("res://" + f)
			if s == null or not s.can_instantiate():
				print("FAIL  parse problem: ", f)
				bad += 1
	print("checked %d scripts" % n)
	print("FAILS: ", bad)
	quit(bad)
