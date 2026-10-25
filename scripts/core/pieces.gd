class_name PieceCatalog
extends RefCounted

const TYPES = ["king", "queen", "rook", "bishop", "knight", "pawn"]
const MODIFIERS = ["wall", "reinforcement", "reposition", "poison"]
const SYMBOLS = {"king": "K", "queen": "Q", "rook": "R", "bishop": "B", "knight": "N", "pawn": "P"}
const VALUES = {"king": 3.0, "queen": 9.0, "rook": 5.0, "bishop": 3.0, "knight": 3.0, "pawn": 1.0}
const PRICES = {"pawn": 30, "knight": 60, "bishop": 60, "rook": 80, "queen": 120}
const MOD_LABELS = {"wall": "W", "reinforcement": "+P", "reposition": "↗", "poison": "☣"}
const DESCRIPTIONS = {
	"wall": "On death: leave a permanent wall. It activates once the capturing piece leaves.",
	"reinforcement": "On death: spawn a pawn in the first free home-row square.",
	"reposition": "After a capture: optionally step to an empty adjacent square.",
	"poison": "On death: poison a cross. Occupants take 1 damage at the start of their next two turns."
}
