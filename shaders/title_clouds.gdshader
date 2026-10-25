shader_type canvas_item;
#include "res://shaders/title_cloud_motion.gdshaderinc"

uniform float elapsed = 0.0;

void fragment() {
	vec2 uv = drifting_cloud_uv(UV, elapsed);
	COLOR = texture(TEXTURE, uv);
}
