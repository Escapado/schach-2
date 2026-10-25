// Adapted from Eduardo Schildt's MIT reference. See REFERENCE_LICENSE.txt.
// Depth silhouettes and normal creases are evaluated at the low viewport resolution.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.65;
uniform float crease_strength : hint_range(0.0, 1.0) = 0.22;

float linear_depth(vec2 uv, mat4 inverse_projection) {
	float raw = texture(depth_texture, uv).r;
	vec4 view = inverse_projection * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return -view.z / view.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal = texture(normal_texture, SCREEN_UV).rgb * 2.0 - 1.0;
	vec2 offsets[4] = vec2[](vec2(1, 0), vec2(-1, 0), vec2(0, 1), vec2(0, -1));
	float silhouette = 0.0;
	float crease = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = clamp(SCREEN_UV + offsets[i] * pixel, pixel, vec2(1.0) - pixel);
		float neighbor = linear_depth(uv, INV_PROJECTION_MATRIX);
		silhouette = max(silhouette, smoothstep(0.12, 0.28, neighbor - center));
		vec3 other_normal = texture(normal_texture, uv).rgb * 2.0 - 1.0;
		crease = max(crease, smoothstep(0.18, 0.6, 1.0 - dot(normal, other_normal))
			* (1.0 - smoothstep(0.05, 0.20, abs(neighbor - center))));
	}
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	color = mix(color, color * vec3(0.25, 0.23, 0.40), silhouette * outline_strength);
	color += vec3(0.12, 0.10, 0.07) * crease * crease_strength * (1.0 - silhouette);
	ALBEDO = color;
}
