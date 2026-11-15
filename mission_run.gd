class_name MissionRun
extends RefCounted
## One playthrough of a contract: what the crew has left to spend, which objectives are done, what the
## player chose, what went wrong, and the evidence that came back. Pure data and rules, no screens, so it can
## be tested without playing. All the numbers are GAME rules (minutes of operations, power units, energy).

## Fires whenever someone loses health, with the reason, and again with died = true on the hit that takes
## their last heart. The screens listen to this to tell the player exactly what happened.
signal crew_hurt(index: int, amount: float, reason: String, died: bool)

var mission_id := 0
var rng := RandomNumberGenerator.new()
## {time, power}: each {max, cur}
var resources := {}
var crew: Array[Dictionary] = []
var objectives: Array[Dictionary] = []     # {id, label, done}
var branches := {}                         # branch id -> choice id
var events: Array[Dictionary] = []         # {text, choice}
var evidence: Array[Dictionary] = []
var science := {}                          # Contract 02: the comparison {crater, branch, done, eval, says, observations}
var damage_log: Array[Dictionary] = []     # {name, amount, reason, died}


static func start(id: int, crew_in: Array = [], run_seed := -1) -> MissionRun:
	var m := Missions.get_mission(id)
	var r := MissionRun.new()
	r.mission_id = id
	if run_seed >= 0:
		r.rng.seed = run_seed
	else:
		r.rng.randomize()
	var b: Dictionary = m.get("budget", {})
	for k in ["time", "power"]:
		var mx := float(b.get(k, 0.0))
		r.resources[k] = {"max": mx, "cur": mx}
	for o in m.get("objectives", []):
		r.objectives.append({"id": o["id"], "label": o["label"], "done": false})
	var src: Array = crew_in if not crew_in.is_empty() else CrewData.defaults()
	for c in src:
		r.crew.append((c as Dictionary).duplicate())
	return r


# ---------------- resources ----------------

func left(kind: String) -> float:
	return float(resources[kind]["cur"]) if resources.has(kind) else 0.0


func fraction(kind: String) -> float:
	if not resources.has(kind) or float(resources[kind]["max"]) <= 0.0:
		return 0.0
	return float(resources[kind]["cur"]) / float(resources[kind]["max"])


## Spend some of a resource. Returns false (and spends nothing) when there is not enough.
func spend(kind: String, amount: float) -> bool:
	if not resources.has(kind) or amount > float(resources[kind]["cur"]) + 0.0001:
		return false
	resources[kind]["cur"] = float(resources[kind]["cur"]) - amount
	return true


## Use up some of a resource without refusing: it just stops at zero. For things that drain a little at a time.
func drain(kind: String, amount: float) -> void:
	if resources.has(kind):
		resources[kind]["cur"] = maxf(float(resources[kind]["cur"]) - amount, 0.0)


func restore(kind: String, amount: float) -> void:
	if resources.has(kind):
		resources[kind]["cur"] = minf(float(resources[kind]["cur"]) + amount, float(resources[kind]["max"]))


# ---------------- objectives and choices ----------------

func complete(id: String) -> void:
	for o in objectives:
		if o["id"] == id:
			o["done"] = true


func is_done(id: String) -> bool:
	for o in objectives:
		if o["id"] == id:
			return bool(o["done"])
	return false


## Which objectives are done, and how many there are in all.
func progress() -> Vector2i:
	var n := 0
	for o in objectives:
		if o["done"]:
			n += 1
	return Vector2i(n, objectives.size())


func all_done() -> bool:
	var p := progress()
	return p.y > 0 and p.x == p.y


func choose(branch_id: String, choice_id: String) -> void:
	branches[branch_id] = choice_id


func chosen(branch_id: String) -> String:
	return String(branches.get(branch_id, ""))


func log_event(text: String, choice := "") -> void:
	events.append({"text": text, "choice": choice})


# ---------------- crew ----------------

func crew_member(role: String) -> Dictionary:
	for c in crew:
		if c["role"] == role:
			return c
	return {}


## True while that role is on board and well enough to work.
func crew_fit(role: String) -> bool:
	var c := crew_member(role)
	return not c.is_empty() and float(c["health"]) > 0.0


## Hurt one crew member and say why. Returns true if this is the hit that took their last heart (they are lost).
## reason is the full sentence for the pop-up. short is the few words shown under their name afterwards.
func hurt(index: int, amount: float, reason := "They were hurt.", short := "") -> bool:
	if index < 0 or index >= crew.size() or amount <= 0.0:
		return false
	var was_alive := float(crew[index]["health"]) > 0.0
	if not was_alive:
		return false
	crew[index]["health"] = maxf(float(crew[index]["health"]) - amount, 0.0)
	var died := float(crew[index]["health"]) <= 0.0
	var s_text := short if short != "" else (reason if reason.length() <= 40 else reason.substr(0, 37) + "...")
	crew[index]["note"] = s_text
	damage_log.append({"name": crew[index]["name"], "amount": amount, "reason": reason, "died": died})
	if died:
		crew[index]["cause"] = reason
		log_event("%s died: %s" % [crew[index]["name"], reason])
	crew_hurt.emit(index, amount, reason, died)
	return died


## Hurt everyone who is still alive, for the same reason. Returns the names of anyone lost to it.
func hurt_all(amount: float, reason := "The crew was hurt.", short := "") -> Array[String]:
	var lost: Array[String] = []
	for i in crew.size():
		if hurt(i, amount, reason, short):
			lost.append(String(crew[i]["name"]))
	return lost


## The ship is destroyed with the crew aboard. Returns who was lost.
func kill_all(reason := "The ship was destroyed.") -> Array[String]:
	return hurt_all(1000.0, reason, "Ship destroyed")


## Who has died so far, and why.
func deaths() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in crew:
		if float(c["health"]) <= 0.0:
			out.append({"name": c["name"], "cause": c.get("cause", "")})
	return out


## A few words on how someone is doing, for the screen that is always up.
func status_line(index: int) -> String:
	if index < 0 or index >= crew.size():
		return ""
	var c: Dictionary = crew[index]
	var h := float(c["health"])
	if h <= 0.0:
		return "Lost: " + String(c.get("note", ""))
	if h < 100.0 and String(c.get("note", "")) != "":
		return String(c["note"])
	if h <= 40.0:
		return "Badly hurt."
	var e := float(c["energy"])
	if e <= 15.0:
		return "Exhausted."
	if e <= 40.0:
		return "Tired. Needs rest or food."
	return "Rested and ready."


func is_dead(index: int) -> bool:
	return index >= 0 and index < crew.size() and float(crew[index]["health"]) <= 0.0


func alive_count() -> int:
	var n := 0
	for c in crew:
		if float(c["health"]) > 0.0:
			n += 1
	return n


## Five hearts, 20 health each. 3.5 means three and a half hearts.
func hearts(index: int) -> float:
	return float(crew[index]["health"]) / 20.0 if index >= 0 and index < crew.size() else 0.0


## One line for the result screen, such as "Ada 5/5   Sam 3/5   Noor LOST".
func crew_summary() -> String:
	var bits: Array[String] = []
	for c in crew:
		bits.append("%s %s" % [c["name"], "LOST" if float(c["health"]) <= 0.0 else "%d/5" % int(ceil(float(c["health"]) / 20.0))])
	return "   ".join(bits)


func tire(index: int, amount: float) -> void:
	if index >= 0 and index < crew.size():
		crew[index]["energy"] = clampf(float(crew[index]["energy"]) - amount, 0.0, 100.0)
