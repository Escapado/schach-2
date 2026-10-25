shader_type canvas_item;
render_mode unshaded;
uniform bool enabled = true;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float adjacent = max(max(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0)).a,
		texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0)).a),
		max(texture(TEXTURE, UV + vec2(0, TEXTURE_PIXEL_SIZE.y)).a,
		texture(TEXTURE, UV - vec2(0, TEXTURE_PIXEL_SIZE.y)).a));
	COLOR = source;
	if (enabled && source.a < 0.1 && adjacent > 0.5) {
		COLOR = vec4(0.15, 0.16, 0.23, 0.65);
	}
}
