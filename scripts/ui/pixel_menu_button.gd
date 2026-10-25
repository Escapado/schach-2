extends Button
## Native Button input, focus and accessibility with a pixel-drawn frame and icon.

const INK := Color("#102439")
const CREAM := Color("#eee3b5")
var primary := false
var icon_kind := "diamond"
var hovered := false

const ICONS := {
	"diamond": ["000000010000000", "000000111000000", "000001101100000", "000011000110000", "000110010011000", "001100111001100", "011001010100110", "110011101110011", "011001010100110", "001100111001100", "000110010011000", "000011000110000", "000001101100000", "000000111000000", "000000010000000"],
	"crown": ["000000010000000", "000000111000000", "100000010000001", "110010010010011", "111111111111111", "011111111111110", "011111111111110", "001111111111100", "001111111111100", "001111111111100", "000000000000000", "001111111111100", "011111111111110", "000000000000000", "000000000000000"],
	"gear": ["000001111100000", "000001111100000", "001101111101100", "011111111111110", "011111111111110", "111110000011111", "111100111001111", "111100111001111", "111100111001111", "111110000011111", "011111111111110", "011111111111110", "001101111101100", "000001111100000", "000001111100000"],
	"exit": ["001111111110000", "001100000110000", "001100000110000", "001100000110000", "001100000110100", "001100000110110", "001100111111111", "001100111111111", "001100000110110", "001100000110100", "001100000110000", "001100000110000", "001100000110000", "001111111110000", "000000000000000"],
}

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# Draw lettering after the frame. Keep Button.text for native accessibility.
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	add_theme_color_override("font_shadow_color", Color("#081826"))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _draw() -> void:
	var active := (hovered or has_focus()) and not disabled
	var pressed := is_pressed()
	var offset := Vector2(0, 2 if pressed else 0)
	var rect := Rect2(offset, size - Vector2(0, 4))
	var fill := Color("#087c80") if primary else INK
	if active:
		fill = Color("#10999b") if primary else Color("#24475b")
	if pressed:
		fill = Color("#07585f")
	if disabled:
		fill = Color("#1b303d")
	var trim := Color("#70828f") if disabled else CREAM
	var border := Color("#526571") if disabled else (Color("#58d8c5") if primary or active else Color("#73848e"))
	# Square steps keep the corners crisp at any menu size.
	draw_rect(Rect2(Vector2(4, 6), size - Vector2(4, 6)), Color("#081522b0"))
	draw_style_box(_frame(fill, border), rect)
	var inner := rect.grow(-5)
	draw_style_box(_frame(Color.TRANSPARENT, trim if primary or active or disabled else Color("#b8b8aa")), inner)
	for corner in [Vector2(10, 10), Vector2(size.x - 10, 10), Vector2(10, size.y - 14), Vector2(size.x - 10, size.y - 14)]:
		var point: Vector2 = corner + offset
		draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), trim)
		draw_rect(Rect2(point - Vector2(1, 5), Vector2(2, 10)), trim)
		draw_rect(Rect2(point - Vector2(5, 1), Vector2(10, 2)), trim)
	var unit := 1 if size.x < 160 else 2
	var origin := Vector2(16 if unit == 1 else 28, floor((size.y - 15 * unit) / 2.0) - 2) + offset
	var pattern: Array = ICONS.get(icon_kind, ICONS.diamond)
	var icon_color := trim if active or primary or disabled else Color("#c7ac84")
	for y in range(pattern.size()):
		for x in range(pattern[y].length()):
			if pattern[y][x] == "1":
				draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2(unit, unit)), icon_color)
	if primary:
		var center := Vector2(size.x - 38, size.y / 2 - 2) + offset
		draw_polyline(PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0), center + Vector2(0, -7)]), trim, 2)
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2((size.x - text_width) / 2 + 12, (size.y - 4) / 2 + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2) + offset
	draw_string(font, baseline + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#081826"))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#fff9d6") if active else trim)

func _frame(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.corner_detail = 1
	return style
