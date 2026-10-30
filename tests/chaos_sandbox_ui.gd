extends SceneTree
const Scene = preload("res://scenes/sandbox/chess_sandbox.tscn")
const Model = preload("res://scripts/sandbox/chaos_battle.gd")
var checks := 0
var failures := 0
var game
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	_run.call_deferred()
func fixture():
	var b = Model.new()
	b.chaos = true
	b.royal_mode = ["capture", "capture"]
	b.add_piece("king", 0, Vector2i(7, 7))
	b.add_piece("king", 1, Vector2i(7, 0))
	return b
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
func bounds(control: Control, label: String) -> void:
	var rect = control.get_global_rect()
	expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= root.get_visible_rect().size.x + 1 and rect.end.y <= root.get_visible_rect().size.y + 1, label + " fits canvas " + str(rect))
func _run() -> void:
	root.size = Vector2i(1120, 820) if OS.get_cmdline_user_args().has("--small") else Vector2i(1280, 900)
	game = Scene.instantiate()
	game.ai_enabled = false
	root.add_child(game)
	await settle()
	expect(game.shop_tabs.get_tab_count() == 3, "three shop categories")
	for key in Model.Chaos.PIECES:
		expect(game.pool_buttons.has(key) and game.board.ICONS.has(key), "special piece pool and art " + key)
	for key in Model.Chaos.UPGRADES: expect(game.pool_buttons.has("unit:" + key), "unit upgrade shop " + key)
	for key in Model.Chaos.BOARDS: expect(game.pool_buttons.has("board:" + key), "board upgrade shop " + key)
	for tab in range(3):
		game.shop_tabs.current_tab = tab
		await settle()
		bounds(game.shop_tabs, "scrolling shop tab")
		bounds(game.start_button, "start button")
	game.choose_setup_tool("ghost"); game.cell_clicked(Vector2i(0, 7))
	expect(game.battle.pieces[game.battle.at(Vector2i(0, 7))].type == "ghost" and game.battle.pieces[game.battle.at(Vector2i(7, 7))].type == "ghost", "replace mirrored pair through shop")
	game.choose_setup_tool("unit:+1"); game.cell_clicked(Vector2i(0, 7))
	expect(game.battle.has_upgrade(game.battle.at(Vector2i(0, 7)), "+1"), "apply upgrade through shop")
	game.choose_setup_tool("board:wall"); game.cell_clicked(Vector2i(0, 4)); game.cell_clicked(Vector2i(0, 3))
	expect(game.battle.walls.has(Vector2i(0, 4)) and not game.battle.walls.has(Vector2i(0, 3)), "terrain editing only own half")
	game.choose_setup_tool("board:mine"); game.cell_clicked(Vector2i(1, 4))
	expect(game.battle.mines.has(Vector2i(1, 4)), "bury mine through shop")
	game.choose_setup_tool("board:belt")
	expect(game.battle.belts.size() == 1 and game.battle.belts[0] == game.battle.roundabout(), "shop installs the fixed roundabout immediately")
	game.start_battle(); await settle()
	expect(game.battle.phase == "move" and game.battle.chaos and game.action_panel.visible and not game.pool_panel.visible, "variant starts explicitly and hides shop")
	bounds(game.action_panel, "battle actions")
	bounds(game.resign_button, "resign button")
	game.resign(); game.next_battle(); await settle()
	expect(game.encounter == 2 and game.battle.phase == "setup" and game.battle.has_upgrade(game.battle.at(Vector2i(0, 7)), "+1") and game.battle.walls.has(Vector2i(0, 4)) and game.battle.belts.size() == 1, "next battle restores build and terrain")
	expect(game.battle.pieces.values().any(func(p): return p.side == 1 and p.get("upgrades", []).has("gun")), "next opponent has themed upgrades")
	game.new_game(); game.choose_setup_tool("board:large"); await settle()
	expect(game.battle.width == 10 and game.battle.pieces.size() == 40, "10×10 via shop")
	bounds(game.board, "10×10 board")
	game.choose_setup_tool("board:regents")
	expect(game.battle._royals(0).size() == 2, "Regents via shop")
	game.battle = fixture()
	var id = game.battle.add_piece("rook", 0, Vector2i(0, 4)); game.battle.pieces[id].upgrades = ["gun"]
	var victim = game.battle.add_piece("pawn", 1, Vector2i(0, 1))
	game.refresh(); game.shoot_mode.button_pressed = true; game.cell_clicked(Vector2i(0, 4)); game.cell_clicked(Vector2i(0, 1))
	expect(not game.battle.pieces.has(victim) and game.battle.pieces[id].pos == Vector2i(0, 4), "ranged attack toggle fires without moving")
	game.battle = fixture(); id = game.battle.add_piece("rook", 0, Vector2i(0, 4)); game.battle.pieces[id].upgrades = ["+1"]; game.shoot_mode.button_pressed = false
	game.refresh(); game.cell_clicked(Vector2i(0, 4)); game.cell_clicked(Vector2i(1, 4)); game._special_action()
	expect(game.battle.side == 1, "End bonus turn still skips unused +1 actions")
	game.battle = fixture(); id = game.battle.add_piece("rook", 0, Vector2i(0, 4)); game.battle.pieces[id].upgrades = ["voidwalker"]; game.selected = id; game.coordinate_x.value = -800; game.coordinate_y.value = 4; game._coordinate_move(); await settle()
	expect(game.battle.pieces[id].pos == Vector2i(-800, 4) and game.offboard_picker.visible, "coordinate entry and off-board piece selector")
	# An actual variant worker reply, not a direct bot call.
	game.battle = fixture(); game.battle.side = 1; id = game.battle.add_piece("rook", 1, Vector2i(0, 1)); game.battle.pieces[id].upgrades = ["gun"]; game.battle.add_piece("rook", 0, Vector2i(0, 4)); game.enemy_max_nodes = 120; game.enemy_depth = 1; game.ai_enabled = true; game.refresh()
	var deadline = Time.get_ticks_msec() + 15000
	while (game.battle.side == 1 or game.thread != null) and Time.get_ticks_msec() < deadline: await process_frame
	expect(game.battle.side == 0 and game.thread == null and game.last_search != "", "actual background variant worker completes")
	for key in ["dragon", "gambler", "unit:loaded_dice", "unit:push_your_luck", "board:insurance", "board:cards"]:
		expect(not game.pool_buttons.has(key), "retired mechanic is absent from debug shop: " + key)
	var properties = game.get_property_list().map(func(entry): return entry.name)
	for property in ["cards_panel", "dice_buttons", "die_choice", "pending_card"]: expect(not properties.has(property), "retired controller state is absent: " + property)
	game.queue_free(); await process_frame
	print("Chaos UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
