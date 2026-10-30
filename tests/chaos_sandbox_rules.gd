extends SceneTree
const Model = preload("res://scripts/sandbox/chaos_battle.gd")
const Bot = preload("res://scripts/sandbox/chess_bot.gd")
var checks := 0
var failures := 0
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func fixture():
	var b = Model.new()
	b.chaos = true
	b.royal_mode = ["capture", "capture"]
	b.add_piece("king", 0, Vector2i(7, 7))
	b.add_piece("king", 1, Vector2i(7, 0))
	return b
func move(b, id: int, to: Vector2i, kind: String = "move") -> void:
	var action = {"kind": kind, "id": id, "to": to}
	expect(b.legal_actions().has(action), "%s legal to %s" % [kind, str(to)])
	b.apply(action)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var b = Model.new()
	b.setup(true)
	expect(not b.chaos and b.legal_actions().is_empty(), "plain setup remains orthodox and waits")
	for upgrade in Model.Chaos.UPGRADES:
		expect(b.equip(b.at(Vector2i(0, 6)), upgrade) == "", "equip " + upgrade)
	expect(not b.has_upgrade(b.at(Vector2i(0, 6)), "+1") and b.has_upgrade(b.at(Vector2i(0, 6)), "+2"), "action upgrades replace rather than stack")
	expect(b.start_prepared() == "", "upgraded standard build starts")
	var id: int
	var target: int
	b = fixture()
	id = b.add_piece("rook", 0, Vector2i(0, 4))
	b.pieces[id].upgrades = ["gun", "+1"]
	target = b.add_piece("pawn", 1, Vector2i(0, 1))
	move(b, id, Vector2i(0, 1), "shoot")
	expect(not b.has_upgrade(id, "gun") and b.side == 0 and b.remaining == 1 and b.phase == "bonus", "Gun single use and +1 holds turn")
	move(b, id, Vector2i(1, 4))
	expect(b.side == 1, "second mixed action ends turn")
	b = fixture()
	id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["+2"]
	for to in [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]: move(b, id, to)
	expect(b.side == 1, "+2 permits exactly three actions")
	b = fixture()
	id = b.add_piece("ghost", 0, Vector2i(0, 4))
	b.add_piece("pawn", 0, Vector2i(0, 3)); target = b.add_piece("pawn", 1, Vector2i(0, 2))
	expect(b.destinations(id).has(Vector2i(0, 1)) and not b.destinations(id).has(Vector2i(0, 2)), "Ghost crosses units without capturing ordinary targets")
	b.pieces[b.at(Vector2i(7, 0))].pos = Vector2i(0, 0)
	move(b, id, Vector2i(0, 0)); expect(b.result == "win", "Ghost captures royal")
	b = fixture()
	id = b.add_piece("elephant", 0, Vector2i(0, 4)); target = b.add_piece("pawn", 1, Vector2i(0, 3)); var target2 = b.add_piece("rook", 1, Vector2i(0, 2))
	move(b, id, Vector2i(0, 2)); expect(not b.pieces.has(target) and not b.pieces.has(target2), "Elephant double capture")
	b = fixture()
	id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["phasing"]
	b.add_piece("pawn", 0, Vector2i(0, 3)); expect(b.destinations(id).has(Vector2i(0, 2)), "Phasing crosses ally")
	b.walls[Vector2i(0, 2)] = true; expect(not b.destinations(id).has(Vector2i(0, 1)), "Phasing respects walls")
	b = fixture()
	id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["recoil", "eldritch"]
	target = b.add_piece("pawn", 1, Vector2i(0, 2))
	move(b, id, Vector2i(0, 2)); expect(b.holes.has(Vector2i(0, 4)) and b.pieces[id].pos == Vector2i(0, 2), "Eldritch prevents recoil to vanished tile")
	b = fixture()
	id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["recoil"]
	target = b.add_piece("pawn", 1, Vector2i(0, 2))
	move(b, id, Vector2i(0, 2)); expect(b.pieces[id].pos == Vector2i(0, 4), "Recoil returns after capture")
	for upgrade in ["backup", "dagger"]:
		b = fixture(); id = b.add_piece("rook", 0, Vector2i(0, 4)); target = b.add_piece("bishop", 1, Vector2i(0, 2)); b.pieces[target].upgrades = [upgrade]
		move(b, id, Vector2i(0, 2))
		if upgrade == "backup": expect(b.pieces[target].type == "rook" and b.pieces[id].pos == Vector2i(0, 4) and not b.has_upgrade(target, "backup"), "Backup replaces victim, consumes upgrade and cancels movement")
		else: expect(not b.pieces.has(target) and not b.pieces.has(id), "Dagger kills capturer")
	# A saved second victim undoes the first capture too.
	b = fixture()
	id = b.add_piece("elephant", 0, Vector2i(0, 4)); target = b.add_piece("pawn", 1, Vector2i(0, 3)); target2 = b.add_piece("pawn", 1, Vector2i(0, 2)); b.pieces[target2].upgrades = ["backup"]
	move(b, id, Vector2i(0, 2)); expect(b.pieces.has(target) and b.pieces[target2].type == "rook" and b.pieces[id].pos == Vector2i(0, 4), "multi-capture Backup rollback is atomic")
	b = fixture(); id = b.add_piece("bouncer", 0, Vector2i(0, 4)); target = b.add_piece("pawn", 1, Vector2i(1, 4)); b.walls[Vector2i(5, 4)] = true
	move(b, id, Vector2i(1, 4)); expect(b.pieces[target].pos == Vector2i(4, 4), "Bouncer stops before obstacle")
	b = fixture(); id = b.add_piece("seductress", 0, Vector2i(0, 4)); target = b.add_piece("rook", 1, Vector2i(1, 4)); b.pieces[target].upgrades = ["gun"]
	move(b, id, Vector2i(1, 4)); expect(b.pieces[target].side == 0 and b.has_upgrade(target, "gun") and b.pieces[id].pos == Vector2i(0, 4), "conversion keeps gear and leaves seductress put")
	b = fixture(); id = b.add_piece("rook", 0, Vector2i(0, 4)); b.add_piece("portal", 0, Vector2i(0, 3)); b.add_piece("portal", 0, Vector2i(4, 3))
	expect(b.destinations(id).has(Vector2i(4, 2)) and not b.destinations(id).has(Vector2i(0, 2)), "friendly portal continues relative trajectory")
	b.pieces[b.at(Vector2i(0, 3))].side = 1; expect(not b.destinations(id).has(Vector2i(4, 2)), "enemy portals never transport")
	b = fixture(); id = b.add_piece("factory", 0, Vector2i(0, 7)); b.begin()
	expect(b.at(Vector2i(0, 6)) != -1 and b.pieces[b.at(Vector2i(0, 6))].type == "pawn" and b.destinations(id).is_empty(), "Factory spawns forward and remains immobile")
	b._start_turn(); expect(b.pieces.size() == 4, "Factory cannot spawn into occupied tile")
	b = Model.new(); b.setup(true); expect(b.toggle_rule("regents") == "" and b._royals(0).size() == 2, "Twin Regents replace king and queen")
	id = b._royals(0)[0].id; expect(not b.destinations(id).has(b.pieces[id].pos + Vector2i(0, -4)), "Regent range is three")
	b = Model.new(); b.setup(true); expect(b.toggle_rule("large") == "" and b.width == 10 and b.height == 10 and b.pieces.size() == 40, "10×10 grants four units per side")
	expect(b.start_prepared() == "", "10×10 setup valid")
	b = fixture(); b.rules.wrap = true; id = b.add_piece("bishop", 0, Vector2i(7, 4)); expect(b.destinations(id).has(Vector2i(0, 3)), "bishop crosses cylindrical seam")
	id = b.add_piece("rook", 0, Vector2i(0, 4)); expect(b.destinations(id).size() < 40, "wrap rays terminate")
	b = fixture(); b.rules.brittle = true; id = b.add_piece("rook", 0, Vector2i(0, 0)); target = b.add_piece("rook", 0, Vector2i(1, 4)); move(b, target, Vector2i(2, 4)); expect(b.holes.has(Vector2i(0, 0)) and not b.pieces.has(id), "Brittle collapse destroys occupant outside first")
	b = fixture(); id = b.add_piece("rook", 0, Vector2i(0, 4)); b.belts = [[Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]]; b.mines[Vector2i(2, 4)] = 1
	move(b, id, Vector2i(1, 4)); expect(not b.pieces.has(id) and not b.mines.has(Vector2i(2, 4)), "belt arrival triggers enemy mine once")
	b = fixture(); id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["voidwalker"]
	var output = b.apply_coordinate(id, Vector2i(-100000, 4)); expect(output[0].kind != "invalid" and b.pieces[id].pos == Vector2i(-100000, 4), "Voidwalker arbitrarily distant coordinate")
	target = b.add_piece("rook", 1, Vector2i(2, 4)); b.side = 1; b.phase = "move"; b.apply_coordinate(target, Vector2i(-100000, 4)); expect(not b.pieces.has(id) and not b.pieces.has(target), "ordinary off-board capturer dies")
	b = fixture(); id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["voidwalker"]; b.apply_coordinate(id, Vector2i(-20, 4)); target = b.add_piece("rook", 1, Vector2i(2, 4)); b.pieces[target].upgrades = ["voidwalker"]; b.apply_coordinate(target, Vector2i(-20, 4)); expect(b.pieces.has(target) and not b.pieces.has(id), "Voidwalker capturer survives")
	var edge = fixture(); var knight = edge.add_piece("knight", 0, Vector2i(0, 4)); edge.pieces[knight].upgrades = ["voidwalker"]; edge.apply_coordinate(knight, Vector2i(-2, 3)); expect(edge.pieces[knight].pos == Vector2i(-2, 3), "non-sliding Voidwalker can leave board through coordinate UI")
	edge = fixture(); var king = edge.at(Vector2i(7, 7)); edge.walls = {Vector2i(6, 7): true, Vector2i(6, 6): true, Vector2i(7, 6): true}; edge.begin(); expect(edge.result == "loss", "variant detects immobility at initial turn start")
	# Off-board input is still subject to phase/ownership and obstacle rules.
	var prep = Model.new(); prep.setup(true); var prep_id = prep.at(Vector2i(0, 7)); prep.equip(prep_id, "voidwalker")
	expect(prep.coordinate_action(prep_id, Vector2i(-99, 7)).is_empty(), "coordinate API cannot bypass preparation lock")
	prep.toggle_rule("regents"); expect(prep.place_setup_piece("pawn", Vector2i(4, 7)) != "", "shop protects Regent royalty")
	prep = Model.new(); prep.setup(true); prep.toggle_rule("large"); expect(prep.place_setup_piece("pawn", Vector2i(0, 9)) != "", "10×10 pawn back rank rejected")
	expect(prep.place_setup_piece("pawn", Vector2i(8, 8)) != "", "10×10 pawn replacement is locked")
	var identity = fixture(); identity._enable(); var royal = identity.at(Vector2i(7, 0)); identity.pieces[royal].upgrades = ["backup"]; var attacker = identity.add_piece("rook", 0, Vector2i(7, 2)); move(identity, attacker, Vector2i(7, 0)); expect(identity.result == "" and identity.is_royal(royal) and identity.pieces[royal].type == "rook", "Backup preserves royal identity")
	b = fixture(); id = b.add_piece("rook", 0, Vector2i(0, 4)); b.pieces[id].upgrades = ["recoil"]; target = b.add_piece("rook", 1, Vector2i(0, 2)); b.belts = [[Vector2i(3, 4), Vector2i(4, 4)]]
	var clone = b.copy(); clone.belts[0].append(Vector2i(5, 4)); clone.pieces[id].upgrades.append("gun"); clone.holes[Vector2i(2, 2)] = true
	expect(b.belts[0].size() == 2 and not b.has_upgrade(id, "gun") and b.holes.is_empty(), "deep copies isolate nested variant state")
	b.pieces[target].upgrades = ["gun", "dagger"]; b.mines[Vector2i(1, 1)] = 1
	clone = b.public_copy(0); expect(not clone.has_upgrade(target, "dagger") and clone.has_upgrade(target, "gun") and clone.mines.is_empty(), "worker cannot see enemy dagger or mine")
	var bot = Bot.new(); b.side = 1; b.phase = "move"; var snapshot = b.copy(); var chosen = bot.choose(b.public_copy(1), 1, 99, {"max_nodes": 90, "beam_width": 5})
	expect(b.legal_actions().has(chosen) and b.pieces == snapshot.pieces and bot.nodes <= 90, "bounded bot chooses variant legal action without mutating live state")
	for seed_value in range(5):
		b = fixture(); b.rules = {"brittle": true}; b.add_piece("elephant", 0, Vector2i(2, 6)); b.add_piece("rook", 1, Vector2i(2, 1), ""); b.begin()
		clone = b.copy()
		for n in range(45):
			var actions = b.legal_actions()
			if actions.is_empty(): break
			var action = actions[(seed_value + n * 7) % actions.size()]
			b.apply(action); clone.apply(action)
			expect(b.pieces == clone.pieces and b.holes == clone.holes and b.side == clone.side and b.result == clone.result, "seeded replay determinism")
	var no_dragon = Model.new(); no_dragon.setup(true); var unchanged = no_dragon.pieces.duplicate(true)
	expect(not Model.Chaos.PIECES.has("dragon") and not Model.Chaos.VALUES.has("dragon") and not Model.Chaos.ROYALS.has("dragon"), "removed piece is absent from catalog and royal rules")
	expect(no_dragon.place_setup_piece("dragon", Vector2i(4, 7)) != "" and no_dragon.pieces == unchanged, "removed piece cannot be selected through setup API")
	var retired = Model.new(); retired.setup(true)
	for key in ["gambler", "loaded_dice", "push_your_luck", "insurance", "cards"]:
		expect(not Model.Chaos.PIECES.has(key) and not Model.Chaos.UPGRADES.has(key) and not Model.Chaos.BOARDS.has(key), "removed mechanic is absent from all catalogs: " + key)
	expect(retired.toggle_rule("cards") != "" and retired.toggle_rule("insurance") != "" and retired.rules.is_empty(), "removed board switches are rejected without mutation")
	retired.equip(retired.at(Vector2i(0, 7)), "+1"); retired.start_prepared()
	var state_before = retired.pieces.duplicate(true)
	for kind in ["card", "roll", "choose_die", "push_luck"]:
		expect(retired.apply({"kind": kind, "id": 1, "to": Vector2i.ZERO})[0].kind == "invalid" and retired.pieces == state_before, "retired action is rejected: " + kind)
	expect(retired.legal_actions().all(func(action): return action.kind in ["move", "shoot", "skip"]), "remaining action contract has no cards or dice")
	var properties = retired.get_property_list().map(func(entry): return entry.name)
	for property in ["hands", "decks", "discards", "pending_dice", "forced_die", "insurance_used", "random_state"]:
		expect(not properties.has(property), "retired state is absent: " + property)
	print("Chaos sandbox: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
