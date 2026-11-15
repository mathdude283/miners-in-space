class_name BuildState
extends RefCounted
## The player's ship as data. Totals, checks and fixes are all computed from this, never from
## the pictures. Undo keeps the last 40 steps.

signal changed

var bays: Array[String] = []
var kit := false
var wings := 0
var wide := false
var close := false
var _history: Array[Dictionary] = []


func _init() -> void:
	bays.resize(ShipData.RULES["bays"])
	bays.fill("")


# ---------- snapshots / undo ----------

func _snapshot() -> Dictionary:
	return {"bays": bays.duplicate(), "kit": kit, "wings": wings, "wide": wide, "close": close}


func _restore(d: Dictionary) -> void:
	bays.assign(d["bays"])
	kit = d["kit"]
	wings = d["wings"]
	wide = d["wide"]
	close = d["close"]


func _push() -> void:
	_history.append(_snapshot())
	if _history.size() > 40:
		_history.pop_front()


func can_undo() -> bool:
	return not _history.is_empty()


func undo() -> void:
	if _history.is_empty():
		return
	_restore(_history.pop_back())
	changed.emit()


func clear() -> void:
	if is_empty():
		return
	_push()
	bays.fill("")
	kit = false
	wings = 0
	wide = false
	close = false
	changed.emit()


func load_starter(d: Dictionary) -> void:
	_push()
	_restore(d)
	changed.emit()


func is_empty() -> bool:
	return used_bays() == 0 and not kit and wings == 0 and not wide and not close


# ---------- edits ----------

func used_bays() -> int:
	var n := 0
	for id in bays:
		if id != "":
			n += 1
	return n


func has_room(id: String) -> bool:
	return bays.has(id)


func first_empty() -> int:
	return bays.find("")


## Puts a room in bay `at`, or in the first empty bay. Each room can only be used once.
func place_room(id: String, at: int = -1) -> int:
	if has_room(id):
		return -1
	if at < 0 or at >= bays.size() or bays[at] != "":
		at = first_empty()
	if at < 0:
		return -1
	_push()
	bays[at] = id
	changed.emit()
	return at


func remove_bay(at: int) -> void:
	if at < 0 or at >= bays.size() or bays[at] == "":
		return
	_push()
	bays[at] = ""
	changed.emit()


func toggle_kit() -> void:
	_push()
	kit = not kit
	changed.emit()


func set_wings(n: int) -> void:
	n = clampi(n, 0, ShipData.RULES["wings_max"])
	if n == wings:
		return
	_push()
	wings = n
	changed.emit()


func toggle_wide() -> void:
	_push()
	wide = not wide
	changed.emit()


func toggle_close() -> void:
	_push()
	close = not close
	changed.emit()


# ---------- totals ----------

## Totals for the ship, plus what it would be after adding `extra`
## (a dictionary with any of mass / draw / cost / gen) to see a choice before making it.
func totals() -> Dictionary:
	var mass := 0
	var draw := 0
	var cost := 0
	var have := {}
	var used := 0
	for id in bays:
		if id == "":
			continue
		var r := ShipData.room(id)
		used += 1
		mass += int(r["mass"])
		draw += int(r["power"])
		cost += int(r["cost"])
		for f in r["provides"]:
			if not have.has(f):
				have[f] = r["name"]
	if kit:
		mass += int(ShipData.KIT["mass"])
		draw += int(ShipData.KIT["power"])
		cost += int(ShipData.KIT["cost"])
		for f in ShipData.KIT["provides"]:
			if not have.has(f):
				have[f] = ShipData.KIT["name"]
	var R := ShipData.RULES
	mass += wings * int(R["wing_mass"]) + (int(R["lens_mass"]) if wide else 0) + (int(R["lens_mass"]) if close else 0)
	cost += wings * int(R["wing_cost"]) + (int(R["lens_cost"]) if wide else 0) + (int(R["lens_cost"]) if close else 0)
	var gen := int(R["base_power"]) + wings * int(R["wing_power"])
	return {
		"mass": mass, "draw": draw, "gen": gen, "cost": cost,
		"margin": gen - draw, "have": have, "used": used,
		"mass_left": int(R["mass_limit"]) - mass,
		"budget_left": int(R["budget_limit"]) - cost,
	}


# ---------- checks ----------

## One row per thing the ship needs, with a plain-language reason and a fix label.
func checks() -> Array[Dictionary]:
	var t := totals()
	var R := ShipData.RULES
	var list: Array[Dictionary] = []
	for f in ShipData.FUNCTION_ORDER:
		var def: Dictionary = ShipData.FUNCTIONS[f]
		var ok: bool = t["have"].has(f)
		list.append({
			"key": "fn:" + f, "group": "crew", "label": def["label"], "ok": ok,
			"why": t["have"][f] if ok else "Missing",
			"fix": "Add crew kit" if def["kit"] else "Add " + ShipData.room(def["room"])["name"],
		})
	var has_window: bool = t["have"].has("camera")
	list.append({"key": "camera", "group": "mission", "label": "Window", "ok": has_window,
		"why": "Observation Bay" if has_window else "Missing", "fix": "Add Observation Bay"})
	var has_lens := wide or close
	var lens_parts: Array[String] = []
	if wide:
		lens_parts.append("Wide")
	if close:
		lens_parts.append("Close-up")
	list.append({"key": "lens", "group": "mission", "label": "Lens", "ok": has_lens,
		"why": " + ".join(lens_parts) if has_lens else "Missing", "fix": "Pack wide lens"})

	var ex := extras(false)
	var mass_fix: String = "Remove " + ShipData.room(ex[0]["id"])["name"] if not ex.is_empty() else ("Remove close-up lens" if (close and wide) else "Nothing extra to remove")
	list.append({"key": "mass", "group": "limits", "label": "Weight", "ok": int(t["mass"]) <= int(R["mass_limit"]),
		"why": "%d / %d%s" % [t["mass"], R["mass_limit"], " - too heavy" if int(t["mass"]) > int(R["mass_limit"]) else ""], "fix": mass_fix})
	var pex := extras(true)
	var pow_fix: String = "Add a solar wing" if wings < int(R["wings_max"]) else ("Remove " + ShipData.room(pex[0]["id"])["name"] if not pex.is_empty() else "Nothing extra to remove")
	list.append({"key": "power", "group": "limits", "label": "Power", "ok": int(t["margin"]) >= 0,
		"why": "%d used / %d made%s" % [t["draw"], t["gen"], " - not enough" if int(t["margin"]) < 0 else ""], "fix": pow_fix})
	var cex := extras(false)
	var cost_fix: String = "Remove " + ShipData.room(cex[0]["id"])["name"] if not cex.is_empty() else ("Remove close-up lens" if (close and wide) else "Nothing extra to remove")
	list.append({"key": "cost", "group": "limits", "label": "Budget", "ok": int(t["cost"]) <= int(R["budget_limit"]),
		"why": "%d / %d%s" % [t["cost"], R["budget_limit"], " - over budget" if int(t["cost"]) > int(R["budget_limit"]) else ""], "fix": cost_fix})
	return list


func problems() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in checks():
		if not c["ok"]:
			out.append(c)
	return out


func is_ready() -> bool:
	return problems().is_empty()


## A room is "extra" if everything it provides is already covered by another room or the crew kit
## (the Observation Bay is never extra: it is the window).
func is_extra(idx: int) -> bool:
	var id := bays[idx]
	if id == "" or id == "observation":
		return false
	for f in ShipData.room(id)["provides"]:
		if kit and ShipData.FUNCTIONS.has(f) and ShipData.FUNCTIONS[f]["kit"]:
			continue
		var covered := false
		for j in bays.size():
			if j != idx and bays[j] != "" and ShipData.room(bays[j])["provides"].has(f):
				covered = true
				break
		if not covered:
			return false
	return true


## Rooms that could be removed without losing a need, biggest saving first.
func extras(by_power: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in bays.size():
		if bays[i] != "" and is_extra(i):
			var r := ShipData.room(bays[i])
			out.append({"i": i, "id": bays[i], "key": int(r["power"]) if by_power else int(r["mass"])})
	out.sort_custom(func(a, b): return a["key"] > b["key"])
	return out
