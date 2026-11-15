class_name CrewData
extends RefCounted
## The crew. Seven people to choose from (art from the team's Drive: Crew members folder), three fly.
## Each of the three seats has a role; the player picks who sits in each seat and names them.
## Roles, traits and the health numbers are GAME rules, not NASA claims.

const CHARACTERS: Array[Dictionary] = [
	{"id": "ada", "name": "Ada"},
	{"id": "sam", "name": "Sam"},
	{"id": "noor", "name": "Noor"},
	{"id": "jules", "name": "Jules"},
	{"id": "imani", "name": "Imani"},
	{"id": "ren", "name": "Ren"},
	{"id": "tavi", "name": "Tavi"},
]
## One entry per seat. "char" is who sits there by default.
const ROLES: Array[Dictionary] = [
	{"role": "COMMANDER", "char": "ada", "trait": "Keeps the crew steady. Morale falls more slowly."},
	{"role": "PILOT", "char": "sam", "trait": "Steady hands. The Moon camera shakes 10% less."},
	{"role": "SCIENTIST", "char": "noor", "trait": "Quick analyst. Lab work takes less time."},
]
const MAX_NAME := 12

static var _cache := {}


static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func portrait(char_id: String) -> Texture2D:
	return _tex("res://assets/ui/crew/%s_portrait.png" % char_id)


static func idle_front(char_id: String) -> Texture2D:
	return _tex("res://assets/ui/crew/%s_idle_front.png" % char_id)


static func idle_right(char_id: String) -> Texture2D:
	return _tex("res://assets/ui/crew/%s_idle_right.png" % char_id)


## The four frames of the walk cycle, facing right.
static func walk_frames(char_id: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in 4:
		out.append(_tex("res://assets/ui/crew/%s_walk_%d.png" % [char_id, i]))
	return out


static func char_name(char_id: String) -> String:
	for c in CHARACTERS:
		if c["id"] == char_id:
			return c["name"]
	return char_id.capitalize()


static func char_ids() -> Array[String]:
	var out: Array[String] = []
	for c in CHARACTERS:
		out.append(c["id"])
	return out


## A fresh crew with full energy, health and morale.
static func defaults() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in ROLES:
		out.append(make(String(r["char"]), char_name(String(r["char"])), String(r["role"])))
	return out


static func make(char_id: String, crew_name: String, role: String) -> Dictionary:
	return {"name": crew_name, "role": role, "char": char_id, "energy": 100.0, "health": 100.0, "morale": 100.0, "note": "", "cause": ""}


## Names come from the player, so keep them plain: no markup characters, no control characters, short.
static func clean_name(raw: String, fallback: String) -> String:
	var s := ""
	for ch in raw.strip_edges():
		if ch in ["[", "]", "\n", "\r", "\t", "\\"]:
			continue
		s += ch
	s = s.strip_edges().substr(0, MAX_NAME).strip_edges()
	return s if s != "" else fallback


static func trait_for(role: String) -> String:
	for r in ROLES:
		if r["role"] == role:
			return r["trait"]
	return ""
