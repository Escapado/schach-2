extends Control
## Independent experiment entry point. Never loads GameRun or writes a profile.

const Model = preload("res://scripts/sandbox/chaos_battle.gd")
const BotModel = preload("res://scripts/sandbox/chess_bot.gd")
const Board = preload("res://scripts/sandbox/chess_board_view.gd")
@export_range(1, 12) var enemy_depth := 2
@export var enemy_max_nodes := 800
@export var enemy_beam_width := 8
@export var ai_enabled := true
var battle = Model.new()
var board: Control
var selected := -1
var selected_actions: Array = []
var promotion_actions: Array = []
var log_lines: Array[String] = []
var status: Label
var details: Label
var move_log: RichTextLabel
var promotion_row: HBoxContainer
var resign_button: Button
var thread: Thread
var generation := 0
var worker_generation := -1
var last_search := ""
var setup_tool := ""
var setup_message := ""
var pool_panel: VBoxContainer
var pool_buttons: Dictionary = {}
var start_button: Button
var remove_button: Button
var instructions: Label
var log_heading: Label
const Chaos = preload("res://scripts/sandbox/chaos_catalog.gd")
var shop_tabs: TabContainer
var action_panel: VBoxContainer
var shoot_mode: CheckButton
var coordinate_x: SpinBox
var coordinate_y: SpinBox
var prepared_build: Battle
var encounter := 1
var next_button: Button
var offboard_picker: OptionButton

func _ready() -> void:
	_build_ui()
	new_game()

func _exit_tree() -> void:
	if thread != null and thread.is_started():
		thread.wait_to_finish()

func _process(_delta: float) -> void:
	# Poll old workers even after restart; a stale result must never touch a new board.
	if thread != null:
		if not thread.is_alive():
			var response: Dictionary = thread.wait_to_finish()
			thread = null
			if worker_generation == generation and battle.phase in ["move", "bonus"] and battle.result == "" and battle.side == 1:
				last_search = "AI: depth %d · %d positions" % [response.depth, response.nodes]
				if not response.action.is_empty():
					play_action(response.action)
		return
	if not ai_enabled or battle.phase not in ["move", "bonus"] or battle.result != "" or battle.side != 1 or not promotion_actions.is_empty():
		return
	var snapshot = battle.public_copy(1) if battle.chaos else battle.copy()
	var depth = enemy_depth
	var options = {"max_nodes": enemy_max_nodes, "beam_width": enemy_beam_width, "consistency": 1.0}
	var seed_value: int = battle.ply + 1
	worker_generation = generation
	thread = Thread.new()
	thread.start(func():
		var bot = BotModel.new()
		var action = bot.choose(snapshot, depth, seed_value, options)
		return {"action": action, "depth": bot.completed_depth, "nodes": bot.nodes})

func _label(value: String, font_size: int) -> Label:
	var control = Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_font_size_override("font_size", font_size)
	return control

func _button(value: String, callback: Callable) -> Button:
	var control = Button.new()
	control.text = value
	control.custom_minimum_size.y = 44
	control.pressed.connect(callback)
	return control

func _build_ui() -> void:
	var background = ColorRect.new()
	background.color = Color("101e24")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	var title = _label("SCHACH / 2   ·   CHESS SANDBOX", 25)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Reset board", new_game))
	column.add_child(_label("Build your starting army · You play White · Black is controlled by the AI", 16))
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var frame = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(frame)
	board = Board.new()
	board.custom_minimum_size = Vector2(520, 520)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_clicked.connect(cell_clicked)
	frame.add_child(board)
	var sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 300
	sidebar.add_theme_constant_override("separation", 14)
	body.add_child(sidebar)
	status = _label("White to move", 25)
	status.custom_minimum_size.x = 300
	sidebar.add_child(status)
	details = _label("", 15)
	sidebar.add_child(details)
	instructions = _label("", 16)
	sidebar.add_child(instructions)
	pool_panel = VBoxContainer.new()
	pool_panel.add_theme_constant_override("separation", 10)
	sidebar.add_child(pool_panel)
	pool_panel.add_child(_label("DEBUG SHOP · FREE", 17))
	shop_tabs = TabContainer.new()
	shop_tabs.custom_minimum_size = Vector2(320, 260)
	pool_panel.add_child(shop_tabs)
	for category in ["Pieces", "Units", "Board"]:
		var scroll = ScrollContainer.new()
		scroll.name = category
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		shop_tabs.add_child(scroll)
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		var entries: Array = []
		if category == "Pieces": entries = Model.Catalog.TYPES.filter(func(kind): return kind != "pawn") + Chaos.PIECES.keys()
		elif category == "Units": entries = Chaos.UPGRADES.keys()
		else: entries = Chaos.BOARDS.keys()
		for kind in entries:
			var key: String = kind if category == "Pieces" else ("unit:" if category == "Units" else "board:") + kind
			var item = _button(kind.replace("_", " ").capitalize(), choose_setup_tool.bind(key))
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item.add_theme_font_size_override("font_size", 13)
			item.custom_minimum_size = Vector2(145, 46)
			item.toggle_mode = true
			if category == "Pieces":
				item.icon = Board.ICONS.get(kind, Board.ICONS.rook)
				item.expand_icon = true
				item.add_theme_constant_override("icon_max_width", 25)
				item.tooltip_text = Chaos.PIECES.get(kind, "Replace this piece and its mirrored partner. Pawns stay fixed.")
			elif category == "Units": item.tooltip_text = Chaos.UPGRADES[kind]
			else: item.tooltip_text = Chaos.BOARDS[kind]
			grid.add_child(item)
			pool_buttons[key] = item
	var tools = HBoxContainer.new()
	pool_panel.add_child(tools)
	tools.add_child(_button("Rearrange", choose_setup_tool.bind("")))
	remove_button = _button("Remove", func(): pass)
	remove_button.disabled = true
	remove_button.tooltip_text = "Removal is disabled; replace pieces using the pool."
	tools.add_child(remove_button)
	start_button = _button("Start battle →", start_battle)
	sidebar.add_child(start_button)
	promotion_row = HBoxContainer.new()
	sidebar.add_child(promotion_row)
	action_panel = VBoxContainer.new()
	sidebar.add_child(action_panel)
	shoot_mode = CheckButton.new()
	shoot_mode.text = "Ranged attack"
	shoot_mode.toggled.connect(func(_value): _select_actions())
	action_panel.add_child(shoot_mode)
	var camera_tools = HBoxContainer.new()
	action_panel.add_child(camera_tools)
	camera_tools.name = "VoidCamera"
	for item in [["←", Vector2i(-2, 0)], ["→", Vector2i(2, 0)], ["↑", Vector2i(0, -2)], ["↓", Vector2i(0, 2)]]:
		camera_tools.add_child(_button(item[0], board.pan_camera.bind(item[1])))
	camera_tools.add_child(_button("−", board.zoom_camera.bind(2)))
	camera_tools.add_child(_button("+", board.zoom_camera.bind(-2)))
	camera_tools.add_child(_button("Home", board.reset_camera))
	action_panel.add_child(_button("End bonus turn", _special_action))
	var coords = HBoxContainer.new()
	action_panel.add_child(coords)
	for axis in range(2):
		var spin = SpinBox.new()
		spin.min_value = -100000000
		spin.max_value = 100000000
		spin.custom_minimum_size.x = 95
		spin.tooltip_text = "Absolute x,y coordinates (top-left is 0,0); for Voidwalker moves."
		coords.add_child(spin)
		if axis == 0: coordinate_x = spin
		else: coordinate_y = spin
	coords.add_child(_button("Go", _coordinate_move))
	offboard_picker = OptionButton.new()
	offboard_picker.item_selected.connect(func(index):
		selected = offboard_picker.get_item_id(index)
		_select_actions())
	action_panel.add_child(offboard_picker)
	next_button = _button("Next battle →", next_battle)
	sidebar.add_child(next_button)
	log_heading = _label("MOVE LOG", 15)
	sidebar.add_child(log_heading)
	move_log = RichTextLabel.new()
	move_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	move_log.custom_minimum_size = Vector2(300, 60)
	move_log.scroll_following = true
	move_log.add_theme_font_size_override("normal_font_size", 15)
	sidebar.add_child(move_log)
	resign_button = _button("Resign", resign)
	sidebar.add_child(resign_button)
	column.add_child(_label("Parallel experiment · Free debug shop · No progression or profile writes.", 14))

func new_game() -> void:
	generation += 1
	battle = Model.new()
	battle.setup(true)
	selected = -1
	selected_actions = []
	promotion_actions = []
	log_lines.clear()
	last_search = ""
	setup_tool = ""
	shoot_mode.set_pressed_no_signal(false)
	board.follow_id = -1
	board.void_visible = false
	board.reset_camera()
	encounter = 1
	prepared_build = null
	setup_message = "Choose pieces, apply unit upgrades, or edit your half of the board."
	refresh()

func choose_setup_tool(tool: String) -> void:
	if battle.phase != "setup":
		return
	if tool != "" and not pool_buttons.has(tool): return
	setup_tool = tool
	selected = -1
	if tool.begins_with("board:"):
		var key = tool.trim_prefix("board:")
		if key not in ["wall", "mine", "terrain_erase"]:
			setup_message = battle.toggle_rule(key)
			if setup_message == "": setup_message = Chaos.BOARDS[key]
			setup_tool = ""
		else: setup_message = Chaos.BOARDS[key]
	elif tool.begins_with("unit:"): setup_message = Chaos.UPGRADES[tool.trim_prefix("unit:")] + " Click a friendly unit."
	else: setup_message = "Select a piece, then its new square." if tool == "" else Chaos.PIECES.get(tool, "Replace a friendly piece on ranks 1–2.")
	refresh()

func start_battle() -> void:
	var candidate = battle.copy()
	var error: String = battle.start_prepared()
	if error != "":
		setup_message = error
	else:
		prepared_build = candidate
		selected = -1
		selected_actions = []
		setup_tool = ""
		setup_message = ""
	refresh()

func refresh() -> void:
	var editing: bool = battle.phase == "setup"
	var highlights: Array = []
	for action in selected_actions:
		if action.kind in ["move", "shoot"] and not highlights.has(action.to):
			highlights.append(action.to)
	board.setup_mode = editing
	board.set_state(battle, selected, highlights)
	action_panel.get_node("VoidCamera").visible = board.void_visible
	pool_panel.visible = editing
	action_panel.visible = not editing and battle.chaos and battle.result == ""
	next_button.visible = battle.result != ""
	start_button.visible = editing
	move_log.visible = not editing
	log_heading.visible = not editing
	resign_button.visible = not editing
	for kind in pool_buttons:
		pool_buttons[kind].set_pressed_no_signal(setup_tool == kind)
	instructions.text = "Pawns fixed; paired pieces change together. Terrain: your half. Hover shop items for rules. Start when ready." if editing else ("Ordinary kings: checkmate. Capture both Regents to defeat them. Void: click to move; wheel to zoom, right-drag to pan." if battle.chaos else "Select a piece, then a highlighted square. Castle with a two-square king move.")
	status.text = battle.reason if battle.result != "" else ("Black is thinking…" if battle.side == 1 and ai_enabled else ("White to move" if battle.side == 0 else "Black to move"))
	if editing:
		status.text = "Prepare your army"
		details.text = setup_message
	elif battle.result == "" and battle.in_check(battle.side):
		status.text += " · CHECK"
	if not editing:
		details.text = "Move %d · %s\n%s" % [battle.ply / 2 + 1, "White" if battle.side == 0 else "Black", last_search]
	if battle.phase == "bonus": status.text += " · %d actions left" % battle.remaining
	offboard_picker.clear()
	offboard_picker.add_item("Off-board units…", -1)
	for p in battle.pieces.values():
		if not battle.inside(p.pos):
			offboard_picker.add_item("%s %s @ %s" % ["White" if p.side == 0 else "Black", p.type, str(p.pos)], p.id)
	offboard_picker.visible = offboard_picker.item_count > 1
	move_log.text = "\n".join(log_lines)
	resign_button.disabled = battle.result != "" or (ai_enabled and battle.side != 0)
	for child in promotion_row.get_children():
		promotion_row.remove_child(child)
		child.queue_free()
	for action in promotion_actions:
		var choice = _button("", play_action.bind(action))
		choice.icon = Board.ICONS[action.promotion]
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 30)
		choice.custom_minimum_size = Vector2(60, 52)
		choice.tooltip_text = "Promote to " + action.promotion
		promotion_row.add_child(choice)

func cell_clicked(square: Vector2i) -> void:
	if battle.phase == "setup":
		_setup_clicked(square)
		return
	if battle.result != "" or (ai_enabled and battle.side == 1) or not promotion_actions.is_empty():
		return
	var id: int = battle.at(square)
	if id != -1 and battle.pieces[id].side == battle.side and not selected_actions.any(func(a): return a.to == square and a.kind in ["move", "shoot"]):
		selected = id
		if not battle.has_upgrade(id, "gun"): shoot_mode.set_pressed_no_signal(false)
		_select_actions()
		refresh()
		return
	if id != -1 and battle.pieces[id].side != battle.side and selected_actions.is_empty():
		selected = id
		refresh()
		return
	var matching = selected_actions.filter(func(action): return action.kind in ["move", "shoot"] and action.to == square)
	if matching.size() > 1:
		promotion_actions = matching
		status.text = "Choose a promotion"
		refresh()
		status.text = "Choose a promotion"
	elif matching.size() == 1:
		play_action(matching[0])
	elif battle.chaos and battle.pieces.has(selected):
		# Clicking a panned void can exceed the AI's finite candidate window.
		var action = battle.coordinate_shot(selected, square) if shoot_mode.button_pressed else battle.coordinate_action(selected, square)
		if not action.is_empty():
			var output = battle.apply_coordinate(selected, square, shoot_mode.button_pressed)
			for event in output: log_lines.append(event.text)
			selected = -1
			selected_actions = []
			refresh()

func _setup_clicked(square: Vector2i) -> void:
	var id: int = battle.at(square)
	if setup_tool.begins_with("unit:"):
		setup_message = battle.equip(id, setup_tool.trim_prefix("unit:"))
		if setup_message == "": setup_message = "Equipped " + setup_tool.trim_prefix("unit:") + ". Its mirrored partner is upgraded too."
	elif setup_tool.begins_with("board:"):
		setup_message = battle.edit_terrain(setup_tool.trim_prefix("board:"), square)
	elif setup_tool != "":
		setup_message = battle.place_setup_piece(setup_tool, square)
	elif selected != -1:
		setup_message = battle.move_setup_piece(selected, square)
		if setup_message == "":
			selected = -1
	elif id != -1 and battle.pieces[id].side == 0:
		if battle.pieces[id].type == "pawn":
			setup_message = "Pawns stay fixed. Choose a unit upgrade to upgrade a mirrored pawn pair."
			refresh()
			return
		selected = id
		setup_message = "Choose a new square for your %s." % battle.pieces[id].type
	else:
		setup_message = "Select a friendly piece or pick one from the pool."
	refresh()

func play_action(action: Dictionary) -> void:
	var output: Array = battle.apply(action)
	for event in output:
		log_lines.append(event.text)
	selected = -1
	selected_actions = []
	promotion_actions = []
	refresh()

func resign() -> void:
	if battle.phase not in ["move", "bonus"] or battle.result != "" or (ai_enabled and battle.side != 0):
		return
	battle.result = "loss" if battle.side == 0 else "win"
	battle.reason = "%s resigned." % ("White" if battle.side == 0 else "Black")
	refresh()

func _select_actions() -> void:
	selected_actions = battle.legal_actions().filter(func(a): return a.get("id", -1) == selected and a.kind == ("shoot" if shoot_mode.button_pressed else "move"))
	refresh()

func _special_action() -> void:
	if ai_enabled and battle.side == 1: return
	var actions = battle.legal_actions().filter(func(a): return a.kind == "skip")
	if not actions.is_empty(): play_action(actions[0])

func _coordinate_move() -> void:
	if ai_enabled and battle.side == 1: return
	var output = battle.apply_coordinate(selected, Vector2i(int(coordinate_x.value), int(coordinate_y.value)), shoot_mode.button_pressed)
	for event in output: log_lines.append(event.text)
	selected_actions = []
	refresh()

func next_battle() -> void:
	if battle.result == "" or prepared_build == null: return
	generation += 1
	encounter += 1
	battle = prepared_build.copy()
	battle.round_number = encounter
	battle.phase = "setup"
	battle.result = ""
	battle.reason = ""
	battle.events = []
	battle._enable()
	battle.castle_rights = [[false, false], [false, false]]
	# Preserve the player's half; the next opponent owns a fresh northern half.
	for pos in battle.walls.keys():
		if pos.y < battle.height / 2: battle.walls.erase(pos)
	for pos in battle.mines.keys():
		if pos.y < battle.height / 2: battle.mines.erase(pos)
	battle.set_roundabout(1, false)
	var family = (encounter - 2) % 3
	var enemy = battle.pieces.values().filter(func(p): return p.side == 1 and not Chaos.ROYALS.has(p.type))
	for i in range(mini(enemy.size(), encounter)):
		enemy[i].type = ["rook", "ghost", "bouncer"][family]
		if family == 0: enemy[i].upgrades = ["gun"]
		if encounter >= 4: enemy[i].upgrades = ["+1", "gun"] if family == 0 else ["+1"]
		if encounter >= 7: enemy[i].upgrades = ["+2", "gun"]
	if family == 2:
		battle.set_roundabout(1)
	selected = -1
	selected_actions = []
	setup_tool = ""
	log_lines.clear()
	setup_message = "Battle %d · %s. Your starting build and terrain are restored. Edit before starting." % [encounter, ["Shooting Club", "Night Shift", "Moving Company"][family]]
	refresh()
