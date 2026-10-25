class_name BoardView
extends Control

signal cell_clicked(pos: Vector2i)
const Catalog = preload("res://scripts/core/pieces.gd")
var battle: Battle
var selected: int = -1
var highlights: Array = []
var deployment: bool = false
var compact: bool = false
var show_threats: bool = false
var hovered = Vector2i(-1, -1)
var threats: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hovered = Vector2i(-1, -1); queue_redraw())

func set_state(value: Battle, selection: int = -1, moves: Array = [], placing: bool = false) -> void:
	battle = value
	selected = selection
	highlights = moves
	deployment = placing
	threats = []
	if battle != null and show_threats:
		for p in battle.pieces.values():
			if p.side == 1:
				threats.append_array(battle.destinations(p.id))
	queue_redraw()

func geometry() -> Dictionary:
	if battle == null:
		return {"cell": 1.0, "origin": Vector2.ZERO}
	var margin = 22.0 if compact else 32.0
	var cell = minf((size.x - margin * 2) / battle.width, (size.y - margin * 2) / battle.height)
	return {"cell": cell, "origin": (size - Vector2(battle.width, battle.height) * cell) / 2}

func _gui_input(event: InputEvent) -> void:
	if battle == null:
		return
	var g = geometry()
	if event is InputEventMouse:
		var local: Vector2 = (event.position - g.origin) / g.cell
		hovered = Vector2i(floori(local.x), floori(local.y))
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and battle.inside(hovered):
		cell_clicked.emit(hovered)

func _get_tooltip(at_position: Vector2) -> String:
	if battle == null:
		return ""
	var g = geometry()
	var local: Vector2 = (at_position - g.origin) / g.cell
	var pos = Vector2i(floori(local.x), floori(local.y))
	var id = battle.at(pos)
	if id != -1:
		var p: Dictionary = battle.pieces[id]
		var text = "%s %s · %d/2 HP" % ["Your" if p.side == 0 else "Enemy", p.type.capitalize(), p.hp]
		if id == battle.target_id:
			text += "\nOBJECTIVE TARGET"
		if p.modifier != "":
			text += "\n" + Catalog.DESCRIPTIONS[p.modifier]
		if battle.poison_at(pos, p.side):
			text += "\nPoisoned tile: 1 damage at your turn start."
		return text
	if battle.blocked(pos):
		return "Wall · blocks movement and sliding paths. Knights may jump over it."
	return "Poison · 1 damage at the start of an occupant's turn." if battle.poison_at(pos, 0) or battle.poison_at(pos, 1) else ""

func _draw() -> void:
	if battle == null:
		return
	var g = geometry()
	var cell: float = g.cell
	var origin: Vector2 = g.origin
	var font = ThemeDB.fallback_font
	for y in range(battle.height):
		for x in range(battle.width):
			var pos = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(pos) * cell, Vector2.ONE * cell)
			var color = Color("34464b") if (x + y) % 2 == 0 else Color("25363c")
			if deployment and y >= battle.height - 2:
				color = color.lerp(Color("68b5a0"), 0.18)
			draw_rect(rect.grow(-1), color)
			if battle.poison_at(pos, 0) or battle.poison_at(pos, 1):
				draw_rect(rect.grow(-3), Color(0.55, 0.7, 0.18, 0.26))
				for dot in [Vector2(0.2, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8)]:
					draw_circle(rect.position + dot * cell, cell * 0.035, Color("a6c75b"))
			if battle.walls.has(pos):
				var wall_color = Color("9aa3a6") if battle.walls[pos] else Color(0.7, 0.75, 0.8, 0.3)
				for row in range(3):
					for col in range(2):
						var brick = Rect2(rect.position + Vector2(0.12 + col * 0.39, 0.2 + row * 0.2) * cell, Vector2(0.35, 0.15) * cell)
						draw_rect(brick, wall_color)
			if show_threats and threats.has(pos) and not compact:
				draw_line(rect.position + Vector2(5, 5), rect.position + Vector2(cell - 5, 5), Color("dd8274"), 3)
			if highlights.has(pos):
				draw_rect(rect.grow(-3), Color("d6b272"), false, 2)
				if battle.at(pos) == -1:
					draw_circle(rect.get_center(), cell * 0.09, Color("d6b272"))
			if pos == hovered and not compact:
				draw_rect(rect.grow(-2), Color(1, 1, 1, 0.3), false, 1)
			var id = battle.at(pos)
			if id != -1:
				_draw_piece(rect, battle.pieces[id], id == selected, id == battle.target_id)
	for x in range(battle.width):
		draw_string(font, origin + Vector2((x + 0.5) * cell - 4, battle.height * cell + 18), String.chr(65 + x), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("87999d"))
	for y in range(battle.height):
		draw_string(font, origin + Vector2(-18, (y + 0.5) * cell + 4), str(battle.height - y), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("87999d"))

func _draw_piece(rect: Rect2, p: Dictionary, active: bool, target: bool) -> void:
	var cell = rect.size.x
	var center = rect.get_center() - Vector2(0, cell * 0.025)
	var radius = cell * 0.30
	var color = Color("eadbbd") if p.side == 0 else Color("dc8474")
	if active:
		draw_circle(center, radius + 5, Color("d9b676"), false, 2)
	draw_circle(center + Vector2(0, 3), radius, Color(0, 0, 0, 0.25))
	if p.side == 0:
		draw_circle(center, radius, color)
	else:
		var points = PackedVector2Array([center + Vector2(0, -radius * 1.15), center + Vector2(radius * 1.1, 0), center + Vector2(0, radius * 1.15), center + Vector2(-radius * 1.1, 0)])
		draw_colored_polygon(points, color)
	var text: String = Catalog.SYMBOLS[p.type]
	var font = ThemeDB.fallback_font
	var font_size = maxi(12, int(cell * 0.32))
	var ts = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-ts.x / 2, ts.y * 0.25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("18282d"))
	if target:
		draw_arc(center, radius + 9, 0, TAU, 32, Color("f4c773"), 2)
		draw_circle(rect.position + Vector2(cell - 9, 9), 4, Color("f4c773"))
	if not compact:
		for i in range(2):
			draw_circle(center + Vector2((i - 0.5) * 9, radius + 10), 2.5, color if i < p.hp else Color("121f24"))
	if p.modifier != "":
		var label: String = Catalog.MOD_LABELS[p.modifier]
		var badge = Rect2(rect.position + Vector2(3, 3), Vector2(cell * 0.3, cell * 0.22))
		draw_rect(badge, Color("14252b"))
		draw_string(font, badge.position + Vector2(3, badge.size.y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(cell * 0.16)), Color("9bd5b9"))
