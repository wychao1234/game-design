extends Node3D
class_name DungeonRoom

# Original low-poly environment. World floor is XZ, top surface Y = 0.
# All geometry/materials are built once; only torch intensities animate.
const TEX_ROOT := "res://assets/environment/"
var _rng := RandomNumberGenerator.new()
var _stone: StandardMaterial3D
var _wall: StandardMaterial3D
var _wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _rubble: StandardMaterial3D
var _gold: StandardMaterial3D
var _dark: StandardMaterial3D
var _cyan: StandardMaterial3D
var _flame: StandardMaterial3D
var _torch_lights: Array[OmniLight3D] = []
var _clock := 0.0

func _ready() -> void:
	_rng.seed = 415
	_make_materials()
	_make_environment()
	_make_exterior()
	_make_floor()
	_make_walls()
	_make_supports()
	_make_rails()
	_make_props()
	_make_lighting()
	_make_campfire()

func get_spawn_points() -> Array[Vector3]:
	return [Vector3(-3.6, 0, -2.5), Vector3(3.8, 0, -3.2), Vector3(5.0, 0, 2.2), Vector3(-2.8, 0, 0.0)]

func configure_camera(camera: Camera3D) -> void:
	var attrs := CameraAttributesPractical.new()
	# Desktop Forward+ only: Mobile retains the same scene without DoF.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		camera.attributes = attrs
		return
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		attrs.dof_blur_far_enabled = true
		attrs.dof_blur_far_distance = camera.global_position.distance_to(Vector3.ZERO) + 13.0
		attrs.dof_blur_far_transition = 8.0
		attrs.dof_blur_amount = 0.07
	camera.attributes = attrs

func _make_materials() -> void:
	_stone = _textured("mine_floor", Color(0.95, 1.0, 1.0))
	_wall = _textured("mine_wall", Color(0.88, 0.96, 1.0))
	_wood = _textured("mine_timber", Color.WHITE)
	_iron = _textured("mine_iron", Color(0.78, 0.9, 0.94))
	_iron.metallic = 0.55
	_iron.roughness = 0.62
	_rubble = _textured("mine_rubble", Color.WHITE)
	_gold = _plain(Color("967044"))
	_gold.metallic = 0.65
	_dark = _plain(Color("101a20"))
	_cyan = _plain(Color("247e8d"))
	_cyan.emission_enabled = true
	_cyan.emission = Color("2ba5ae")
	_cyan.emission_energy_multiplier = 0.75
	_flame = _plain(Color("ffbc56"))
	_flame.emission_enabled = true
	_flame.emission = Color("ff9b30")
	_flame.emission_energy_multiplier = 3.0

func _textured(file_name: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEX_ROOT + file_name + ".png")
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.95
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
	return mat

func _plain(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "MineAtmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("263c4c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9fcbdb")
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("2d4959")
	env.fog_density = 0.007
	env.fog_sky_affect = 0.0
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.glow_enabled = true
		env.glow_intensity = 0.45
		env.glow_hdr_threshold = 1.4
	# No SSAO/SSIL/volumetric fog: retain light GPU and Mobile costs.
	world.environment = env
	add_child(world)

func _box(label: String, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.position = at
		body.add_child(collision)
		add_child(body)
	return node

func _make_exterior() -> void:
	# A dark cutaway mine diorama replaces the black void; scenery is below or
	# behind the playable boundary and deliberately has no extra collision.
	var cave_floor := _plain(Color("293b43"))
	var cave_rock := _textured("mine_rubble", Color("78858d"))
	_box("CavernShelf", Vector3(0, -0.95, 0), Vector3(26.3, 1.0, 20.5), cave_rock)
	_box("CaveDepth", Vector3(0, -1.9, 0), Vector3(70, 0.6, 60), cave_floor)
	for i in range(12):
		var x := -14.5 + i * 2.7
		var radius := _rng.randf_range(1.9, 3.1)
		_rock(Vector3(x, 0.2, -10.6 - _rng.randf_range(0.0, 1.1)), radius, cave_rock)
	for i in range(8):
		var z := -8.0 + i * 2.6
		var radius := _rng.randf_range(1.6, 2.5)
		_rock(Vector3(-13.3 - _rng.randf_range(0.0, 0.9), -0.1, z), radius, cave_rock)
	# Foreground strata remain lower than the character's feet.
	for p in [Vector3(-9, -0.8, 9.4), Vector3(-4, -1.0, 9.8), Vector3(3, -1.1, 9.7), Vector3(9, -1.0, 9.4), Vector3(12.5, -1, 2.8)]:
		_rock(p, 1.4, cave_rock)

func _make_floor() -> void:
	_box("Foundation", Vector3(0, -0.31, 0), Vector3(22.8, 0.6, 16.8), _dark, true)
	# Five material batches keep hundreds of flagstones to five draw calls.
	for variant in range(5):
		var tiles := MultiMeshInstance3D.new()
		tiles.name = "Flagstones%d" % variant
		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(0.987, 0.10, 0.987)
		tiles.multimesh = MultiMesh.new()
		tiles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		tiles.multimesh.mesh = tile_mesh
		var locations: Array[Vector3] = []
		for x in range(-11, 11):
			for z in range(-8, 8):
				if posmod(x * 17 + z * 7, 5) == variant:
					locations.append(Vector3(float(x) + 0.5, -0.04, float(z) + 0.5))
		tiles.multimesh.instance_count = locations.size()
		var material := _stone.duplicate() as StandardMaterial3D
		material.albedo_color = Color(0.88 + variant * 0.025, 0.94 + variant * 0.015, 0.96 + variant * 0.01)
		tiles.material_override = material
		for i in range(locations.size()):
			tiles.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, locations[i]))
		add_child(tiles)
	# Paving edges guide the central fighting lane without adding collision.
	for x in [-6.8, 6.8]:
		_box("LaneBorder", Vector3(x, 0.025, 0), Vector3(0.13, 0.05, 11.5), _gold)

func _make_walls() -> void:
	# Camera sits at positive X/Z. Those walls are intentional low cutaways.
	_box("RearWallLeft", Vector3(-6.4, 1.65, -8.15), Vector3(9.6, 3.3, 0.9), _wall, true)
	_box("RearWallRight", Vector3(6.4, 1.65, -8.15), Vector3(9.6, 3.3, 0.9), _wall, true)
	_box("LeftWall", Vector3(-11.15, 1.65, 0), Vector3(0.9, 3.3, 16.2), _wall, true)
	_box("ForegroundCutaway", Vector3(0, 0.25, 8.15), Vector3(22.8, 0.5, 0.9), _wall, true)
	_box("RightCutaway", Vector3(11.15, 0.25, 0), Vector3(0.9, 0.5, 16.2), _wall, true)
	_box("LeftWallCap", Vector3(-11.15, 3.36, 0), Vector3(1.05, 0.18, 16.6), _wood)
	_box("RearWallCap", Vector3(0, 3.36, -8.15), Vector3(22.8, 0.18, 1.05), _wood)
	_box("FrontCap", Vector3(0, 0.53, 8.15), Vector3(22.8, 0.10, 1.0), _wood)
	_box("RightCap", Vector3(11.15, 0.53, 0), Vector3(1.0, 0.10, 16.2), _wood)
	# Gateway recess, structural jambs and a shut gate prevent leaving the map.
	_box("GateDarkness", Vector3(0, 1.4, -8.32), Vector3(3.3, 2.8, 0.32), _dark, true)
	for x in [-1.75, 1.75]:
		_box("GateJamb", Vector3(x, 1.42, -7.86), Vector3(0.38, 2.84, 0.9), _wood, true)
		_box("GateFoot", Vector3(x, 0.2, -7.7), Vector3(0.65, 0.4, 1.12), _wall)
	_box("GateLintel", Vector3(0, 2.85, -7.85), Vector3(4.1, 0.48, 1.1), _wood)
	for x in range(-3, 4):
		_box("GateBar", Vector3(x * 0.43, 1.3, -7.96), Vector3(0.055, 2.6, 0.075), _iron)
	_box("GateBrace", Vector3(0, 0.9, -7.88), Vector3(3.15, 0.14, 0.09), _iron)
	# Back wall stone footing and irregular block relief.
	_box("RearFooting", Vector3(0, 0.15, -7.58), Vector3(22.4, 0.3, 0.32), _rubble)
	for x in [-9.0, -7.0, -4.5, 4.7, 7.0, 9.3]:
		_box("MasonryRelief", Vector3(x, 1.25, -7.65), Vector3(1.8, 0.75, 0.13), _rubble)

func _make_supports() -> void:
	for x in [-9.3, -5.7, 5.7, 9.3]:
		_box("BackTimber", Vector3(x, 1.55, -7.45), Vector3(0.32, 3.1, 0.32), _wood)
		for y in [0.4, 2.5]:
			_box("TimberStrap", Vector3(x, y, -7.45), Vector3(0.37, 0.18, 0.37), _iron)
	for z in [-5.5, 0.0, 5.2]:
		_box("LeftTimber", Vector3(-10.48, 1.5, z), Vector3(0.4, 3.0, 0.4), _wood)
		var brace := _box("TimberBrace", Vector3(-9.99, 2.65, z), Vector3(1.2, 0.22, 0.24), _wood)
		brace.rotation.z = -0.65
	for p in [Vector3(-8.1, 0, -4.4), Vector3(8.1, 0, -4.5), Vector3(-8.1, 0, 4.8)]:
		_box("PillarFoot", p + Vector3(0, 0.18, 0), Vector3(1.25, 0.36, 1.25), _rubble, true)
		_box("Pillar", p + Vector3(0, 1.26, 0), Vector3(0.82, 2.52, 0.82), _wall, true)
		_box("PillarCapital", p + Vector3(0, 2.48, 0), Vector3(1.18, 0.3, 1.18), _rubble)
		_box("PillarBand", p + Vector3(0, 1.55, 0), Vector3(0.86, 0.14, 0.86), _iron)

func _make_rails() -> void:
	for z in range(-6, 7):
		_box("RailSleeper", Vector3(-5.15, 0.065, z), Vector3(1.75, 0.1, 0.2), _wood)
	for x in [-5.70, -4.60]:
		_box("MineRail", Vector3(x, 0.13, 0), Vector3(0.09, 0.12, 13.0), _iron)
	# Mine cart at rear left, outside central combat lane.
	var cart := Vector3(-5.15, 0, -4.3)
	_box("CartChassis", cart + Vector3(0, 0.42, 0), Vector3(1.45, 0.22, 1.9), _iron, true)
	_box("CartOre", cart + Vector3(0, 0.9, 0), Vector3(1.18, 0.82, 1.55), _dark, true)
	for x in [-0.72, 0.72]:
		_box("CartSide", cart + Vector3(x, 0.98, 0), Vector3(0.12, 0.95, 1.9), _wood)
		_box("CartRim", cart + Vector3(x, 1.49, 0), Vector3(0.16, 0.1, 2.0), _iron)
	for z in [-0.9, 0.9]:
		_box("CartEnd", cart + Vector3(0, 0.98, z), Vector3(1.45, 0.95, 0.12), _wood)
	for x in [-0.78, 0.78]:
		for z in [-0.62, 0.62]:
			var wheel := _cylinder("CartWheel", cart + Vector3(x, 0.3, z), 0.28, 0.14, _iron, 10)
			wheel.rotation.z = PI / 2.0
	for i in range(5):
		_rock(cart + Vector3(_rng.randf_range(-0.42, 0.42), 1.35, _rng.randf_range(-0.6, 0.6)), 0.3, _rubble)

func _cylinder(label: String, at: Vector3, radius: float, height: float, mat: Material, sides: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	return node

func _rock(at: Vector3, radius: float, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.45
	mesh.radial_segments = 6
	mesh.rings = 3
	var node := MeshInstance3D.new()
	node.name = "LowPolyOre"
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.rotation = Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())
	add_child(node)

func _make_props() -> void:
	# Rear-side stepped ore platform, kept away from the playable center.
	for i in range(3):
		_box("OrePlatformStep", Vector3(8.8, 0.16 + i * 0.20, -6.0 - i * 0.48), Vector3(3.0, 0.32 + i * 0.40, 1.25), _rubble, true)
	for center in [Vector3(8.7, 0, -6.3), Vector3(9.4, 0, 1.6), Vector3(-9.5, 0, -6.6)]:
		for i in range(4):
			var at: Vector3 = center + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.4, 0.4))
			var height := _rng.randf_range(0.4, 1.05)
			var crystal_mesh := CylinderMesh.new()
			crystal_mesh.top_radius = 0.0
			crystal_mesh.bottom_radius = 0.17 + height * 0.1
			crystal_mesh.height = height
			crystal_mesh.radial_segments = 5
			var crystal := MeshInstance3D.new()
			crystal.name = "TealCrystal"
			crystal.mesh = crystal_mesh
			crystal.material_override = _cyan
			crystal.position = at + Vector3(0, height * 0.5 + (0.9 if center.z < -6.0 and center.x > 0 else 0), 0)
			crystal.rotation.z = _rng.randf_range(-0.25, 0.25)
			add_child(crystal)
		_omni(center + Vector3(0, 1.0, 0), Color("48c7d0"), 0.5, 3.2)
	# Chest and supplies along the side, represented by solid low-poly forms.
	var chest := Vector3(8.5, 0, 4.9)
	_box("SupplyChest", chest + Vector3(0, 0.4, 0), Vector3(1.35, 0.8, 0.9), _wood, true)
	_box("ChestLid", chest + Vector3(0, 0.84, 0), Vector3(1.46, 0.2, 1.0), _wood)
	for x in [-0.43, 0.43]:
		_box("ChestBand", chest + Vector3(x, 0.48, 0), Vector3(0.12, 0.96, 1.03), _gold)
	_box("ChestLock", chest + Vector3(0, 0.6, 0.53), Vector3(0.22, 0.25, 0.08), _gold)
	for p in [Vector3(-9.0, 0, 6.2), Vector3(-9.1, 0, 2.2)]:
		_box("SupplyCrate", p + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95), _wood, true)
		_box("CrateStrap", p + Vector3(0, 0.45, 0), Vector3(1.0, 0.14, 1.0), _iron)
	for i in range(25):
		var x := _rng.randf_range(-10.3, 10.3)
		var z := _rng.randf_range(-7.2, 7.2)
		if absf(x) < 7.0 and absf(z) < 6.0:
			continue
		var radius := _rng.randf_range(0.10, 0.33)
		_rock(Vector3(x, radius * 0.3, z), radius, _rubble)
	# Original ground medallion: subtle rings, not a visual combat hazard.
	var ring := TorusMesh.new()
	ring.inner_radius = 1.7
	ring.outer_radius = 1.76
	ring.rings = 32
	ring.ring_segments = 4
	var medallion := MeshInstance3D.new()
	medallion.name = "OldWaymark"
	medallion.mesh = ring
	medallion.material_override = _gold
	medallion.position = Vector3(0, 0.025, 0.7)
	add_child(medallion)

func _make_lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "ColdMineFill"
	key.light_color = Color("b5d5ee")
	key.light_energy = 0.78
	key.rotation_degrees = Vector3(-55, -30, 0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 50.0
	key.shadow_bias = 0.08
	add_child(key)
	for p in [Vector3(-3.0, 1.9, -7.15), Vector3(3.0, 1.9, -7.15), Vector3(-10.15, 1.8, 0.0), Vector3(9.8, 0.95, 4.1)]:
		_make_torch(p)
	_omni(Vector3(0, 3.4, 3.0), Color("9abacb"), 0.35, 12.0)

func _omni(at: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	add_child(light)
	return light

func _make_torch(at: Vector3) -> void:
	_box("TorchBracket", at + Vector3(0, -0.40, 0), Vector3(0.18, 0.65, 0.20), _iron)
	_box("TorchWood", at + Vector3(0, -0.12, 0), Vector3(0.13, 0.48, 0.13), _wood)
	_cylinder("TorchBasket", at, 0.19, 0.18, _iron, 6)
	var fire_mesh := CylinderMesh.new()
	fire_mesh.top_radius = 0
	fire_mesh.bottom_radius = 0.15
	fire_mesh.height = 0.48
	fire_mesh.radial_segments = 5
	var fire := MeshInstance3D.new()
	fire.name = "FacetedFlame"
	fire.mesh = fire_mesh
	fire.material_override = _flame
	fire.position = at + Vector3(0, 0.23, 0)
	add_child(fire)
	_torch_lights.append(_omni(at + Vector3(0, 0.38, 0), Color("ffad57"), 3.25, 5.8))

func _process(delta: float) -> void:
	_clock += delta
	for i in range(_torch_lights.size()):
		_torch_lights[i].light_energy = 3.20 + 0.10 * sin(_clock * 5.1 + i * 1.8) + 0.05 * sin(_clock * 11.7 + i)

func _make_campfire() -> void:
	# Non-blocking respawn / repeat-trial landmark, matching gameplay position.
	var center := Vector3(0, 0, 5.8)
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		_rock(center + Vector3(cos(angle) * 0.48, 0.11, sin(angle) * 0.48), 0.18, _rubble)
	for i in range(3):
		var log_node := _box("CampFirewood", center + Vector3(0, 0.12 + i * 0.035, 0), Vector3(0.72, 0.15, 0.17), _wood)
		log_node.rotation.y = float(i) * PI / 3.0
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.0
	flame_mesh.bottom_radius = 0.24
	flame_mesh.height = 0.68
	flame_mesh.radial_segments = 6
	var fire := MeshInstance3D.new()
	fire.name = "CampfireFlame"
	fire.mesh = flame_mesh
	fire.material_override = _flame
	fire.position = center + Vector3(0, 0.47, 0)
	add_child(fire)
	_omni(center + Vector3(0, 0.85, 0), Color("ffab56"), 2.8, 4.8)
	var label := Label3D.new()
	label.name = "CampfireTrialPrompt"
	label.text = "营火 · F 再次试炼"
	label.font = load("res://assets/fonts/NotoSansCJKJP-Regular.woff2")
	label.font_size = 44
	label.pixel_size = 0.006
	label.modulate = Color("ffe2a1")
	label.outline_modulate = Color("17222b")
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = center + Vector3(0, 1.25, 0)
	add_child(label)
