shader_type canvas_item;

void fragment() {
	float y = floor(UV.y * 360.0) / 360.0;
	vec3 high = vec3(0.29, 0.39, 0.61);
	vec3 low = vec3(0.93, 0.61, 0.64);
	COLOR = vec4(mix(high, low, smoothstep(0.0, 0.62, y)), 1.0);
}
