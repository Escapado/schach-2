extends "res://scripts/sandbox/chess_battle.gd"
## Variant resolver. With no experimental content, delegates to orthodox chess.
const Chaos = preload("res://scripts/sandbox/chaos_catalog.gd")
var rules: Dictionary = {}
var holes: Dictionary = {}
var mines: Dictionary = {}
var belts: Array = []
var remaining := 0
var active_id := -1
var round_number := 1
var chaos := false
var _checking_legality := false
var _cancelled_capture := -1
var royal_mode: Array = ["king", "king"]

func _copy_state(with_cache: bool):
	var clone = super._copy_state(with_cache)
	for key in ["rules", "holes", "mines", "belts", "remaining", "active_id", "round_number", "chaos", "royal_mode"]:
		var value = get(key)
		clone.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	return clone

func footprint(id: int, anchor: Variant = null) -> Array:
	if not pieces.has(id): return []
	var origin: Vector2i = pieces[id].pos if anchor == null else anchor
	return [_normalize(origin)]

func at(square: Vector2i) -> int:
	return super.at(square)

func _fits(id: int, anchor: Vector2i, occupied: bool = false) -> bool:
	for square in footprint(id, anchor):
		if blocked(square) or holes.has(square) or (not inside(square) and not has_upgrade(id, "voidwalker")): return false
		var other = at(square)
		if occupied and other != -1 and other != id: return false
	return true

func has_upgrade(id: int, upgrade: String) -> bool:
	if not pieces.has(id):
		return false
	return pieces[id].get("upgrades", []).has(upgrade)

func _enable() -> void:
	for p in pieces.values():
		if Chaos.ROYALS.has(p.type): p.royal = true
	chaos = true
	castle_rights = [[false, false], [false, false]]
	_legal_signature = ""

func setup_group(id: int) -> Array:
	if not pieces.has(id): return []
	var p: Dictionary = pieces[id]
	var out: Array = [id]
	var other = at(Vector2i(width - 1 - p.pos.x, p.pos.y))
	if other != -1 and other != id and pieces[other].side == p.side and pieces[other].type == p.type:
		out.append(other)
	return out

func place_setup_piece(kind: String, square: Vector2i) -> String:
	var error = _setup_square_error(square)
	if error != "": return error
	if not Catalog.TYPES.has(kind) and not Chaos.PIECES.has(kind): return "Choose an available piece."
	var id = at(square)
	if id == -1 or pieces[id].side != 0: return "Replace an occupied friendly piece."
	if pieces[id].type == "pawn" or kind == "pawn": return "Pawn types and positions are fixed. Unit upgrades are allowed."
	if kind == "king": return move_setup_piece(at(king_position(0)), square)
	if is_royal(id): return "Move your royal instead of replacing it."
	var group = setup_group(id)
	if kind == "portal":
		var existing = pieces.values().filter(func(p): return p.side == 0 and p.type == "portal" and not group.has(p.id)).size()
		if existing + group.size() != 2: return "Portals require one mirrored pair."
	for member in group: pieces[member].type = kind
	if Chaos.PIECES.has(kind): _enable()
	return ""

func move_setup_piece(id: int, square: Vector2i) -> String:
	var error = _setup_square_error(square)
	if error != "": return error
	if not pieces.has(id) or pieces[id].side != 0: return "Select a friendly piece."
	if pieces[id].type == "pawn": return "Pawn types and positions are fixed."
	var group = setup_group(id)
	var origin: Vector2i = pieces[id].pos
	var targets: Dictionary = {id: square}
	if group.size() == 2: targets[group[1] if group[0] == id else group[0]] = Vector2i(width - 1 - square.x, square.y)
	var exchange: Dictionary = {}
	for member in targets:
		var to: Vector2i = targets[member]
		if not is_setup_square(to) or blocked(to) or holes.has(to): return "Both mirrored destinations must be open deployment squares."
		var other = at(to)
		if other != -1 and not group.has(other):
			if pieces[other].side != 0 or pieces[other].type == "pawn": return "Pawn positions are fixed."
			if setup_group(other).size() != group.size(): return "Keep paired pieces in mirrored slots; the king/queen center is separate."
			exchange[other] = pieces[member].pos
	for member in exchange: pieces[member].pos = exchange[member]
	for member in targets: pieces[member].pos = targets[member]
	return ""

func equip(id: int, upgrade: String) -> String:
	if phase != "setup" or not Chaos.UPGRADES.has(upgrade) or not pieces.has(id) or pieces[id].side != 0:
		return "Choose a friendly piece during preparation."
	for member in setup_group(id):
		var list: Array = pieces[member].get("upgrades", []).duplicate()
		if upgrade == "+1": list.erase("+2")
		if upgrade == "+2": list.erase("+1")
		if not list.has(upgrade): list.append(upgrade)
		pieces[member].upgrades = list
	_enable()
	return ""

func _replace_royals(kind: String, owner: int = 0) -> String:
	var king = -1
	var queen = -1
	for p in pieces.values():
		if p.side != owner: continue
		if p.type == "king": king = p.id
		if p.type == "queen": queen = p.id
	if king != -1:
		var center_queen = at(Vector2i(width - 1 - pieces[king].pos.x, pieces[king].pos.y))
		if center_queen != -1 and pieces[center_queen].side == owner and pieces[center_queen].type == "queen": queen = center_queen
	if kind != "regent" or king == -1 or queen == -1:
		return "Twin Regents require a king and queen."
	pieces[king].type = kind
	pieces[queen].type = kind
	pieces[queen].royal = true
	var shared: Array = pieces[king].get("upgrades", []).duplicate()
	for upgrade in pieces[queen].get("upgrades", []):
		if not shared.has(upgrade): shared.append(upgrade)
	if shared.has("+2"): shared.erase("+1")
	pieces[king].upgrades = shared.duplicate()
	pieces[queen].upgrades = shared.duplicate()
	royal_mode[owner] = kind
	_enable()
	return ""

func roundabout(owner: int = 0) -> Array:
	var top = height - 4 if owner == 0 else 2
	var route: Array = []
	for x in range(width): route.append(Vector2i(x, top))
	for x in range(width - 1, -1, -1): route.append(Vector2i(x, top + 1))
	route.append(route[0])
	return route

func set_roundabout(owner: int, enabled: bool = true) -> void:
	if phase != "setup" or owner not in [0, 1]: return
	belts = belts.filter(func(route): return not route.is_empty() and (0 if route[0].y >= height / 2 else 1) != owner)
	rules["belt" if owner == 0 else "enemy_belt"] = enabled
	if enabled: belts.append(roundabout(owner))
	_enable()

func toggle_rule(key: String) -> String:
	if phase != "setup": return "Board editing is locked during battle."
	if not Chaos.BOARDS.has(key): return "Choose an available board upgrade."
	if key == "regents": return _replace_royals("regent")
	if key == "belt":
		set_roundabout(0, not rules.get("belt", false))
		return ""
	if key == "large":
		if width == 10: return "Already 10×10. Reset to return to 8×8."
		for p in pieces.values():
			p.pos.x += 1
			if p.side == 0: p.pos.y += 2
		width = 10
		height = 10
		for owner in range(2):
			for x in [0, 9]:
				add_piece("rook", owner, Vector2i(x, 9 if owner == 0 else 0))
				add_piece("elephant", owner, Vector2i(x, 8 if owner == 0 else 1))
		var shifted: Dictionary = {}
		for pos in walls: shifted[pos + Vector2i(1, 2 if pos.y >= 4 else 0)] = walls[pos]
		walls = shifted
		shifted = {}
		for pos in mines: shifted[pos + Vector2i(1, 2 if pos.y >= 4 else 0)] = mines[pos]
		mines = shifted
		belts = []
		if rules.get("belt", false): set_roundabout(0)
		if rules.get("enemy_belt", false): set_roundabout(1)
	else:
		rules[key] = not rules.get(key, false)
	_enable()
	return ""

func edit_terrain(tool: String, square: Vector2i) -> String:
	if phase != "setup" or not inside(square) or square.y < height / 2:
		return "Terrain can be edited only in your half before battle."
	if tool == "terrain_erase":
		walls.erase(square)
		mines.erase(square)
	elif tool == "belt":
		return "Use the Conveyor Belt board upgrade to enable the fixed roundabout."
	elif tool in ["wall", "mine"]:
		if at(square) != -1: return "Place terrain on an empty square."
		if tool == "wall":
			if walls.has(square): walls.erase(square)
			else: walls[square] = true; mines.erase(square)
		else:
			if blocked(square): return "A mine cannot occupy a wall."
			if mines.has(square): mines.erase(square)
			else: mines[square] = 0
	_enable()
	return ""

func start_prepared() -> String:
	if not chaos: return super.start_prepared()
	if phase != "setup": return "Battle has already started."
	for route in belts:
		if route.is_empty(): return "Conveyors must follow the fixed two-rank roundabout."
		var owner = 0 if route[0].y >= height / 2 else 1
		if route != roundabout(owner): return "Conveyors must follow the fixed two-rank roundabout."
	var occupied: Dictionary = {}
	for p in pieces.values():
		for cell in footprint(p.id):
			if not inside(cell) or blocked(cell) or holes.has(cell) or occupied.has(cell): return "Pieces need distinct, intact, unblocked squares for their entire footprint."
			if p.side == 0 and not is_setup_square(cell): return "Deploy only in the bottom two ranks."
			occupied[cell] = true
	for owner in range(2):
		if _royals(owner).is_empty(): return "Each side needs a royal."
		var portals = pieces.values().filter(func(p): return p.side == owner and p.type == "portal").size()
		if portals == 1: return "Place the second portal, or replace the first."
	if uses_check(1) and in_check(1): return "Black cannot start in check. Adjust your formation."
	_enable()
	phase = "move"
	begin()
	return ""

func _royals(owner: int) -> Array:
	return pieces.values().filter(func(p): return p.side == owner and p.get("royal", Chaos.ROYALS.has(p.type)))

func king_position(owner: int) -> Vector2i:
	if chaos and uses_check(owner):
		var royals = _royals(owner)
		return royals[0].pos if not royals.is_empty() else Vector2i(-1, -1)
	return super.king_position(owner)

func uses_check(owner: int) -> bool:
	return royal_mode[owner] == "king"

func in_check(owner: int) -> bool:
	if not chaos: return super.in_check(owner)
	if not uses_check(owner): return false
	var royals = _royals(owner)
	if royals.is_empty(): return true
	var simple_geometry = not rules.get("wrap", false) and not pieces.values().any(func(p): return p.type == "portal")
	for royal in royals:
		for p in pieces.values():
			if p.side == owner: continue
			if simple_geometry:
				if _direct_attack(p.id, royal.pos): return true
				continue
			if p.type not in ["seductress", "bouncer"] and destinations(p.id).has(royal.pos): return true
			if has_upgrade(p.id, "gun"):
				for d in (ORTHO + DIAG):
					for to in _ray(p.id, d, 0, true):
						if at(to) == royal.id: return true
	return false

func _direct_attack(id: int, target: Vector2i) -> bool:
	var p: Dictionary = pieces[id]
	var delta: Vector2i = target - p.pos
	var distance = maxi(absi(delta.x), absi(delta.y))
	var straight = delta.x == 0 or delta.y == 0
	var diagonal = absi(delta.x) == absi(delta.y)
	if distance == 0: return false
	var movement := false
	match p.type:
		"king": movement = distance == 1
		"knight": movement = absi(delta.x) * absi(delta.y) == 2
		"pawn": movement = absi(delta.x) == 1 and delta.y == (-1 if p.side == 0 else 1)
		"rook", "ghost": movement = straight
		"bishop": movement = diagonal
		"queen": movement = straight or diagonal
		"regent": movement = (straight or diagonal) and distance <= 3
		"elephant": movement = straight and distance <= 2
	var gun = has_upgrade(id, "gun") and (straight or diagonal)
	if not movement and not gun: return false
	if blocked(target) or holes.has(target): return false
	if movement and p.type in ["king", "knight", "pawn"]: return true
	var d = Vector2i(signi(delta.x), signi(delta.y))
	# A short in-board ray is cheap; sparse coordinates keep distant threats bounded.
	for square in walls.keys() + holes.keys():
		var offset: Vector2i = square - p.pos
		if offset.x * d.y == offset.y * d.x and offset.x * d.x + offset.y * d.y > 0 and offset.length_squared() < delta.length_squared(): return false
	for other in pieces.values():
		if other.id == id: continue
		for square in footprint(other.id):
			var offset: Vector2i = square - p.pos
			if square == target: continue
			if offset.x * d.y != offset.y * d.x or offset.x * d.x + offset.y * d.y <= 0 or offset.length_squared() >= delta.length_squared(): continue
			gun = false
			if not (p.type == "ghost" or has_upgrade(id, "phasing") or (p.type == "elephant" and other.side != p.side)): movement = false
	return movement or gun

func _capture_targets(action: Dictionary) -> Array:
	if action.kind not in ["move", "shoot"] or not pieces.has(action.id): return []
	var p: Dictionary = pieces[action.id]
	if action.kind == "move" and p.type in ["seductress", "bouncer"]: return []
	var cells: Array = [action.to]
	if action.kind == "move" and p.type == "elephant":
		cells = []
		cells = _capture_path(p.id, action.to)
	var targets: Array = []
	for cell in cells:
		var id = at(cell)
		if id != -1 and id != p.id and pieces[id].side != p.side and not targets.has(id): targets.append(id)
	return targets

func _action_safe(action: Dictionary) -> bool:
	for target in _capture_targets(action):
		if is_royal(target) and uses_check(pieces[target].side): return false
	if not uses_check(side): return true
	var probe = _copy_state(false)
	probe._checking_legality = true
	probe.events = []
	# Legality must not reveal concealed enemy traps.
	for square in probe.mines.keys():
		if probe.mines[square] != side: probe.mines.erase(square)
	for p in probe.pieces.values():
		if p.side != side:
			p.upgrades = p.get("upgrades", []).duplicate()
			p.upgrades.erase("dagger")
	if action.kind in ["move", "shoot"]:
		probe._resolve_action(action)
		var allowance = remaining if phase == "bonus" else 3 if has_upgrade(action.id, "+2") else 2 if has_upgrade(action.id, "+1") else 1
		if allowance <= 1 or not probe.pieces.has(action.id): probe._end_turn()
	elif action.kind == "skip": probe._end_turn()
	return not probe.in_check(side)

func _resolve_turn_status() -> void:
	if result != "" or _checking_legality: return
	var checked = in_check(side)
	var has_action = not legal_actions().is_empty() if checked else _pseudo_actions().any(func(action): return _action_safe(action))
	if not has_action:
		if uses_check(side):
			if in_check(side): _end("loss" if side == 0 else "win", "%s wins by checkmate." % ("Black" if side == 0 else "White"))
			else: _end("draw", "Draw by stalemate.")
		else: _end("loss" if side == 0 else "win", "No legal action remains.")
	elif checked: _emit("check", "%s is in check." % ("White" if side == 0 else "Black"))

func begin() -> void:
	if not chaos: super.begin(); return
	events = []
	_start_turn()
	_resolve_royals()
	_resolve_turn_status()

func _normalize(square: Vector2i) -> Vector2i:
	if rules.get("wrap", false): square.x = posmod(square.x, width)
	return square

func _walkable(square: Vector2i, id: int) -> bool:
	return not blocked(square) and not holes.has(square) and (inside(square) or has_upgrade(id, "voidwalker") or (at(square) != -1 and pieces[at(square)].side != pieces[id].side))

# A ray is bounded by visited cells, not board width, so cylindrical paths terminate.
func _ray(id: int, direction: Vector2i, max_steps: int = 0, shooting: bool = false) -> Array:
	var p: Dictionary = pieces[id]
	var origin: Vector2i = p.pos
	var cursor = origin
	var visited: Dictionary = {origin: true}
	var out: Array = []
	var used_portal := false
	var offboard_pieces = pieces.values().any(func(other): return not inside(other.pos))
	var limit = max_steps if max_steps > 0 else maxi(width, height) * 2 + 8
	# Include arbitrarily distant aligned units and nearby squares around them.
	if has_upgrade(id, "voidwalker") or not inside(origin) or offboard_pieces:
		for other in pieces.values():
			limit = maxi(limit, maxi(absi(other.pos.x - origin.x), absi(other.pos.y - origin.y)) + 2)
	limit = mini(limit, 256) # Candidate generation only; coordinate_action handles arbitrary distance.
	for step in range(limit):
		cursor = _normalize(cursor + direction)
		if visited.has(cursor): break
		visited[cursor] = true
		if blocked(cursor) or holes.has(cursor): break
		var target = at(cursor)
		if target == id: target = -1
		if not inside(cursor) and not has_upgrade(id, "voidwalker"):
			if not offboard_pieces: break
			# A normal slider may capture an aligned off-board enemy, crossing empty void.
			if target != -1:
				if pieces[target].side != p.side and (p.type != "ghost" or pieces[target].get("royal", Chaos.ROYALS.has(pieces[target].type))): out.append(cursor)
				if shooting or (p.type != "ghost" and not has_upgrade(id, "phasing")): break
			continue
		if target != -1 and pieces[target].type == "portal" and pieces[target].side == p.side and not shooting and not used_portal:
			for exit in pieces.values():
				if exit.id != target and exit.side == p.side and exit.type == "portal":
					cursor = exit.pos
					used_portal = true
					break
			if used_portal: continue
		if target == -1:
			if not shooting: out.append(cursor)
			continue
		if shooting:
			if pieces[target].side != p.side: out.append(cursor)
			break
		if pieces[target].side != p.side and (p.type != "ghost" or pieces[target].get("royal", Chaos.ROYALS.has(pieces[target].type))):
			out.append(cursor)
		if p.type == "ghost" or has_upgrade(id, "phasing"): continue
		break
	return out

func destinations(id: int, reposition: bool = false) -> Array:
	if not chaos: return super.destinations(id, reposition)
	if not pieces.has(id) or reposition: return []
	var p: Dictionary = pieces[id]
	var out: Array = []
	match p.type:
		"factory", "portal": return []
		"pawn":
			var d = Vector2i(0, -1 if p.side == 0 else 1)
			var to = _normalize(p.pos + d)
			if _walkable(to, id) and at(to) == -1:
				out.append(to)
				var two = _normalize(to + d)
				if p.pos.y == (height - 2 if p.side == 0 else 1) and _walkable(two, id) and at(two) == -1: out.append(two)
			for x in [-1, 1]:
				to = _normalize(p.pos + d + Vector2i(x, 0))
				if _walkable(to, id) and at(to) != -1 and pieces[at(to)].side != p.side: out.append(to)
		"knight", "king", "bouncer", "seductress":
			var dirs: Array = ORTHO + DIAG
			if p.type == "knight": dirs = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
			for d in dirs:
				var to = _normalize(p.pos + d)
				if not _walkable(to, id): continue
				var target = at(to)
				if target == -1 or (pieces[target].side != p.side and (p.type != "seductress" or not pieces[target].get("royal", Chaos.ROYALS.has(pieces[target].type)))) or p.type == "bouncer": out.append(to)
		_:
			var dirs: Array = ORTHO
			if p.type == "bishop": dirs = DIAG
			if p.type in ["queen", "regent"]: dirs = ORTHO + DIAG
			for d in dirs:
				if p.type == "elephant":
					for n in [1, 2]:
						var to = _normalize(p.pos + d * n)
						if not _walkable(to, id) or (at(to) != -1 and pieces[at(to)].side == p.side): break
						out.append(to)
				else: out.append_array(_ray(id, d, 3 if p.type == "regent" else 0))
	return out

func legal_actions() -> Array:
	if not chaos: return super.legal_actions()
	if result != "" or phase not in ["move", "bonus"]: return []
	var signature = var_to_str([width, height, pieces, side, phase, rules, holes, walls, mines, belts, remaining, active_id, royal_mode])
	if signature != _legal_signature:
		_legal_cache = _pseudo_actions().filter(func(action): return _action_safe(action))
		_legal_signature = signature
	return _legal_cache.duplicate(true)

func _pseudo_actions() -> Array:
	if result != "" or phase not in ["move", "bonus"]: return []
	var out: Array = []
	for p in pieces.values():
		if p.side != side or (phase == "bonus" and p.id != active_id): continue
		for to in destinations(p.id):
			var action = {"kind": "move", "id": p.id, "to": to}
			if p.type == "pawn" and to.y == (0 if p.side == 0 else height - 1): action.promotion = "queen"
			out.append(action)
		if has_upgrade(p.id, "gun"):
			for d in (ORTHO + DIAG):
				for to in _ray(p.id, d, 0, true):
					out.append({"kind": "shoot", "id": p.id, "to": to})
	if phase == "bonus": out.append({"kind": "skip", "id": active_id, "to": Vector2i.ZERO})
	# Infinite rays use a finite nearby window plus every aligned occupied off-board target.
	for p in pieces.values():
		if p.side != side or (phase == "bonus" and p.id != active_id): continue
		for target in pieces.values():
			if target.side == side or (inside(target.pos) and inside(p.pos)): continue
			var candidate = _coordinate_action_unchecked(p.id, target.pos)
			if not candidate.is_empty() and not out.has(candidate): out.append(candidate)
			var shot = _coordinate_shot_unchecked(p.id, target.pos)
			if not shot.is_empty() and not out.has(shot): out.append(shot)
	return out

func apply(action: Dictionary) -> Array:
	if not chaos: return super.apply(action)
	if not legal_actions().has(action): return [{"kind": "invalid", "text": "Illegal experimental action rejected."}]
	events = []
	if action.kind == "skip":
		_end_turn()
		return events.duplicate(true)
	if phase == "move":
		active_id = action.id
		remaining = 3 if has_upgrade(active_id, "+2") else 2 if has_upgrade(active_id, "+1") else 1
	_resolve_action(action)
	if _cancelled_capture >= 0 and in_check(side):
		_emit("check", "The save cancelled this attempt. You must still resolve check.")
		return events.duplicate(true)
	ply += 1
	remaining -= 1
	_resolve_royals()
	if result == "":
		if remaining > 0 and pieces.has(active_id): phase = "bonus"
		else: _end_turn()
	return events.duplicate(true)

func _capture(attacker: int, victim: int) -> String:
	if not pieces.has(attacker) or not pieces.has(victim): return "gone"
	var lost: Dictionary = pieces[victim].duplicate(true)
	if has_upgrade(victim, "backup"):
		pieces[victim].type = "rook"
		pieces[victim].upgrades.erase("backup")
		_emit("backup", "Backup replaces the victim with a rook; the attacker stays put.")
		_cancelled_capture = victim
		return "saved"
	var dagger = has_upgrade(victim, "dagger")
	pieces.erase(victim)
	_emit("capture", "%s captured." % lost.type.capitalize(), {"piece": lost})
	if dagger:
		pieces.erase(attacker)
		_emit("dagger", "A concealed dagger kills the capturer.")
	return "captured"

func _displace(id: int, to: Vector2i) -> void:
	if not pieces.has(id): return
	var from: Vector2i = pieces[id].pos
	if from == to: return
	var departed = footprint(id)
	pieces[id].pos = to
	if has_upgrade(id, "eldritch"):
		for cell in departed:
			if inside(cell) and not footprint(id).has(cell): holes[cell] = true
		_emit("eldritch", "The departure tile vanishes.")
	for cell in footprint(id):
		if mines.has(cell) and mines[cell] != pieces[id].side:
			mines.erase(cell)
			pieces.erase(id)
			_emit("mine", "A buried mine destroys its visitor.")
			break

func _resolve_action(action: Dictionary) -> void:
	var before = _copy_state(false)
	var event_start = events.size()
	_cancelled_capture = -1
	_resolve_action_inner(action)
	if _cancelled_capture >= 0:
		var victim = _cancelled_capture
		var saved = pieces[victim].duplicate(true)
		var notices = events.slice(event_start).filter(func(e): return e.kind == "backup")
		pieces = before.pieces.duplicate(true)
		pieces[victim] = saved
		holes = before.holes.duplicate(true)
		mines = before.mines.duplicate(true)
		result = before.result
		reason = before.reason
		events.resize(event_start)
		events.append_array(notices)
		_emit("cancel", "The attack is cancelled; all earlier effects of this attack are undone.")

func _resolve_action_inner(action: Dictionary) -> void:
	var id: int = action.id
	var p: Dictionary = pieces[id].duplicate(true)
	var origin: Vector2i = p.pos
	var to: Vector2i = action.to
	var target = at(to)
	if action.kind == "shoot":
		if has_upgrade(id, "gun"): pieces[id].upgrades.erase("gun")
		_capture(id, target)
		_emit("shot", "%s fires." % p.type.capitalize())
		return
	if p.type == "seductress" and target != -1:
		pieces[target].side = p.side
		_emit("convert", "Seductress converts %s." % pieces[target].type)
		return
	if p.type == "bouncer" and target != -1:
		var d: Vector2i = to - origin
		if rules.get("wrap", false) and absi(d.x) > 1: d.x = -signi(d.x)
		var cursor = to
		var visited: Dictionary = {origin: true, to: true}
		while true:
			var next = _normalize(cursor + d)
			if visited.has(next) or not _fits(target, pieces[target].pos + next - to, true): break
			visited[next] = true
			cursor = next
		_displace(target, pieces[target].pos + cursor - to)
		_emit("push", "Bouncer pushes the unit.")
		return
	var victims: Array = []
	if p.type == "elephant":
		for cursor in _capture_path(id, to):
			var other = at(cursor)
			if other != -1 and other != id and not victims.has(other): victims.append(other)
	elif target != -1: victims.append(target)
	var captured := false
	for victim in victims:
		if not pieces.has(id): break
		var outcome = _capture(id, victim)
		if outcome == "saved": return
		captured = true
	if pieces.has(id):
		_displace(id, to)
		if pieces.has(id) and captured and has_upgrade(id, "recoil") and not holes.has(origin) and not blocked(origin) and at(origin) in [-1, id] and _fits(id, origin, true): _displace(id, origin)
		if pieces.has(id) and not inside(pieces[id].pos) and not has_upgrade(id, "voidwalker"):
			pieces.erase(id)
			_emit("void", "The capturer falls into the void.")
		if pieces.has(id) and action.has("promotion"): pieces[id].type = action.promotion
	_emit("move", "%s acts: %s → %s." % [p.type.capitalize(), str(origin), str(to)])

func _capture_path(id: int, to: Vector2i) -> Array:
	var p: Dictionary = pieces[id]
	if p.type == "elephant":
		for d in ORTHO:
			var path: Array = []
			for distance in [1, 2]:
				var cell = _normalize(p.pos + d * distance)
				path.append(cell)
				if cell == to: return path
		return []
	# Coordinate-entry moves may be extremely distant: only occupied path squares matter.
	if not inside(to) or not inside(p.pos):
		var delta: Vector2i = to - p.pos
		var d = Vector2i(signi(delta.x), signi(delta.y))
		var path = pieces.values().filter(func(other):
			var offset: Vector2i = other.pos - p.pos
			return other.id != id and offset.x * d.y == offset.y * d.x and offset.x * d.x + offset.y * d.y > 0 and offset.length_squared() <= delta.length_squared())
		path.sort_custom(func(a, b): return (a.pos - p.pos).length_squared() < (b.pos - p.pos).length_squared())
		return path.map(func(other): return other.pos)
	for d in ORTHO:
		if not _ray(id, d, 2 if p.type == "elephant" else 0).has(to) and p.type != "elephant": continue
		var cursor: Vector2i = p.pos
		var path: Array = []
		var visited: Dictionary = {cursor: true}
		var teleported := false
		for _step in range(2 if p.type == "elephant" else width * height + 8):
			cursor = _normalize(cursor + d)
			if visited.has(cursor) or blocked(cursor) or holes.has(cursor): break
			visited[cursor] = true
			var occupant = at(cursor)
			if occupant != -1 and pieces[occupant].type == "portal" and pieces[occupant].side == p.side and not teleported and p.type != "elephant":
				for exit in pieces.values():
					if exit.id != occupant and exit.type == "portal" and exit.side == p.side:
						cursor = exit.pos
						teleported = true
						break
				if teleported: continue
			path.append(cursor)
			if cursor == to: return path
			if occupant != -1 and p.type == "elephant" and pieces[occupant].side == p.side: break
	return [to]

func _advance_route(index: int) -> void:
	var route: Array = belts[index]
	var moves: Dictionary = {}
	for i in range(route.size() - 1):
		var id = at(route[i])
		if id != -1 and pieces[id].pos == route[i] and _fits(id, route[i + 1]): moves[id] = route[i + 1]
	# Simultaneous movement permits occupied loops; a blocked endpoint stops its chain.
	var changed := true
	while changed:
		changed = false
		var claims: Dictionary = {}
		for id in moves.keys():
			var valid := true
			for cell in footprint(id, moves[id]):
				var other = at(cell)
				if (other != -1 and other != id and (not moves.has(other) or footprint(other, moves[other]).has(cell))) or claims.has(cell): valid = false
				claims[cell] = id
			if not valid: moves.erase(id); changed = true
	var departed: Dictionary = {}
	for id in moves:
		departed[id] = footprint(id)
		pieces[id].pos = moves[id]
	for id in moves:
		if has_upgrade(id, "eldritch"):
			for cell in departed[id]:
				if inside(cell) and not footprint(id).has(cell): holes[cell] = true
	for id in moves:
		for cell in footprint(id):
			if holes.has(cell) or (mines.has(cell) and mines[cell] != pieces[id].side):
				mines.erase(cell)
				pieces.erase(id)
				_emit("conveyor", "A conveyor arrival triggers a hole or mine.")
				break
	if not moves.is_empty(): _emit("conveyor", "Conveyor advances %d unit(s) one square." % moves.size())

func _end_turn() -> void:
	for i in range(belts.size()):
		# Routes cannot share tiles through the editor; imported overlapping routes resolve in order.
		_advance_route(i)
	if rules.get("brittle", false):
		var best = Vector2i(-1, -1)
		var depth = 99999
		for y in range(height):
			for x in range(width):
				var square = Vector2i(x, y)
				if holes.has(square): continue
				var layer = mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
				if layer < depth: depth = layer; best = square
		if best.x >= 0:
			holes[best] = true
			var id = at(best)
			if id != -1: pieces.erase(id)
			_emit("collapse", "Brittle board loses %s." % str(best))
	if side == 0: turns += 1
	side = 1 - side
	phase = "move"
	remaining = 0
	active_id = -1
	_start_turn()
	_resolve_royals()
	_resolve_turn_status()

func _start_turn() -> void:
	var factories = pieces.values().filter(func(p): return p.side == side and p.type == "factory").duplicate(true)
	for p in factories:
		var to: Vector2i = p.pos + Vector2i(0, -1 if side == 0 else 1)
		if inside(to) and not blocked(to) and not holes.has(to) and at(to) == -1:
			var id = add_piece("pawn", side, to)
			_emit("factory", "Factory creates a pawn.")
			if mines.has(to) and mines[to] != side: mines.erase(to); pieces.erase(id)

func _resolve_royals() -> void:
	if result != "": return
	var white = _royals(0).is_empty()
	var black = _royals(1).is_empty()
	if white and black: _end("draw", "Both royal armies fell.")
	elif white: _end("loss", "White's last royal was captured.")
	elif black: _end("win", "Black's last royal was captured.")

func coordinate_action(id: int, to: Vector2i) -> Dictionary:
	var action = _coordinate_action_unchecked(id, to)
	return action if not action.is_empty() and _action_safe(action) else {}

func _coordinate_action_unchecked(id: int, to: Vector2i) -> Dictionary:
	if not chaos or phase not in ["move", "bonus"] or not pieces.has(id) or pieces[id].side != side or result != "": return {}
	if rules.get("wrap", false) and (to.x < 0 or to.x >= width): return {}
	if phase == "bonus" and id != active_id: return {}
	var p: Dictionary = pieces[id]
	if p.type not in ["rook", "bishop", "queen", "ghost", "regent"]:
		if not destinations(id).has(to): return {}
		var action = {"kind": "move", "id": id, "to": to}
		if p.type == "pawn" and to.y == (0 if p.side == 0 else height - 1): action.promotion = "queen"
		return action
	if not has_upgrade(id, "voidwalker") and (at(to) == -1 or pieces[at(to)].side == side): return {}
	var delta: Vector2i = to - p.pos
	if delta == Vector2i.ZERO: return {}
	var straight = delta.x == 0 or delta.y == 0
	var diagonal = absi(delta.x) == absi(delta.y)
	if not ((straight and p.type != "bishop") or (diagonal and p.type in ["bishop", "queen", "regent"])): return {}
	if p.type == "regent" and maxi(absi(delta.x), absi(delta.y)) > 3: return {}
	if blocked(to) or holes.has(to): return {}
	var target = at(to)
	if target != -1 and pieces[target].side == side: return {}
	if target != -1 and p.type == "ghost" and not pieces[target].get("royal", Chaos.ROYALS.has(pieces[target].type)): return {}
	var d = Vector2i(signi(delta.x), signi(delta.y))
	# Check occupied/terrain coordinates instead of iterating through a potentially huge void.
	for obstacle in pieces.values():
		if obstacle.id == id: continue
		for cell in footprint(obstacle.id):
			var offset: Vector2i = cell - p.pos
			if offset == Vector2i.ZERO or cell == to: continue
			if offset.x * d.y == offset.y * d.x and (offset.x * d.x + offset.y * d.y) > 0 and offset.length_squared() < delta.length_squared():
				if p.type != "ghost" and not has_upgrade(id, "phasing"): return {}
	for square in walls.keys() + holes.keys():
		var offset: Vector2i = square - p.pos
		if offset.x * d.y == offset.y * d.x and (offset.x * d.x + offset.y * d.y) > 0 and offset.length_squared() < delta.length_squared(): return {}
	return {"kind": "move", "id": id, "to": to}

func coordinate_shot(id: int, to: Vector2i) -> Dictionary:
	var action = _coordinate_shot_unchecked(id, to)
	return action if not action.is_empty() and _action_safe(action) else {}

func _coordinate_shot_unchecked(id: int, to: Vector2i) -> Dictionary:
	if not chaos or phase not in ["move", "bonus"] or result != "" or not pieces.has(id) or pieces[id].side != side: return {}
	if phase == "bonus" and id != active_id: return {}
	var p: Dictionary = pieces[id]
	if not has_upgrade(id, "gun"): return {}
	var victim = at(to)
	if victim == -1 or pieces[victim].side == side: return {}
	var delta: Vector2i = to - p.pos
	var straight = delta.x == 0 or delta.y == 0
	if delta == Vector2i.ZERO or (not straight and absi(delta.x) != absi(delta.y)): return {}
	var d = Vector2i(signi(delta.x), signi(delta.y))
	var obstacles = walls.keys() + holes.keys()
	for other in pieces.values():
		if other.id != id: obstacles.append_array(footprint(other.id))
	for square in obstacles:
		var offset: Vector2i = square - p.pos
		if square in [p.pos, to]: continue
		if offset.x * d.y == offset.y * d.x and offset.x * d.x + offset.y * d.y > 0 and offset.length_squared() < delta.length_squared(): return {}
	if blocked(to) or holes.has(to): return {}
	return {"kind": "shoot", "id": id, "to": to}

func apply_coordinate(id: int, to: Vector2i, shooting: bool = false) -> Array:
	var action = coordinate_shot(id, to) if shooting else coordinate_action(id, to)
	if action.is_empty(): return [{"kind": "invalid", "text": "Invalid coordinate move."}]
	# The same resolver as enumerated moves, with an explicitly validated extra candidate.
	if phase == "move": active_id = id; remaining = 3 if has_upgrade(id, "+2") else 2 if has_upgrade(id, "+1") else 1
	events = []
	_resolve_action(action)
	if _cancelled_capture >= 0 and in_check(side):
		_emit("check", "The save cancelled this attempt. You must still resolve check.")
		return events.duplicate(true)
	ply += 1
	remaining -= 1
	_resolve_royals()
	if result == "":
		if remaining > 0 and pieces.has(id): phase = "bonus"
		else: _end_turn()
	return events.duplicate(true)

func public_copy(viewer: int):
	var clone = copy()
	for p in clone.pieces.values():
		if p.side != viewer:
			p.upgrades = p.get("upgrades", []).duplicate()
			p.upgrades.erase("dagger")
	for pos in clone.mines.keys():
		if clone.mines[pos] != viewer: clone.mines.erase(pos)
	return clone

func is_royal(id: int) -> bool:
	return pieces.has(id) and pieces[id].get("royal", Chaos.ROYALS.has(pieces[id].type))
