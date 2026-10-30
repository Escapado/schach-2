extends SceneTree
const Model = preload("res://scripts/sandbox/chaos_battle.gd")
const Scene = preload("res://scenes/sandbox/chess_sandbox.tscn")
var checks := 0
var failures := 0
var game
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func press(square: Vector2i, released: bool = false) -> void:
	var layout = game.board.geometry()
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = not released
	event.position = layout.origin + (Vector2(square) + Vector2(0.5, 0.5)) * layout.cell
	game.board._gui_input(event)
func settle() -> void:
	await process_frame
	await process_frame
func fixture():
	var b = Model.new(); b.chaos = true; b.royal_mode = ["capture", "capture"]
	b.add_piece("king", 0, Vector2i(7, 7)); b.add_piece("king", 1, Vector2i(7, 0))
	return b
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var b = Model.new(); b.setup(true)
	var pawn = b.at(Vector2i(0, 6)); var rook = b.at(Vector2i(0, 7)); var other_rook = b.at(Vector2i(7, 7))
	var before = b.pieces.duplicate(true)
	expect(b.place_setup_piece("queen", Vector2i(0, 6)) != "" and b.pieces == before, "pawns cannot be replaced")
	expect(b.move_setup_piece(pawn, Vector2i(1, 6)) != "" and b.pieces == before, "pawns cannot be moved or swapped")
	expect(b.move_setup_piece(rook, Vector2i(0, 6)) != "" and b.pieces == before, "moving another unit cannot displace a pawn")
	expect(b.equip(pawn, "voidwalker") == "" and b.has_upgrade(pawn, "voidwalker") and b.has_upgrade(b.at(Vector2i(7, 6)), "voidwalker"), "pawn upgrades are allowed and mirrored")
	expect(b.place_setup_piece("ghost", Vector2i(0, 7)) == "" and b.pieces[rook].type == "ghost" and b.pieces[other_rook].type == "ghost", "one rook replacement changes both rooks")
	b.equip(rook, "+1"); expect(b.has_upgrade(rook, "+1") and b.has_upgrade(other_rook, "+1"), "unit upgrades apply symmetrically")
	var bishop = b.at(Vector2i(2, 7)); var other_bishop = b.at(Vector2i(5, 7))
	expect(b.move_setup_piece(rook, Vector2i(2, 7)) == "" and b.pieces[other_rook].pos == Vector2i(5, 7) and b.pieces[bishop].pos == Vector2i(0, 7) and b.pieces[other_bishop].pos == Vector2i(7, 7), "rearranging swaps both mirrored pairs atomically")
	before = b.pieces.duplicate(true)
	expect(b.move_setup_piece(rook, Vector2i(3, 7)) != "" and b.pieces == before, "paired rearrangement cannot break the unique king/queen center")
	expect(b.place_setup_piece("hunter", Vector2i(0, 7)) != "" and not Model.Chaos.PIECES.has("hunter"), "Hunter is unavailable")
	b = Model.new(); b.setup(true); b.place_setup_piece("portal", Vector2i(0, 7))
	expect(b.pieces[b.at(Vector2i(0, 7))].type == "portal" and b.pieces[b.at(Vector2i(7, 7))].type == "portal" and b.start_prepared() == "", "one portal purchase creates a usable mirrored pair")
	b = Model.new(); b.setup(true); b.toggle_rule("large")
	for p in b.pieces.values():
		if p.side != 0 or p.type in ["king", "queen"]: continue
		var mirror = b.at(Vector2i(b.width - 1 - p.pos.x, p.pos.y))
		expect(mirror != -1 and b.pieces[mirror].type == p.type, "10×10 preserves mirrored roster")
	b.place_setup_piece("factory", Vector2i(0, 9))
	expect(b.pieces[b.at(Vector2i(9, 9))].type == "factory", "10×10 edge pair replaces together")
	var far = fixture(); var distant = far.add_piece("rook", 0, Vector2i(-10000, 4)); far.pieces[distant].upgrades = ["voidwalker"]; var on_board = far.add_piece("rook", 1, Vector2i(0, 4))
	expect(far.legal_actions().has({"kind": "move", "id": distant, "to": Vector2i(0, 4)}), "off-board piece can target an arbitrarily distant on-board enemy")
	var royals = Model.new(); royals.setup(true); royals.place_setup_piece("queen", Vector2i(0, 7)); royals.toggle_rule("regents")
	expect(royals.pieces[royals.at(Vector2i(3, 7))].type == "regent" and royals.pieces[royals.at(Vector2i(4, 7))].type == "regent", "royal replacement uses center queen despite extra mirrored queens")
	# A filled loop must rotate rather than deadlock on occupied destinations.
	b = fixture(); b.belts = [[Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 5), Vector2i(1, 5), Vector2i(1, 4)]]
	var loop_ids: Array = []
	for i in range(4): loop_ids.append(b.add_piece("pawn", 0, b.belts[0][i]))
	b._advance_route(0)
	for i in range(4): expect(b.pieces[loop_ids[i]].pos == b.belts[0][i + 1], "occupied belt loop moves every unit once")
	b = fixture(); b.belts = [[Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]]
	var first = b.add_piece("pawn", 0, Vector2i(0, 4)); var second = b.add_piece("pawn", 0, Vector2i(1, 4)); b.add_piece("pawn", 1, Vector2i(2, 4)); b._advance_route(0)
	expect(b.pieces[first].pos == Vector2i(0, 4) and b.pieces[second].pos == Vector2i(1, 4), "blocked endpoint stops the whole chain without overlap")
	b = fixture(); b.belts = [[Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]]
	first = b.add_piece("rook", 0, Vector2i(0, 4)); second = b.add_piece("rook", 0, Vector2i(1, 4)); b._advance_route(0)
	expect(b.pieces[first].pos == Vector2i(1, 4) and b.pieces[second].pos == Vector2i(2, 4), "open belt advances both units one tile")
	# Drive actual mouse input through the scene instead of calling a coordinate API.
	root.size = Vector2i(1120, 820) if OS.get_cmdline_user_args().has("--small") else Vector2i(1280, 900)
	game = Scene.instantiate(); game.ai_enabled = false; root.add_child(game); await settle()
	expect(not game.pool_buttons.has("hunter") and not game.pool_buttons.has("pawn"), "removed Hunter and fixed pawn have no replacement shop entries")
	game.choose_setup_tool("unit:voidwalker"); press(Vector2i(0, 7)); press(Vector2i(0, 7), true)
	expect(game.board.void_visible and game.board.visible_square(Vector2i(-1, 7)), "equipping Voidwalker reveals a clickable void margin")
	game.start_battle(); await settle()
	press(Vector2i(0, 7)); press(Vector2i(0, 7), true)
	expect(game.board.highlights.has(Vector2i(-1, 7)), "normal piece selection highlights legal off-board move")
	var walker = game.selected
	press(Vector2i(-1, 7)); press(Vector2i(-1, 7), true)
	expect(game.battle.pieces.has(walker) and game.battle.pieces[walker].pos == Vector2i(-1, 7), "mouse click moves Voidwalker off board and leaves it visible")
	game.battle.apply({"kind": "move", "id": game.battle.at(Vector2i(4, 1)), "to": Vector2i(4, 3)}); game.refresh()
	press(Vector2i(-1, 7)); press(Vector2i(-1, 7), true); press(Vector2i(0, 7)); press(Vector2i(0, 7), true)
	expect(game.battle.pieces[walker].pos == Vector2i(0, 7), "off-board piece can be clicked and return to the board")
	game.battle.side = 0; game.selected = walker; game._select_actions(); game.board.focus_square(Vector2i(-1000, 7)); press(Vector2i(-1000, 7)); press(Vector2i(-1000, 7), true)
	expect(game.battle.pieces[walker].pos == Vector2i(-1000, 7), "panning and clicking supports a move beyond finite AI candidates")
	game.battle.side = 0; game.selected = walker; game.coordinate_x.value = -10000; game.coordinate_y.value = 7; game._coordinate_move()
	expect(game.board.visible_square(Vector2i(-10000, 7)), "camera follows a distant coordinate move")
	game.board.reset_camera(); expect(game.board.visible_square(Vector2i(0, 7)), "Home returns to the board")
	game.board.focus_square(Vector2i(-10000, 7)); var old_span = game.board.camera_span; game.board.zoom_camera(2)
	expect(game.board.camera_span.x == old_span.x + 2, "void zoom adjusts visible extent")
	var old_min = game.board.camera_min; game.board.pan_camera(Vector2i(2, 0)); expect(game.board.camera_min == old_min + Vector2i(2, 0), "void pan reaches further squares")
	game.new_game(); game.choose_setup_tool("board:belt")
	expect(game.battle.belts.size() == 1 and game.battle.belts[0] == game.battle.roundabout() and game.setup_tool == "", "shop installs the fixed roundabout without painting")
	game.start_battle(); var passenger = game.battle.at(Vector2i(0, 6))
	press(Vector2i(0, 6)); press(Vector2i(0, 6), true); press(Vector2i(0, 5)); press(Vector2i(0, 5), true)
	expect(game.battle.pieces[passenger].pos == Vector2i(0, 4), "pawn entering lower roundabout corner rides up after White's turn")
	expect(game.log_lines.any(func(line): return line.contains("Conveyor advances")), "belt movement appears in action log")
	game.play_action({"kind": "move", "id": game.battle.at(Vector2i(4, 1)), "to": Vector2i(4, 3)})
	expect(game.battle.pieces[passenger].pos == Vector2i(1, 4), "roundabout advances clockwise after Black's turn")
	game.resign(); game.next_battle(); expect(game.battle.belts.size() == 1 and game.battle.belts[0] == game.battle.roundabout(), "roundabout persists into next preparation")
	for board_size in [8, 10]:
		var track = Model.new(); track.setup(true)
		if board_size == 10: track.toggle_rule("large")
		track.toggle_rule("belt")
		var route: Array = track.belts[0]
		expect(route.size() == board_size * 2 + 1 and route[0] == route[-1], "roundabout is closed at each board size")
		var seen: Dictionary = {}
		for i in range(route.size() - 1):
			expect(route[i].y in [track.height - 4, track.height - 3] and not seen.has(route[i]) and (route[i + 1] - route[i]).length_squared() == 1, "roundabout visits each empty-rank tile once with adjacent steps")
			seen[route[i]] = true
		track.toggle_rule("belt"); expect(track.belts.is_empty(), "upgrade toggles the entire roundabout off")
	var expanded = Model.new(); expanded.setup(true); expanded.toggle_rule("belt"); expanded.toggle_rule("large")
	expect(expanded.belts.size() == 1 and expanded.belts[0] == expanded.roundabout(), "expansion rebuilds roundabout to span the new board width")
	expect(expanded.edit_terrain("belt", Vector2i(0, 6)) != "" and expanded.belts.size() == 1, "arbitrary belt drawing is rejected")
	expanded.edit_terrain("terrain_erase", Vector2i(0, 6)); expect(expanded.belts[0] == expanded.roundabout(), "terrain eraser cannot cut the roundabout")
	game.new_game(); game.choose_setup_tool("unit:voidwalker"); game.cell_clicked(Vector2i(0, 7)); game.start_battle()
	expect(game.resign_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "Voidwalker controls fit the battle sidebar")
	game.battle.apply_coordinate(game.battle.at(Vector2i(0, 7)), Vector2i(-1, 7)); game.refresh(); await settle()
	expect(game.resign_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "off-board selector remains accessible")
	game.queue_free(); await process_frame
	print("Setup, void and belts: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
