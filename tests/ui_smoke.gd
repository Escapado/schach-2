extends SceneTree

const Scene = preload("res://main.tscn")
const Bot = preload("res://scripts/core/bot.gd")
const Generator = preload("res://scripts/core/encounters.gd")
const RunModel = preload("res://scripts/core/run.gd")
const PROFILE = "/tmp/schach2-ui-progress.json"
var game
var failures: int = 0
var checks: int = 0
var screenshots: bool = false

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found = find_button(child, prefix)
		if found != null:
			return found
	return null

func press(prefix: String) -> void:
	var b = find_button(game.root, prefix)
	expect(b != null and not b.disabled, "button available: " + prefix)
	if b != null and not b.disabled:
		b.pressed.emit()
	await process_frame

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	if screenshots:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/schach2-" + name_value + ".png")

func changed_pixels(before: Image, after: Image, region: Rect2) -> int:
	var origin := Vector2i(region.position * Vector2(before.get_size()))
	var end := Vector2i(region.end * Vector2(before.get_size()))
	var changed := 0
	for y in range(origin.y, end.y):
		for x in range(origin.x, end.x):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			# Ignore one-channel quantization noise in GPU compositing.
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.01:
				changed += 1
	return changed

func freeze_scenery_at(view, time_value: float) -> void:
	view.motion_enabled = true
	view.elapsed = time_value
	view._process(0.0)
	view.motion_enabled = false

func player_action(b: Battle) -> Dictionary:
	var options = Bot.new()._successors(b)
	options.sort_custom(func(a, c): return a.score < c.score)
	var best: Dictionary = options[0].action
	var best_value = INF
	for option in options.slice(0, 12):
		var value: float = option.score
		var after: Battle = option.state
		if after.side == 1 and after.result == "":
			var replies = Bot.new()._successors(after)
			value = -INF if not replies.is_empty() else value
			for reply in replies:
				value = maxf(value, reply.score)
		if value < best_value:
			best_value = value
			best = option.action
	return best

# Controlled, legal formations keep UI regression tests independent of AI strength.
# Generation validity and unmodified seeded games are covered by test_runner.gd.
func prepare_fixture(stage: int) -> void:
	var e = Generator.fallback(stage, 0)
	var target_pos = Vector2i.ZERO
	for p in e.enemies:
		if p.target:
			target_pos = p.pos
	for p in e.enemies:
		if p.target:
			p.pos = Vector2i(1, 0)
		elif p.pos == Vector2i(1, 0):
			p.pos = target_pos
	e.title = "UI regression formation"
	game._prepare_deploy(e)

func click_board(pos: Vector2i) -> void:
	var view = game.board
	var geometry = view.geometry()
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = geometry.origin + (Vector2(pos) + Vector2(0.5, 0.5)) * geometry.cell
	view._gui_input(event)

func _run() -> void:
	if OS.get_cmdline_user_args().has("--small"):
		DisplayServer.window_set_size(Vector2i(1120, 820))
	screenshots = DisplayServer.get_name() != "headless"
	DirAccess.remove_absolute(PROFILE)
	game = Scene.instantiate()
	game.profile_path = PROFILE
	root.add_child(game)
	await capture("menu")
	var title_view = game.root
	var speed_pattern := RegEx.create_from_string("CLOUD_DRIFT_SPEED\\s*=\\s*([0-9.]+)")
	var speed_match := speed_pattern.search(FileAccess.get_file_as_string("res://shaders/title_cloud_motion.gdshaderinc"))
	expect(speed_match != null, "cloud speed configuration is readable")
	var cloud_speed: float = speed_match.get_string(1).to_float() if speed_match != null else 1.0
	expect(title_view.landscape.material.get_shader_parameter("water_mask_texture").resource_path == "res://assets/title/landscape_mask.png", "painted water mask is bound")
	expect(title_view.landscape.texture.get_size() == title_view.landscape.material.get_shader_parameter("water_mask_texture").get_size(), "water mask aligns with landscape dimensions")
	expect(is_equal_approx(title_view.clouds.size.x / title_view.clouds.size.y, float(title_view.clouds.texture.get_width()) / title_view.clouds.texture.get_height()), "cloud layer preserves edited aspect ratio")
	expect(title_view.footer.text == "", "title screen has no footer tagline")
	expect(title_view.title.texture.resource_path == "res://assets/title/logo.png", "title uses supplied logo")
	expect(title_view.new_run_button.icon_kind == "diamond" and title_view.upgrades_button.icon_kind == "crown", "menu buttons have pixel icons")
	title_view._process(18.0)
	await capture("menu-motion")
	if screenshots:
		var before := Image.load_from_file("/tmp/schach2-menu.png")
		var after := Image.load_from_file("/tmp/schach2-menu-motion.png")
		expect(changed_pixels(before, after, Rect2(0.4, 0.02, 0.12, 0.12)) > 0, "rendered clouds drift")
		expect(changed_pixels(before, after, Rect2(0.05, 0.64, 0.25, 0.07)) > 0, "rendered water ripples")
		expect(changed_pixels(before, after, Rect2(0.71, 0.28, 0.025, 0.035)) == 0, "mountain pixels remain fixed")
		expect(changed_pixels(before, after, Rect2(0.65, 0.75, 0.12, 0.08)) == 0, "terrace pixels remain fixed")
		title_view.motion_enabled = false
		await capture("menu-reflection")
		var reflected := Image.load_from_file("/tmp/schach2-menu-reflection.png")
		var clear := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		clear.fill(Color.TRANSPARENT)
		title_view.landscape.material.set_shader_parameter("cloud_layer", ImageTexture.create_from_image(clear))
		await capture("menu-no-reflection")
		var unreflected := Image.load_from_file("/tmp/schach2-menu-no-reflection.png")
		expect(changed_pixels(reflected, unreflected, Rect2(0.40, 0.54, 0.12, 0.12)) > 0, "water reflection responds to actual cloud texture")
		expect(changed_pixels(reflected, unreflected, Rect2(0.4, 0.02, 0.12, 0.12)) == 0, "reflection texture change leaves sky alone")
		title_view.landscape.material.set_shader_parameter("cloud_layer", title_view.clouds.texture)
		title_view.landscape.material.set_shader_parameter("water_mask_texture", ImageTexture.create_from_image(clear))
		await capture("menu-no-water-mask")
		var unmasked := Image.load_from_file("/tmp/schach2-menu-no-water-mask.png")
		expect(changed_pixels(reflected, unmasked, Rect2(0.40, 0.54, 0.12, 0.12)) > 0, "painted mask controls water effects")
		expect(changed_pixels(reflected, unmasked, Rect2(0.65, 0.75, 0.12, 0.08)) == 0, "painted black terrace remains unchanged")
		title_view.landscape.material.set_shader_parameter("water_mask_texture", load("res://assets/title/landscape_mask.png"))
		freeze_scenery_at(title_view, 10.0)
		await capture("cloud-substep-a")
		var substep_a := Image.load_from_file("/tmp/schach2-cloud-substep-a.png")
		freeze_scenery_at(title_view, 10.0 + 0.5 / cloud_speed)
		await capture("cloud-substep-b")
		var substep_b := Image.load_from_file("/tmp/schach2-cloud-substep-b.png")
		expect(changed_pixels(substep_a, substep_b, Rect2(0.15, 0.04, 0.55, 0.26)) > 0, "clouds move within a former one-art-pixel step")
		freeze_scenery_at(title_view, 0.0)
		await capture("cloud-loop-a")
		var loop_a := Image.load_from_file("/tmp/schach2-cloud-loop-a.png")
		freeze_scenery_at(title_view, 640.0 / cloud_speed)
		await capture("cloud-loop-b")
		var loop_b := Image.load_from_file("/tmp/schach2-cloud-loop-b.png")
		expect(changed_pixels(loop_a, loop_b, Rect2(0.15, 0.04, 0.55, 0.26)) == 0, "cloud sky repeats after one complete horizontal loop")
		title_view.motion_enabled = true
	title_view.new_run_button.grab_focus()
	await capture("menu-focus")
	title_view.new_run_button.release_focus()
	# Drive the hover signal deterministically; live OS pointer motion can otherwise
	# reset synthetic mouse input between screenshot frames.
	title_view.new_run_button.mouse_entered.emit()
	await capture("menu-hover")
	expect(title_view.new_run_button.hovered, "new run hover handler updates visual state")
	title_view.new_run_button.mouse_exited.emit()
	await press("Settings")
	expect(game.menu_panel == "settings", "settings panel opens")
	var motion = find_button(game.root, "Animated water")
	motion.button_pressed = false
	var frozen_time: float = title_view.elapsed
	await process_frame
	await process_frame
	expect(not game.menu_motion and title_view.elapsed == frozen_time, "scenery animation can be paused")
	motion.button_pressed = true
	game.seed_input.text = "7"
	game.seed_input.text_changed.emit("7")
	await capture("settings")
	await press("Back")
	expect(game.menu_panel == "" and title_view.menu.visible, "back restores title controls")
	await press("Upgrades")
	var upgrade_view = game.root.overlay
	expect(upgrade_view.nodes.size() == 28, "four skill trees include clearly marked placeholders")
	expect(upgrade_view.detail_title.text == "Select a skill to upgrade" and upgrade_view.unlock_button.disabled, "upgrade empty state keeps detail panel visible")
	await capture("upgrades")
	upgrade_view.nodes.purse.mouse_entered.emit()
	expect(upgrade_view.detail_title.text == "Deeper pockets" and upgrade_view.selected_skill == "", "hover previews a skill without selecting")
	expect(upgrade_view.unlock_button.disabled, "hover cannot unlock a skill")
	await capture("upgrades-hover")
	upgrade_view.nodes.purse.pressed.emit()
	expect(upgrade_view.selected_skill == "purse" and upgrade_view.nodes.purse.selected, "click pins and outlines a skill")
	upgrade_view.nodes.purse.mouse_exited.emit()
	upgrade_view.nodes.bishop.mouse_entered.emit()
	expect(upgrade_view.detail_title.text == "Deeper pockets", "pinned selection remains while hovering another skill")
	expect(upgrade_view.unlock_button.disabled, "insufficient EXP prevents unlocking")
	await capture("upgrades-selected")
	upgrade_view.close_button.pressed.emit()
	expect(upgrade_view.detail_title.text == "Select a skill to upgrade" and upgrade_view.selected_skill == "", "X clears the selection and restores empty state")
	upgrade_view.nodes.bishop.pressed.emit()
	expect(upgrade_view.detail_requirement.text.contains("Requires Deeper pockets") and upgrade_view.unlock_button.disabled, "cross-tree prerequisite is visible and enforced")
	upgrade_view.nodes.future_0_0.pressed.emit()
	expect(upgrade_view.unlock_button.disabled and upgrade_view.unlock_button.text == "Coming soon", "placeholder skills cannot be purchased")
	var exp_before_placeholder: int = game.run.meta.exp
	upgrade_view.unlock_button.pressed.emit()
	expect(game.run.meta.exp == exp_before_placeholder, "placeholder activation cannot spend EXP")
	await capture("upgrades-placeholder")
	upgrade_view.clear_selection()
	await press("Back")
	await press("Upgrades")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game.root.overlay._unhandled_key_input(escape)
	expect(game.menu_panel == "" and game.root.menu.visible, "Escape closes upgrade screen safely")
	await press("New Run")
	expect(game.screen == "starter", "starter screen")
	expect(game.run.run_seed == 7, "settings seed reaches new run")
	await capture("starter")
	await press("Preview first battle")
	expect(game.screen == "deploy" and game._deployment_valid(), "valid default deployment")
	# Swap two owned pieces through the same handler as a board click.
	var first: int = game.run.roster[0].id
	var second: int = game.run.roster[1].id
	var old: Vector2i = game.positions[first]
	game.selected_owned = first
	game._cell_clicked(game.positions[second])
	expect(game.positions[second] == old, "deployment swaps occupied squares")
	# Swap back for a reproducible playthrough.
	game._cell_clicked(old)
	await capture("deployment")
	await press("Begin battle")
	await capture("battle")
	# First test an actual background bot response using the normal game loop.
	var first_action = player_action(game.battle)
	var first_id: int = first_action.id
	var source: Vector2i = game.battle.pieces[first_id].pos
	click_board(source)
	expect(game.selected_piece == first_id and game.board.highlights.has(first_action.to), "board click selects piece and displays legal destinations")
	click_board(first_action.to)
	expect(game.battle.turns == 1, "board click executes ordinary move")
	if game.battle.phase == "bonus":
		game._take_action({"kind": "skip"})
	var deadline = Time.get_ticks_msec() + 10000
	while game.screen == "battle" and game.battle.side == 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(game.screen != "battle" or game.battle.side == 0, "worker-thread bot returns control")
	game.set_process(false)
	# Reset after the live worker check; use controlled formations for UI outcomes.
	game.run.start(42)
	game.run.roster[4].modifier = "reposition"
	prepare_fixture(0)
	game._begin_battle()
	# Complete the three-battle flow through public simulation actions.
	var actions = 0
	while game.screen != "results" and actions < 250:
		if game.screen == "battle":
			var action: Dictionary = player_action(game.battle) if game.battle.side == 0 else Bot.new().choose(game.battle, 1 if game.run.stage == 0 else 2, 42 + actions)
			expect(game.battle.legal_actions().has(action), "playthrough action legal")
			game._take_action(action)
			actions += 1
			await process_frame
		elif game.screen == "reward":
			print("Won battle ", game.run.stage + 1, " in ", game.battle.turns, " moves")
			await capture("reward")
			await press("Visit the shop")
			await capture("shop")
			# Buy an available item through the real shop controls and verify score.
			game.shop_target = game.run.roster[0].id
			game.show_screen()
			var earned: int = game.run.earned
			for i in range(game.run.shop.size()):
				if game.run.purchase_error(i, game.shop_target) == "":
					var item: Dictionary = game.run.shop[i]
					var amount: int = game.run.currency
					await press("Buy · %d gold" % item.price)
					expect(game.run.currency == amount - item.price and game.run.earned == earned, "shop spends currency only")
					break
			await press("Choose next board")
			await capture("choices")
			# Select the marked-knight variant, with all three options still rendered.
			prepare_fixture(game.run.stage)
			await press("Begin battle")
		else:
			expect(false, "unexpected screen in playthrough: " + game.screen)
			break
	expect(game.screen == "results", "playthrough reaches results")
	expect(game.run.won == 3, "controlled three-battle run completes")
	await capture("results")
	print("Playthrough: ", game.run.won, " wins, ", game.run.total_moves, " moves, ", game.run.earned, " points")
	var earned_exp: int = game.run.meta.exp
	expect(earned_exp >= 30, "finished run earns enough EXP for root")
	await press("Return to skill tree")
	await press("Deeper pockets")
	expect(not game.root.overlay.unlock_button.disabled, "earned EXP enables selected eligible upgrade")
	await capture("upgrades-can-unlock")
	var exp_before_failed_save: int = game.run.meta.exp
	# PROFILE is an existing test file, so it cannot also be a parent directory.
	game.profile_path = PROFILE + "/blocked.json"
	await press("Unlock · 30 EXP")
	expect(not game.run.meta.unlocks.has("purse") and game.run.meta.exp == exp_before_failed_save, "failed upgrade save rolls back EXP and unlock")
	expect(game.root.overlay.selected_skill == "purse" and game.root.overlay.detail_error.visible, "save error remains visible with selection and retry intact")
	await capture("upgrades-save-error")
	game.profile_path = PROFILE
	await press("Unlock · 30 EXP")
	expect(game.run.meta.unlocks.has("purse"), "skill unlock through UI")
	expect(game.root.overlay.selected_skill == "purse" and game.root.overlay.nodes.purse.node_state == "unlocked", "unlock keeps selection and updates node state")
	expect(game.root.overlay.nodes.bishop.node_state == "available" and game.root.overlay.nodes.reroll.node_state == "available", "unlock refreshes dependent skills in both trees")
	expect(not game.root.overlay.detail_error.visible, "successful retry clears upgrade save error")
	await capture("upgrades-unlocked")
	game.queue_free()
	await process_frame
	game = Scene.instantiate()
	game.profile_path = PROFILE
	root.add_child(game)
	await process_frame
	expect(game.run.meta.unlocks.has("purse") and game.run.meta.exp == earned_exp - 30, "new game instance loads saved progression")
	await press("New Run")
	expect(game.run.currency == 70, "unlocked starting currency applied")
	await press("Preview first battle")
	await press("Begin battle")
	game.set_process(false)
	await press("Resign this run")
	expect(game.screen == "results" and game.battle.result == "loss" and game.run.finished, "loss flow ends run")
	await capture("defeat")
	# A save with the branch unlock also reloads across a new model instance.
	var reload_model = RunModel.new()
	reload_model.load_meta(PROFILE)
	expect(reload_model.meta.unlocks.has("purse"), "loss does not clear permanent skills")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(PROFILE)
	print("UI smoke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
