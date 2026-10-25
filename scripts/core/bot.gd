class_name ChessBot
extends RefCounted

const Catalog = preload("res://scripts/core/pieces.gd")
const MAX_NODES = 420
const BEAM = 10
const MAX_DEPTH = 12
var nodes: int = 0
var visited_actions: int = 0
var completed_depth: int = 0
var node_limit: int = MAX_NODES
var beam_width: int = BEAM
var _aborted: bool = false

# Depth counts ordinary actions, not bonus repositions. Higher scores favor the enemy.
# Options separate search resources from consistency; all work uses private copies.
func choose(b: Battle, depth: int = 2, seed_value: int = 1, options: Dictionary = {}) -> Dictionary:
	nodes = 0
	visited_actions = 0
	completed_depth = 0
	_aborted = false
	node_limit = maxi(1, int(options.get("max_nodes", MAX_NODES)))
	beam_width = maxi(1, int(options.get("beam_width", BEAM)))
	var actions = b.legal_actions()
	if actions.is_empty():
		return {}
	var fallback: Dictionary = actions[0]
	var candidates = _successors(b)
	if _aborted:
		return fallback
	var ranked: Array = []
	# Only adopt a deeper iteration when every retained root candidate was searched.
	# An exhausted budget cannot make a partly searched branch appear stronger.
	for horizon in range(1, clampi(depth, 1, MAX_DEPTH) + 1):
		var iteration: Array = []
		for candidate in candidates.slice(0, beam_width):
			var remaining = horizon - (1 if b.phase == "move" else 0)
			var score = _search(candidate.state, remaining, -INF, INF)
			if _aborted:
				break
			iteration.append({"action": candidate.action, "score": score})
		if _aborted:
			break
		iteration.sort_custom(func(a, c): return a.score > c.score if b.side == 1 else a.score < c.score)
		ranked = iteration
		completed_depth = horizon
	if ranked.is_empty():
		return candidates[0].action
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var consistency = clampf(float(options.get("consistency", 1.0)), 0.0, 1.0)
	if consistency < 1.0 and rng.randf() >= consistency:
		return ranked[rng.randi_range(0, mini(2, ranked.size() - 1))].action
	return ranked[0].action

func _search(b: Battle, remaining: int, alpha: float, beta: float) -> float:
	if b.result != "" or (remaining <= 0 and b.phase != "bonus"):
		return evaluate(b)
	var children = _successors(b)
	if _aborted or children.is_empty():
		return evaluate(b)
	var maximizing = b.side == 1
	var best = -INF if maximizing else INF
	var next_depth = remaining - (1 if b.phase == "move" else 0)
	for child in children.slice(0, beam_width):
		var score = _search(child.state, next_depth, alpha, beta)
		if _aborted:
			return best
		if maximizing:
			best = maxf(best, score)
			alpha = maxf(alpha, best)
		else:
			best = minf(best, score)
			beta = minf(beta, best)
		if beta <= alpha:
			break
	return best

func _successors(b: Battle) -> Array:
	var out: Array = []
	for action in b.legal_actions():
		if nodes >= node_limit:
			_aborted = true
			break
		var after = b.copy()
		after.apply(action)
		nodes += 1
		visited_actions += 1
		out.append({"action": action, "state": after, "score": evaluate(after)})
	out.sort_custom(func(a, c): return a.score > c.score if b.side == 1 else a.score < c.score)
	return out

func evaluate(b: Battle) -> float:
	if b.result == "win":
		return -10000.0
	if b.result == "loss":
		return 10000.0
	var score = b.turns * 0.12
	for p in b.pieces.values():
		var value: float = Catalog.VALUES[p.type]
		if p.modifier != "":
			value += 0.65
		value += (p.hp - 2) * 0.3
		if b.poison_at(p.pos, p.side):
			value -= 0.6 if p.hp > 1 else value * 0.8
		score += value if p.side == 1 else -value
		if p.side == 0 and p.type == "pawn":
			score -= (b.height - 1 - p.pos.y) * (0.9 if b.objective == "promote" else 0.08)
	if b.pieces.has(b.target_id):
		var target: Dictionary = b.pieces[b.target_id]
		# Penalize exposed targets, and reward player approach toward them.
		var nearest = 99
		for p in b.pieces.values():
			if p.side == 0:
				nearest = mini(nearest, absi(p.pos.x - target.pos.x) + absi(p.pos.y - target.pos.y))
				if b.destinations(p.id).has(target.pos):
					score -= 12
		score += nearest * 0.18
	return score
