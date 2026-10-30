extends SceneTree

const Scene = preload("res://scenes/sandbox/chess_sandbox.tscn")
const Model = preload("res://scripts/sandbox/chaos_battle.gd")
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func click_square(name_value: String) -> void:
	var square = Vector2i(name_value.unicode_at(0) - 97, 8 - int(name_value.substr(1)))
	var layout: Dictionary = game.board.geometry()
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = layout.origin + (Vector2(square) + Vector2(0.5, 0.5)) * layout.cell
	game.board._gui_input(event)

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/schach2-sandbox-" + name_value + ".png")

func wait_for_reply() -> void:
	var deadline = Time.get_ticks_msec() + 15000
	while (game.battle.side == 1 or game.thread != null) and game.battle.result == "" and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(game.battle.side == 0 and game.thread == null, "AI worker returns control to White")

func _run() -> void:
	var small = OS.get_cmdline_user_args().has("--small")
	root.size = Vector2i(1120, 820) if small else Vector2i(1280, 900)
	game = Scene.instantiate()
	root.add_child(game)
	await capture("opening-small" if small else "opening")
	expect(game.battle.pieces.size() == 32 and game.battle.phase == "setup", "sandbox opens editable standard position")
	expect(game.board.size.x >= 520 and game.board.size.y >= 520, "board remains usable at window size")
	var area: Rect2 = game.board.get_global_rect()
	print("Sandbox layout: window %s, canvas %s, game %s, board %s, sidebar end %s" % [root.size, root.get_visible_rect(), game.size, area, game.resign_button.get_global_rect().end])
	expect(area.position.x >= 0 and area.end.x <= root.get_visible_rect().size.x and area.end.y <= root.get_visible_rect().size.y, "board fits stretched canvas")
	expect(game.start_button.get_global_rect().end.y <= root.get_visible_rect().size.y and game.pool_panel.get_global_rect().end.x <= root.get_visible_rect().size.x, "setup controls fit stretched canvas")
	for kind in Model.Catalog.TYPES.filter(func(value): return value != "pawn"):
		expect(game.pool_buttons.has(kind) and game.pool_buttons[kind].icon != null and game.board.ICONS.has(kind), "recognizable piece art and pool entry: " + kind)
	expect(game.thread == null and game.battle.ply == 0 and game.start_button.visible, "AI waits for explicit start")
	game.pool_buttons.queen.pressed.emit()
	click_square("a1")
	expect(game.battle.pieces.size() == 32 and game.battle.pieces[game.battle.at(Vector2i(0, 7))].type == "queen" and game.battle.pieces[game.battle.at(Vector2i(7, 7))].type == "queen", "pool click replaces both mirrored rooks")
	click_square("a2")
	expect(game.battle.pieces[game.battle.at(Vector2i(0, 6))].type == "pawn", "pawn replacement is locked")
	click_square("e6")
	expect(game.battle.pieces.size() == 32 and game.setup_message != "", "cannot place pieces in enemy half")
	expect(game.remove_button.disabled, "Remove is disabled")
	click_square("a3")
	expect(game.battle.at(Vector2i(0, 5)) == -1 and game.setup_message != "", "pool placement rejects rank 3")
	click_square("a4")
	expect(game.battle.at(Vector2i(0, 4)) == -1 and game.setup_message != "", "pool placement rejects rank 4")
	game.choose_setup_tool("")
	click_square("b1")
	click_square("c1")
	expect(game.battle.pieces[game.battle.at(Vector2i(2, 7))].type == "knight", "setup swaps pieces within lower quarter")
	game.new_game()
	game.start_button.pressed.emit()
	expect(game.battle.phase == "move" and not game.pool_panel.visible, "Start locks setup and begins battle")
	await process_frame
	expect(game.resign_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "battle controls fit stretched canvas")
	click_square("e2")
	expect(game.selected != -1 and game.board.highlights.has(Vector2i(4, 4)), "shared board input selects pawn and legal double step")
	click_square("e4")
	expect(game.battle.ply == 1 and game.battle.side == 1, "board click applies legal human move")
	var snapshot = game.battle.copy()
	await wait_for_reply()
	expect(game.battle.ply == 2 and snapshot.ply == 1, "background AI changes only live board on completion")
	expect(game.last_search.begins_with("AI: depth"), "AI reports actual achieved depth")
	await capture("reply-small" if small else "reply")
	# Start a real search, restart while it is running, then reject its old result.
	game.new_game()
	game.start_battle()
	click_square("d2")
	click_square("d4")
	await process_frame
	expect(game.thread != null, "worker started before restart")
	game.new_game()
	var deadline = Time.get_ticks_msec() + 15000
	while game.thread != null and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(game.thread == null and game.battle.ply == 0 and game.battle.pieces.size() == 32, "restart discards stale AI result")
	# Promotion is a choice, not an automatic queen.
	game.ai_enabled = false
	game.battle = Model.new()
	game.battle.castle_rights = [[false, false], [false, false]]
	game.battle.add_piece("king", 0, Vector2i(7, 7))
	game.battle.add_piece("king", 1, Vector2i(7, 0))
	game.battle.add_piece("pawn", 0, Vector2i(0, 1))
	game.battle.begin()
	game.refresh()
	click_square("a7")
	click_square("a8")
	expect(game.promotion_actions.size() == 4 and game.promotion_row.get_child_count() == 4 and game.battle.ply == 0, "promotion presents four choices before applying move")
	await capture("promotion")
	game.promotion_row.get_child(3).pressed.emit()
	expect(game.battle.pieces[game.battle.at(Vector2i(0, 0))].type == "knight" and game.promotion_actions.is_empty(), "promotion control underpromotes")
	game.new_game()
	game.start_battle()
	game.resign()
	expect(game.battle.result == "loss" and game.resign_button.disabled, "resignation ends standalone game")
	await capture("resigned")
	game.new_game()
	expect(game.battle.result == "" and game.battle.ply == 0, "new game resets result")
	game.ai_enabled = true
	game.start_battle()
	click_square("e2")
	click_square("e4")
	await process_frame
	expect(game.thread != null, "worker active before scene shutdown")
	game.queue_free()
	await process_frame
	expect(not is_instance_valid(game), "shutdown joins worker safely")
	print("Chess sandbox UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
