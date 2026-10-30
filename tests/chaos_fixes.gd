extends SceneTree
const Model = preload("res://scripts/sandbox/chaos_battle.gd")
const Bot = preload("res://scripts/sandbox/chess_bot.gd")
var checks := 0
var failures := 0
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func position(white: Vector2i = Vector2i(7, 7), black: Vector2i = Vector2i(0, 0)):
	var b = Model.new()
	b.chaos = true
	b.add_piece("king", 0, white)
	b.add_piece("king", 1, black)
	return b
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var b = position(Vector2i(0, 7), Vector2i(2, 5))
	b.add_piece("queen", 1, Vector2i(1, 6)); b.begin()
	expect(b.in_check(0) and b.result == "loss" and b.reason.contains("checkmate"), "upgraded battle evaluates checkmate for ordinary king")
	b = position(Vector2i(2, 2), Vector2i(0, 0)); b.side = 1
	b.add_piece("queen", 0, Vector2i(1, 2)); b.begin()
	expect(not b.in_check(1) and b.result == "draw" and b.reason.contains("stalemate"), "no-check immobility is stalemate")
	b = position(); var rook = b.add_piece("rook", 1, Vector2i(7, 0)); var defender = b.add_piece("rook", 0, Vector2i(1, 6))
	expect(b.in_check(0), "variant rook gives check")
	var invalid = {"kind": "move", "id": defender, "to": Vector2i(2, 6)}
	var snapshot = b.copy(); expect(b.apply(invalid)[0].kind == "invalid" and b.pieces == snapshot.pieces, "cannot ignore check; invalid action leaves state untouched")
	expect(b.legal_actions().has({"kind": "move", "id": defender, "to": Vector2i(7, 6)}), "blocking check remains legal")
	b = position(); rook = b.add_piece("rook", 1, Vector2i(7, 0)); b.pieces[rook].upgrades = ["gun"]; expect(b.in_check(0), "Gun ranged threat gives check")
	expect(not b.coordinate_shot(rook, Vector2i(7, 7)).size(), "opponent cannot act out of turn")
	b = position(); var bishop = b.add_piece("bishop", 0, Vector2i(7, 6)); b.add_piece("rook", 1, Vector2i(7, 0))
	expect(not b.legal_actions().any(func(a): return a.id == bishop), "pinned upgraded piece cannot expose king")
	b = position(Vector2i(0, 7), Vector2i(2, 5)); b.side = 1
	var queen = b.add_piece("queen", 1, Vector2i(1, 5)); b.pieces[queen].upgrades = ["+1"]
	b.apply({"kind": "move", "id": queen, "to": Vector2i(1, 6)})
	expect(b.phase == "bonus" and b.side == 1 and b.result == "", "checkmate waits until attacking bonus turn completes")
	b.apply({"kind": "skip", "id": queen, "to": Vector2i.ZERO})
	expect(b.result == "loss" and b.reason.contains("checkmate"), "ending bonus sequence evaluates checkmate")
	b = position(); b.pieces[b.at(Vector2i(0, 0))].type = "regent"; b.royal_mode[1] = "regent"; b.add_piece("regent", 1, Vector2i(0, 1)); rook = b.add_piece("rook", 0, Vector2i(0, 3))
	b.apply({"kind": "move", "id": rook, "to": Vector2i(0, 1)})
	expect(b.result == "" and b._royals(1).size() == 1, "first Regent capture does not end battle")
	b.side = 0; b.apply({"kind": "move", "id": rook, "to": Vector2i(0, 0)})
	expect(b.result == "win", "second Regent capture wins")
	b = position(); var factory = b.add_piece("factory", 0, Vector2i(2, 7)); b.begin()
	var pawn = b.at(Vector2i(2, 6))
	expect(pawn != -1 and b.pieces[pawn].type == "pawn" and not b.pieces[pawn].owned and b.pieces[pawn].get("upgrades", []).is_empty(), "Factory creates an ordinary temporary pawn")
	expect(b.destinations(pawn).has(Vector2i(2, 5)), "spawned pawn moves forward with pawn rules")
	b._start_turn(); expect(b.pieces.size() == 4, "occupied Factory output blocks duplicate spawn")
	b = position(); b.side = 1; factory = b.add_piece("factory", 1, Vector2i(2, 0)); b.begin()
	expect(b.pieces[b.at(Vector2i(2, 1))].type == "pawn", "enemy Factory also produces forward pawn")
	# A real bounded search must return a legal escape from check.
	b = position(); b.side = 1; b.add_piece("rook", 0, Vector2i(0, 7)); var bot = Bot.new()
	var action = bot.choose(b.copy(), 1, 12, {"max_nodes": 50, "beam_width": 4})
	expect(b.in_check(1) and b.legal_actions().has(action), "bot chooses an upgraded legal check evasion")
	var prepared = position(); prepared.phase = "setup"; prepared.add_piece("rook", 0, Vector2i(0, 6))
	expect(prepared.start_prepared() != "" and prepared.phase == "setup", "preparation cannot start opposing ordinary king in check")
	# Hidden traps cannot make public worker moves illegal or disclose their locations.
	b = position(); var king_id = b.at(Vector2i(7, 7)); b.mines[Vector2i(6, 7)] = 1
	var step = {"kind": "move", "id": king_id, "to": Vector2i(6, 7)}
	expect(b.legal_actions().has(step) and b.public_copy(0).legal_actions().has(step), "hidden mine does not leak through legal king moves")
	b.apply(step); expect(b.result == "loss", "concealed mine still kills a king on arrival")
	b = position(); king_id = b.at(Vector2i(7, 7)); var trap = b.add_piece("pawn", 1, Vector2i(6, 7)); b.pieces[trap].upgrades = ["dagger"]
	expect(b.legal_actions().has({"kind": "move", "id": king_id, "to": Vector2i(6, 7)}), "hidden dagger does not make a capture mysteriously illegal")
	# Compare the fast threat path with movement/ranged geometry across mixed boards.
	var rng = RandomNumberGenerator.new(); rng.seed = 881
	for sample in range(12):
		b = position()
		for kind in ["rook", "bishop", "queen", "knight", "pawn", "ghost", "elephant", "factory"]:
			var cell = Vector2i(rng.randi_range(0, 7), rng.randi_range(1, 6))
			if b.at(cell) != -1: continue
			var attacker_id = b.add_piece(kind, 1, cell)
			b.pieces[attacker_id].upgrades = ["gun"] if sample % 3 == 0 else ["phasing"] if sample % 3 == 1 else []
			var king_square = Vector2i(7, 7)
			var reference = b.destinations(attacker_id).has(king_square)
			if b.has_upgrade(attacker_id, "gun"):
				for d in Model.ORTHO + Model.DIAG:
					if b._ray(attacker_id, d, 0, true).has(king_square): reference = true
			expect(b._direct_attack(attacker_id, king_square) == reference, "optimized threat matches movement/shot geometry")
	# End-to-end search on a full upgraded board, with the same node cap as the UI.
	b = Model.new(); b.setup(true); b.equip(b.at(Vector2i(0, 6)), "+1"); b.start_prepared(); b.apply({"kind": "move", "id": b.at(Vector2i(4, 6)), "to": Vector2i(4, 4)})
	bot = Bot.new(); var started = Time.get_ticks_msec(); action = bot.choose(b.public_copy(1), 2, 42, {"max_nodes": 800, "beam_width": 8})
	expect(b.legal_actions().has(action) and bot.nodes <= 800 and bot.completed_depth >= 1, "full upgraded-board AI completes bounded legal search")
	print("Upgraded board AI: %d ms, %d nodes, depth %d" % [Time.get_ticks_msec() - started, bot.nodes, bot.completed_depth])
	print("Chaos fixes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
