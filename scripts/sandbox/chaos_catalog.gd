extends RefCounted
## Experimental catalog: intentionally separate from the main game's economy.
const PIECES = {
	"portal": "Immobile linked pair. Friendly sliding paths continue from the other portal.",
	"ghost": "Rook movement through units; captures only royal pieces.",
	"elephant": "Moves one or two orthogonal squares; captures enemies on both squares.",
	"bouncer": "King movement; pushes an adjacent piece to the last empty square before an obstacle.",
	"seductress": "King movement; converts adjacent non-royal enemies instead of capturing.",
	"factory": "Immobile; spawns a pawn immediately in front at the start of its owner's turn.",
}
const UPGRADES = {
	"phasing": "Slide through pieces; cannot finish on allies. Walls still block.",
	"+1": "Two consecutive actions with this piece, mixing moves and attacks.",
	"+2": "Three consecutive actions; replaces +1 rather than stacking.",
	"dagger": "Concealed. A successful capturer dies too.",
	"gun": "Visible, single use. Shoot the first enemy in any of eight directions. Allies block.",
	"recoil": "After a successful capture return to the departure square, if it still exists and is empty.",
	"voidwalker": "Moves beyond the board. Non-Voidwalker off-board capturers die. Use coordinate moves for distant squares.",
	"eldritch": "Every displacement removes its departure tile, including belts, swaps and pushes.",
	"backup": "On capture, turn into a rook; cancel the attacker's movement. Consumed once."
}
const BOARDS = {
	"large": "10×10: each side gains two rooks, two Elephants. White army moves to the bottom two rows.",
	"wrap": "Left and right edges connect; top and bottom stay open.",
	"brittle": "After every completed turn one tile collapses, outside inward. Occupants die.",
	"regents": "Replace king and queen with two identical Regents: queen movement limited to three squares. Lose both to lose.",
	"wall": "Click an empty square in your half to toggle an impassable wall.",
	"mine": "Click an empty square in your half to bury a concealed, single-use enemy-triggered mine.",
	"belt": "Toggle a clockwise roundabout across the two empty ranks immediately in front of your army. Every completed turn moves units one tile along the loop.",
	"terrain_erase": "Clear terrain at the clicked square in your half."
}
const VALUES = {"portal": 2.0, "ghost": 4.0, "elephant": 5.0, "bouncer": 3.0, "seductress": 6.0, "factory": 8.0, "regent": 7.0}
const ROYALS = ["king", "regent"]
