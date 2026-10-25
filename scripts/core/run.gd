class_name GameRun
extends RefCounted

const Catalog = preload("res://scripts/core/pieces.gd")
const Generator = preload("res://scripts/core/encounters.gd")
const SAVE_PATH = "user://progress.json"
const SKILL_COSTS = {"purse": 30, "reroll": 50, "bishop": 50}
var meta: Dictionary = {"exp": 0, "unlocks": []}
var active_unlocks: Array = []
var roster: Array = []
var currency: int = 50
var earned: int = 0
var stage: int = 0
var won: int = 0
var total_moves: int = 0
var total_captures: int = 0
var pawns_lost: int = 0
var temp_pawns_lost: int = 0
var run_seed: int = 1
var next_roster_id: int = 1
var shop: Array = []
var rerolled: bool = false
var finished: bool = false
var exp_awarded: int = 0
var save_error: String = ""

func load_meta(path: String = SAVE_PATH) -> void:
	meta = {"exp": 0, "unlocks": []}
	save_error = ""
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		save_error = "Could not read progression."
		return
	var parser = JSON.new()
	var parse_error = parser.parse(file.get_as_text())
	var data = parser.data
	if parse_error != OK or not data is Dictionary or (not data.get("exp") is float and not data.get("exp") is int) or not data.get("unlocks") is Array:
		save_error = "Progression file is invalid; using an empty profile."
		return
	meta.exp = maxi(0, int(data.exp))
	for key in data.unlocks:
		if SKILL_COSTS.has(key) and not meta.unlocks.has(key) and (key == "purse" or data.unlocks.has("purse")):
			meta.unlocks.append(key)

func save_meta(path: String = SAVE_PATH) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "Could not save progression."
		return false
	file.store_string(JSON.stringify({"version": 1, "exp": meta.exp, "unlocks": meta.unlocks}))
	file.close()
	var error = DirAccess.rename_absolute(path + ".tmp", path)
	save_error = "" if error == OK else "Could not replace progression file."
	return error == OK

func unlock(key: String, path: String = SAVE_PATH) -> bool:
	if not SKILL_COSTS.has(key) or meta.unlocks.has(key) or meta.exp < SKILL_COSTS[key]:
		return false
	if key != "purse" and not meta.unlocks.has("purse"):
		return false
	var before = meta.duplicate(true)
	meta.exp -= SKILL_COSTS[key]
	meta.unlocks.append(key)
	if not save_meta(path):
		meta = before
		return false
	return true

func start(seed_value: int) -> void:
	run_seed = seed_value
	active_unlocks = meta.unlocks.duplicate()
	currency = 70 if active_unlocks.has("purse") else 50
	earned = 0
	stage = 0
	won = 0
	total_moves = 0
	total_captures = 0
	pawns_lost = 0
	temp_pawns_lost = 0
	finished = false
	exp_awarded = 0
	next_roster_id = 1
	roster = []
	for kind in Catalog.TYPES:
		_add_owned(kind)

func _add_owned(kind: String) -> void:
	roster.append({"id": next_roster_id, "type": kind, "modifier": ""})
	next_roster_id += 1

func limits() -> Dictionary:
	return {"king": 1, "queen": 1, "rook": 2, "bishop": 3 if active_unlocks.has("bishop") else 2, "knight": 2}

func choices() -> Array:
	var out: Array = []
	for variant in range(3):
		out.append(Generator.generate(stage, variant, run_seed))
	return out

func record_battle(b: Battle) -> int:
	total_moves += b.turns
	total_captures += b.captures
	pawns_lost += b.owned_pawns_lost
	temp_pawns_lost += b.temporary_pawns_lost
	var points = b.reward()
	if b.result == "win":
		won += 1
		earned += points
		currency += points
	return points

func finish(victory: bool, path: String = SAVE_PATH) -> int:
	if finished:
		return exp_awarded
	finished = true
	exp_awarded = earned / 10 + won * 10 + (20 if victory else 0)
	meta.exp += exp_awarded
	save_meta(path)
	return exp_awarded

func open_shop() -> void:
	rerolled = false
	_roll_shop(0)

func _roll_shop(offset: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = run_seed + stage * 49999 + 1231 + offset
	shop = []
	# Guarantee at least one piece and one modifier in every visit.
	for i in range(3):
		var is_modifier = i == 1 or (i == 2 and rng.randf() < 0.5)
		var key: String = Catalog.MODIFIERS[rng.randi_range(0, 3)] if is_modifier else ["pawn", "knight", "bishop", "rook", "queen"][rng.randi_range(0, 4)]
		shop.append({"kind": "modifier" if is_modifier else "piece", "key": key, "price": 60 if is_modifier else Catalog.PRICES[key], "bought": false})

func reroll() -> bool:
	if rerolled or not active_unlocks.has("reroll"):
		return false
	rerolled = true
	_roll_shop(777)
	return true

func purchase_error(index: int, roster_id: int = -1) -> String:
	if index < 0 or index >= shop.size():
		return "Unknown item"
	var item: Dictionary = shop[index]
	if item.bought:
		return "Purchased"
	if currency < item.price:
		return "Not enough currency"
	if item.kind == "piece":
		if roster.size() >= 12:
			return "Deployment rows are full"
		var count = 0
		for p in roster:
			if p.type == item.key:
				count += 1
		if limits().has(item.key) and count >= limits()[item.key]:
			return "Roster limit reached"
	else:
		for p in roster:
			if p.id == roster_id:
				return "" if p.modifier == "" else "Piece already has a modifier"
		return "Select an unmodified piece"
	return ""

func purchase(index: int, roster_id: int = -1) -> bool:
	if purchase_error(index, roster_id) != "":
		return false
	var item: Dictionary = shop[index]
	currency -= item.price
	item.bought = true
	if item.kind == "piece":
		_add_owned(item.key)
	else:
		for p in roster:
			if p.id == roster_id:
				p.modifier = item.key
	return true
