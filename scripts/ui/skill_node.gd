extends Button
## A focusable native button with a pixel icon and a drawn skill-tree frame.

const PIXELS = {
	"coins": ["001111100", "011111110", "010000010", "011111110", "001111100", "010000010", "011111110", "010000010", "011111110"],
	"reroll": ["001111100", "011000110", "110000011", "100000111", "000001111", "111100000", "111000001", "011000110", "001111100"],
	"bishop": ["000010000", "000111000", "001110100", "001101100", "000111000", "000010000", "000111000", "001111100", "011111110"],
	"rook": ["110101011", "111111111", "011111110", "001111100", "001111100", "001111100", "001111100", "011111110", "111111111"],
	"crown": ["000010000", "100010001", "110111011", "111111111", "011111110", "001111100", "001111100", "000000000", "011111110"],
	"clover": ["000111000", "000111000", "110111011", "111111111", "111111111", "011111110", "000010000", "000110000", "001100000"],
	"shield": ["111111111", "110000011", "110010011", "110010011", "010010010", "011010110", "001111100", "000111000", "000010000"],
	"heart": ["011000110", "111101111", "111111111", "111111111", "011111110", "001111100", "000111000", "000010000", "000000000"],
	"flame": ["000010000", "000011000", "001111000", "001111100", "011011100", "111001110", "111001110", "011111100", "001111000"],
	"sword": ["000000011", "000000111", "000001110", "000011100", "010111000", "011110000", "001110000", "011011000", "110001000"],
	"star": ["000010000", "000111000", "000111000", "111111111", "011111110", "001111100", "011101110", "011000110", "010000010"],
	"dice": ["011111110", "110000011", "110001011", "110000011", "110010011", "110000011", "110100011", "110000011", "011111110"],
	"knight": ["000101000", "001111000", "011111100", "111111110", "110011110", "000111100", "001111000", "011111100", "111111110"],
	"cross": ["000111000", "000111000", "000111000", "111111111", "111111111", "111111111", "000111000", "000111000", "000111000"],
}
var icon_kind := "star"
var node_state := "future"
var selected := false
var hovered := false
var diamond := true

func _ready() -> void:
	# Native accessibility keeps the full title; it must not enlarge the icon node.
	add_theme_font_size_override("font_size", 1)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color", "font_shadow_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func state_color() -> Color:
	match node_state:
		"unlocked": return Color("#63efd6")
		"available": return Color("#f2d182")
		"locked": return Color("#a3a9b3")
		_: return Color("#7e8a9c")

func _draw() -> void:
	var center := size / 2
	var radius := size.x / 2 - 5
	var color := state_color()
	var fill := Color("#142b40")
	if hovered or has_focus():
		fill = Color("#294758")
		color = color.lightened(0.25)
	if is_pressed():
		fill = Color("#365968")
	if diamond:
		var points := _diamond(center, radius)
		draw_colored_polygon(points, fill)
		draw_polyline(points, color, 2, false)
	else:
		draw_circle(center, radius * 0.86, fill, true, -1, false)
		draw_arc(center, radius * 0.86, 0, TAU, 32, color, 2, false)
	if selected:
		draw_polyline(_diamond(center, radius + 4), Color("#ffe4a0"), 2, false)
		draw_polyline(_diamond(center, radius + 8), Color("#b99e68"), 1, false)
	elif has_focus():
		draw_polyline(_diamond(center, radius + 4), Color("#fff4cd"), 1, false)
	draw_icon(self, icon_kind, center, 3, color)
	draw_rect(Rect2(center + Vector2(-2, radius + 1), Vector2(4, 4)), color)

func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])

static func draw_icon(canvas: CanvasItem, key: String, center: Vector2, unit: int, color: Color) -> void:
	var pattern: Array = PIXELS.get(key, PIXELS.star)
	var origin := (center - Vector2(9, 9) * unit / 2).floor()
	for y in range(pattern.size()):
		for x in range(pattern[y].length()):
			if pattern[y][x] == "1":
				canvas.draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2(unit, unit)), color)
