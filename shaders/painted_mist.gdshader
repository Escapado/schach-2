shader_type canvas_item;
render_mode unshaded;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(7.0, 5.0);
	float clouds = noise(p) * 0.6 + noise(p * 2.0) * 0.3 + noise(p * 4.0) * 0.1;
	vec3 background = mix(vec3(0.13, 0.25, 0.28), vec3(0.42, 0.59, 0.61), UV.y);
	float fog = smoothstep(0.42, 0.79, clouds + UV.y * 0.3);
	background = mix(background, vec3(0.72, 0.76, 0.72), fog * 0.65);
	float vignette = smoothstep(0.2, 0.7, distance(UV, vec2(0.5, 0.42)));
	COLOR = vec4(background * (1.0 - vignette * 0.3), 1.0);
}
