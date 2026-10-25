extends SceneTree

const B = preload("res://scripts/core/battle.gd")
const G = preload("res://scripts/core/encounters.gd")
const R = preload("res://scripts/core/run.gd")
const Bot = preload("res://scripts/core/bot.gd")
var checks: int = 0
var failures: int = 0
const PROFILE = "/tmp/schach2-test-progress.json"

# A tiny deterministic game tree isolates the search horizon from chess heuristics.
class SearchTree extends Battle:
	var tree: Dictionary = {}
	var key: String = "root"

	func copy() -> Battle:
		var clone = SearchTree.new()
		clone.tree = tree
		clone.key = key
		clone.side = side
		clone.phase = phase
		return clone

	func legal_actions() -> Array:
		var actions: Array = []
		for next in tree[key].get("moves", []):
			actions.append({"kind": next})
		return actions

	func apply(action: Dictionary) -> Array:
		key = action.kind
		side = tree[key].get("side", 1 - side)
		phase = tree[key].get("phase", "move")
		return []

class SearchScorer extends ChessBot:
	func evaluate(b: Battle) -> float:
		var tree: Dictionary = b.get("tree")
		return tree[b.get("key")].score

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func move(b: Battle, id: int, to: Vector2i) -> Array:
	return b.apply({"kind": "move", "id": id, "to": to})

func base() -> Battle:
	var b = B.new()
	b.width = 6
	b.height = 6
	b.objective = "promote"
	b.budget = 40
	return b

func _run() -> void:
	movement()
	captures_and_objectives()
	modifiers()
	poison_timing()
	copy_and_determinism()
	search_depth()
	economy()
	generation_and_bots()
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func movement() -> void:
	var b = base()
	var rook = b.add_piece("rook", 0, Vector2i(2, 3))
	b.add_piece("pawn", 0, Vector2i(2, 2))
	var enemy = b.add_piece("pawn", 1, Vector2i(4, 3))
	b.walls[Vector2i(1, 3)] = true
	expect(b.destinations(rook).has(Vector2i(4, 3)), "rook can capture enemy")
	expect(not b.destinations(rook).has(Vector2i(5, 3)), "rook cannot pass enemy")
	expect(not b.destinations(rook).has(Vector2i(2, 1)), "rook cannot pass ally")
	expect(not b.destinations(rook).has(Vector2i(0, 3)), "wall blocks sliding path")
	var knight = b.add_piece("knight", 0, Vector2i(0, 4))
	expect(b.destinations(knight).has(Vector2i(1, 2)), "knight jumps over walls and pieces")
	b.walls[Vector2i(1, 2)] = true
	expect(not b.destinations(knight).has(Vector2i(1, 2)), "knight cannot land on wall")
	var pawn = b.add_piece("pawn", 0, Vector2i(3, 4))
	expect(b.destinations(pawn).has(Vector2i(3, 3)), "player pawn goes up")
	expect(b.destinations(pawn).has(Vector2i(4, 3)), "pawn captures diagonally")
	expect(not b.destinations(pawn).has(Vector2i(3, 2)), "pawn has no double step")
	expect(b.destinations(enemy).has(Vector2i(4, 4)), "enemy pawn goes down")
	var king = b.add_piece("king", 0, Vector2i(5, 5))
	expect(b.destinations(king).size() == 3, "corner king has three moves")
	var bishop = b.add_piece("bishop", 0, Vector2i(0, 0))
	expect(b.destinations(bishop).has(Vector2i(1, 1)) and not b.destinations(bishop).has(Vector2i(0, 1)), "bishop moves diagonally")
	var queen = b.add_piece("queen", 0, Vector2i(5, 0))
	expect(b.destinations(queen).has(Vector2i(5, 2)) and b.destinations(queen).has(Vector2i(4, 1)), "queen combines movement")
	var before = var_to_str(b.pieces)
	var events = move(b, rook, Vector2i(5, 5))
	expect(events[0].kind == "invalid" and before == var_to_str(b.pieces) and b.turns == 0, "illegal actions do not mutate state")

func captures_and_objectives() -> void:
	var b = base()
	var rook = b.add_piece("rook", 0, Vector2i(0, 2))
	var target = b.add_piece("knight", 1, Vector2i(0, 0))
	b.pieces[target].hp = 100
	b.objective = "knight"
	b.target_id = target
	b.budget = 1
	move(b, rook, Vector2i(0, 0))
	expect(b.result == "win" and not b.pieces.has(target), "capture ignores HP; objective beats final-turn deadline")
	expect(b.reward() == 130, "victory scoring on final turn")
	expect(b.captures == 1 and b.turns == 1, "moves and captures tracked")
	b = base()
	rook = b.add_piece("rook", 0, Vector2i(0, 2))
	b.add_piece("king", 1, Vector2i(5, 0))
	b.budget = 1
	move(b, rook, Vector2i(0, 1))
	expect(b.result == "loss", "move budget causes loss")
	b = base()
	var pawn = b.add_piece("pawn", 0, Vector2i(1, 1))
	b.add_piece("king", 1, Vector2i(5, 0))
	b.budget = 1
	move(b, pawn, Vector2i(1, 0))
	expect(b.result == "win" and b.pieces[pawn].type == "pawn", "promotion objective checked before promotion and deadline")
	b = base()
	b.objective = "knight"
	b.target_id = b.add_piece("knight", 1, Vector2i(5, 0))
	pawn = b.add_piece("pawn", 0, Vector2i(1, 1))
	move(b, pawn, Vector2i(1, 0))
	expect(b.pieces[pawn].type == "queen", "pawn promotes to queen")
	b = base()
	b.objective = "knight"
	b.target_id = b.add_piece("knight", 1, Vector2i(5, 0))
	b.add_piece("queen", 0, Vector2i(4, 5))
	pawn = b.add_piece("pawn", 0, Vector2i(1, 1))
	move(b, pawn, Vector2i(1, 0))
	expect(b.pieces[pawn].type == "rook", "queen cap uses rook promotion")
	b = base()
	b.add_piece("pawn", 0, Vector2i(0, 0))
	b.add_piece("king", 1, Vector2i(5, 0))
	b.begin()
	expect(b.result == "loss", "no legal player actions loses")
	b = base()
	rook = b.add_piece("rook", 0, Vector2i(1, 5))
	b.add_piece("pawn", 1, Vector2i(0, 5))
	move(b, rook, Vector2i(1, 4))
	expect(b.side == 0 and b.result == "", "enemy with no legal moves passes")
	b = base()
	b.side = 1
	var attacker = b.add_piece("rook", 1, Vector2i(0, 0))
	b.add_piece("king", 0, Vector2i(0, 5))
	move(b, attacker, Vector2i(0, 5))
	expect(b.result == "loss", "capturing last player piece loses")

func modifiers() -> void:
	var b = base()
	var rook = b.add_piece("rook", 0, Vector2i(0, 4), "reposition")
	b.add_piece("pawn", 1, Vector2i(0, 2), "wall")
	var enemy = b.add_piece("king", 1, Vector2i(5, 0))
	move(b, rook, Vector2i(0, 2))
	expect(b.phase == "bonus" and b.side == 0 and b.turns == 1, "capture grants bonus before enemy turn")
	expect(b.walls.has(Vector2i(0, 2)) and not b.blocked(Vector2i(0, 2)), "wall dormant under capturer")
	var follow = {"kind": "reposition", "id": rook, "to": Vector2i(1, 2)}
	expect(b.legal_actions().has(follow), "adjacent empty reposition legal")
	b.apply(follow)
	expect(b.blocked(Vector2i(0, 2)) and b.turns == 1 and b.side == 1, "wall activates after departure, bonus costs no move")
	move(b, enemy, Vector2i(4, 0))
	expect(not b.destinations(rook).has(Vector2i(0, 2)), "wall cannot be reentered")
	b = base()
	rook = b.add_piece("rook", 0, Vector2i(0, 4), "reposition")
	b.add_piece("pawn", 1, Vector2i(0, 2))
	b.add_piece("pawn", 1, Vector2i(1, 2))
	move(b, rook, Vector2i(0, 2))
	expect(not b.destinations(rook, true).has(Vector2i(1, 2)), "reposition cannot capture")
	b.apply({"kind": "skip"})
	expect(b.phase == "move" and b.side == 1, "bonus can be skipped")
	b = base()
	rook = b.add_piece("rook", 0, Vector2i(0, 4))
	b.add_piece("pawn", 1, Vector2i(0, 2), "reinforcement")
	move(b, rook, Vector2i(0, 2))
	var spawned = b.at(Vector2i(0, 0))
	expect(spawned != -1 and b.pieces[spawned].type == "pawn" and b.pieces[spawned].modifier == "" and not b.pieces[spawned].owned, "death spawns unmodified temporary home-row pawn")
	b = base()
	rook = b.add_piece("rook", 0, Vector2i(0, 4))
	b.add_piece("pawn", 1, Vector2i(0, 2), "reinforcement")
	for x in range(6):
		b.add_piece("pawn", 1, Vector2i(x, 0))
	move(b, rook, Vector2i(0, 2))
	expect(b.pieces.size() == 7, "full reinforcement row does not spawn")
	b = base()
	b.side = 1
	rook = b.add_piece("rook", 1, Vector2i(0, 0))
	b.add_piece("pawn", 0, Vector2i(0, 4), "", true)
	b.add_piece("pawn", 0, Vector2i(5, 4), "", false)
	move(b, rook, Vector2i(0, 4))
	expect(b.owned_pawns_lost == 1 and b.temporary_pawns_lost == 0, "owned pawn losses separate")
	b.side = 1
	move(b, rook, Vector2i(5, 4))
	expect(b.owned_pawns_lost == 1 and b.temporary_pawns_lost == 1, "temporary pawn losses separate")

func poison_timing() -> void:
	var b = base()
	var rook = b.add_piece("rook", 0, Vector2i(0, 4))
	b.add_piece("pawn", 1, Vector2i(0, 2), "poison")
	var enemy = b.add_piece("king", 1, Vector2i(1, 2))
	move(b, rook, Vector2i(0, 2))
	expect(b.pieces[enemy].hp == 1 and b.pieces[rook].hp == 2, "new poison damages only incoming side")
	expect(b.clouds[0].cells.size() == 4, "poison cross clipped to board")
	move(b, enemy, Vector2i(1, 1))
	expect(b.pieces[rook].hp == 1, "capturer takes poison at own turn start")
	b = base()
	var doomed = b.add_piece("pawn", 0, Vector2i(2, 3), "poison", true)
	b.pieces[doomed].hp = 1
	var survivor = b.add_piece("king", 0, Vector2i(3, 3))
	b.add_piece("king", 1, Vector2i(5, 0))
	b.clouds = [{"cells": [Vector2i(2, 3), Vector2i(3, 3)], "ticks": [2, 2]}, {"cells": [Vector2i(2, 3), Vector2i(3, 3)], "ticks": [2, 2]}]
	b.begin()
	expect(b.pieces[survivor].hp == 1, "overlapping clouds do not stack damage")
	expect(not b.pieces.has(doomed) and b.clouds.size() == 3, "poison death triggers a new cloud")
	expect(b.clouds[2].ticks == [2, 2], "new death cloud does not tick during creation boundary")
	b = base()
	var a = b.add_piece("rook", 0, Vector2i(0, 5))
	var e = b.add_piece("king", 1, Vector2i(5, 0))
	b.clouds = [{"cells": [Vector2i(3, 3)], "ticks": [2, 2]}]
	b.begin()
	move(b, a, Vector2i(0, 4))
	move(b, e, Vector2i(5, 1))
	move(b, a, Vector2i(0, 5))
	expect(b.clouds.is_empty(), "cloud expires after two start-turn ticks for each side")
	b = base()
	b.side = 1
	b.objective = "knight"
	var target = b.add_piece("knight", 1, Vector2i(2, 2), "wall")
	b.target_id = target
	b.pieces[target].hp = 1
	b.add_piece("king", 0, Vector2i(5, 5))
	b.clouds = [{"cells": [Vector2i(2, 2)], "ticks": [2, 2]}]
	b.begin()
	expect(b.result == "win" and b.blocked(Vector2i(2, 2)), "poison can complete capture target objective and death effect")

func copy_and_determinism() -> void:
	var e = G.generate(0, 0, 42)
	var run = R.new()
	run.start(42)
	var positions: Dictionary = {}
	for i in range(6):
		positions[run.roster[i].id] = Vector2i(i % 5, 5 - i / 5)
	var b = G.make_battle(e, run.roster, positions)
	var clone = b.copy()
	var id = clone.pieces.keys()[0]
	clone.pieces[id].hp = 1
	clone.walls[Vector2i(2, 2)] = true
	expect(b.pieces[id].hp == 2 and b.walls.is_empty(), "copies do not share nested state")
	clone = b.copy()
	var actions = b.legal_actions()
	b.apply(actions[0])
	clone.apply(actions[0])
	expect(var_to_str(b.pieces) == var_to_str(clone.pieces) and b.events == clone.events, "same actions produce identical state and events")
	expect(var_to_str(e) == var_to_str(G.generate(0, 0, 42)), "encounter seed repeatable")
	var bot = Bot.new()
	var action = bot.choose(b, 1, 55, {"consistency": 0.0})
	expect(action == Bot.new().choose(b, 1, 55, {"consistency": 0.0}), "easy bot seed repeatable")
	expect(b.legal_actions().has(action), "bot uses legal simulation actions")

func search_depth() -> void:
	var b = SearchTree.new()
	b.side = 1
	b.tree = {
		"root": {"score": 0.0, "moves": ["greedy", "safe"]},
		"greedy": {"score": 5.0, "moves": ["greedy_reply"], "side": 0},
		"safe": {"score": 1.0, "moves": ["safe_reply"], "side": 0},
		"greedy_reply": {"score": 4.0, "moves": ["trap"], "side": 1},
		"safe_reply": {"score": 0.0, "moves": ["success"], "side": 1},
		"trap": {"score": -100.0, "side": 0},
		"success": {"score": 20.0, "side": 0},
	}
	var bot = SearchScorer.new()
	expect(bot.choose(b, 1).kind == "greedy" and bot.completed_depth == 1, "depth one evaluates immediate position")
	expect(bot.choose(b, 2).kind == "greedy" and bot.completed_depth == 2, "depth two includes player reply")
	expect(bot.choose(b, 3).kind == "safe" and bot.completed_depth == 3, "depth three detects consequence beyond player reply")
	expect(bot.choose(b, 3, 1, {"max_nodes": 4}).kind == "greedy" and bot.completed_depth == 2, "interrupted depth retains last fully completed iteration")
	expect(bot.nodes <= 4, "recursive search obeys configured node limit")
	var before = var_to_str(b.tree)
	bot.choose(b, 3)
	expect(b.key == "root" and var_to_str(b.tree) == before, "recursive search leaves live position unchanged")
	expect(bot.choose(b, 0).kind == "greedy" and bot.completed_depth == 1, "nonpositive depth clamps to one")
	expect(b.legal_actions().has(bot.choose(b, 3, 1, {"max_nodes": 1})), "tiny budget returns a legal fallback")
	var seeded = bot.choose(b, 3, 42, {"consistency": 0.0})
	expect(seeded == SearchScorer.new().choose(b, 3, 42, {"consistency": 0.0}), "consistency variation is seeded independently of depth")
	# Same-side bonus branches must maximize for the enemy, and cost no extra ply.
	b.tree = {
		"root": {"score": 0.0, "moves": ["capture", "ordinary"]},
		"capture": {"score": -10.0, "moves": ["escape", "skip"], "phase": "bonus", "side": 1},
		"ordinary": {"score": 2.0, "side": 0},
		"escape": {"score": 8.0, "side": 0},
		"skip": {"score": -8.0, "side": 0},
	}
	expect(bot.choose(b, 1).kind == "capture", "bonus is searched at depth one and preserves acting-side perspective")
	# A passed enemy turn can leave two consecutive ordinary player actions.
	b.tree = {
		"root": {"score": 0.0, "moves": ["pass_line", "ordinary"]},
		"pass_line": {"score": 5.0, "moves": ["bad_reply", "good_reply"], "side": 0},
		"ordinary": {"score": 1.0, "side": 0},
		"bad_reply": {"score": -10.0, "moves": ["player_again_a", "player_again_b"], "side": 0},
		"good_reply": {"score": 10.0, "side": 1},
		"player_again_a": {"score": -20.0, "side": 1},
		"player_again_b": {"score": 20.0, "side": 1},
	}
	expect(bot.choose(b, 3).kind == "ordinary", "search follows actual side after a pass instead of alternating blindly")

func economy() -> void:
	var r = R.new()
	r.start(5)
	expect(r.currency == 50 and r.roster.size() == 6, "starting roster and currency")
	r.currency = 1000
	r.stage = 1
	r.shop = [{"kind": "piece", "key": "queen", "price": 120, "bought": false}, {"kind": "piece", "key": "bishop", "price": 60, "bought": false}, {"kind": "modifier", "key": "poison", "price": 60, "bought": false}]
	expect(not r.purchase(0), "cannot buy second queen")
	expect(r.purchase(1) and r.roster.size() == 7, "buy normal piece")
	expect(not r.purchase(1), "cannot buy same item twice")
	r.shop[1].bought = false
	expect(not r.purchase(1), "cannot buy third bishop by default")
	var recipient: int = r.roster[0].id
	expect(r.purchase(2, recipient) and r.roster[0].modifier == "poison", "modifier attached to selected owned piece")
	r.shop[2].bought = false
	expect(not r.purchase(2, recipient), "modifier cannot stack")
	expect(r.earned == 0, "spending does not affect earned points")
	r.currency = 0
	expect(not r.purchase(2, r.roster[1].id), "insufficient gold rejected")
	r.meta = {"exp": 200, "unlocks": []}
	expect(not r.unlock("bishop", PROFILE), "skill branches require root")
	expect(r.unlock("purse", PROFILE) and r.meta.exp == 170, "root skill costs EXP")
	expect(not r.active_unlocks.has("purse"), "unlock does not modify active run")
	expect(r.unlock("bishop", PROFILE) and r.unlock("reroll", PROFILE), "both branches unlock")
	var loaded = R.new()
	loaded.load_meta(PROFILE)
	expect(loaded.meta == r.meta, "meta progression reloads")
	loaded.start(5)
	expect(loaded.currency == 70 and loaded.limits().bishop == 3, "skills apply to new runs")
	loaded.open_shop()
	expect(loaded.reroll() and not loaded.reroll(), "one free reroll per shop")
	var r2 = R.new()
	r2.meta = loaded.meta.duplicate(true)
	r2.start(5)
	r2.open_shop()
	r2.reroll()
	expect(r2.shop == loaded.shop, "shop and reroll seeded")
	loaded.earned = 259
	loaded.won = 3
	var exp_before: int = loaded.meta.exp
	expect(loaded.finish(true, PROFILE) == 75, "EXP formula rounds down")
	loaded.finish(true, PROFILE)
	expect(loaded.meta.exp == exp_before + 75, "EXP awarded only once")
	var bad = FileAccess.open(PROFILE, FileAccess.WRITE)
	bad.store_string("broken JSON")
	bad.close()
	loaded.load_meta(PROFILE)
	expect(loaded.meta.exp == 0 and loaded.meta.unlocks.is_empty() and loaded.save_error != "", "malformed save handled")
	DirAccess.remove_absolute(PROFILE)
	# Full deployment rows prevent further additions.
	r.start(5)
	r.currency = 1000
	while r.roster.size() < 12:
		r._add_owned("pawn")
	r.shop = [{"kind": "piece", "key": "pawn", "price": 30, "bought": false}]
	expect(not r.purchase(0), "deployment capacity enforced")
	var e = G.generate(0, 0, 5)
	var positions: Dictionary = {}
	for i in range(6):
		positions[r.roster[i].id] = Vector2i(i % 5, 5 - i / 5)
	var roster = r.roster.slice(0, 6)
	var b = G.make_battle(e, roster, positions)
	b.pieces.erase(b.pieces.keys()[-1])
	var restored = G.make_battle(e, roster, positions)
	expect(restored.pieces.size() == e.enemies.size() + 6 and roster.size() == 6, "battle casualties never mutate owned roster")

func generation_and_bots() -> void:
	var r = R.new()
	r.start(9)
	for seed_value in range(25):
		for stage in range(3):
			for variant in range(3):
				var e = G.generate(stage, variant, seed_value)
				expect(G.valid(e, 12 if stage > 0 else 6), "generated encounter valid")
				if e.objective != "promote":
					var probe = G.make_battle(e, [], {})
					var target_pos: Vector2i = probe.pieces[probe.target_id].pos
					var safe = true
					for y in range(e.height - 2, e.height):
						for x in range(e.width):
							var id = probe.add_piece("queen", 0, Vector2i(x, y))
							if probe.destinations(id).has(target_pos):
								safe = false
							probe.pieces.erase(id)
					expect(safe, "target protected from move-one queen capture at any deployment square")
	for stage in range(3):
		expect(G.valid(G.fallback(stage, 0)), "fallback encounter valid")
	# Exercise the actual per-stage depth/resource profiles on real chess positions.
	for stage in range(3):
		var e = G.generate(stage, 0, 42)
		var positions: Dictionary = {}
		for i in range(6):
			positions[r.roster[i].id] = Vector2i(i % e.width, e.height - 1 - i / e.width)
		var b = G.make_battle(e, r.roster, positions)
		b.side = 1
		var bot = Bot.new()
		var budget: int = [420, 2400, 6000][stage]
		var started = Time.get_ticks_msec()
		var action = bot.choose(b, stage + 1, 42, {"max_nodes": budget})
		expect(b.legal_actions().has(action) and bot.nodes <= budget, "stage depth profile returns legal action within budget")
		expect(bot.completed_depth >= 1 and bot.completed_depth <= stage + 1, "stage profile reports achieved depth honestly")
		print("Stage %d search: depth %d/%d, %d nodes, %d ms" % [stage + 1, bot.completed_depth, stage + 1, bot.nodes, Time.get_ticks_msec() - started])
	# Simulate both sides through the public action API, including optional follow-ups.
	for seed_value in range(4):
		var e = G.generate(seed_value % 3, seed_value % 3, seed_value)
		var positions: Dictionary = {}
		for i in range(6):
			positions[r.roster[i].id] = Vector2i(i % e.width, e.height - 1 - i / e.width)
		var b = G.make_battle(e, r.roster, positions)
		b.begin()
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_value
		var steps = 0
		while b.result == "" and steps < 150:
			var actions = b.legal_actions()
			expect(not actions.is_empty(), "active simulated side has action")
			if actions.is_empty():
				break
			var action: Dictionary
			if b.side == 1:
				var bot = Bot.new()
				action = bot.choose(b, 2, seed_value + steps)
				expect(bot.nodes <= Bot.MAX_NODES, "bot obeys search cap")
			else:
				action = actions[rng.randi_range(0, actions.size() - 1)]
			expect(actions.has(action), "simulation bot action legal")
			b.apply(action)
			steps += 1
		expect(b.result != "", "seeded game terminates within move budget")
