extends "res://scripts/core/bot.gd"
## Reuses the existing bounded search; only the position evaluation is chess-specific.

func evaluate(b: Battle) -> float:
	if b.result == "win":
		return -10000.0
	if b.result == "loss":
		return 10000.0
	if b.result == "draw":
		return 0.0
	var score = 0.0
	var variant = b.get("chaos") == true
	for piece in b.pieces.values():
		var value: float = Catalog.VALUES.get(piece.type, preload("res://scripts/sandbox/chaos_catalog.gd").VALUES.get(piece.type, 5.0))
		var center = 3.5 - (absf(piece.pos.x - 3.5) + absf(piece.pos.y - 3.5)) / 2.0
		if piece.type in ["knight", "bishop"]:
			value += center * 0.09
		elif piece.type == "pawn":
			value += (6 - piece.pos.y if piece.side == 0 else piece.pos.y - 1) * 0.06
		elif piece.type == "king" and b.ply < 30:
			value -= center * 0.07
		value += piece.get("upgrades", []).size() * 0.7
		if variant:
			if b.is_royal(piece.id): value += 25.0
			if b.has_upgrade(piece.id, "+1"): value *= 1.5
			if b.has_upgrade(piece.id, "+2"): value *= 2.0
			if b.mines.has(piece.pos) and b.mines[piece.pos] != piece.side: value -= 8.0
		score += value if piece.side == 1 else -value
	if b.in_check(0):
		score += 0.2
	if b.in_check(1):
		score -= 0.2
	return score
