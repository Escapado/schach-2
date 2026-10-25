shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 stone_color : source_color = vec4(0.85, 0.76, 0.59, 1.0);

void fragment() {
	ALBEDO = stone_color.rgb;
	ROUGHNESS = 0.85;
}
