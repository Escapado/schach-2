extends Control
## Presentation only. GameRun remains the authority for prices, prerequisites and saves.

signal back_requested
signal unlock_requested(key: String)
signal selection_changed(key: String)

const SkillNode = preload("res://scripts/ui/skill_node.gd")
const PixelButton = preload("res://scripts/ui/pixel_menu_button.gd")
const FONT = preload("res://pixelfont.ttf")
const RunModel = preload("res://scripts/core/run.gd")
const BACKGROUND = preload("res://assets/upgrades/background.png")
const WATER_MASK = preload("res://assets/upgrades/upgrades_mask.png")
const WATER_SHADER = preload("res://shaders/title_water.gdshader")
const CATEGORIES := ["Sacrifice", "Command", "Fortune", "Resilience"]
const CATEGORY_ICONS := ["flame", "rook", "clover", "shield"]
const NODE_POSITIONS := [Vector2(0.5, 0.04), Vector2(0.21, 0.24), Vector2(0.79, 0.24), Vector2(0.5, 0.46), Vector2(0.20, 0.66), Vector2(0.80, 0.66), Vector2(0.5, 0.88)]
const LIVE_SKILLS := {
	"purse": {"title": "Deeper pockets", "description": "Start each new run with 20 extra gold.", "category": 2, "icon": "coins"},
	"reroll": {"title": "Second look", "description": "Reroll the shop once per visit, for free.", "category": 2, "icon": "reroll"},
	"bishop": {"title": "Bishop's company", "description": "Raise your bishop roster limit from two to three.", "category": 1, "icon": "bishop"},
}
var profile: Dictionary = {"exp": 0, "unlocks": []}
var save_error := ""
var selected_skill := ""
var hovered_skill := ""
var skills: Dictionary = {}
var nodes: Dictionary = {}
var category_keys: Array = []
var layers: Array[TextureRect] = []
var background: TextureRect
var motion_enabled := true
var elapsed := 0.0
var graph: Control
var category_labels: Array[Label] = []
var category_icons: Array[Control] = []
var back_button: Button
var exp_badge: Label
var progress_badge: Label
var detail: PanelContainer
var detail_frame: Control
var close_button: Button
var detail_icon: Control
var detail_title: Label
var detail_category: Label
var detail_description: Label
var detail_stats: Label
var detail_requirement: Label
var detail_error: Label
var unlock_button: Button
var legend: HBoxContainer
var legend_panel: PanelContainer
var tree_rect: Rect2

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_catalog()
	_build_layers()
	_build_header()
	graph = Control.new()
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.draw.connect(_draw_connections)
	add_child(graph)
	for category in range(4):
		var heading := _label(CATEGORIES[category], 20)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(heading)
		category_labels.append(heading)
		var emblem := Control.new()
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.draw.connect(func() -> void: SkillNode.draw_icon(emblem, CATEGORY_ICONS[category], emblem.size / 2, 3, Color("#e7d9b0")))
		add_child(emblem)
		category_icons.append(emblem)
		for key in category_keys[category]:
			var node := SkillNode.new()
			node.text = skills[key].title
			node.name = key
			node.icon_kind = skills[key].icon
			node.diamond = nodes.size() % 3 != 2
			node.tooltip_text = skills[key].title
			node.mouse_entered.connect(_hover.bind(key))
			node.mouse_exited.connect(_leave.bind(key))
			node.focus_entered.connect(_hover.bind(key))
			node.focus_exited.connect(_leave.bind(key))
			node.pressed.connect(select_skill.bind(key))
			graph.add_child(node)
			nodes[key] = node
	_build_detail()
	_build_footer()
	resized.connect(_layout)
	_layout()
	refresh_profile(profile, save_error)
	back_button.grab_focus()

func _build_catalog() -> void:
	var titles := [
		["Willing sacrifice", "Lasting legacy", "Second breath", "Blood price", "Afterlife", "Fallen crown", "Final gambit"],
		["Bishop's company", "Cavalry", "United front", "Royal decree", "Vanguard", "Castle guard", "Grand command"],
		["Deeper pockets", "Second look", "Lucky find", "Windfall", "Fate's favor", "Golden touch", "Fortune's favor"],
		["Iron will", "Renewal", "Borrowed time", "Safe haven", "Endurance", "Last stand", "Unbroken"],
	]
	var icons := [
		["flame", "crown", "heart", "sword", "bishop", "crown", "star"],
		["bishop", "knight", "rook", "crown", "knight", "shield", "rook"],
		["coins", "reroll", "dice", "coins", "star", "clover", "star"],
		["shield", "cross", "reroll", "heart", "shield", "rook", "crown"],
	]
	for category in range(4):
		var keys: Array[String] = []
		for index in range(7):
			var key := "future_%d_%d" % [category, index]
			if category == 1 and index == 0:
				key = "bishop"
			elif category == 2 and index == 0:
				key = "purse"
			elif category == 2 and index == 1:
				key = "reroll"
			var data := {"title": titles[category][index], "category": category, "icon": icons[category][index], "implemented": LIVE_SKILLS.has(key)}
			if LIVE_SKILLS.has(key):
				data.merge(LIVE_SKILLS[key], true)
			else:
				data.description = "A future %s skill.\n\nNot implemented in this prototype." % CATEGORIES[category].to_lower()
			skills[key] = data
			keys.append(key)
		category_keys.append(keys)

func _build_layers() -> void:
	background = _add_layer(BACKGROUND)
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("water_mask_texture", WATER_MASK)
	material.set_shader_parameter("cloud_reflections_enabled", false)
	background.material = material

func _process(delta: float) -> void:
	if motion_enabled:
		elapsed += delta
		background.material.set_shader_parameter("elapsed", elapsed)

func _add_layer(texture: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	layers.append(layer)
	return layer

func _label(value: String, font_size: int, color: Color = Color("#f0e4c4")) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color("#091b2c"))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 2)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(value: String, icon: String, primary: bool = false) -> Button:
	var result := PixelButton.new()
	result.text = value
	result.icon_kind = icon
	result.primary = primary
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", 18)
	return result

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102439f5")
	style.border_color = Color("#d6c7a3")
	style.set_border_width_all(2)
	style.shadow_color = Color("#081522b0")
	style.shadow_size = 6
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style

func _badge(value: String) -> Label:
	var label := _label(value, 19)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var style := _panel_style()
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", style)
	add_child(label)
	return label

func _build_header() -> void:
	back_button = _button("Back", "exit")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)
	exp_badge = _badge("")
	progress_badge = _badge("")

func _build_detail() -> void:
	detail = PanelContainer.new()
	detail.add_theme_stylebox_override("panel", _panel_style())
	add_child(detail)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	detail.add_child(body)
	detail_category = _label("", 13, Color("#a8bac5"))
	body.add_child(detail_category)
	detail_icon = Control.new()
	detail_icon.custom_minimum_size.y = 104
	detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_icon.draw.connect(_draw_detail_icon)
	body.add_child(detail_icon)
	detail_title = _label("", 24)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(detail_title)
	var separator := HSeparator.new()
	body.add_child(separator)
	detail_description = _label("", 17)
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(detail_description)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	detail_stats = _label("", 16)
	body.add_child(detail_stats)
	detail_requirement = _label("", 14, Color("#b6c6ce"))
	detail_requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail_requirement)
	detail_error = _label("", 13, Color("#f3ac9c"))
	detail_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail_error)
	unlock_button = _button("Select a skill", "diamond", true)
	unlock_button.custom_minimum_size.y = 62
	unlock_button.pressed.connect(_request_unlock)
	body.add_child(unlock_button)
	detail_frame = Control.new()
	detail_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_frame.draw.connect(_draw_detail_frame)
	add_child(detail_frame)
	close_button = Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Clear selection"
	close_button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT if state == "normal" else Color("#294758")
		style.border_color = Color("#b5bba7")
		style.set_border_width_all(0 if state == "normal" else 1)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		close_button.add_theme_stylebox_override(state, style)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(clear_selection)
	add_child(close_button)

func _build_footer() -> void:
	legend = HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 20)
	var labels := ["Unlocked", "Available", "Locked", "Coming soon"]
	var colors := [Color("#63efd6"), Color("#f2d182"), Color("#a3a9b3"), Color("#7e8a9c")]
	for index in range(labels.size()):
		legend.add_child(_label("◇ " + labels[index], 14, colors[index]))
	legend_panel = PanelContainer.new()
	var style := _panel_style()
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	legend_panel.add_theme_stylebox_override("panel", style)
	legend_panel.add_child(legend)
	add_child(legend_panel)
	legend_panel.minimum_size_changed.connect(_layout)

func _layout() -> void:
	if not is_instance_valid(graph):
		return
	var cover_scale := maxf(size.x / BACKGROUND.get_width(), size.y / BACKGROUND.get_height())
	var cover_size := Vector2(BACKGROUND.get_size()) * cover_scale
	for layer in layers:
		layer.size = cover_size
		layer.position = (size - cover_size) / 2
	var cover_origin := (size - cover_size) / 2
	var detail_width := 338.0
	# Keep the trees inside the painted stone, using the artwork's coordinates.
	var tree_origin := cover_origin + Vector2(270, 275) * cover_scale
	var tree_right := minf(cover_origin.x + 1090 * cover_scale, size.x - detail_width - 60)
	tree_rect = Rect2(tree_origin, Vector2(tree_right - tree_origin.x, 350 * cover_scale))
	graph.position = tree_rect.position
	graph.size = tree_rect.size
	back_button.position = Vector2(32, 28)
	back_button.size = Vector2(154, 54)
	exp_badge.position = Vector2(size.x - 416, 30)
	exp_badge.size = Vector2(172, 48)
	progress_badge.position = Vector2(size.x - 230, 30)
	progress_badge.size = Vector2(198, 48)
	for category in range(4):
		var width := tree_rect.size.x / 4
		var x := tree_rect.position.x + width * category
		category_labels[category].position = Vector2(x, cover_origin.y + 185 * cover_scale)
		category_labels[category].size = Vector2(width, 30)
		category_icons[category].position = Vector2(x + width / 2 - 20, cover_origin.y + 137 * cover_scale)
		category_icons[category].size = Vector2(40, 40)
		category_icons[category].queue_redraw()
		for index in range(7):
			var node: Button = nodes[category_keys[category][index]]
			node.size = Vector2(52, 52)
			node.position = Vector2(width * category, 0) + NODE_POSITIONS[index] * Vector2(width, tree_rect.size.y) - node.size / 2
	detail.position = Vector2(size.x - detail_width - 32, 124)
	detail.size = Vector2(detail_width, size.y - 248)
	detail_frame.position = detail.position
	detail_frame.size = detail.size
	detail_frame.queue_redraw()
	close_button.position = detail.position + Vector2(detail_width - 44, 12)
	close_button.size = Vector2(30, 30)
	legend_panel.size = legend_panel.get_combined_minimum_size()
	legend_panel.position = Vector2(floorf((size.x - legend_panel.size.x) / 2), size.y - legend_panel.size.y - 28)
	graph.queue_redraw()

func _displayed() -> String:
	return selected_skill if selected_skill != "" else hovered_skill

func _state(key: String) -> String:
	if not LIVE_SKILLS.has(key):
		return "future"
	if profile.unlocks.has(key):
		return "unlocked"
	if key != "purse" and not profile.unlocks.has("purse"):
		return "locked"
	if profile.exp < RunModel.SKILL_COSTS[key]:
		return "locked"
	return "available"

func can_unlock(key: String) -> bool:
	return LIVE_SKILLS.has(key) and _state(key) == "available" and profile.exp >= RunModel.SKILL_COSTS[key]

func refresh_profile(meta: Dictionary, error: String = "") -> void:
	profile = meta.duplicate(true)
	save_error = error
	if not is_node_ready():
		return
	exp_badge.text = "◇ EXP  %d" % profile.exp
	progress_badge.text = "Skills  %d / 3" % profile.unlocks.size()
	for key in nodes:
		nodes[key].node_state = _state(key)
		nodes[key].selected = selected_skill == key
		nodes[key].queue_redraw()
	graph.queue_redraw()
	_refresh_detail()

func _hover(key: String) -> void:
	hovered_skill = key
	_refresh_detail()

func _leave(key: String) -> void:
	if hovered_skill == key:
		hovered_skill = ""
		_refresh_detail()

func select_skill(key: String) -> void:
	if not skills.has(key):
		return
	selected_skill = key
	selection_changed.emit(key)
	refresh_profile(profile, save_error)

func clear_selection() -> void:
	selected_skill = ""
	hovered_skill = ""
	selection_changed.emit("")
	refresh_profile(profile, save_error)

func _request_unlock() -> void:
	if selected_skill != "" and can_unlock(selected_skill):
		unlock_requested.emit(selected_skill)

func _refresh_detail() -> void:
	if not is_instance_valid(close_button):
		return
	var key := _displayed()
	close_button.visible = selected_skill != ""
	detail_error.text = save_error
	detail_error.visible = save_error != ""
	if key == "":
		detail_category.text = "THE SKILL TREE"
		detail_title.text = "Select a skill to upgrade"
		detail_description.text = "Hover to preview.\nClick a skill to keep it selected."
		detail_stats.text = ""
		detail_requirement.text = "Unlock permanent advantages with EXP earned on your runs."
		unlock_button.text = "Select a skill"
		unlock_button.disabled = true
	else:
		var data: Dictionary = skills[key]
		var implemented: bool = data.implemented
		detail_category.text = CATEGORIES[data.category].to_upper() + ("  /  PREVIEW" if selected_skill == "" else "  /  SELECTED")
		detail_title.text = data.title
		detail_description.text = data.description
		if implemented:
			var unlocked: bool = profile.unlocks.has(key)
			var cost: int = RunModel.SKILL_COSTS[key]
			detail_stats.text = "Rank  %d / 1\n\nCost  %d EXP" % [1 if unlocked else 0, cost]
			detail_requirement.text = "Unlocked. Applies to new runs." if unlocked else ("Requires Deeper pockets." if key != "purse" and not profile.unlocks.has("purse") else ("Need %d more EXP." % (cost - profile.exp) if profile.exp < cost else "Requirements met."))
			if selected_skill == "" and not unlocked:
				detail_requirement.text += "\nClick this skill to select it."
			unlock_button.text = "Unlocked" if unlocked else "Unlock · %d EXP" % cost
			unlock_button.disabled = selected_skill == "" or not can_unlock(key)
		else:
			detail_stats.text = "Not yet available"
			detail_requirement.text = "Placeholder. No EXP can be spent here."
			unlock_button.text = "Coming soon"
			unlock_button.disabled = true
	detail_icon.queue_redraw()
	unlock_button.queue_redraw()

func _draw_detail_icon() -> void:
	var center := detail_icon.size / 2
	var key := _displayed()
	var color: Color = Color("#b1c3cf") if key == "" else nodes[key].state_color()
	var radius := 44.0
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
	detail_icon.draw_polyline(points, color, 2, false)
	SkillNode.draw_icon(detail_icon, "star" if key == "" else skills[key].icon, center, 5, color)

func _draw_detail_frame() -> void:
	var trim := Color("#d6c7a3")
	detail_frame.draw_rect(Rect2(Vector2(6, 6), detail_frame.size - Vector2(12, 12)), Color("#7c8990"), false, 1)
	for point in [Vector2(8, 8), Vector2(detail_frame.size.x - 8, 8), Vector2(8, detail_frame.size.y - 8), detail_frame.size - Vector2(8, 8)]:
		detail_frame.draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), trim)
		detail_frame.draw_rect(Rect2(point - Vector2(1, 6), Vector2(2, 12)), trim)
		detail_frame.draw_rect(Rect2(point - Vector2(6, 1), Vector2(12, 2)), trim)

func _draw_connections() -> void:
	for category in range(4):
		var keys: Array = category_keys[category]
		for pair in [[0, 1], [0, 2], [1, 3], [2, 5], [3, 4], [4, 6], [5, 6]]:
			var from: Control = nodes[keys[pair[0]]]
			var to: Control = nodes[keys[pair[1]]]
			var color := Color("#7f8d9e")
			if LIVE_SKILLS.has(keys[pair[1]]):
				color = nodes[keys[pair[1]]].state_color()
			_draw_link(from.position + from.size / 2, to.position + to.size / 2, color)
		var width := graph.size.x / 4
		var x := width * category
		graph.draw_line(Vector2(x + 18, -30), Vector2(x + width - 18, -30), Color("#c4bca3"), 1)
		graph.draw_rect(Rect2(Vector2(x + width / 2 - 2, -32), Vector2(4, 4)), Color("#e9d6a3"))
	# Actual cross-tree prerequisite: Fortune's Deeper pockets unlocks Command's bishop.
	var purse: Control = nodes.purse
	var bishop: Control = nodes.bishop
	var a := purse.position + purse.size / 2
	var b := bishop.position + bishop.size / 2
	var bridge_y := minf(a.y, b.y) - 38
	graph.draw_polyline(PackedVector2Array([a, Vector2(a.x, bridge_y), Vector2(b.x, bridge_y), b]), nodes.bishop.state_color(), 2, false)

func _draw_link(a: Vector2, b: Vector2, color: Color) -> void:
	var middle := (a.y + b.y) / 2
	graph.draw_polyline(PackedVector2Array([a, Vector2(a.x, middle), Vector2(b.x, middle), b]), color, 2, false)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
