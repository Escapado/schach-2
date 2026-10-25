extends Control
## Painted isometric terrain with live, transparent 3D piece portraits.
## Visual study only. No battle, input-to-action, run, or persistence access.

const PIECE_MATERIAL = preload("res://shaders/painted_piece.gdshader")
const PIECE_OUTLINE = preload("res://shaders/painted_piece_outline.gdshader")
const MIST = preload("res://shaders/painted_mist.gdshader")
const PREVIEW_SIZE := Vector2i(600, 380)
const HALF_TILE := Vector2(30, 17)
const ORIGIN := Vector2(300, 108)
const SAMPLE_PIECES := [
	["king", Vector2i(1, 4), 0], ["bishop", Vector2i(3, 4), 0],
	["pawn", Vector2i(4, 3), 0], ["knight", Vector2i(1, 3), 0],
	["queen", Vector2i(2, 1), 1], ["bishop", Vector2i(4, 2), 1],
	["pawn", Vector2i(3, 0), 1], ["rook", Vector2i(4, 4), 1],
]
# Anchors measured on the original, untrimmed images. Top centers for cliffs;
# ground-contact centers for columns and arches. Never align by image bounds.
const TOP_ANCHORS := {
	6: Vector2(37, 24), 25: Vector2(36, 24), 49: Vector2(30, 20),
	50: Vector2(35, 22), 51: Vector2(39, 24), 53: Vector2(31, 22),
	67: Vector2(43, 30), 69: Vector2(36, 25), 70: Vector2(29, 20),
	73: Vector2(26, 17), 74: Vector2(24, 15),
}
const FOOT_ANCHORS := {
	27: Vector2(40, 165), 28: Vector2(34, 164),
	30: Vector2(75, 188), 31: Vector2(59, 139),
	58: Vector2(36, 91), 60: Vector2(30, 143), 62: Vector2(34, 119),
}

var terrain_seed := 72
var broken_paths := true
var show_pieces := true
var show_grid := false
var show_outlines := true
var viewport: SubViewport
var display: TextureRect
var canvas: Node2D
var terrain: Node2D
var actors: Node2D
var piece_layer: Array[Node2D] = []
var piece_views: Dictionary = {}
var textures: Dictionary = {}
var cells: Dictionary = {}
var seed_label: Label
var footer: Label
var capture_frames := 0
var selected_cell := Vector2i(-99, -99)
var selection: Node2D
var toggles: Dictionary = {}

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("#14282e"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--terrain-seed="):
			terrain_seed = argument.get_slice("=", 1).to_int()
		if argument == "--intact":
			broken_paths = false
		if argument == "--no-pieces":
			show_pieces = false
	viewport = SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	canvas = Node2D.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(PREVIEW_SIZE)
	var mist := ShaderMaterial.new()
	mist.shader = MIST
	background.material = mist
	canvas.add_child(background)
	_build_distance()
	terrain = Node2D.new()
	canvas.add_child(terrain)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_STOP
	display.gui_input.connect(_preview_input)
	add_child(display)
	_compose()
	_build_overlay()
	resized.connect(_layout)
	_layout()

func grid_to_screen(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2((cell.x - cell.y) * HALF_TILE.x, (cell.x + cell.y) * HALF_TILE.y)

func screen_to_grid(point: Vector2) -> Vector2i:
	var local := point - ORIGIN
	return Vector2i(roundi((local.x / HALF_TILE.x + local.y / HALF_TILE.y) * 0.5),
		roundi((local.y / HALF_TILE.y - local.x / HALF_TILE.x) * 0.5))

func _texture(number: int) -> Texture2D:
	if not textures.has(number):
		textures[number] = load("res://assets/terrain_painted/slice%02d.png" % number)
	return textures[number]

func _sprite(parent: Node, number: int, at: Vector2, anchor: Vector2, scale_value := 1.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(number)
	sprite.centered = false
	sprite.position = at - anchor * scale_value
	sprite.scale = Vector2.ONE * scale_value
	parent.add_child(sprite)
	return sprite

func _build_distance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 814
	for index in range(21):
		var at := Vector2(rng.randf_range(-20, 620), rng.randf_range(110, 375))
		# Leave a quiet center behind the main board. Distant ruins are deliberately faint.
		if at.x > 155 and at.x < 450:
			continue
		var sprite := _sprite(canvas, [27, 28, 50, 60, 62][index % 5], at, Vector2(35, 20), rng.randf_range(0.25, 0.55))
		sprite.modulate = Color(0.46, 0.65, 0.67, 0.20)

func _connected(candidate: Dictionary) -> bool:
	var visited := {}
	var pending: Array[Vector2i] = [Vector2i(2, 2)]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell) or not candidate.has(cell):
			continue
		visited[cell] = true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(cell + direction)
	return visited.size() == candidate.size()

func _generate_cells(rng: RandomNumberGenerator) -> void:
	cells.clear()
	for y in range(6):
		for x in range(6):
			cells[Vector2i(x, y)] = true
	if broken_paths:
		var protected := {Vector2i(2, 2): true}
		for entry in SAMPLE_PIECES:
			protected[entry[1]] = true
		var candidates: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 5),
			Vector2i(5, 5), Vector2i(2, 3), Vector2i(3, 2), Vector2i(0, 2)]
		for cell in candidates:
			if protected.has(cell) or rng.randf() > 0.7:
				continue
			cells.erase(cell)
			if not _connected(cells):
				cells[cell] = true
	# Garden ledges use the same lattice as the main paving.
	for cell in [Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(1, -1), Vector2i(2, -1), Vector2i(6, 3), Vector2i(3, 6)]:
		if rng.randf() < 0.7 and (cells.has(cell + Vector2i.RIGHT) or cells.has(cell + Vector2i.LEFT) or cells.has(cell + Vector2i.UP) or cells.has(cell + Vector2i.DOWN)):
			cells[cell] = true

func _compose() -> void:
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.queue_free()
	piece_layer.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	_generate_cells(rng)
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y < b.x + b.y if a.x + a.y != b.x + b.y else a.x < b.x)
	# Foundation first, then continuous top diamonds. No internal vertical slab seams.
	for cell: Vector2i in ordered:
		if not cells.has(cell + Vector2i.RIGHT) or not cells.has(cell + Vector2i.DOWN):
			var number: int = [49, 50, 51, 67, 69, 70][rng.randi_range(0, 5)]
			_sprite(terrain, number, grid_to_screen(cell), TOP_ANCHORS[number], 0.98)
	for cell: Vector2i in ordered:
		_floor_tile(cell, rng)
	_build_selection()
	actors = Node2D.new()
	actors.y_sort_enabled = true
	terrain.add_child(actors)
	for cell in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 5), Vector2i(5, 5)]:
		if cells.has(cell):
			_decoration(6, cell, 0.82, true)
	# Ground anchors determine draw order. Tall art may extend far above its cell.
	for entry in [[27, Vector2i(0, 1), 0.68], [28, Vector2i(1, 0), 0.68],
		[31, Vector2i(4, 0), 0.72], [58, Vector2i(0, 3), 0.65], [62, Vector2i(5, 1), 0.64]]:
		if cells.has(entry[1]):
			_decoration(entry[0], entry[1], entry[2])
	for cell: Vector2i in ordered:
		if cell.x < 0 or cell.y < 0 or cell.x > 5 or cell.y > 5:
			_decoration(6, cell, 0.82, true)
	for entry in SAMPLE_PIECES:
		_place_piece(entry[0], entry[1], entry[2])
	selected_cell = Vector2i(-99, -99)
	_fit_terrain()
	_sync_controls()
	if is_instance_valid(seed_label):
		seed_label.text = "PAINTED RUINS    /    SEED %d" % terrain_seed

func _collect_bounds(node: Node2D, parent_transform: Transform2D, rectangles: Array[Rect2]) -> void:
	if not node.visible:
		return
	var transform := parent_transform * node.transform
	if node is Sprite2D:
		rectangles.append(transform * node.get_rect())
	elif node is Polygon2D:
		# Polygon bounds also cover intact maps with hidden pieces.
		var bounds := Rect2(node.polygon[0], Vector2.ZERO)
		for point in node.polygon:
			bounds = bounds.expand(point)
		rectangles.append(transform * bounds)
	for child in node.get_children():
		if child is Node2D:
			_collect_bounds(child, transform, rectangles)

func _fit_terrain() -> void:
	# Different cliff slices have different depths. Fit their actual painted bounds,
	# including tall columns, instead of assuming every seed fits the same framing.
	var rectangles: Array[Rect2] = []
	for child in terrain.get_children():
		if child is Node2D:
			_collect_bounds(child, Transform2D.IDENTITY, rectangles)
	var bounds := rectangles[0]
	for rectangle in rectangles:
		bounds = bounds.merge(rectangle)
	var available := Rect2(24, 12, PREVIEW_SIZE.x - 48, PREVIEW_SIZE.y - 24)
	var fit := minf(1.0, minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y))
	terrain.scale = Vector2.ONE * fit
	terrain.position = available.get_center() - bounds.get_center() * fit

func _sync_controls() -> void:
	for option in [["Broken paths", broken_paths], ["3D pieces", show_pieces], ["Grid", show_grid], ["Piece outlines", show_outlines]]:
		if toggles.has(option[0]):
			toggles[option[0]].set_pressed_no_signal(option[1])

func _build_selection() -> void:
	selection = Node2D.new()
	selection.visible = false
	terrain.add_child(selection)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(0, -17), Vector2(30, 0), Vector2(0, 17), Vector2(-30, 0), Vector2(0, -17)])
	edge.width = 1.0
	edge.default_color = Color("#ffe5a4")
	selection.add_child(edge)
	for points in [PackedVector2Array([Vector2(-3, 0), Vector2(3, 0)]), PackedVector2Array([Vector2(0, -3), Vector2(0, 3)])]:
		var cross := Line2D.new()
		cross.points = points
		cross.width = 1.0
		cross.default_color = Color("#ffe5a4")
		selection.add_child(cross)

func _floor_tile(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var tile := Polygon2D.new()
	tile.position = grid_to_screen(cell)
	tile.polygon = PackedVector2Array([Vector2(0, -17), Vector2(30, 0), Vector2(0, 17), Vector2(-30, 0)])
	tile.texture = _texture(9)
	# Four measured corners of the painted top face, independent of the slice's sides.
	tile.uv = PackedVector2Array([Vector2(37, 1), Vector2(73, 23), Vector2(38, 44), Vector2(1, 23)])
	var tone := rng.randf_range(0.95, 1.04)
	tile.color = Color(tone, tone, tone) if (cell.x + cell.y) % 2 == 0 else Color(0.63 * tone, 0.72 * tone, 0.70 * tone)
	terrain.add_child(tile)
	if show_grid:
		var line := Line2D.new()
		line.points = tile.polygon
		line.add_point(tile.polygon[0])
		line.width = 0.7
		line.default_color = Color(0.95, 0.84, 0.52, 0.7)
		tile.add_child(line)

func _decoration(number: int, cell: Vector2i, scale_value: float, top_anchor := false) -> void:
	var root := Node2D.new()
	root.position = grid_to_screen(cell)
	actors.add_child(root)
	_sprite(root, number, Vector2.ZERO, TOP_ANCHORS[number] if top_anchor else FOOT_ANCHORS[number], scale_value)

func _piece_view(kind: String, side: int) -> Dictionary:
	var key := "%s_%d" % [kind, side]
	if piece_views.has(key):
		return piece_views[key]
	var piece_view := SubViewport.new()
	piece_view.size = Vector2i(64, 96)
	piece_view.own_world_3d = true
	piece_view.transparent_bg = true
	piece_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	piece_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(piece_view)
	var world := Node3D.new()
	piece_view.add_child(world)
	var piece := (load("res://assets/pieces/%s.glb" % kind) as PackedScene).instantiate() as Node3D
	world.add_child(piece)
	piece.rotation.y = -0.35 if side == 0 else 0.5
	var material := ShaderMaterial.new()
	material.shader = PIECE_MATERIAL
	material.set_shader_parameter("stone_color", Color("#fff0ce") if side == 0 else Color("#79758a"))
	material.set_shader_parameter("shadow_color", Color("#777282") if side == 0 else Color("#222433"))
	_apply_material(piece, material)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	world.add_child(camera)
	# sin(elevation) = tile rise / tile run. This matches the painted diamond.
	var elevation := asin(HALF_TILE.y / HALF_TILE.x)
	camera.position = Vector3(10, tan(elevation) * sqrt(200.0), 10) + Vector3(0, 0.7, 0)
	camera.look_at(Vector3(0, 0.7, 0))
	var result := {"viewport": piece_view, "foot": camera.unproject_position(Vector3.ZERO)}
	piece_views[key] = result
	return result

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material(child, material)

func _place_piece(kind: String, cell: Vector2i, side: int) -> void:
	var portrait := _piece_view(kind, side)
	var root := Node2D.new()
	root.position = grid_to_screen(cell)
	root.visible = show_pieces
	actors.add_child(root)
	piece_layer.append(root)
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for index in range(20):
		var angle := index * TAU / 20
		points.append(Vector2(cos(angle) * 12 + 3, sin(angle) * 5 + 2))
	shadow.polygon = points
	shadow.color = Color(0.12, 0.17, 0.22, 0.3)
	root.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = portrait.viewport.get_texture()
	sprite.centered = false
	sprite.position = -portrait.foot
	var edges := ShaderMaterial.new()
	edges.shader = PIECE_OUTLINE
	edges.set_shader_parameter("enabled", show_outlines)
	sprite.material = edges
	root.add_child(sprite)

func _build_overlay() -> void:
	var heading := Label.new()
	heading.position = Vector2(32, 17)
	heading.text = "SCHACH / 2     •     TERRAIN LAB 02"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color("#efdbb2"))
	add_child(heading)
	seed_label = Label.new()
	seed_label.text = "PAINTED RUINS    /    SEED %d" % terrain_seed
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color("#a8bebc"))
	add_child(seed_label)
	var controls := HBoxContainer.new()
	controls.position = Vector2(32, 57)
	controls.add_theme_constant_override("separation", 16)
	add_child(controls)
	var regenerate := Button.new()
	regenerate.text = "New map"
	regenerate.pressed.connect(func() -> void:
		terrain_seed += 1
		_compose())
	controls.add_child(regenerate)
	for option in [["Broken paths", broken_paths], ["3D pieces", show_pieces], ["Grid", show_grid], ["Piece outlines", show_outlines]]:
		var toggle := CheckButton.new()
		toggle.text = option[0]
		toggle.button_pressed = option[1]
		toggles[option[0]] = toggle
		toggle.toggled.connect(func(enabled: bool) -> void:
			match option[0]:
				"Broken paths": broken_paths = enabled
				"3D pieces": show_pieces = enabled
				"Grid": show_grid = enabled
				"Piece outlines": show_outlines = enabled
			_compose())
		controls.add_child(toggle)
	footer = Label.new()
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", Color("#a8bebc"))
	add_child(footer)

func _layout() -> void:
	if not is_instance_valid(display):
		return
	var available := Vector2(size.x - 48, size.y - 132)
	var fit := minf(available.x / PREVIEW_SIZE.x, available.y / PREVIEW_SIZE.y)
	display.size = Vector2(PREVIEW_SIZE) * fit
	display.position = Vector2((size.x - display.size.x) * 0.5, 102 + (available.y - display.size.y) * 0.5)
	seed_label.position = Vector2(size.x - seed_label.get_minimum_size().x - 32, 25)
	footer.position = Vector2(32, size.y - 28)
	footer.text = "N  New seed    •    G  Grid    •    P  Pieces    •    Click a tile to inspect alignment    /    Fixed painted perspective"

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = event.position * Vector2(PREVIEW_SIZE) / display.size
		var cell := screen_to_grid(terrain.transform.affine_inverse() * point)
		if cells.has(cell):
			selected_cell = cell
			selection.position = grid_to_screen(cell)
			selection.visible = true
			footer.text = "Tile (%d, %d)    /    Top center (%d, %d)    /    Shared anchor for terrain and 3D piece bases" % [cell.x, cell.y, grid_to_screen(cell).x, grid_to_screen(cell).y]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_N:
		terrain_seed += 1
		_compose()
	elif event.keycode == KEY_G:
		show_grid = not show_grid
		_compose()
	elif event.keycode == KEY_P:
		show_pieces = not show_pieces
		_compose()

func _process(_delta: float) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		capture_frames += 1
		if capture_frames == 35:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/schach2-terrain-lab2.png")
			viewport.get_texture().get_image().save_png("/tmp/schach2-terrain-lab2-art.png")
			print("Painted terrain captured to /tmp/schach2-terrain-lab2.png")
			get_tree().quit()
