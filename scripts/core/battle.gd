class_name Battle
extends RefCounted

const Catalog = preload("res://scripts/core/pieces.gd")
const ORTHO = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
var width: int = 5
var height: int = 6
var pieces: Dictionary = {}
var walls: Dictionary = {} # position -> active; an occupied death square starts dormant.
var clouds: Array = [] # Each cloud has independent remaining ticks for each side.
var side: int = 0
var phase: String = "move"
var bonus_id: int = -1
var next_id: int = 1
var turns: int = 0
var budget: int = 20
var objective: String = "knight"
var target_id: int = -1
var bonus: String = "speed"
var bonus_threshold: int = 10
var result: String = ""
var reason: String = ""
var events: Array = []
var captures: int = 0
var owned_pawns_lost: int = 0
var temporary_pawns_lost: int = 0
var promotion_reached: bool = false

func copy() -> Battle:
	var b = Battle.new()
	for key in ["width", "height", "pieces", "walls", "clouds", "side", "phase", "bonus_id", "next_id", "turns", "budget", "objective", "target_id", "bonus", "bonus_threshold", "result", "reason", "captures", "owned_pawns_lost", "temporary_pawns_lost", "promotion_reached"]:
		var value = get(key)
		b.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	return b

func add_piece(kind: String, owner: int, pos: Vector2i, modifier: String = "", owned: bool = false) -> int:
	var id = next_id
	next_id += 1
	pieces[id] = {"id": id, "type": kind, "side": owner, "pos": pos, "hp": 2, "modifier": modifier, "owned": owned}
	return id

func inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func at(pos: Vector2i) -> int:
	for id in pieces:
		if pieces[id].pos == pos:
			return id
	return -1

func blocked(pos: Vector2i) -> bool:
	return walls.get(pos, false)

func destinations(id: int, reposition: bool = false) -> Array:
	var out: Array = []
	if not pieces.has(id):
		return out
	var p: Dictionary = pieces[id]
	var pos: Vector2i = p.pos
	if reposition:
		for d in ORTHO + DIAG:
			var to: Vector2i = pos + d
			if inside(to) and at(to) == -1 and not blocked(to):
				out.append(to)
		return out
	if p.type == "pawn":
		var forward = Vector2i(0, -1 if p.side == 0 else 1)
		var to: Vector2i = pos + forward
		if inside(to) and not blocked(to) and at(to) == -1:
			out.append(to)
		for x in [-1, 1]:
			to = pos + forward + Vector2i(x, 0)
			var other = at(to)
			if inside(to) and not blocked(to) and other != -1 and pieces[other].side != p.side:
				out.append(to)
		return out
	var dirs: Array = []
	var sliding = true
	match p.type:
		"rook": dirs = ORTHO
		"bishop": dirs = DIAG
		"queen": dirs = ORTHO + DIAG
		"king":
			dirs = ORTHO + DIAG
			sliding = false
		"knight":
			dirs = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
			sliding = false
	for d in dirs:
		var to: Vector2i = pos + d
		while inside(to) and not blocked(to):
			var other = at(to)
			if other != -1:
				if pieces[other].side != p.side:
					out.append(to)
				break
			out.append(to)
			if not sliding:
				break
			to += d
	return out

func legal_actions() -> Array:
	var out: Array = []
	if result != "":
		return out
	if phase == "bonus":
		out.append({"kind": "skip"})
		for to in destinations(bonus_id, true):
			out.append({"kind": "reposition", "id": bonus_id, "to": to})
		return out
	for id in pieces:
		if pieces[id].side == side:
			for to in destinations(id):
				out.append({"kind": "move", "id": id, "to": to})
	return out

func apply(action: Dictionary) -> Array:
	events = []
	if not legal_actions().has(action):
		return [{"kind": "invalid", "text": "Illegal action rejected."}]
	if action.kind == "skip":
		_finish_turn()
		return events.duplicate(true)
	var id: int = action.id
	var p: Dictionary = pieces[id]
	var from: Vector2i = p.pos
	var victim = at(action.to)
	var deaths: Array = []
	if action.kind == "move" and side == 0:
		turns += 1
	if victim != -1:
		deaths.append(_remove(victim, "capture"))
		if side == 0:
			captures += 1
	pieces[id].pos = action.to
	_emit("move", "%s %s moved." % ["Your" if side == 0 else "Enemy", p.type], {"id": id, "from": from, "to": action.to})
	_activate_walls()
	_resolve_deaths(deaths)
	if p.type == "pawn" and action.to.y == (0 if side == 0 else height - 1):
		if side == 0:
			promotion_reached = true
		_check_objective()
		if result == "":
			var has_queen = false
			for other in pieces.values():
				if other.side == side and other.type == "queen":
					has_queen = true
			pieces[id].type = "rook" if has_queen else "queen"
			_emit("promotion", "Pawn promoted to %s." % pieces[id].type)
	_check_objective()
	if result != "":
		return events.duplicate(true)
	if action.kind == "move" and victim != -1 and p.modifier == "reposition" and not destinations(id, true).is_empty():
		phase = "bonus"
		bonus_id = id
		_emit("bonus", "Optional reposition: choose an empty neighbor or skip.")
	else:
		_finish_turn()
	return events.duplicate(true)

func _emit(kind: String, message: String, data: Dictionary = {}) -> void:
	var e = data.duplicate(true)
	e.kind = kind
	e.text = message
	events.append(e)

func _remove(id: int, cause: String) -> Dictionary:
	var p: Dictionary = pieces[id].duplicate(true)
	pieces.erase(id)
	if p.side == 0 and p.type == "pawn":
		if p.owned:
			owned_pawns_lost += 1
		else:
			temporary_pawns_lost += 1
	_emit("capture" if cause == "capture" else "death", "%s %s lost (%s)." % ["Your" if p.side == 0 else "Enemy", p.type, cause], {"piece": p})
	return p

func _resolve_deaths(queue: Array) -> void:
	for p in queue:
		match p.modifier:
			"wall":
				walls[p.pos] = at(p.pos) == -1
				_emit("wall", "A fallen piece leaves a wall.", {"pos": p.pos})
			"reinforcement":
				var y = height - 1 if p.side == 0 else 0
				for x in range(width):
					var pos = Vector2i(x, y)
					if at(pos) == -1 and not blocked(pos):
						var id = add_piece("pawn", p.side, pos)
						_emit("spawn", "A reinforcement pawn arrives.", {"id": id, "pos": pos})
						break
			"poison":
				var cells: Array = [p.pos]
				for d in ORTHO:
					if inside(p.pos + d):
						cells.append(p.pos + d)
				clouds.append({"cells": cells, "ticks": [2, 2]})
				_emit("poison", "A poison cross lingers for two turns per side.")
	_activate_walls()

func _activate_walls() -> void:
	for pos in walls:
		if not walls[pos] and at(pos) == -1:
			walls[pos] = true

func poison_at(pos: Vector2i, owner: int) -> bool:
	for cloud in clouds:
		if cloud.ticks[owner] > 0 and cloud.cells.has(pos):
			return true
	return false

func _start_turn() -> void:
	# Snapshot exposure, tick old clouds, then resolve deaths. New clouds tick next turn.
	var exposed: Array = []
	for id in pieces:
		if pieces[id].side == side and poison_at(pieces[id].pos, side):
			exposed.append(id)
	for cloud in clouds:
		cloud.ticks[side] = maxi(0, cloud.ticks[side] - 1)
	clouds = clouds.filter(func(c): return c.ticks[0] > 0 or c.ticks[1] > 0)
	var deaths: Array = []
	for id in exposed:
		pieces[id].hp -= 1
		_emit("damage", "%s %s takes 1 poison damage." % ["Your" if side == 0 else "Enemy", pieces[id].type], {"id": id, "amount": 1})
		if pieces[id].hp <= 0:
			deaths.append(_remove(id, "poison"))
	_resolve_deaths(deaths)
	_check_objective()
	if result != "":
		return
	if side == 0:
		if legal_actions().is_empty():
			_end("loss", "Your army has no legal moves.")
	elif legal_actions().is_empty():
		_emit("pass", "Enemy has no legal moves and passes.")
		side = 0
		_start_turn()

func _finish_turn() -> void:
	phase = "move"
	bonus_id = -1
	_check_objective()
	if result != "":
		return
	if side == 0 and turns >= budget:
		_end("loss", "The move budget is exhausted.")
		return
	side = 1 - side
	_start_turn()

func _check_objective() -> void:
	if result != "":
		return
	if (objective == "promote" and promotion_reached) or (objective != "promote" and target_id >= 0 and not pieces.has(target_id)):
		_end("win", "Objective complete!")
		return
	var living = false
	for p in pieces.values():
		if p.side == 0:
			living = true
	if not living:
		_end("loss", "Your army has been eliminated.")

func _end(outcome: String, message: String) -> void:
	result = outcome
	reason = message
	_emit("result", message, {"result": outcome})

func begin() -> void:
	events = []
	_start_turn()

func bonus_complete() -> bool:
	return turns <= bonus_threshold if bonus == "speed" else owned_pawns_lost == 0

func reward() -> int:
	return 100 + 5 * maxi(0, budget - turns) + (30 if bonus_complete() else 0) if result == "win" else 0
