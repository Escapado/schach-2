extends SceneTree
## Dedicated art-lab checks. Never loads or writes player progress.

const LAB = preload("res://scenes/labs/terrain_lab2.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _signature(lab: Control) -> String:
	var parts: Array[String] = []
	for child in lab.terrain.get_children():
		if child is Sprite2D:
			parts.append("%s:%s:%s" % [child.texture.resource_path, child.position, child.scale])
		elif child is Polygon2D:
			parts.append("%s:%s" % [child.position, child.color])
	return "|".join(parts)

func _run() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	await process_frame
	_check(lab.piece_views.size() == 8, "All sample pieces have cached 3D portraits")
	var first := _signature(lab)
	lab._compose()
	_check(first == _signature(lab), "Same seed reproduces tiles, cliff selection, tint and placement")
	_check(lab.piece_views.size() == 8, "Regeneration reuses portrait views")
	for seed_value in range(120):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		lab._generate_cells(rng)
		_check(lab._connected(lab.cells), "Seed %d produces one connected island" % seed_value)
		for entry in lab.SAMPLE_PIECES:
			_check(lab.cells.has(entry[1]), "Seed %d retains sample piece cell %s" % [seed_value, entry[1]])
		for cell: Vector2i in lab.cells:
			_check(lab.screen_to_grid(lab.grid_to_screen(cell)) == cell, "Cell center round trips through projection")
	for seed_value in range(20):
		lab.terrain_seed = seed_value
		lab._compose()
		var rectangles: Array[Rect2] = []
		for child in lab.terrain.get_children():
			if child is Node2D:
				lab._collect_bounds(child, lab.terrain.transform, rectangles)
		for rectangle in rectangles:
			_check(rectangle.position.x >= 23.9 and rectangle.end.x <= 576.1 and rectangle.position.y >= 11.9 and rectangle.end.y <= 368.1,
				"Seed %d fits all painted art within the preview" % seed_value)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (lab.terrain.transform * lab.grid_to_screen(Vector2i(2, 2))) * lab.display.size / Vector2(lab.PREVIEW_SIZE)
	lab._preview_input(click)
	_check(lab.selected_cell == Vector2i(2, 2), "Picking accounts for composition fit transform")
	_check(lab.selection.visible, "Picking shows the tile anchor marker")
	lab.terrain_seed = 73
	lab._compose()
	_check(first != _signature(lab), "Changing seed changes the composition")
	for root_node in lab.piece_layer:
		var sprite := root_node.get_child(1) as Sprite2D
		var match_found := false
		for portrait in lab.piece_views.values():
			if sprite.texture == portrait.viewport.get_texture():
				match_found = true
				_check(sprite.position.is_equal_approx(-portrait.foot), "Projected model ground origin matches painted tile center")
		_check(match_found, "Piece uses a live 3D portrait")
	lab.broken_paths = false
	lab.show_grid = true
	lab.show_pieces = false
	lab._compose()
	for y in range(6):
		for x in range(6):
			_check(lab.cells.has(Vector2i(x, y)), "Intact option retains every board cell")
	for piece in lab.piece_layer:
		_check(not piece.visible, "Piece visibility follows toggle")
	_check(lab.toggles["Grid"].button_pressed, "Grid control follows state")
	_check(not lab.toggles["3D pieces"].button_pressed, "Piece control follows state")
	_check(not lab.toggles["Broken paths"].button_pressed, "Intact map control follows state")
	# Adjacent diamonds share their entire edge exactly, regardless of source margins.
	var a: Vector2 = lab.grid_to_screen(Vector2i(2, 2))
	var b: Vector2 = lab.grid_to_screen(Vector2i(3, 2))
	_check((a + Vector2(30, 0)).is_equal_approx(b + Vector2(0, -17)), "Shared north vertex has no gap")
	_check((a + Vector2(0, 17)).is_equal_approx(b + Vector2(-30, 0)), "Shared south vertex has no gap")
	lab.queue_free()
	await process_frame
	print("Painted terrain lab: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
