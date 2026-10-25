extends Control

const RunModel = preload("res://scripts/core/run.gd")
const Generator = preload("res://scripts/core/encounters.gd")
const Catalog = preload("res://scripts/core/pieces.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Board = preload("res://scripts/ui/board_view.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const UpgradeScreen = preload("res://scripts/ui/upgrade_screen.gd")
# Inspector settings keep foresight, work budget, and consistency independent.
@export var enemy_depth_by_stage: Array[int] = [1, 2, 3]
@export var enemy_nodes_by_stage: Array[int] = [420, 2400, 6000]
@export var enemy_consistency_by_stage: Array[float] = [0.0, 1.0, 1.0]
var run = RunModel.new()
var profile_path: String = RunModel.SAVE_PATH
var screen: String = "menu"
var root: Control
var content: HBoxContainer
var sidebar: VBoxContainer
var board: BoardView
var encounter: Dictionary = {}
var battle: Battle
var positions: Dictionary = {}
var selected_owned: int = -1
var selected_piece: int = -1
var selected_modifier: String = "reposition"
var shop_target: int = -1
var event_log: Array = []
var points: int = 0
var settled: bool = false
var threats_on: bool = false
var bot_thread: Thread
var think_at: int = 0
var seed_input: LineEdit
var status_message: String = ""
var menu_seed: String = ""
var menu_panel: String = ""
var menu_motion: bool = true
var menu_skill_selection: String = ""

func _ready() -> void:
	_build_theme()
	run.load_meta(profile_path)
	show_screen()

func _exit_tree() -> void:
	if bot_thread != null and bot_thread.is_started():
		bot_thread.wait_to_finish()

func _process(_delta: float) -> void:
	if screen != "battle" or battle == null or battle.result != "" or battle.side != 1:
		return
	if bot_thread != null:
		if not bot_thread.is_alive():
			var action: Dictionary = bot_thread.wait_to_finish()
			bot_thread = null
			if not action.is_empty():
				_take_action(action)
		return
	if Time.get_ticks_msec() < think_at:
		return
	var snapshot = battle.copy()
	var depth = enemy_depth_by_stage[mini(run.stage, enemy_depth_by_stage.size() - 1)] if not enemy_depth_by_stage.is_empty() else 2
	var options = {
		"max_nodes": enemy_nodes_by_stage[mini(run.stage, enemy_nodes_by_stage.size() - 1)] if not enemy_nodes_by_stage.is_empty() else Bot.MAX_NODES,
		"consistency": enemy_consistency_by_stage[mini(run.stage, enemy_consistency_by_stage.size() - 1)] if not enemy_consistency_by_stage.is_empty() else 1.0,
	}
	var seed_value = run.run_seed + battle.turns * 31 + (7 if battle.phase == "bonus" else 0)
	bot_thread = Thread.new()
	bot_thread.start(func(): return Bot.new().choose(snapshot, depth, seed_value, options))

func _style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _build_theme() -> void:
	var t = Theme.new()
	var pixel_font = preload("res://pixelfont.ttf")
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	t.default_font = pixel_font
	t.default_font_size = 16
	t.set_color("font_color", "Label", Color("e9e4d8"))
	t.set_color("font_color", "Button", Color("e9e4d8"))
	t.set_color("font_disabled_color", "Button", Color("68797c"))
	t.set_stylebox("normal", "Button", _style(Color("283c42"), Color("42565a")))
	t.set_stylebox("hover", "Button", _style(Color("39565b"), Color("a9c6bb")))
	t.set_stylebox("pressed", "Button", _style(Color("4a6865"), Color("d6b272")))
	t.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, Color("d6b272")))
	t.set_stylebox("disabled", "Button", _style(Color("1c2b30")))
	t.set_stylebox("panel", "PanelContainer", _style(Color("192b31"), Color("30434a"), 14))
	t.set_stylebox("normal", "LineEdit", _style(Color("132329"), Color("42565a")))
	t.set_color("font_color", "LineEdit", Color("e9e4d8"))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 18)
	theme = t
	var background = ColorRect.new()
	background.color = Color("101e24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func label(text: String, size_value: int = 16, muted: bool = false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_value)
	if muted:
		l.add_theme_color_override("font_color", Color("9caeb0"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button(text: String, fn: Callable, disabled: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.disabled = disabled
	b.custom_minimum_size.y = 44
	b.pressed.connect(fn)
	return b

func panel_box(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box = VBoxContainer.new()
	panel.add_child(box)
	return box

func show_screen() -> void:
	if root != null:
		remove_child(root)
		root.queue_free()
	if screen == "menu":
		_menu()
		return
	root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 32
	root.offset_right = -32
	root.offset_top = 24
	root.offset_bottom = -24
	add_child(root)
	var header = HBoxContainer.new()
	root.add_child(header)
	var brand = label("SCHACH / 2", 24)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	header.add_child(label("A CHESS ROGUELITE  ·  PROTOTYPE", 12, true))
	if screen != "menu":
		header.add_child(label("%d GOLD   /   %d POINTS" % [run.currency, run.earned], 15))
	for item in header.get_children():
		item.autowrap_mode = TextServer.AUTOWRAP_OFF
	var names = {"menu": "Build your next gambit.", "starter": "Choose your opening edge.", "deploy": "Arrange your army.", "battle": "Make every move count.", "reward": "Position won.", "shop": "Invest in the next battle.", "choices": "Choose your next opponent.", "results": "Run complete."}
	root.add_child(label(names[screen], 32))
	var subtitle = "Preserve your best pieces. Make the others count."
	if screen in ["deploy", "battle"]:
		subtitle = "BATTLE %d / 3   ·   %s   ·   %d × %d BOARD" % [run.stage + 1, encounter.title, encounter.width, encounter.height]
	elif screen not in ["menu", "results"]:
		subtitle = "STARTER  →  DEPLOY  →  BATTLE  →  SHOP  →  CHOOSE  ·  Run seed %d" % run.run_seed
	root.add_child(label(subtitle, 14, true))
	content = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	match screen:
		"menu": _menu()
		"starter": _starter()
		"deploy": _deployment()
		"battle": _battle_screen()
		"reward": _reward()
		"shop": _shop()
		"choices": _choices()
		"results": _results()
	var foot = HBoxContainer.new()
	root.add_child(foot)
	var note = label(status_message if status_message != "" else "K King   Q Queen   R Rook   B Bishop   N Knight   P Pawn     /     Cream circles: yours · Coral diamonds: enemy", 12, true)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(note)
	if run.save_error != "":
		foot.add_child(button("Retry saving", func(): run.save_meta(profile_path); show_screen()))
		foot.add_child(label(run.save_error, 12))

func _menu() -> void:
	var title_view = TitleScreen.new()
	root = title_view
	add_child(root)
	title_view.motion_enabled = menu_motion
	title_view.new_run_requested.connect(_new_run)
	title_view.upgrades_requested.connect(func(): menu_panel = "upgrades"; _menu_upgrades())
	title_view.settings_requested.connect(func(): menu_panel = "settings"; _menu_settings())
	title_view.panel_closed.connect(func(): menu_panel = "")
	if menu_panel == "upgrades":
		_menu_upgrades()
	elif menu_panel == "settings":
		_menu_settings()
	if run.save_error != "":
		title_view.footer.text = run.save_error + "  /  Retry saving in Settings"
		_menu_save_error()

func _menu_upgrades() -> void:
	var view = UpgradeScreen.new()
	view.motion_enabled = menu_motion
	view.profile = run.meta.duplicate(true)
	view.save_error = run.save_error
	view.selected_skill = menu_skill_selection
	view.selection_changed.connect(func(key: String): menu_skill_selection = key)
	view.unlock_requested.connect(func(key: String):
		run.unlock(key, profile_path)
		root.footer.text = "" if run.save_error == "" else run.save_error + "  /  Retry saving in Settings"
		view.refresh_profile(run.meta, run.save_error))
	view.back_requested.connect(root.close_panel)
	root.open_fullscreen_panel(view)

func _menu_settings() -> void:
	var box: VBoxContainer = root.open_panel("Settings")
	if run.save_error != "":
		box.add_child(label(run.save_error, 14))
		box.add_child(button("Retry saving", func(): run.save_meta(profile_path); show_screen()))
	box.add_child(label("SCENERY", 13, true))
	var motion := CheckButton.new()
	motion.text = "Animated water and clouds"
	motion.button_pressed = menu_motion
	motion.toggled.connect(func(enabled: bool):
		menu_motion = enabled
		root.motion_enabled = enabled)
	box.add_child(motion)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(fullscreen)
	box.add_child(label("RUN SEED", 13, true))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Leave blank for a new run"
	seed_input.text = menu_seed
	seed_input.text_changed.connect(func(value): menu_seed = value)
	box.add_child(seed_input)
	box.add_child(label("Enter a number to replay the same encounters and shops. Settings apply for this session.", 14, true))
	box.add_child(label("HOW TO PLAY", 13, true))
	box.add_child(label("Choose a starting modifier, then deploy every piece in the bottom two rows. Click a piece and a highlighted square to move.\n\nComplete each board's objective before your moves run out. Captures kill instantly. There is no check or checkmate.\n\nVictory restores your army. Spend gold between battles. EXP and unlocked skills survive defeat.", 16))

func _menu_save_error() -> void:
	var box: VBoxContainer = root.open_panel("Player profile")
	box.add_child(label(run.save_error, 16))
	box.add_child(button("Retry saving", func(): run.save_meta(profile_path); show_screen()))

func _new_run() -> void:
	menu_panel = ""
	var seed_value = int(menu_seed) if menu_seed.is_valid_int() else int(Time.get_unix_time_from_system())
	run.start(seed_value)
	selected_modifier = "reposition"
	selected_owned = run.roster[4].id
	screen = "starter"
	status_message = ""
	show_screen()

func _starter() -> void:
	var left = panel_box(content)
	left.add_child(label("ONE MODIFIER", 13, true))
	for key in Catalog.MODIFIERS:
		left.add_child(button(("● " if key == selected_modifier else "○ ") + key.capitalize(), func(): selected_modifier = key; show_screen()))
		left.add_child(label(Catalog.DESCRIPTIONS[key], 14, true))
	var right = panel_box(content)
	right.add_child(label("ATTACH TO A PIECE", 13, true))
	_roster_buttons(right, selected_owned, func(id): selected_owned = id; show_screen())
	right.add_child(label("Each piece can hold one modifier. This choice lasts for the run.", 14, true))
	right.add_child(button("Preview first battle →", func():
		for p in run.roster:
			if p.id == selected_owned:
				p.modifier = selected_modifier
		_prepare_deploy(Generator.generate(0, 0, run.run_seed))))

func _roster_buttons(parent: VBoxContainer, chosen: int, fn: Callable) -> void:
	for p in run.roster:
		var text = ("● " if chosen == p.id else "") + Catalog.SYMBOLS[p.type] + "  " + p.type.capitalize()
		if p.modifier != "":
			text += "  /  " + p.modifier.capitalize()
		parent.add_child(button(text, fn.bind(p.id)))

func _prepare_deploy(e: Dictionary) -> void:
	encounter = e
	positions = {}
	for i in range(run.roster.size()):
		positions[run.roster[i].id] = Vector2i(i % e.width, e.height - 1 - i / e.width)
	selected_owned = run.roster[0].id
	selected_piece = -1
	event_log = []
	settled = false
	screen = "deploy"
	status_message = "Select a piece, then a square in the bottom two rows. Clicking an occupied square swaps the pieces."
	show_screen()

func _board_panel(model: Battle, selection: int = -1, moves: Array = [], placing: bool = false) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.5
	content.add_child(panel)
	board = Board.new()
	board.custom_minimum_size = Vector2(480, 480)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.show_threats = threats_on
	panel.add_child(board)
	board.set_state(model, selection, moves, placing)
	board.cell_clicked.connect(_cell_clicked)
	var right = PanelContainer.new()
	right.custom_minimum_size.x = 340
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar)

func _objective_panel() -> void:
	sidebar.add_child(label("OBJECTIVE", 12, true))
	sidebar.add_child(label(Generator.objective_text(encounter), 23))
	sidebar.add_child(label("Bonus +30 points · " + Generator.bonus_text(encounter), 14, true))

func _deployment() -> void:
	var preview = Generator.make_battle(encounter, run.roster, positions)
	var selection = -1
	if positions.has(selected_owned):
		selection = preview.at(positions[selected_owned])
	_board_panel(preview, selection, [], true)
	_objective_panel()
	sidebar.add_child(label("%d player moves available" % encounter.budget, 18))
	sidebar.add_child(label("DEPLOY YOUR ROSTER", 12, true))
	_roster_buttons(sidebar, selected_owned, func(id): selected_owned = id; show_screen())
	var valid = _deployment_valid()
	sidebar.add_child(button("Begin battle →", _begin_battle, not valid))
	sidebar.add_child(label("Enemy modifiers: " + _enemy_modifier_text(encounter), 13, true))

func _deployment_valid() -> bool:
	var used: Array = []
	for p in run.roster:
		if not positions.has(p.id):
			return false
		var pos: Vector2i = positions[p.id]
		if pos.x < 0 or pos.x >= encounter.width or pos.y < encounter.height - 2 or pos.y >= encounter.height or used.has(pos):
			return false
		used.append(pos)
	return true

func _begin_battle() -> void:
	if not _deployment_valid():
		return
	battle = Generator.make_battle(encounter, run.roster, positions)
	battle.begin()
	event_log = []
	screen = "battle"
	status_message = "Click one of your pieces to see its legal moves. Hover a piece to inspect its modifier."
	selected_piece = -1
	if battle.result != "":
		_settle()
	else:
		show_screen()

func _battle_screen() -> void:
	var moves: Array = []
	if battle.side == 0:
		moves = battle.destinations(battle.bonus_id, true) if battle.phase == "bonus" else battle.destinations(selected_piece)
	_board_panel(battle, battle.bonus_id if battle.phase == "bonus" else selected_piece, moves)
	_objective_panel()
	sidebar.add_child(label("%d / %d MOVES" % [battle.turns, battle.budget], 26))
	sidebar.add_child(label("Your reposition" if battle.side == 0 and battle.phase == "bonus" else ("Your turn" if battle.side == 0 else "Enemy is thinking…"), 20))
	if battle.side == 0 and battle.phase == "bonus":
		sidebar.add_child(button("Skip reposition →", func(): _take_action({"kind": "skip"})))
	if selected_piece != -1 and battle.pieces.has(selected_piece):
		var p: Dictionary = battle.pieces[selected_piece]
		sidebar.add_child(label("%s · %d/2 HP" % [p.type.capitalize(), p.hp], 18))
		if p.modifier != "":
			sidebar.add_child(label(Catalog.DESCRIPTIONS[p.modifier], 14, true))
	sidebar.add_child(button("Hide threat hints" if threats_on else "Show threat hints", func(): threats_on = not threats_on; show_screen()))
	if threats_on:
		sidebar.add_child(label("Red edges show enemy legal destinations. Pawn hints include only currently available captures.", 12, true))
	sidebar.add_child(label("BATTLE LOG", 12, true))
	for message in event_log.slice(maxi(0, event_log.size() - 6)):
		sidebar.add_child(label(message, 13, true))
	sidebar.add_child(button("Resign this run", _resign, battle.side != 0))

func _cell_clicked(pos: Vector2i) -> void:
	if screen == "deploy":
		if pos.y < encounter.height - 2 or selected_owned == -1:
			return
		var old: Vector2i = positions[selected_owned]
		for id in positions:
			if positions[id] == pos and id != selected_owned:
				positions[id] = old
				break
		positions[selected_owned] = pos
		show_screen()
	elif screen == "battle" and battle.side == 0:
		if battle.phase == "bonus":
			var action = {"kind": "reposition", "id": battle.bonus_id, "to": pos}
			if battle.legal_actions().has(action):
				_take_action(action)
			return
		var id = battle.at(pos)
		if id != -1 and battle.pieces[id].side == 0:
			selected_piece = id
			show_screen()
		elif selected_piece != -1:
			var action = {"kind": "move", "id": selected_piece, "to": pos}
			if battle.legal_actions().has(action):
				_take_action(action)

func _take_action(action: Dictionary) -> void:
	var output = battle.apply(action)
	for event in output:
		event_log.append(event.text)
	selected_piece = -1
	think_at = Time.get_ticks_msec() + 350
	if battle.result != "":
		_settle()
	else:
		show_screen()

func _resign() -> void:
	battle.result = "loss"
	battle.reason = "Run resigned."
	_settle()

func _settle() -> void:
	if settled:
		return
	settled = true
	points = run.record_battle(battle)
	status_message = ""
	if battle.result == "loss" or run.stage == 2:
		run.finish(battle.result == "win", profile_path)
		screen = "results"
	else:
		screen = "reward"
	show_screen()

func _reward() -> void:
	var left = panel_box(content)
	left.add_child(label("OBJECTIVE COMPLETE", 13, true))
	left.add_child(label("+%d points / gold" % points, 42))
	left.add_child(label("100 victory + %d unused-move points + %d bonus points" % [5 * (battle.budget - battle.turns), 30 if battle.bonus_complete() else 0], 17))
	left.add_child(label("%d moves used · %d captures · %d owned pawns lost" % [battle.turns, battle.captures, battle.owned_pawns_lost], 17, true))
	left.add_child(label("Your owned army returns at full health. Temporary pawns and board effects are cleared.", 18))
	left.add_child(button("Visit the shop →", func():
		run.stage += 1
		run.open_shop()
		shop_target = -1
		screen = "shop"
		show_screen()))
	var right = panel_box(content)
	right.add_child(label("YOUR BUILD", 13, true))
	for p in run.roster:
		right.add_child(label(p.type.capitalize() + (" / " + p.modifier.capitalize() if p.modifier != "" else ""), 20))

func _shop() -> void:
	var left = panel_box(content)
	left.add_child(label("%d GOLD AVAILABLE" % run.currency, 23))
	for i in range(run.shop.size()):
		var item: Dictionary = run.shop[i]
		left.add_child(label(item.key.capitalize() + (" modifier" if item.kind == "modifier" else " piece"), 21))
		left.add_child(label(Catalog.DESCRIPTIONS[item.key] if item.kind == "modifier" else "Add an unmodified piece to your owned army.", 14, true))
		var error = run.purchase_error(i, shop_target)
		left.add_child(button("Purchased" if item.bought else "Buy · %d gold%s" % [item.price, " · " + error if error != "" else ""], func(): run.purchase(i, shop_target); show_screen(), error != ""))
	left.add_child(button("Free reroll" if not run.rerolled else "Reroll used", func(): run.reroll(); show_screen(), run.rerolled or not run.active_unlocks.has("reroll")))
	left.add_child(button("Choose next board →", func(): screen = "choices"; show_screen()))
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right_panel)
	var scroll = ScrollContainer.new()
	right_panel.add_child(scroll)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	right.add_child(label("SELECT A MODIFIER RECIPIENT", 13, true))
	_roster_buttons(right, shop_target, func(id): shop_target = id; show_screen())
	right.add_child(label("%d / 12 deployment slots\nLimits: 1 king, 1 queen, 2 rooks, %d bishops, 2 knights. One modifier per piece." % [run.roster.size(), run.limits().bishop], 14, true))

func _enemy_modifier_text(e: Dictionary) -> String:
	var names: Array = []
	for p in e.enemies:
		if p.modifier != "":
			names.append(p.type.capitalize() + " / " + p.modifier.capitalize())
	return ", ".join(names) if not names.is_empty() else "none"

func _choices() -> void:
	for e in run.choices():
		var box = panel_box(content)
		box.add_child(label(e.title, 21))
		var preview = Board.new()
		preview.compact = true
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.custom_minimum_size = Vector2(220, 255)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(preview)
		var model = Generator.make_battle(e, [], {})
		preview.set_state(model)
		box.add_child(label(Generator.objective_text(e), 19))
		box.add_child(label("%d × %d · %d moves\nBonus: %s\nEnemy modifiers: %s" % [e.width, e.height, e.budget, Generator.bonus_text(e), _enemy_modifier_text(e)], 14, true))
		box.add_child(button("Choose this board →", _prepare_deploy.bind(e)))

func _results() -> void:
	var left = panel_box(content)
	var victory = battle.result == "win"
	left.add_child(label("THREE BOARDS CONQUERED" if victory else "THE RUN ENDS HERE", 13, true))
	left.add_child(label("Victory." if victory else "Defeat.", 52))
	left.add_child(label(battle.reason, 20, true))
	left.add_child(label("%d total points" % run.earned, 32))
	left.add_child(label("%d / 3 battles won\n%d player moves\n%d enemy pieces captured\n%d owned pawns lost\n%d temporary pawns lost" % [run.won, run.total_moves, run.total_captures, run.pawns_lost, run.temp_pawns_lost], 21))
	left.add_child(label("Run seed %d" % run.run_seed, 14, true))
	var right = panel_box(content)
	right.add_child(label("+%d EXP" % run.exp_awarded, 42))
	right.add_child(label("%d EXP available for permanent skills" % run.meta.exp, 19))
	right.add_child(label("The army and gold reset. Your skill tree remains.\n\nTry a different starter modifier or a different deployment to change the next run.", 17, true))
	right.add_child(button("Return to skill tree →", func(): screen = "menu"; menu_panel = "upgrades"; status_message = ""; show_screen()))
