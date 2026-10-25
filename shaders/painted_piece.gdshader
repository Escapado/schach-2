shader_type spatial;
render_mode unshaded;

uniform vec4 stone_color : source_color = vec4(0.94, 0.86, 0.70, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.38, 0.37, 0.45, 1.0);
varying vec3 stone_position;

void vertex() {
	stone_position = VERTEX;
}

void fragment() {
	// A fixed world-space key matches the painted tiles, including in transparent views.
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float light = clamp(dot(world_normal, normalize(vec3(-0.7, 1.0, 0.45))), 0.0, 1.0);
	float band = floor(light * 4.0 + 0.5) / 4.0;
	vec3 grain = floor(stone_position * 55.0);
	float fleck = fract(sin(dot(grain, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	ALBEDO = mix(shadow_color.rgb, stone_color.rgb, band) * (0.97 + step(0.8, fleck) * 0.06);
}
