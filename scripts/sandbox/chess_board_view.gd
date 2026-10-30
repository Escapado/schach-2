extends "res://scripts/ui/board_view.gd"
## Shared board/picking with local vector art, setup boundaries and check marking.

const ICONS = {
	"king": preload("res://assets/sandbox/pieces/king.svg"),
	"queen": preload("res://assets/sandbox/pieces/queen.svg"),
	"rook": preload("res://assets/sandbox/pieces/rook.svg"),
	"bishop": preload("res://assets/sandbox/pieces/bishop.svg"),
	"knight": preload("res://assets/sandbox/pieces/knight.svg"),
	"pawn": preload("res://assets/sandbox/pieces/pawn.svg"),
	"portal": preload("res://assets/sandbox/pieces/portal.svg"),
	"ghost": preload("res://assets/sandbox/pieces/ghost.svg"),
	"elephant": preload("res://assets/sandbox/pieces/elephant.svg"),
	"bouncer": preload("res://assets/sandbox/pieces/bouncer.svg"),
	"seductress": preload("res://assets/sandbox/pieces/seductress.svg"),
	"factory": preload("res://assets/sandbox/pieces/factory.svg"),
	"regent": preload("res://assets/sandbox/pieces/regent.svg"),
}
var setup_mode := true
var camera_min := Vector2i.ZERO
var camera_span := Vector2i(8, 8)
var void_visible := false
var follow_id := -1
var _pan_pixels := Vector2.ZERO

func set_state(value: Battle, selection: int = -1, moves: Array = [], placing: bool = false) -> void:
	super.set_state(value, selection, moves, placing)
	var enabled = value.pieces.keys().any(func(id): return value.has_upgrade(id, "voidwalker") or not value.inside(value.pieces[id].pos))
	if enabled != void_visible or (not enabled and camera_span != Vector2i(value.width, value.height)):
		void_visible = enabled
		reset_camera()
	if selection != -1: follow_id = selection
	if void_visible and value.pieces.has(follow_id):
		var square: Vector2i = value.pieces[follow_id].pos
		if not visible_square(square): focus_square(square)

func reset_camera() -> void:
	if battle == null: return
	camera_min = Vector2i(-2, -2) if void_visible else Vector2i.ZERO
	camera_span = Vector2i(battle.width, battle.height) + (Vector2i(4, 4) if void_visible else Vector2i.ZERO)
	queue_redraw()

func visible_square(square: Vector2i) -> bool:
	return Rect2i(camera_min, camera_span).has_point(square)

func focus_square(square: Vector2i) -> void:
	camera_min = square - camera_span / 2
	queue_redraw()

func pan_camera(delta: Vector2i) -> void:
	if not void_visible: return
	camera_min += delta
	queue_redraw()

func zoom_camera(amount: int) -> void:
	if not void_visible: return
	var center = camera_min + camera_span / 2
	camera_span = Vector2i(clampi(camera_span.x + amount, 6, 32), clampi(camera_span.y + amount, 6, 32))
	camera_min = center - camera_span / 2
	queue_redraw()

func geometry() -> Dictionary:
	if battle == null: return {"cell": 1.0, "origin": Vector2.ZERO}
	var cell = minf((size.x - 44) / camera_span.x, (size.y - 44) / camera_span.y)
	var corner = (size - Vector2(camera_span) * cell) / 2
	return {"cell": cell, "origin": corner - Vector2(camera_min) * cell}

func _gui_input(event: InputEvent) -> void:
	if battle == null: return
	var layout = geometry()
	if event is InputEventMouse:
		var local = (event.position - layout.origin) / layout.cell
		hovered = Vector2i(floori(local.x), floori(local.y))
		queue_redraw()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_camera(-2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2)
			accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and visible_square(hovered):
			cell_clicked.emit(hovered)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_pan_pixels += event.relative
			var steps = Vector2i(_pan_pixels / layout.cell)
			if steps != Vector2i.ZERO:
				pan_camera(-steps)
				_pan_pixels -= Vector2(steps) * layout.cell
		else: _pan_pixels = Vector2.ZERO

func _ready() -> void:
	compact = true
	super._ready()

func _get_tooltip(at_position: Vector2) -> String:
	if battle == null:
		return ""
	var layout = geometry()
	var local = (at_position - layout.origin) / layout.cell
	var square = Vector2i(floori(local.x), floori(local.y))
	var id = battle.at(square)
	if id == -1:
		if not battle.inside(square): return "Void %s · Voidwalkers can move here." % str(square)
		return "Your setup area" if setup_mode and square.y >= battle.height - 2 and battle.inside(square) else ""
	var piece: Dictionary = battle.pieces[id]
	var upgrades: Array = piece.get("upgrades", []).duplicate()
	if piece.side == 1: upgrades.erase("dagger")
	return "%s %s · %s\n%s" % ["White" if piece.side == 0 else "Black", piece.type.capitalize(), str(square), ", ".join(upgrades)]

func _draw_piece(rect: Rect2, piece: Dictionary, active: bool, _target: bool) -> void:
	var texture: Texture2D = ICONS.get(piece.type, ICONS.rook)
	var height = rect.size.y * 0.87
	var dimensions = Vector2(height * texture.get_width() / texture.get_height(), height)
	var target = Rect2(rect.get_center() - dimensions / 2, dimensions)
	var tags: Array = piece.get("upgrades", []).duplicate()
	if piece.side != 0: tags.erase("dagger")
	if not tags.is_empty():
		draw_circle(rect.position + Vector2(rect.size.x - 9, 9), 6, Color("e7bc73"))
	if active:
		draw_rect(rect.grow(-3), Color("e7bc73"), false, 3)
	draw_texture_rect(texture, target, false, Color("f3dfb4") if piece.side == 0 else Color("b59bd7"))

func _draw() -> void:
	if battle == null: return
	var layout = geometry()
	var cell: float = layout.cell
	var origin: Vector2 = layout.origin
	var font = ThemeDB.fallback_font
	for y in range(camera_min.y, camera_min.y + camera_span.y):
		for x in range(camera_min.x, camera_min.x + camera_span.x):
			var square = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(square) * cell, Vector2.ONE * cell)
			var on_board = battle.inside(square)
			var color = Color("34464b") if (x + y) % 2 == 0 else Color("25363c")
			if not on_board: color = Color("191526") if (x + y) % 2 == 0 else Color("211b32")
			draw_rect(rect.grow(-1), color)
			if battle.holes.has(square):
				draw_rect(rect.grow(-1), Color("080d11"))
				draw_line(rect.position + Vector2.ONE * 5, rect.end - Vector2.ONE * 5, Color("705563"), 1)
			if battle.blocked(square):
				for row in range(3):
					for column in range(2): draw_rect(Rect2(rect.position + Vector2(0.1 + column * 0.4, 0.15 + row * 0.23) * cell, Vector2(0.35, 0.18) * cell), Color("9aa3a6"))
			if battle.mines.get(square, -1) == 0: draw_circle(rect.get_center(), cell * 0.16, Color("ed8274"))
			if highlights.has(square):
				draw_rect(rect.grow(-3), Color("d6b272"), false, 2)
				if battle.at(square) == -1: draw_circle(rect.get_center(), cell * 0.09, Color("d6b272"))
	for route in battle.belts:
		for i in range(route.size() - 1):
			if not visible_square(route[i]): continue
			var rect = Rect2(origin + Vector2(route[i]) * cell, Vector2.ONE * cell)
			draw_rect(rect.grow(-2), Color(0.3, 0.78, 0.66, 0.18))
			var direction = Vector2(route[i + 1] - route[i])
			var middle = rect.get_center() + Vector2(0.22, 0.22) * cell
			var end = middle + direction * cell * 0.16
			var start = middle - direction * cell * 0.16
			var across = direction.orthogonal() * cell * 0.1
			draw_line(start, end, Color("74c4b0"), 3)
			draw_line(end, middle + across, Color("74c4b0"), 3)
			draw_line(end, middle - across, Color("74c4b0"), 3)
	for piece in battle.pieces.values():
		if visible_square(piece.pos):
			_draw_piece(Rect2(origin + Vector2(piece.pos) * cell, Vector2.ONE * cell), piece, piece.id == selected, false)
	if setup_mode:
		draw_rect(Rect2(origin + Vector2(0, battle.height - 2) * cell, Vector2(battle.width, 2) * cell).grow(-1), Color("74c4b0"), false, 2)
	else:
		for owner in range(2):
			if battle.in_check(owner):
				var square: Vector2i = battle.king_position(owner)
				if visible_square(square): draw_rect(Rect2(origin + Vector2(square) * cell, Vector2.ONE * cell).grow(-3), Color("ed8274"), false, 3)
	for x in range(camera_min.x, camera_min.x + camera_span.x):
		var label = String.chr(65 + x) if x >= 0 and x < battle.width else str(x)
		draw_string(font, origin + Vector2((x + 0.5) * cell - 4, (camera_min.y + camera_span.y) * cell + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("87999d"))
	for y in range(camera_min.y, camera_min.y + camera_span.y):
		var label = str(battle.height - y) if y >= 0 and y < battle.height else "y" + str(y)
		draw_string(font, origin + Vector2(camera_min.x * cell - 22, (y + 0.5) * cell + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("87999d"))
