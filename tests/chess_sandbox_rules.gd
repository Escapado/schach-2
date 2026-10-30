extends SceneTree

const Model = preload("res://scripts/sandbox/chess_battle.gd")
const Bot = preload("res://scripts/sandbox/chess_bot.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func from_fen(fen: String):
	var b = Model.new()
	var fields = fen.split(" ")
	var names = {"k": "king", "q": "queen", "r": "rook", "b": "bishop", "n": "knight", "p": "pawn"}
	var y = 0
	for row in fields[0].split("/"):
		var x = 0
		for symbol in row:
			if symbol.is_valid_int():
				x += int(symbol)
			else:
				b.add_piece(names[symbol.to_lower()], 0 if symbol == symbol.to_upper() else 1, Vector2i(x, y))
				x += 1
		y += 1
	b.side = 0 if fields[1] == "w" else 1
	b.castle_rights = [[fields[2].contains("Q"), fields[2].contains("K")], [fields[2].contains("q"), fields[2].contains("k")]]
	if fields[3] != "-":
		b.en_passant = square(fields[3])
	b.halfmove_clock = int(fields[4])
	return b

func square(value: String) -> Vector2i:
	return Vector2i(value.unicode_at(0) - 97, 8 - int(value.substr(1)))

func action_to(b, from: String, to: String, promotion: String = "") -> Dictionary:
	for action in b.legal_actions():
		if action.id == b.at(square(from)) and action.to == square(to) and action.get("promotion", "") == promotion:
			return action
	return {}

func play(b, from: String, to: String, promotion: String = "") -> void:
	var action = action_to(b, from, to, promotion)
	expect(not action.is_empty(), "legal move " + from + to + promotion)
	if not action.is_empty():
		b.apply(action)

func perft(b, depth: int) -> int:
	if depth == 0:
		return 1
	var actions = b.legal_actions()
	if depth == 1:
		return actions.size()
	var total = 0
	for action in actions:
		var next = b.copy()
		next._execute_move(action, false)
		next.side = 1 - b.side
		total += perft(next, depth - 1)
	return total

func _run() -> void:
	_setup_rules()
	var started = Time.get_ticks_msec()
	var b = Model.new()
	b.setup()
	expect(b.pieces.size() == 32 and b.side == 0 and b.width == 8 and b.height == 8, "standard starting position")
	expect(perft(b, 1) == 20, "initial perft depth 1: 20")
	expect(perft(b, 2) == 400, "initial perft depth 2: 400")
	expect(perft(b, 3) == 8902, "initial perft depth 3: 8902")
	# Kiwipete exercises castling, pinned pieces and captures. Stockfish tests/perft.sh.
	b = from_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	expect(perft(b, 1) == 48, "Kiwipete perft depth 1: 48")
	expect(perft(b, 2) == 2039, "Kiwipete perft depth 2: 2039")
	b = from_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	expect(perft(b, 1) == 14 and perft(b, 2) == 191 and perft(b, 3) == 2812, "endgame perft: 14, 191, 2812")
	b = from_fen("4r1k1/8/8/8/8/8/4R3/4K3 w - - 0 1")
	expect(action_to(b, "e2", "d2").is_empty(), "pinned rook cannot expose own king")
	var before = var_to_str(b.pieces)
	b.apply({"kind": "move", "id": b.at(square("e2")), "to": square("d2")})
	expect(before == var_to_str(b.pieces) and b.side == 0 and b.ply == 0, "illegal move leaves state unchanged")
	b = from_fen("4k3/8/8/8/8/8/4K3/8 w - - 0 1")
	expect(action_to(b, "e2", "e3").size() > 0, "king can move normally")
	b = from_fen("8/8/8/8/8/4k3/8/4K3 w - - 0 1")
	expect(action_to(b, "e1", "e2").is_empty(), "kings cannot become adjacent")
	b = from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	play(b, "e1", "g1")
	expect(b.pieces[b.at(square("f1"))].type == "rook" and b.at(square("h1")) == -1, "kingside castling moves rook")
	expect(b.castle_rights[0] == [false, false], "castling revokes both rights")
	play(b, "e8", "c8")
	expect(b.pieces[b.at(square("d8"))].type == "rook", "black queenside castling")
	b = from_fen("r3kr1r/8/8/8/8/8/8/R3K2R w KQ - 0 1")
	expect(action_to(b, "e1", "g1").is_empty(), "cannot castle through attack")
	b = from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	play(b, "h1", "h2")
	play(b, "h8", "h7")
	play(b, "h2", "h1")
	expect(not b.castle_rights[0][1], "returned rook does not restore rights")
	b = Model.new()
	b.setup()
	play(b, "e2", "e4")
	play(b, "a7", "a6")
	play(b, "e4", "e5")
	play(b, "d7", "d5")
	play(b, "e5", "d6")
	expect(b.at(square("d5")) == -1 and b.pieces.size() == 31, "en passant removes bypassed pawn")
	b = from_fen("4k3/8/8/r4pPK/8/8/8/8 w - f6 0 1")
	expect(action_to(b, "g5", "f6").is_empty(), "en passant cannot uncover check along rank")
	var key = b.position_key()
	b.en_passant = Vector2i(-1, -1)
	expect(key == b.position_key(), "illegal en passant does not change repetition identity")
	b = from_fen("7k/P7/8/8/8/8/8/7K w - - 0 1")
	var promotions = b.legal_actions().filter(func(action): return action.to == square("a8"))
	expect(promotions.size() == 4, "all four promotion choices")
	play(b, "a7", "a8", "knight")
	expect(b.pieces[b.at(square("a8"))].type == "knight", "underpromotion applies")
	b = Model.new()
	b.setup()
	play(b, "f2", "f3")
	play(b, "e7", "e5")
	play(b, "g2", "g4")
	play(b, "d8", "h4")
	expect(b.result == "loss" and b.reason.contains("checkmate") and b.pieces.size() == 32, "Fool's Mate ends without capturing king")
	b = from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	b.begin()
	expect(b.result == "draw" and b.reason.contains("stalemate"), "stalemate")
	b = from_fen("7k/8/8/8/8/8/8/KN6 w - - 0 1")
	b.begin()
	expect(b.result == "draw", "king and minor versus king insufficient material")
	b = from_fen("7k/8/8/8/8/8/R7/K7 w - - 100 1")
	b.begin()
	expect(b.result == "draw" and b.reason.contains("fifty"), "automatic fifty-move draw")
	b = Model.new()
	b.setup()
	for repetition in range(2):
		play(b, "g1", "f3")
		play(b, "g8", "f6")
		play(b, "f3", "g1")
		play(b, "f6", "g8")
	expect(b.result == "draw" and b.reason.contains("repetition"), "threefold repetition")
	b = Model.new()
	b.setup()
	var clone = b.copy()
	clone.castle_rights[0][0] = false
	clone.pieces[clone.at(square("e2"))].pos = square("e4")
	clone.repetitions.clear()
	expect(b.castle_rights[0][0] and b.at(square("e2")) != -1 and not b.repetitions.is_empty(), "copy preserves subclass and nested state independence")
	b = from_fen("7k/8/5KQ1/8/8/8/8/8 w - - 0 1")
	var bot = Bot.new()
	var signature = var_to_str(b.pieces)
	var action = bot.choose(b, 1, 8, {"max_nodes": 200})
	expect(b.legal_actions().has(action) and bot.nodes <= 200, "reused search returns legal bounded action")
	var after = b.copy()
	after.apply(action)
	expect(after.result == "win", "bot finds mate in one")
	expect(signature == var_to_str(b.pieces), "bot does not mutate live chess model")
	b = Model.new()
	b.setup()
	play(b, "e2", "e4")
	bot = Bot.new()
	var search_start = Time.get_ticks_msec()
	action = bot.choose(b, 3, 1, {"max_nodes": 1600, "beam_width": 8})
	expect(b.legal_actions().has(action), "black opening reply legal")
	expect(action == Bot.new().choose(b, 3, 1, {"max_nodes": 1600, "beam_width": 8}), "chess AI deterministic")
	print("Sandbox AI: depth %d, %d nodes, %d ms (two searches)" % [bot.completed_depth, bot.nodes, Time.get_ticks_msec() - search_start])
	print("Chess sandbox rules: %d checks, %d failures, %d ms" % [checks, failures, Time.get_ticks_msec() - started])
	quit(1 if failures else 0)

func _setup_rules() -> void:
	var b = Model.new()
	b.setup(true)
	expect(b.phase == "setup" and b.legal_actions().is_empty(), "setup has no battle actions")
	var untouched = var_to_str(b.pieces)
	b.apply({"kind": "move", "id": b.at(square("e2")), "to": square("e4")})
	expect(untouched == var_to_str(b.pieces) and b.ply == 0, "battle cannot advance before Start")
	expect(b.place_setup_piece("queen", square("a2")) == "" and b.pieces.size() == 32, "pool replaces pawn with queen freely")
	expect(b.place_setup_piece("rook", square("a2")) == "" and b.pieces.size() == 32 and b.pieces[b.at(square("a2"))].type == "rook", "pool replaces friendly piece")
	var before = var_to_str(b.pieces)
	expect(b.place_setup_piece("queen", square("a6")) != "" and before == var_to_str(b.pieces), "enemy half protected")
	for rank in ["a3", "a4"]:
		expect(b.place_setup_piece("queen", square(rank)) != "" and b.move_setup_piece(b.at(square("a2")), square(rank)) != "" and before == var_to_str(b.pieces), "ranks 3 and 4 reject placement and rearrangement")
	expect(b.place_setup_piece("dragon", square("d2")) != "", "pool accepts only standard pieces")
	expect(b.place_setup_piece("pawn", square("a1")) != "", "no pawn setup on back rank")
	expect(b.remove_setup_piece(square("e1")) != "", "king cannot be removed")
	expect(b.place_setup_piece("queen", square("e1")) != "", "king cannot be overwritten")
	var king = b.at(square("e1"))
	expect(b.place_setup_piece("king", square("d1")) == "" and b.at(square("d1")) == king and b.pieces.size() == 32, "king pool entry relocates rather than duplicates")
	var kings = b.pieces.values().filter(func(piece): return piece.side == 0 and piece.type == "king")
	expect(kings.size() == 1, "exactly one White king after relocation")
	var rook = b.at(square("a2"))
	expect(b.move_setup_piece(rook, square("b2")) == "" and b.at(square("b2")) == rook, "existing piece freely rearranged")
	expect(b.remove_setup_piece(square("b2")) != "" and b.at(square("b2")) == rook and b.pieces.size() == 32, "removal disabled; replacement preserves army size")
	expect(b.start_prepared() == "" and b.phase == "move" and b.ply == 0, "explicit start keeps prepared formation without taking a move")
	expect(b.castle_rights[0] == [false, false], "prepared king outside home has no castling rights")
	before = var_to_str(b.pieces)
	expect(b.place_setup_piece("queen", square("e4")) != "" and b.remove_setup_piece(square("a2")) != "" and before == var_to_str(b.pieces), "editing locked after start")
	b = Model.new()
	b.setup(true)
	for piece in b.pieces.values().duplicate():
		if piece.type != "king":
			b.pieces.erase(piece.id)
	b.add_piece("rook", 0, square("e2"))
	expect(b.start_prepared() != "" and b.phase == "setup", "cannot start with nonmoving Black king in check")
