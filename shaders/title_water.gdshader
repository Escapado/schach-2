shader_type canvas_item;
#include "res://shaders/title_cloud_motion.gdshaderinc"

uniform float elapsed = 0.0;
uniform bool cloud_reflections_enabled = true;
uniform vec2 pixel_grid = vec2(640.0, 360.0);
uniform sampler2D cloud_layer : source_color, filter_linear, repeat_enable;
uniform sampler2D water_mask_texture : filter_nearest, repeat_disable;
// Cloud rectangle expressed in normalized landscape coordinates.
uniform vec2 cloud_uv_scale = vec2(1.0);
uniform vec2 cloud_uv_offset = vec2(0.0);

float pink_reflection(vec3 color) {
	return step(0.4, color.r) * step(color.g * 1.05, color.r) * step(color.g * 0.95, color.b);
}

float water_mask(vec2 uv) {
	vec4 painted = texture(water_mask_texture, uv);
	return painted.r * painted.a;
}

void fragment() {
	vec2 uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
	vec4 original = texture(TEXTURE, uv);
	float mask = water_mask(uv) * original.a;
	// Visible two-to-four-pixel ripples, still confined to water.
	float wave = sin(uv.y * 145.0 + elapsed * 1.7) + sin(uv.y * 287.0 - elapsed * 1.1);
	float shift = round(wave * 1.8) / pixel_grid.x;
	vec2 ripple_uv = uv + vec2(shift * mask, 0.0);
	vec4 displaced = texture(TEXTURE, ripple_uv);
	// Protect black shoreline pixels without squaring the painted gray strength.
	float safe = step(0.0001, water_mask(ripple_uv)) * displaced.a;
	vec4 color = mix(original, displaced, mask * safe);
	// Replace the fixed painted streak with a reflection of the actual cloud layer.
	float pink = pink_reflection(color.rgb) * float(cloud_reflections_enabled);
	float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 lake = vec3(0.035, 0.53, 0.65) * clamp(brightness / 0.48, 0.6, 1.3);
	color.rgb = mix(color.rgb, lake, pink * mask * 0.9);
	// Mirror around the lake horizon, then map into the actual cloud rectangle.
	vec2 reflected_uv = vec2(uv.x + shift * 1.8, 0.96 - uv.y + wave * 0.004);
	reflected_uv = (reflected_uv - cloud_uv_offset) / cloud_uv_scale;
	vec2 cloud_uv = drifting_cloud_uv(reflected_uv, elapsed);
	vec4 reflection = texture(cloud_layer, cloud_uv);
	// Horizontal wrapping only; never repeat clouds vertically below their layer.
	reflection.a *= step(0.0, cloud_uv.y) * step(cloud_uv.y, 1.0);
	float reflection_strength = reflection.a * mix(0.48, 0.25, smoothstep(0.5, 1.0, uv.y));
	color.rgb = mix(color.rgb, reflection.rgb, reflection_strength * mask * safe * float(cloud_reflections_enabled));
	float glint = pow(max(0.0, sin(uv.y * 420.0 + elapsed * 1.8 + sin(uv.x * 37.0))), 12.0);
	color.rgb += vec3(0.075, 0.14, 0.13) * glint * mask * safe;
	COLOR = color;
}
