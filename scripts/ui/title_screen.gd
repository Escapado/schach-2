extends Control
## Presentation-only start screen. The game controller owns runs and progression.

signal new_run_requested
signal upgrades_requested
signal settings_requested
signal panel_closed

const PixelButton = preload("res://scripts/ui/pixel_menu_button.gd")
const DISPLAY_FONT = preload("res://pixelfont.ttf")
const LOGO = preload("res://assets/title/logo.png")
const LANDSCAPE = preload("res://assets/title/landscape.png")
const CLOUDS = preload("res://assets/title/clouds-tile.png")
const WATER_MASK = preload("res://assets/title/landscape_mask.png")
var scenery: Control
var clouds: TextureRect
var landscape: TextureRect
var menu: Control
var title: TextureRect
var divider: Control
var new_run_button: Button
var upgrades_button: Button
var settings_button: Button
var exit_button: Button
var footer: Label
var overlay: Control
var modal: PanelContainer
var motion_enabled := true
var elapsed := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenery = Control.new()
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scenery)
	var sky := ColorRect.new()
	sky.material = _shader("res://shaders/title_sky.gdshader")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.add_child(sky)
	clouds = _layer(CLOUDS, "res://shaders/title_clouds.gdshader")
	# Subpixel translation with a one-texel filter keeps motion smooth while the
	# artwork's large pixel clusters retain their shape.
	clouds.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clouds.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	landscape = _layer(LANDSCAPE, "res://shaders/title_water.gdshader")
	landscape.material.set_shader_parameter("cloud_layer", CLOUDS)
	landscape.material.set_shader_parameter("water_mask_texture", WATER_MASK)
	# A quiet left edge lets the scenery stay bright beside readable controls.
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#0b17365c"))
	gradient.set_color(1, Color("#0b173600"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	var veil := TextureRect.new()
	veil.texture = texture
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	title = TextureRect.new()
	title.texture = LOGO
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(title)
	divider = Control.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(_draw_divider)
	menu.add_child(divider)
	new_run_button = _button("New Run", "diamond", true)
	new_run_button.name = "NewRun"
	new_run_button.pressed.connect(func() -> void: new_run_requested.emit())
	menu.add_child(new_run_button)
	upgrades_button = _button("Upgrades", "crown")
	upgrades_button.name = "Upgrades"
	upgrades_button.pressed.connect(func() -> void: upgrades_requested.emit())
	menu.add_child(upgrades_button)
	settings_button = _button("Settings", "gear")
	settings_button.name = "Settings"
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	menu.add_child(settings_button)
	exit_button = _button("Exit", "exit")
	exit_button.name = "Exit"
	exit_button.add_theme_font_size_override("font_size", 23)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	add_child(exit_button)
	# Reserved for actionable profile errors; otherwise the lower edge stays clear.
	footer = _label("", 14)
	footer.add_theme_color_override("font_shadow_color", Color("#102439"))
	footer.add_theme_constant_override("shadow_offset_x", 1)
	footer.add_theme_constant_override("shadow_offset_y", 2)
	add_child(footer)
	resized.connect(_layout)
	_layout()

func _shader(path: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(path)
	return material

func _layer(texture: Texture2D, shader_path: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.material = _shader(shader_path)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.add_child(layer)
	return layer

func _label(value: String, font_size: int, display_font: bool = false) -> Label:
	var result := Label.new()
	result.text = value
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("#fff1c9"))
	if display_font:
		result.add_theme_font_override("font", DISPLAY_FONT)
	return result

func _button(value: String, icon: String, primary: bool = false) -> Button:
	var result := PixelButton.new()
	result.text = value
	result.icon_kind = icon
	result.primary = primary
	result.add_theme_font_override("font", DISPLAY_FONT)
	result.add_theme_font_size_override("font_size", 31)
	return result

func _draw_divider() -> void:
	var cream := Color("#f0e1b8")
	var width := divider.size.x
	var center := width / 2
	divider.draw_line(Vector2(8, 16), Vector2(center - 28, 16), Color("#d0c9aa80"), 2)
	divider.draw_line(Vector2(center + 28, 16), Vector2(width - 8, 16), Color("#d0c9aa80"), 2)
	# Small king silhouette, drawn on a two-pixel grid.
	var rows := ["00011000", "00111100", "00011000", "01111110", "00111100", "00011000", "00111100", "00111100", "01111110", "11111111"]
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] == "1":
				divider.draw_rect(Rect2(Vector2(center - 8 + x * 2, 5 + y * 2), Vector2(2, 2)), cream)
	for x in [center - 32, center + 32]:
		divider.draw_rect(Rect2(Vector2(x - 2, 14), Vector2(4, 4)), cream)

func _layout() -> void:
	if not is_instance_valid(scenery):
		return
	scenery.size = size
	var cover_scale := maxf(size.x / LANDSCAPE.get_width(), size.y / LANDSCAPE.get_height())
	var cover_size := Vector2(LANDSCAPE.get_size()) * cover_scale
	var cover_origin := (size - cover_size) / 2.0
	landscape.position = cover_origin
	landscape.size = cover_size
	# Use the same source-pixel scale as the landscape, preserving a cropped tile's
	# aspect ratio. Center its canvas before applying the existing upward offset.
	clouds.size = Vector2(CLOUDS.get_size()) * cover_scale
	clouds.position = cover_origin + (cover_size - clouds.size) / 2.0 - Vector2(0, cover_size.y * 0.16)
	landscape.material.set_shader_parameter("cloud_uv_scale", clouds.size / cover_size)
	landscape.material.set_shader_parameter("cloud_uv_offset", (clouds.position - cover_origin) / cover_size)
	var left := floorf(size.x * 0.055)
	var width := minf(420, size.x * 0.35)
	var top := maxf(76, size.y * 0.16)
	title.position = Vector2(left - 4, top - 40)
	title.size = Vector2(width + 8, (width + 8) / 3.0)
	divider.position = Vector2(left, top + 104)
	divider.size = Vector2(width, 32)
	divider.queue_redraw()
	for index in range(3):
		var item: Button = [new_run_button, upgrades_button, settings_button][index]
		item.position = Vector2(left, top + 159 + index * 88)
		item.size = Vector2(width, 76)
	exit_button.size = Vector2(170, 58)
	exit_button.position = size - Vector2(210, 96)
	footer.position = Vector2(left, size.y - 49)
	if is_instance_valid(modal):
		modal.size = Vector2(minf(700, size.x - 80), minf(740, size.y - 80))
		modal.position = (size - modal.size) / 2

func _process(delta: float) -> void:
	if motion_enabled:
		elapsed += delta
		landscape.material.set_shader_parameter("elapsed", elapsed)
		clouds.material.set_shader_parameter("elapsed", elapsed)

func open_panel(heading: String) -> VBoxContainer:
	scenery.show()
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	menu.hide()
	exit_button.hide()
	footer.hide()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color("#061522b0")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	modal = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102439f5")
	style.border_color = Color("#bcbca0")
	style.set_border_width_all(2)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	modal.add_theme_stylebox_override("panel", style)
	overlay.add_child(modal)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	modal.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var name_label := _label(heading, 29, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var back := _button("Back", "exit")
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(134, 48)
	back.pressed.connect(close_panel)
	header.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 12)
	scroll.add_child(contents)
	_layout()
	back.grab_focus()
	return contents

func open_fullscreen_panel(view: Control) -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	menu.hide()
	exit_button.hide()
	footer.hide()
	scenery.hide()
	modal = null
	overlay = view
	add_child(view)

func close_panel() -> void:
	if not is_instance_valid(overlay):
		return
	remove_child(overlay)
	overlay.queue_free()
	overlay = null
	modal = null
	menu.show()
	scenery.show()
	exit_button.show()
	footer.show()
	new_run_button.grab_focus()
	panel_closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay):
		close_panel()
		get_viewport().set_input_as_handled()
