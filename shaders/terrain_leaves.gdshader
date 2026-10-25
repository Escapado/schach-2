// Adapted from Eduardo Schildt, MIT (2026). See assets/terrain/foliage/LICENSE.txt.
shader_type spatial;
render_mode specular_disabled, cull_disabled;


uniform float wind_scale = 0.15;
uniform float wind_speed = 0.06;
uniform float wind_strength = 0.045;
uniform vec3 wind_direction = vec3(0.7, 0.0, 1.0);
uniform sampler2D wind_noise : filter_linear_mipmap;

uniform vec4 color: source_color = vec4(0.36, 0.58, 0.13, 1.0);
uniform sampler2D alpha : filter_linear_mipmap, repeat_disable;
uniform float leaves_scale = 0.12;
uniform float leaf_bend_amount = 0.7;
uniform float light_steps = 5.0;

varying vec4 view_pos;
varying vec4 world_pos;

void vertex() {
	// The reference expands face UVs toward the camera while retaining canopy normals.
	// Store each face center explicitly so the expansion is stable on rotated vine meshes.
	world_pos = MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0);
	view_pos = VIEW_MATRIX * world_pos;
	float speed = TIME * wind_speed;
	float noise = textureLod(wind_noise, world_pos.xz * wind_scale - speed * wind_direction.xz, 1.0).r;
	noise = (noise * 2.0 - 1.0) * wind_strength * leaf_bend_amount;
	vec2 corner = UV * 2.0 - 1.0;
	vec2 offset = corner * leaves_scale;
	offset += vec2(noise * corner.x, -noise * corner.y);
	POSITION = PROJECTION_MATRIX * (view_pos + vec4(offset, 0.0, 0.0));
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = texture(alpha, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.0;
	SPECULAR = 0.0;
	LIGHT_VERTEX = view_pos.xyz;
}

void light() {
	// Cel shaded diffuse lighting
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	light = ceil(light * light_steps) / light_steps;
	DIFFUSE_LIGHT += light * (LIGHT_COLOR / PI) * ATTENUATION;

	// Rim Lighting
	float rim = 1.0 - dot(NORMAL, VIEW);
	rim *= light;
	rim = round(rim * light_steps) / light_steps;
	rim = rim * rim;
	DIFFUSE_LIGHT += rim * ATTENUATION * LIGHT_COLOR / PI;
	
}
