extends "res://scripts/core/battle.gd"
## Orthodox chess foundation for the parallel sandbox. No run or profile access.
## Inherits the board data contract and ordinary movement, not roguelite resolution.

const PROMOTIONS = ["queen", "rook", "bishop", "knight"]
var castle_rights: Array = [[true, true], [true, true]] # queenside, kingside
var en_passant := Vector2i(-1, -1)
var halfmove_clock := 0
var ply := 0
var repetitions: Dictionary = {}
var last_move: Dictionary = {}
var _legal_cache: Array = []
var _legal_signature := ""

func _init() -> void:
	width = 8
	height = 8
	objective = "chess"
	budget = 0

func setup(editing: bool = false) -> void:
	pieces.clear()
	walls.clear()
	clouds.clear()
	side = 0
	phase = "move"
	bonus_id = -1
	next_id = 1
	turns = 0
	captures = 0
	result = ""
	reason = ""
	events = []
	castle_rights = [[true, true], [true, true]]
	en_passant = Vector2i(-1, -1)
	halfmove_clock = 0
	ply = 0
	repetitions = {}
	last_move = {}
	var back_rank = ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]
	for owner in range(2):
		for x in range(8):
			add_piece(back_rank[x], owner, Vector2i(x, 7 if owner == 0 else 0))
			add_piece("pawn", owner, Vector2i(x, 6 if owner == 0 else 1))
	if editing:
		phase = "setup"
	else:
		begin()

func is_setup_square(square: Vector2i) -> bool:
	return inside(square) and square.y >= height - 2

func _setup_square_error(square: Vector2i) -> String:
	if phase != "setup" or result != "":
		return "The starting board is locked during battle."
	if not is_setup_square(square):
		return "Edit only the lower quarter: ranks 1 and 2."
	return ""

func place_setup_piece(kind: String, square: Vector2i) -> String:
	var error = _setup_square_error(square)
	if error != "":
		return error
	if not Catalog.TYPES.has(kind):
		return "Choose a standard chess piece."
	if kind == "pawn" and square.y == 7:
		return "Pawns cannot start on the back rank."
	var occupant = at(square)
	if occupant != -1 and pieces[occupant].side != 0:
		return "The enemy army cannot be edited."
	if occupant != -1 and pieces[occupant].type == "king" and kind != "king":
		return "Move your king instead of replacing it."
	if kind == "king":
		var king = at(king_position(0))
		return move_setup_piece(king, square)
	elif occupant != -1:
		pieces[occupant].type = kind
	else:
		return "Choose an occupied friendly square to replace."
	return ""

func move_setup_piece(id: int, square: Vector2i) -> String:
	var error = _setup_square_error(square)
	if error != "":
		return error
	if not pieces.has(id) or pieces[id].side != 0:
		return "Select one of your pieces."
	var occupant = at(square)
	if occupant != -1 and pieces[occupant].side != 0:
		return "The enemy army cannot be edited."
	var origin: Vector2i = pieces[id].pos
	if (pieces[id].type == "pawn" and square.y == 7) or (occupant != -1 and pieces[occupant].type == "pawn" and origin.y == 7):
		return "Pawns cannot start on the back rank."
	if occupant != -1:
		pieces[occupant].pos = origin
	pieces[id].pos = square
	return ""

func remove_setup_piece(_square: Vector2i) -> String:
	return "Removal is disabled. Replace pieces using the pool."

func start_prepared() -> String:
	if phase != "setup":
		return "This battle has already started."
	var kings = [0, 0]
	var occupied: Dictionary = {}
	for piece in pieces.values():
		if not inside(piece.pos) or occupied.has(piece.pos):
			return "Every piece needs its own board square."
		occupied[piece.pos] = true
		if piece.side == 0 and not is_setup_square(piece.pos):
			return "Your pieces must start on ranks 1 and 2."
		if piece.type == "king":
			kings[piece.side] += 1
		if piece.type == "pawn" and piece.pos.y in [0, 7]:
			return "Pawns cannot start on either back rank."
	if kings != [1, 1]:
		return "Each army needs exactly one king."
	if in_check(1):
		return "Black cannot start in check. Adjust your formation."
	for owner in range(2):
		var home = 7 if owner == 0 else 0
		for flank in range(2):
			var rook = at(Vector2i(0 if flank == 0 else 7, home))
			castle_rights[owner][flank] = king_position(owner) == Vector2i(4, home) and rook != -1 and pieces[rook].type == "rook" and pieces[rook].side == owner
	phase = "move"
	begin()
	return ""

func copy() -> Battle:
	return _copy_state(true)

func _copy_state(with_cache: bool):
	var clone = get_script().new()
	for key in ["width", "height", "pieces", "walls", "clouds", "side", "phase", "bonus_id", "next_id", "turns", "budget", "objective", "target_id", "result", "reason", "captures", "castle_rights", "en_passant", "halfmove_clock", "ply", "repetitions", "last_move"]:
		var value = get(key)
		clone.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	if with_cache:
		clone._legal_signature = _legal_signature
		clone._legal_cache = _legal_cache.duplicate(true)
	return clone

func king_position(owner: int) -> Vector2i:
	for piece in pieces.values():
		if piece.side == owner and piece.type == "king":
			return piece.pos
	return Vector2i(-1, -1)

func is_attacked(square: Vector2i, attacker: int) -> bool:
	for piece in pieces.values():
		if piece.side != attacker:
			continue
		var delta: Vector2i = square - piece.pos
		if piece.type == "pawn":
			if absi(delta.x) == 1 and delta.y == (-1 if attacker == 0 else 1):
				return true
		elif piece.type == "king":
			if maxi(absi(delta.x), absi(delta.y)) == 1:
				return true
		elif piece.type == "knight":
			if (absi(delta.x) == 1 and absi(delta.y) == 2) or (absi(delta.x) == 2 and absi(delta.y) == 1):
				return true
		else:
			var straight = (delta.x == 0 or delta.y == 0) and delta != Vector2i.ZERO
			var diagonal = absi(delta.x) == absi(delta.y) and delta != Vector2i.ZERO
			if not ((straight and piece.type in ["rook", "queen"]) or (diagonal and piece.type in ["bishop", "queen"])):
				continue
			var step = Vector2i(signi(delta.x), signi(delta.y))
			var cursor: Vector2i = piece.pos + step
			while cursor != square and at(cursor) == -1:
				cursor += step
			if cursor == square:
				return true
	return false

func in_check(owner: int) -> bool:
	var king = king_position(owner)
	return king.x < 0 or is_attacked(king, 1 - owner)

func destinations(id: int, reposition: bool = false) -> Array:
	if not pieces.has(id) or reposition:
		return []
	var piece: Dictionary = pieces[id]
	var out: Array = super.destinations(id)
	if piece.type == "pawn":
		var direction = -1 if piece.side == 0 else 1
		var one: Vector2i = piece.pos + Vector2i(0, direction)
		var two: Vector2i = piece.pos + Vector2i(0, direction * 2)
		if piece.pos.y == (6 if piece.side == 0 else 1) and at(one) == -1 and at(two) == -1:
			out.append(two)
		if en_passant.y == piece.pos.y + direction and absi(en_passant.x - piece.pos.x) == 1 and at(en_passant) == -1:
			var victim = at(Vector2i(en_passant.x, piece.pos.y))
			if victim != -1 and pieces[victim].type == "pawn" and pieces[victim].side != piece.side:
				out.append(en_passant)
	elif piece.type == "king":
		for flank in range(2):
			if _can_castle(piece.side, flank):
				out.append(Vector2i(2 if flank == 0 else 6, piece.pos.y))
	return out.filter(func(to):
		var target = at(to)
		return target == -1 or pieces[target].type != "king")

func _can_castle(owner: int, flank: int) -> bool:
	var home = 7 if owner == 0 else 0
	if not castle_rights[owner][flank] or king_position(owner) != Vector2i(4, home) or in_check(owner):
		return false
	var rook = at(Vector2i(0 if flank == 0 else 7, home))
	if rook == -1 or pieces[rook].type != "rook" or pieces[rook].side != owner:
		return false
	for x in ([1, 2, 3] if flank == 0 else [5, 6]):
		if at(Vector2i(x, home)) != -1:
			return false
	# Test the transit square with the king moved off its original square.
	var transit = _copy_state(false)
	var king = transit.at(Vector2i(4, home))
	transit.pieces[king].pos = Vector2i(3 if flank == 0 else 5, home)
	return not transit.in_check(owner)

func legal_actions() -> Array:
	if result != "" or phase != "move":
		return []
	var signature = var_to_str([pieces, side, castle_rights, en_passant])
	if signature != _legal_signature:
		_legal_cache = _move_actions()
		_legal_signature = signature
	return _legal_cache.duplicate(true)

func _move_actions() -> Array:
	var out: Array = []
	for id in pieces:
		var piece: Dictionary = pieces[id]
		if piece.side != side:
			continue
		for to in destinations(id):
			var action = {"kind": "move", "id": id, "to": to}
			var promotions: Array = PROMOTIONS if piece.type == "pawn" and to.y in [0, 7] else [""]
			for promotion in promotions:
				var candidate = action.duplicate()
				if promotion != "":
					candidate.promotion = promotion
				var after = _copy_state(false)
				after._execute_move(candidate, false)
				if not after.in_check(side):
					out.append(candidate)
	return out

func _revoke_rook_right(owner: int, square: Vector2i) -> void:
	var home = 7 if owner == 0 else 0
	if square == Vector2i(0, home):
		castle_rights[owner][0] = false
	elif square == Vector2i(7, home):
		castle_rights[owner][1] = false

# Shared transition for legality probes and real/search moves. Never ends a turn itself.
func _execute_move(action: Dictionary, emit_events: bool = true) -> void:
	var piece: Dictionary = pieces[action.id]
	var from: Vector2i = piece.pos
	var to: Vector2i = action.to
	var kind: String = piece.type
	var victim = at(to)
	if kind == "pawn" and to == en_passant and from.x != to.x and victim == -1:
		victim = at(Vector2i(to.x, from.y))
	if victim != -1:
		var lost: Dictionary = pieces[victim].duplicate(true)
		_revoke_rook_right(lost.side, lost.pos)
		pieces.erase(victim)
		if emit_events:
			_emit("capture", "%s captured %s." % [kind.capitalize(), lost.type], {"piece": lost})
		if side == 0:
			captures += 1
	if kind == "king":
		castle_rights[piece.side] = [false, false]
		if absi(to.x - from.x) == 2:
			var rook = at(Vector2i(0 if to.x < from.x else 7, from.y))
			pieces[rook].pos = Vector2i(3 if to.x < from.x else 5, from.y)
			if emit_events:
				_emit("castle", "Castled %s." % ("queenside" if to.x < from.x else "kingside"))
	elif kind == "rook":
		_revoke_rook_right(piece.side, from)
	pieces[action.id].pos = to
	if action.has("promotion"):
		pieces[action.id].type = action.promotion
		if emit_events:
			_emit("promotion", "Pawn promoted to %s." % action.promotion)
	en_passant = Vector2i(from.x, (from.y + to.y) / 2) if kind == "pawn" and absi(to.y - from.y) == 2 else Vector2i(-1, -1)
	halfmove_clock = 0 if kind == "pawn" or victim != -1 else halfmove_clock + 1
	if emit_events:
		_emit("move", "%s: %s%s%s" % ["White" if side == 0 else "Black", Catalog.SYMBOLS[kind], square_name(from), square_name(to)], {"id": action.id, "from": from, "to": to})
	last_move = {"from": from, "to": to}

func apply(action: Dictionary) -> Array:
	if not legal_actions().has(action):
		return [{"kind": "invalid", "text": "Illegal chess move rejected."}]
	events = []
	_execute_move(action)
	ply += 1
	if side == 0:
		turns += 1
	side = 1 - side
	var key = position_key()
	repetitions[key] = repetitions.get(key, 0) + 1
	_resolve_position()
	return events.duplicate(true)

func begin() -> void:
	events = []
	if repetitions.is_empty():
		repetitions[position_key()] = 1
	_resolve_position()

func _resolve_position() -> void:
	var moves = legal_actions()
	if moves.is_empty():
		if in_check(side):
			_end("win" if side == 1 else "loss", "%s wins by checkmate." % ("White" if side == 1 else "Black"))
		else:
			_end("draw", "Draw by stalemate.")
	elif insufficient_material():
		_end("draw", "Draw by insufficient mating material.")
	elif halfmove_clock >= 100:
		_end("draw", "Draw by the fifty-move rule (automatic in this sandbox).")
	elif repetitions.get(position_key(), 0) >= 3:
		_end("draw", "Draw by threefold repetition (automatic in this sandbox).")
	elif in_check(side):
		_emit("check", "%s is in check." % ("White" if side == 0 else "Black"))

func position_key() -> String:
	var cells: Array[String] = []
	for piece in pieces.values():
		cells.append("%d:%s:%d:%d" % [piece.side, piece.type, piece.pos.x, piece.pos.y])
	cells.sort()
	# An unavailable (including pinned) en passant capture does not change repetition.
	var effective_ep = Vector2i(-1, -1)
	if en_passant.x >= 0:
		for piece in pieces.values():
			if piece.side == side and piece.type == "pawn" and destinations(piece.id).has(en_passant):
				var probe = _copy_state(false)
				probe._execute_move({"kind": "move", "id": piece.id, "to": en_passant}, false)
				if not probe.in_check(side):
					effective_ep = en_passant
	return "|".join(cells) + "/%d/%s/%s" % [side, str(castle_rights), str(effective_ep)]

func insufficient_material() -> bool:
	var minors: Array = []
	for piece in pieces.values():
		if piece.type == "king":
			continue
		if piece.type not in ["bishop", "knight"]:
			return false
		minors.append(piece)
	if minors.size() <= 1:
		return true
	var color = -1
	for piece in minors:
		if piece.type != "bishop":
			return false
		var square_color: int = (piece.pos.x + piece.pos.y) % 2
		if color != -1 and color != square_color:
			return false
		color = square_color
	return true

static func square_name(square: Vector2i) -> String:
	return String.chr(97 + square.x) + str(8 - square.y)
