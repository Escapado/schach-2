class_name Encounters
extends RefCounted

const BattleModel = preload("res://scripts/core/battle.gd")

static func generate(stage: int, variant: int, run_seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = run_seed + stage * 104729 + variant * 7919
	var w = 5 if stage == 0 else 6
	var h = 6 if stage < 2 else 7
	var objective = ["knight", "queen", "promote"][(variant + stage) % 3]
	# The opening always has a marked knight; all later sets offer each objective.
	if stage == 0:
		objective = "knight"
	var kinds: Array = ["king", "queen", "rook", "bishop", "knight", "pawn"]
	if stage == 1:
		kinds = ["king", "queen", "rook", "knight", "pawn", "pawn", "bishop"]
	elif stage == 2:
		kinds = ["king", "queen", "rook", "rook", "knight", "bishop", "pawn", "pawn"]
	var cells: Array = []
	for y in range(2):
		for x in range(w):
			cells.append(Vector2i(x, y))
	# Keep pieces in the enemy's two home rows; deterministic Fisher-Yates shuffle.
	for i in range(cells.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var enemies: Array = []
	var marked = false
	for i in range(kinds.size()):
		var is_target: bool = not marked and kinds[i] == objective
		marked = marked or is_target
		var modifier = ""
		if stage > 0 and i == kinds.size() - 1:
			modifier = "wall" if variant % 2 == 0 else "poison"
		if stage == 2 and i == 2:
			modifier = "reposition"
		enemies.append({"type": kinds[i], "pos": cells[i], "modifier": modifier, "target": is_target})
	# Protect marked targets from an immediate long-range capture after deployment.
	# Three front-rank guards block vertical and diagonal approaches to a rear target.
	if objective != "promote":
		var center = rng.randi_range(1, w - 2)
		var reserved: Array = [Vector2i(center, 0), Vector2i(center - 1, 1), Vector2i(center, 1), Vector2i(center + 1, 1)]
		var guards = 0
		var remaining: Array = []
		for cell in cells:
			if not reserved.has(cell):
				remaining.append(cell)
		for p in enemies:
			if p.target:
				p.pos = reserved[0]
			elif guards < 3:
				p.pos = reserved[guards + 1]
				guards += 1
			else:
				p.pos = remaining.pop_front()
	var encounter = {"stage": stage, "variant": variant, "seed": rng.seed, "width": w, "height": h,
		"objective": objective, "budget": 20 + stage * 5, "bonus": "speed" if variant % 2 == 0 else "preserve",
		"bonus_threshold": 10 + stage * 3, "enemies": enemies, "title": ["First gambit", "Changing ranks", "Last stand"][stage] + " · " + str(variant + 1)}
	if not valid(encounter):
		return fallback(stage, variant)
	return encounter

static func valid(e: Dictionary, roster_size: int = 6) -> bool:
	if e.width * 2 < roster_size or e.height < 5 or e.enemies.is_empty():
		return false
	var occupied: Array = []
	var targets = 0
	var b = BattleModel.new()
	b.width = e.width
	b.height = e.height
	for p in e.enemies:
		if not b.inside(p.pos) or p.pos.y >= 2 or occupied.has(p.pos):
			return false
		occupied.append(p.pos)
		if p.target:
			if p.type != e.objective:
				return false
			targets += 1
		b.add_piece(p.type, 1, p.pos, p.modifier)
	if e.objective != "promote" and targets != 1:
		return false
	# Verify both sides have an opening action with a standard deployment.
	for i in range(6):
		b.add_piece(["king", "queen", "rook", "bishop", "knight", "pawn"][i], 0, Vector2i(i % e.width, e.height - 1 - i / e.width))
	if b.legal_actions().is_empty():
		return false
	b.side = 1
	return not b.legal_actions().is_empty()

static func fallback(stage: int, variant: int) -> Dictionary:
	var w = 5 if stage == 0 else 6
	var enemies: Array = []
	for i in range(6):
		var kind: String = ["king", "queen", "rook", "bishop", "knight", "pawn"][i]
		enemies.append({"type": kind, "pos": Vector2i(i % w, i / w), "modifier": "", "target": kind == "knight"})
	return {"stage": stage, "variant": variant, "seed": 0, "width": w, "height": 7 if stage == 2 else 6,
		"objective": "knight", "budget": 20 + stage * 5, "bonus": "preserve", "bonus_threshold": 10,
		"enemies": enemies, "title": "Training formation"}

static func make_battle(e: Dictionary, roster: Array, positions: Dictionary) -> Battle:
	var b = BattleModel.new()
	for key in ["width", "height", "objective", "budget", "bonus", "bonus_threshold"]:
		b.set(key, e[key])
	for p in e.enemies:
		var id = b.add_piece(p.type, 1, p.pos, p.modifier)
		if p.target:
			b.target_id = id
	for entry in roster:
		b.add_piece(entry.type, 0, positions[entry.id], entry.modifier, true)
	return b

static func objective_text(e: Dictionary) -> String:
	return "Reach the far rank with a pawn" if e.objective == "promote" else "Capture the marked enemy " + e.objective

static func bonus_text(e: Dictionary) -> String:
	return "Win in %d moves or fewer" % e.bonus_threshold if e.bonus == "speed" else "Lose no owned pawns"
