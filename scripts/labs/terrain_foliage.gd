extends RefCounted
## Reference vegetation technique: face UV masks, view-facing expansion, face-normal lighting.
const LEAVES = preload("res://shaders/terrain_leaves.gdshader")
const MASK = preload("res://assets/terrain/foliage/leaf_alpha.png")
static var wind_texture: NoiseTexture2D

static func material(leaf_size: float, color: Color) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = LEAVES
	result.set_shader_parameter("alpha", MASK)
	result.set_shader_parameter("leaves_scale", leaf_size)
	result.set_shader_parameter("color", color)
	result.set_shader_parameter("light_steps", 5.0)
	if not wind_texture:
		wind_texture = NoiseTexture2D.new()
		var source := FastNoiseLite.new()
		source.seed = 341
		source.frequency = 0.045
		wind_texture.noise = source
		wind_texture.width = 128
		wind_texture.height = 128
		wind_texture.seamless = true
	result.set_shader_parameter("wind_noise", wind_texture)
	return result

static func _quad(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var center := (points[0] + points[1] + points[2] + points[3]) / 4.0
	for index in [0, 2, 1, 0, 3, 2]:
		surface.set_custom(0, Color(center.x, center.y, center.z, 1.0))
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(points[index])

static func _bough(surface: SurfaceTool, center: Vector3, radius: Vector3, rng: RandomNumberGenerator) -> void:
	var segments := 12
	var rings := 8
	var points: Array[Vector3] = []
	for row in range(rings + 1):
		var latitude := 0.04 + (PI - 0.08) * row / rings
		for column in range(segments):
			var longitude := TAU * column / segments
			var direction := Vector3(sin(latitude) * cos(longitude), cos(latitude), sin(latitude) * sin(longitude))
			points.append(center + direction * radius * rng.randf_range(0.88, 1.12))
	for row in range(rings):
		for column in range(segments):
			var next := (column + 1) % segments
			var quad: Array[Vector3] = [points[row * segments + column], points[row * segments + next], points[(row + 1) * segments + next], points[(row + 1) * segments + column]]
			var midpoint := (quad[0] + quad[1] + quad[2] + quad[3]) / 4.0
			var normal := ((midpoint - center) / (radius * radius)).normalized()
			_quad(surface, quad, normal)

static func add_canopy(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 341
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for entry in [[Vector3(-1.05, 2.23, -0.04), Vector3(0.72, 0.42, 0.57)], [Vector3(0.33, 2.35, -0.20), Vector3(0.67, 0.46, 0.55)], [Vector3(-0.21, 2.43, 0.55), Vector3(0.65, 0.44, 0.49)], [Vector3(-0.46, 2.59, -0.57), Vector3(0.65, 0.43, 0.50)], [Vector3(-0.56, 2.83, -0.04), Vector3(0.70, 0.39, 0.55)]]:
		_bough(surface, entry[0], entry[1], rng)
	var mesh := surface.commit()
	var canopy := MeshInstance3D.new()
	canopy.name = "PainterlyCanopy"
	canopy.mesh = mesh
	canopy.material_override = material(0.22, Color("#7fa83e"))
	canopy.extra_cull_margin = 0.5
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(canopy)
	# Match the reference's separate opaque shadow proxy.
	var shadow := MeshInstance3D.new()
	shadow.name = "CanopyShadow"
	shadow.mesh = mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(shadow)

static func replace_tree_leaves(node: Node) -> void:
	if node is MeshInstance3D:
		var retained := ArrayMesh.new()
		for index in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(index) as StandardMaterial3D
			if source and source.albedo_texture:
				continue
			retained.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, node.mesh.surface_get_arrays(index))
			retained.surface_set_material(retained.get_surface_count() - 1, source)
		node.mesh = retained
	for child in node.get_children():
		replace_tree_leaves(child)

static func add_vine_leaves(parent: Node3D, variant: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for strand in range(3):
		var length := 1.1 + strand * 0.24 + variant * 0.3
		for index in range(18):
			var t := float(index) / 17.0
			var center := Vector3((strand - 1) * 0.26 + sin(t * 8.1 + strand) * 0.075, -t * length, 0.05)
			var side := -1.0 if index % 2 else 1.0
			center.x += side * 0.065
			var width := 0.075
			var points: Array[Vector3] = [center + Vector3(-width, -width, 0), center + Vector3(width, -width, 0), center + Vector3(width, width, 0), center + Vector3(-width, width, 0)]
			_quad(surface, points, Vector3(side * 0.35, 0.45, 0.8).normalized())
	var leaves := MeshInstance3D.new()
	leaves.name = "PainterlyIvy"
	leaves.mesh = surface.commit()
	leaves.material_override = material(0.09, Color("#77963a"))
	leaves.extra_cull_margin = 0.2
	parent.add_child(leaves)
