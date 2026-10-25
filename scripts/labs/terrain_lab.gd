extends "res://scripts/labs/piece_lab.gd"
## Seeded visual composition only. Never reads battle or persistence state.
const FOLIAGE = preload("res://scripts/labs/terrain_foliage.gd")
var terrain_root: Node3D
var terrain_seed := 72
var seed_label: Label
var detail_label: Label
var pixel_scale := 1
var preview_size := Vector2i(1024, 576)

func _build_world() -> void:
	super._build_world()
	# Reuse the piece lab's viewport, lighting, camera, and postprocess.
	var world := viewport.get_child(0)
	for child in world.get_children():
		if child is MeshInstance3D or (child is Node3D and not child is Light3D and not child is Camera3D and not child is WorldEnvironment):
			child.queue_free()
	terrain_root = Node3D.new()
	world.add_child(terrain_root)
	camera.size = 11.7
	angle = PI / 4.0
	_position_camera()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--terrain-seed="):
			terrain_seed = argument.get_slice("=", 1).to_int()
		if argument.begins_with("--orbit-degrees="):
			angle = deg_to_rad(argument.get_slice("=", 1).to_float())
			_position_camera()
		if argument.begins_with("--pixel-scale="):
			pixel_scale = clampi(argument.get_slice("=", 1).to_int(), 1, 3)
		if argument.begins_with("--viewport="):
			var dimensions := argument.get_slice("=", 1).split("x")
			preview_size = Vector2i(clampi(dimensions[0].to_int(), 320, 1920), clampi(dimensions[1].to_int(), 180, 1080))
	_compose()

func _module(asset: String, at: Vector3, rotation_y := 0.0) -> Node3D:
	var packed := load("res://assets/terrain/%s.glb" % asset) as PackedScene
	var node := packed.instantiate() as Node3D
	terrain_root.add_child(node)
	node.position = at
	node.rotation.y = rotation_y
	if asset == "tree":
		FOLIAGE.replace_tree_leaves(node)
		FOLIAGE.add_canopy(node)
	elif asset.begins_with("vines_"):
		_replace_vine_leaves(node)
		FOLIAGE.add_vine_leaves(node, asset.get_slice("_", 1).to_int())
	return node

func _compose() -> void:
	for child in terrain_root.get_children():
		terrain_root.remove_child(child)
		child.queue_free()
	if is_instance_valid(seed_label):
		seed_label.text = "Weathered ruins & wild garden   /   Seed %d   /   6 × 6" % terrain_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	for z in range(6):
		for x in range(6):
			var at := Vector3(x - 2.5, 0, z - 2.5)
			var tone := "light" if (x + z) % 2 == 0 else "dark"
			var styles := ["weathered", "weathered", "weathered", "grass", "grass", "ivy", "flowers"]
			var style: String = styles[rng.randi_range(0, styles.size() - 1)]
			var slab := "slab_%s_%s" % [style, tone]
			_module(slab, at, rng.randi_range(0, 3) * PI / 2.0)
			_module("foundation", at)
			if x == 0 or x == 5 or z == 0 or z == 5:
				if rng.randf() < 0.65:
					_module("foundation", at + Vector3(0, -rng.randf_range(0.25, 1.0), 0))
				if z == 5 and rng.randf() < 0.8:
					_module("vines_%d" % rng.randi_range(0, 1), at + Vector3(0, -0.12, 0.51))
				if x == 5 and rng.randf() < 0.8:
					_module("vines_%d" % rng.randi_range(0, 1), at + Vector3(0.51, -0.12, 0), PI / 2)
	# Decorative perimeter grows around the complete, level 6x6 board.
	for cell in [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(4, -1), Vector2i(5, -1), Vector2i(6, 0), Vector2i(6, 4), Vector2i(5, 6), Vector2i(1, 6), Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(2, -1), Vector2i(3, -1)]:
		var at := Vector3(cell.x - 2.5, 0, cell.y - 2.5)
		var garden_slabs := ["slab_moss", "slab_ivy_light", "slab_grass_light", "slab_flowers_light"]
		_module(garden_slabs[rng.randi_range(0, garden_slabs.size() - 1)], at, rng.randi_range(0, 3) * PI / 2)
		_module("foundation", at)
		_module("vines_1", at + Vector3(0, 0, 0.5))
		if cell.y == 6 or cell.x == 6 or cell.x == -2:
			_module("garden_flowers" if rng.randf() < 0.6 else "garden_fern", at)
	_module("tree", Vector3(-4.0, 0, -2.0))
	_module("garden_fern", Vector3(-3.5, 0, -1.5))
	_module("garden_flowers", Vector3(-4.5, 0, -0.5))
	_module("pillar_broken", Vector3(-3.5, 0, 0.5))
	_module("pillar_leaning", Vector3(2.5, 0, -3.5))
	_module("pillar_overgrown", Vector3(-1.5, 0, -3.5))
	for x in [-0.5, 0.5, 1.5]:
		_module("wall_broken" if x == 0.5 else "wall_low", Vector3(x, 0, -3.5))
	_module("wall_broken", Vector3(3.5, 0, -2.5), PI / 2)
	for entry in [["king", Vector3(-1.5, 0, 1.5), 0], ["pawn", Vector3(0.5, 0, 1.5), 0], ["knight", Vector3(1.5, 0, 0.5), 0], ["bishop", Vector3(-0.5, 0, -1.5), 1], ["pawn", Vector3(1.5, 0, -1.5), 1]]:
		var packed := load("res://assets/pieces/%s.glb" % entry[0]) as PackedScene
		var piece := packed.instantiate() as Node3D
		terrain_root.add_child(piece)
		piece.position = entry[1]
		var material := ShaderMaterial.new()
		material.shader = STONE
		material.set_shader_parameter("stone_color", Color("#f0d9ac") if entry[2] == 0 else Color("#4c395f"))
		_apply_stone(piece, material)

func _replace_vine_leaves(node: Node) -> void:
	if node is MeshInstance3D:
		var retained := ArrayMesh.new()
		for index in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(index) as StandardMaterial3D
			if source and source.albedo_color.g > source.albedo_color.r:
				continue
			retained.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, node.mesh.surface_get_arrays(index))
			retained.surface_set_material(retained.get_surface_count() - 1, source)
		node.mesh = retained
	for child in node.get_children():
		_replace_vine_leaves(child)

func _build_overlay() -> void:
	_label("SCHACH / 2     •     TERRAIN STUDY", Vector2(40, 22), 28, Color("#ebd7ae"))
	seed_label = _label("Weathered ruins & wild garden   /   Seed %d   /   6 × 6" % terrain_seed,
		Vector2(40, 62), 17, Color("#a4b6bd"))
	var controls := HBoxContainer.new()
	controls.position = Vector2(40, 100)
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	var detail_group := ButtonGroup.new()
	for index in range(3):
		var scale_value := 3 - index
		var button := Button.new()
		button.text = ["Chunky", "Balanced", "Fine"][index]
		button.toggle_mode = true
		button.button_group = detail_group
		button.button_pressed = pixel_scale == scale_value
		button.pressed.connect(func() -> void:
			pixel_scale = scale_value
			_layout())
		controls.add_child(button)
	var edges := CheckButton.new()
	edges.text = "Outlines"
	edges.button_pressed = true
	edges.toggled.connect(func(enabled: bool) -> void: outline.visible = enabled)
	controls.add_child(edges)
	var light := Button.new()
	light.text = "Turn light"
	light.pressed.connect(func() -> void: sun.rotation.y += PI / 4)
	controls.add_child(light)
	var regenerate := Button.new()
	regenerate.text = "New terrain seed"
	regenerate.pressed.connect(func() -> void:
		terrain_seed += 1
		_compose())
	controls.add_child(regenerate)
	var sizing := HBoxContainer.new()
	sizing.position = Vector2(40, 142)
	sizing.add_theme_constant_override("separation", 10)
	add_child(sizing)
	var sizing_label := Label.new()
	sizing_label.text = "Viewport width × height"
	sizing.add_child(sizing_label)
	for dimension in range(2):
		var field := SpinBox.new()
		field.min_value = 320 if dimension == 0 else 180
		field.max_value = 1920 if dimension == 0 else 1080
		field.step = 1
		field.value = preview_size[dimension]
		field.custom_minimum_size.x = 120
		field.suffix = "px"
		field.value_changed.connect(func(value: float) -> void:
			preview_size[dimension] = int(value)
			_layout())
		sizing.add_child(field)
	var zoom_label := Label.new()
	zoom_label.text = "Camera zoom"
	sizing.add_child(zoom_label)
	var zoom := HSlider.new()
	zoom.min_value = 7.0
	zoom.max_value = 16.0
	zoom.step = 0.1
	zoom.value = camera.size
	zoom.custom_minimum_size.x = 160
	zoom.value_changed.connect(func(value: float) -> void: camera.size = value)
	sizing.add_child(zoom)
	detail_label = _label("", Vector2(40, 0), 16, Color("#a4b6bd"))
	detail_label.name = "Footer"

func _layout() -> void:
	if not is_instance_valid(display):
		return
	var available := Vector2(size.x - 64, size.y - 245)
	viewport.size = Vector2i(maxi(1, preview_size.x / pixel_scale), maxi(1, preview_size.y / pixel_scale))
	var fit := minf(available.x / viewport.size.x, available.y / viewport.size.y)
	var display_scale := minf(float(pixel_scale), floorf(fit)) if fit >= 1.0 else fit
	display.size = Vector2(viewport.size) * display_scale
	display.position = Vector2((size.x - display.size.x) / 2, 190 + (available.y - display.size.y) / 2)
	if is_instance_valid(detail_label):
		detail_label.position.y = size.y - 38
		detail_label.text = "← →  Orbit   •   R  Reset   /   %d × %d render   /   %.2f× display" % [viewport.size.x, viewport.size.y, display_scale]

func _process(delta: float) -> void:
	# Retain orbit controls while using a dedicated capture path.
	var direction := float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
	if direction != 0:
		angle += direction * delta * 0.65
		_position_camera()
	if Input.is_physical_key_pressed(KEY_R):
		angle = PI / 4
		_position_camera()
	if "--capture" in OS.get_cmdline_user_args():
		capture_frames += 1
		if capture_frames == 25:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/schach2-terrain-lab.png")
			print("Terrain lab rendered to /tmp/schach2-terrain-lab.png")
			get_tree().quit()
