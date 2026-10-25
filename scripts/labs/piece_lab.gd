extends Control
## Isolated art lab. No battle or profile state is accessed.

const PIECES := ["pawn", "rook", "knight", "bishop", "queen", "king"]
const STONE = preload("res://shaders/piece_stone.gdshader")
const OUTLINE = preload("res://shaders/pixel_outline.gdshader")
var viewport: SubViewport
var display: TextureRect
var camera: Camera3D
var outline: MeshInstance3D
var sun: DirectionalLight3D
var angle := 0.20
var pixel_width := 512
var capture_frames := 0

func _ready() -> void:
	# The gameplay UI stretches its canvas. This lab needs physical integer pixels.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("#0c1c28"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(pixel_width, pixel_width * 9 / 16)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	_build_world()
	_build_overlay()
	resized.connect(_layout)
	_layout()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = at
	parent.add_child(instance)

func _build_world() -> void:
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#183442")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a2b8d1")
	environment.environment.ambient_light_energy = 0.35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("#ffe0ad")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 0.2
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color("#7acbd2")
	fill.light_energy = 0.35
	world.add_child(fill)
	_box(world, Vector3(0, -0.55, 0), Vector3(200, 0.2, 200), Color("#183442"))
	_box(world, Vector3(0, -0.23, 0), Vector3(8.35, 0.4, 5.2), Color("#172835"))
	_box(world, Vector3(0, -0.035, 0), Vector3(8.4, 0.07, 5.25), Color("#b99b63"))
	for row in range(4):
		for col in range(6):
			var color := Color("#62767c") if (row + col) % 2 else Color("#a2a38c")
			_box(world, Vector3((col - 2.5) * 1.34, 0.04, (row - 1.5) * 1.22),
				Vector3(1.31, 0.14, 1.19), color)
	for side in range(2):
		var material := ShaderMaterial.new()
		material.shader = STONE
		material.set_shader_parameter("stone_color", Color("#e9d5ae") if side == 0 else Color("#655579"))
		for index in range(PIECES.size()):
			var packed := load("res://assets/pieces/%s.glb" % PIECES[index]) as PackedScene
			var piece := packed.instantiate() as Node3D
			world.add_child(piece)
			piece.position = Vector3((index - 2.5) * 1.34, 0.115, 1.22 if side == 0 else -1.22)
			piece.rotation.y = -0.5 if side == 0 else 0.5
			_apply_stone(piece, material)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	camera.near = 0.1
	camera.far = 80.0
	world.add_child(camera)
	_position_camera()
	outline = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	outline.mesh = quad
	outline.extra_cull_margin = 16384.0
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var post := ShaderMaterial.new()
	post.shader = OUTLINE
	outline.material_override = post
	camera.add_child(outline)
	outline.position.z = -1

func _apply_stone(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_stone(child, material)

func _position_camera() -> void:
	camera.position = Vector3(sin(angle) * 14, 10, cos(angle) * 14)
	camera.look_at(Vector3(0, 0.45, 0))

func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _build_overlay() -> void:
	_label("SCHACH / 2     •     PIECE STUDY", Vector2(40, 22), 28, Color("#ebd7ae"))
	_label("Ivory & violet stone   /   Blender models   /   orthographic 3D", Vector2(40, 62), 17, Color("#a4b6bd"))
	var controls := HBoxContainer.new()
	controls.position = Vector2(40, 100)
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	for width in [384, 512, 640]:
		var button := Button.new()
		button.text = "%d px" % width
		button.pressed.connect(func() -> void:
			pixel_width = width
			viewport.size = Vector2i(width, width * 9 / 16)
			_layout())
		controls.add_child(button)
	var edges := CheckButton.new()
	edges.text = "Outlines"
	edges.button_pressed = true
	edges.toggled.connect(func(enabled: bool) -> void: outline.visible = enabled)
	controls.add_child(edges)
	var light := Button.new()
	light.text = "Turn light"
	light.pressed.connect(func() -> void: sun.rotation.y += PI / 4.0)
	controls.add_child(light)
	var note := _label("← →  Orbit     •     R  Reset view     •     Ivory foreground / violet background",
		Vector2(40, 0), 17, Color("#a4b6bd"))
	note.name = "Footer"

func _layout() -> void:
	if not is_instance_valid(display):
		return
	var available := Vector2(size.x - 64, size.y - 205)
	var scale_factor := maxf(1.0, floorf(minf(available.x / viewport.size.x, available.y / viewport.size.y)))
	display.size = Vector2(viewport.size) * scale_factor
	display.position = Vector2((size.x - display.size.x) / 2, 150 + (available.y - display.size.y) / 2)
	var footer := get_node_or_null("Footer") as Label
	if footer:
		footer.position.y = size.y - 38

func _process(delta: float) -> void:
	var direction := float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
	if direction != 0:
		angle += direction * delta * 0.65
		_position_camera()
	if Input.is_physical_key_pressed(KEY_R):
		angle = 0.20
		_position_camera()
	if "--capture" in OS.get_cmdline_user_args():
		capture_frames += 1
		if capture_frames == 25:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/schach2-piece-lab.png")
			print("Piece lab rendered to /tmp/schach2-piece-lab.png")
			get_tree().quit()
