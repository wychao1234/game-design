extends Node3D
class_name Waterfront

# All geometry is built once; repeated architecture is batched by material.
# This is real walkable geometry, never a flattened concept-image backdrop.
var mode: String = "town"
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _boxes: Dictionary = {}
var _cylinders: Dictionary = {}
var _spheres: Dictionary = {}
var _bevels: Dictionary = {}
var _bevel_mesh: ArrayMesh
var _deck_batches: Array = [[],[],[],[]]
var _water_material: ShaderMaterial
var _water_lights := PackedVector4Array()
var _sign_font: Font = preload("res://assets/fonts/NotoSansCJKJP-Regular.woff2")

func _ready() -> void:
	name = "LinchuanWaterfront_" + mode
	_rng.seed = 75105 if mode == "town" else 75106
	_materials_init()
	_atmosphere()
	_water()
	_ground()
	_boundaries()
	_district()
	_decorations()
	_reflections()
	_rain()
	_flush_batches()
	_flush_deck()

func configure_camera(camera: Camera3D) -> void:
	var attributes := CameraAttributesPractical.new()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		attributes.dof_blur_far_enabled = true
		attributes.dof_blur_far_distance = camera.global_position.distance_to(Vector3.ZERO) + 13.0
		attributes.dof_blur_far_transition = 12.0
		attributes.dof_blur_amount = 0.13
		attributes.dof_blur_near_enabled = true
		attributes.dof_blur_near_distance = 19.5
		attributes.dof_blur_near_transition = 1.5
	camera.attributes = attributes

func get_spawn_points() -> Array[Vector3]:
	return [Vector3(-6,0,-3.5), Vector3(6,0,-3.5), Vector3(-6.5,0,2), Vector3(6.5,0,2), Vector3(0,0,-4)]

func get_interaction_points() -> Array[Dictionary]:
	if mode == "town":
		return [{"id":"gate","title":"渡口 · 选择秘境","position":Vector3(8.4,0,-4.8)}, {"id":"craft","title":"听雨工坊 · 装备兑换","position":Vector3(-6.7,0,-3.8)}, {"id":"notice","title":"镇中告示 · 编队整备","position":Vector3(-1.6,0,-4.5)}]
	return [{"id":"exit","title":"返回临川镇","position":Vector3(0,0,5.5)}]

func _mat(key: String, color: Color, roughness: float = 0.75, texture: String = "") -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if not texture.is_empty():
		var texture_path := "res://assets/environment/" + texture + ".png"
		if texture == "mine_timber": texture_path = "res://assets/environment/dock_aged_wood.png"
		if ResourceLoader.exists(texture_path): mat.albedo_texture = load(texture_path)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.3
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_materials[key] = mat

func _materials_init() -> void:
	var plaster := ShaderMaterial.new()
	plaster.shader = load("res://assets/environment/waterfront_plaster.gdshader")
	_materials["plaster"] = plaster
	_mat("wood",Color("5d4738"),0.38,"mine_timber")
	_mat("darkwood",Color("302c29"),0.51,"mine_timber")
	_mat("stone",Color("98a6a7"),0.40,"mine_floor")
	_mat("foundation",Color("657b82"),0.73,"mine_wall")
	_mat("tile",Color("101f2b"),0.78)
	_mat("tileedge",Color("233542"),0.82)
	_mat("black",Color("101e28"),0.90)
	_mat("iron",Color("354a50"),0.35)
	_mat("bronze",Color("a87e43"),0.48)
	_mat("rope",Color("9a8e70"),0.90)
	_mat("cloth",Color("706e62"),0.95)
	_mat("redcloth",Color("914a37"),0.95)
	_mat("jadecloth",Color("456d6b"),0.90)
	_mat("moss",Color("3f655b"),1.0)
	_mat("ceramic",Color("688d8b"),0.32)
	_mat("fruit",Color("c7a259"),0.78)
	_mat("paper",Color("f2aa54"),0.80)
	var paper: StandardMaterial3D = _materials.paper
	paper.emission_enabled = true
	paper.emission = Color("ff701c")
	paper.emission_energy_multiplier = 3.0
	_mat("window",Color("bd8d45"),0.60)
	var window: StandardMaterial3D = _materials.window
	window.emission_enabled = true
	window.emission = Color("ff943e")
	window.emission_energy_multiplier = 1.2
	_detail_materials()
	for i in range(4):
		_mat("floor%d" % i,Color(0.67+i*0.045,0.76+i*0.025,0.79+i*0.02),0.32+i*0.05,"mine_floor")
		var deck := ShaderMaterial.new()
		deck.shader = load("res://assets/environment/waterfront_wetwood.gdshader")
		deck.set_shader_parameter("base_tint", Color(0.36+i*0.060,0.30+i*0.045,0.245+i*0.038))
		if ResourceLoader.exists("res://assets/environment/dock_aged_wood.png"):
			deck.set_shader_parameter("albedo_tex",load("res://assets/environment/dock_aged_wood.png"))
			deck.set_shader_parameter("use_albedo",true)
		_materials["deck%d" % i] = deck

func _box(at: Vector3, size: Vector3, material: String, solid: bool = false, rotation: Vector3 = Vector3.ZERO) -> void:
	if not _boxes.has(material): _boxes[material] = []
	# Scale local axes before rotation, otherwise roof ribs become spikes.
	_boxes[material].append(Transform3D(Basis.from_euler(rotation).scaled_local(size),at))
	if solid: _collision(at,size,rotation)

func _cylinder(at: Vector3, radius: float, height: float, material: String, rotation: Vector3 = Vector3.ZERO) -> void:
	if not _cylinders.has(material): _cylinders[material] = []
	_cylinders[material].append(Transform3D(Basis.from_euler(rotation).scaled_local(Vector3(radius*2,height,radius*2)),at))

func _sphere(at: Vector3, size: Vector3, material: String) -> void:
	if not _spheres.has(material): _spheres[material] = []
	_spheres[material].append(Transform3D(Basis.from_scale(size),at))

func _collision(at: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	body.rotation = rotation
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func _flush_batches() -> void:
	var groups: Array[Dictionary] = [_boxes,_cylinders,_spheres,_bevels]
	for group_index in range(groups.size()):
		var group: Dictionary = groups[group_index]
		for key: String in group:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			var mesh: Mesh
			if group_index == 0:
				var box := BoxMesh.new()
				box.size = Vector3.ONE
				mesh = box
			elif group_index == 1:
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.5
				cylinder.bottom_radius = 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 10
				mesh = cylinder
			elif group_index == 2:
				var sphere := SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 12
				sphere.rings = 6
				mesh = sphere
			else:
				if _bevel_mesh == null: _bevel_mesh = _make_bevel_mesh()
				mesh = _bevel_mesh
			mm.mesh = mesh
			mm.instance_count = group[key].size()
			for i in range(mm.instance_count): mm.set_instance_transform(i,group[key][i])
			var node := MultiMeshInstance3D.new()
			node.name = "Architecture_" + key
			node.multimesh = mm
			node.material_override = _materials[key]
			add_child(node)
	_boxes.clear()
	_cylinders.clear()
	_spheres.clear()
	_bevels.clear()

func _atmosphere() -> void:
	var world := WorldEnvironment.new()
	world.name = "RainLanternAtmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07111e")
	# Radiance for actual wet PBR, without brightening the visible night background or actor lighting.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("1d344e")
	sky_material.sky_horizon_color = Color("7397b7")
	sky_material.ground_horizon_color = Color("405b70")
	sky_material.ground_bottom_color = Color("0a1625")
	sky_material.sky_curve = 0.34
	sky_material.sky_energy_multiplier = 0.42
	sky_material.ground_energy_multiplier = 0.22
	var reflection_sky := Sky.new()
	reflection_sky.sky_material = sky_material
	reflection_sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = reflection_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("759abf")
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("162a3d")
	env.fog_density = 0.012
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.glow_enabled = true
		env.glow_intensity = 0.66
		env.glow_hdr_threshold = 1.1
		env.ssr_enabled = true
		env.ssr_max_steps = 40
		env.ssao_enabled = true
		env.ssao_radius = 1.15
		env.ssao_intensity = 1.15
		env.ssao_light_affect = 0.10
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "RainMoon"
	moon.rotation_degrees = Vector3(-66,-22,0)
	moon.light_color = Color("81a6d2")
	moon.light_energy = 0.46
	moon.shadow_opacity = 0.24
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 50
	moon.shadow_blur = 2.0
	add_child(moon)
	# A broad neutral-cool fill keeps the playable actors and ground readable while the harbour stays dark.
	var fill := OmniLight3D.new()
	fill.name = "BattleReadabilityFill"
	fill.position = Vector3(0,5.2,0.8)
	fill.light_color = Color("a0b8d2")
	fill.light_energy = 1.65
	fill.light_specular = 0.36
	fill.omni_range = 16.0
	fill.omni_attenuation = 1.15
	fill.shadow_enabled = false
	add_child(fill)
	if mode != "town":
		# The rear cool source reflects near the middle of the wet deck, rather than at the foreground rail.
		var reflected_moon := OmniLight3D.new()
		reflected_moon.name = "CanalMoonReflectionFill"
		reflected_moon.position = Vector3(0,4,-5)
		reflected_moon.light_color = Color("a0c1e4")
		reflected_moon.light_energy = 0.68
		reflected_moon.light_specular = 1.15
		reflected_moon.omni_range = 15.5
		reflected_moon.omni_attenuation = 1.1
		reflected_moon.shadow_enabled = false
		add_child(reflected_moon)

func _water() -> void:
	var node := MeshInstance3D.new()
	node.name = "AnimatedCanalWater"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(110,100)
	node.mesh = mesh
	node.position = Vector3(0,-0.64,-12)
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://assets/environment/waterfront_water.gdshader")
	node.material_override = _water_material
	add_child(node)

func _ground() -> void:
	_box(Vector3(0,-0.24,0),Vector3(21.5,0.48,13.5),"foundation",true)
	if mode == "town":
		for x in range(22):
			for z in range(14):
				var offset := 0.16 if z%2 == 0 else 0.0
				_box(Vector3(-10.45+x*0.97+offset,0.012,-6.37+z*0.97),Vector3(0.94,0.07,0.94),"floor%d" % _rng.randi_range(0,3))
	else:
		var x := -10.57
		var column := 0
		while x < 10.57:
			var width := minf(_rng.randf_range(0.22,0.36),10.60-x)
			var z := -6.62
			while z < 6.62:
				var repair := _rng.randf() < 0.20
				var length := minf(_rng.randf_range(0.65,1.25) if repair else _rng.randf_range(1.3,3.3),6.64-z)
				if length < 0.08: break
				var variant := _rng.randi_range(0,3)
				var size := Vector3(width-_rng.randf_range(0.018,0.035),0.09,length-0.026)
				var at := Vector3(x+width*0.5,0.021+_rng.randf_range(-0.006,0.006),z+length*0.5)
				var yaw := sin(at.x*35.0+at.z*13.0)*0.008 if repair else 0.0
				_deck_batches[variant].append(Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),at))
				if posmod(column*17+roundi(z*31),9) == 0:
					for dz in [0.10,length-0.10]: _cylinder(Vector3(x+width*0.5,0.072,z+dz),0.022,0.008,"agediron")
				z += length
			x += width
			column += 1
		for z in [-6.5,6.5]: _box(Vector3(0,-0.09,z),Vector3(21.1,0.25,0.25),"darkwood")
	for z in [-6.8,6.8]: _box(Vector3(0,-0.14,z),Vector3(21.7,0.28,0.22),"darkwood")
	for x in [-10.8,10.8]: _box(Vector3(x,-0.14,0),Vector3(0.22,0.28,13.8),"darkwood")

func _boundaries() -> void:
	_collision(Vector3(-10.8,0.7,0),Vector3(0.6,1.4,14))
	_collision(Vector3(10.8,0.7,0),Vector3(0.6,1.4,14))
	_collision(Vector3(0,0.7,-6.8),Vector3(22,1.4,0.6))
	_collision(Vector3(0,0.7,6.8),Vector3(22,1.4,0.6))
	for x in range(-10,11,2):
		for z in [-6.5,6.5]: _post(Vector3(x,0,z),z < 0)
	for z in range(-4,6,2):
		for x in [-10.5,10.5]: _post(Vector3(x,0,z),false)
	for y in ([0.42,0.8] if mode == "town" else [0.42]): _box(Vector3(0,y,-6.5),Vector3(21,0.09,0.1),"wood")
	if mode != "town":
		for x in range(-10,10,4): _rope_curve(Vector3(x,1.04,-6.5),Vector3(x+4,1.04,-6.5),0.23,0.022)
	for x in [-10.5,10.5]: _box(Vector3(x,0.43,0),Vector3(0.1,0.09,13),"wood")
	_box(Vector3(0,0.27,6.5),Vector3(21,0.08,0.1),"darkwood")

func _post(at: Vector3, tall: bool) -> void:
	var h := 1.25 if tall else 0.62
	_beveled(at+Vector3(0,h*0.5,0),Vector3(0.23,h,0.23),"postwood")
	_beveled(at+Vector3(0,h,0),Vector3(0.32,0.11,0.32),"endwood")
	_mooring_hitch(at+Vector3(0,0.26,0),0.158)
	_box(at+Vector3(0,-0.55,0),Vector3(0.25,1.1,0.25),"darkwood")

func _district() -> void:
	if mode != "town":
		_harbour()
		return
	# These staggered facades face the positive-Z play camera; eaves stay outside play bounds.
	_house(Vector3(-7.4,0,-9.1),5.8,4.0,3.0,true)
	_house(Vector3(-0.6,0,-11.2),4.3,4.4,5.3,false)
	_house(Vector3(6.7,0,-9.8),6.5,4.1,2.9,true)
	_house(Vector3(-15,-0.1,-2.5),5.0,5.0,4.0,false)
	_house(Vector3(-19,-0.3,-15),5.0,5.0,5.4,true)
	for x in [-19.0,-11.0,-3.0,6.0,14.0,22.0]:
		_house(Vector3(x,-0.3,-27-_rng.randf_range(0,3)),5.8,4.8,_rng.randf_range(3.8,6.0),false,false)
	_box(Vector3(1,-0.38,-20),Vector3(55,0.5,3.6),"foundation")
	for x in range(-23,25,4):
		_box(Vector3(x,0.8,-18.6),Vector3(0.2,2.0,0.2),"darkwood")
		_lantern(Vector3(x,1.8,-18.6),false)
	_bridge(Vector3(16,-0.2,-8))
	_boat(Vector3(-4,-0.43,-14.3),1.1,true)
	_boat(Vector3(12.8,-0.43,-2.4),0.85,false)
	_boat(Vector3(-15,-0.43,6.3),0.75,false)
	if mode == "town":
		_stall(Vector3(-7.2,0,-5.1),"redcloth")
		_notice(Vector3(-1.6,0,-5.8))
		_gate(Vector3(8.5,0,-5.9))
		_town_life()
	else:
		_gate(Vector3(0,0,-7.4))
		if mode == "ferry": _ferry_cargo()
		if mode == "boss":
			for x in [-8.8,8.8]:
				for i in range(8): _cylinder(Vector3(x,0.11,-5.8+i*0.23),0.10,0.07,"iron",Vector3(0,0,PI*0.5))

func _house(at: Vector3, width: float, depth: float, height: float, shop: bool, lights: bool = true) -> void:
	_box(at+Vector3(0,height*0.5,0),Vector3(width,height,depth),"plaster")
	_box(at+Vector3(0,0.2,0),Vector3(width+0.2,0.4,depth+0.2),"foundation")
	for x in [-width*0.49,0.0,width*0.49]: _box(at+Vector3(x,height*0.5,depth*0.51),Vector3(0.16,height,0.15),"darkwood")
	for y in [0.5,height-0.18]: _box(at+Vector3(0,y,depth*0.51),Vector3(width,0.16,0.15),"wood")
	for x in [-width*0.30,width*0.29]:
		var win := at+Vector3(x,height*0.54,depth*0.514)
		_box(win,Vector3(width*0.22,1.2,0.06),"window")
		for step in range(5): _box(win+Vector3(-width*0.11+step*width*0.055,0,0.04),Vector3(0.04,1.23,0.04),"darkwood")
		for y in [-0.6,-0.18,0.2,0.6]: _box(win+Vector3(0,y,0.04),Vector3(width*0.23,0.045,0.04),"darkwood")
		_box(win+Vector3(0,-0.66,0.15),Vector3(width*0.28,0.14,0.38),"foundation")
		if shop:
			for fold in range(7): _box(win+Vector3(-0.51+fold*0.17,0.42,0.08),Vector3(0.145,0.33,0.04),"jadecloth")
			_cylinder(win+Vector3(0,0.62,0.13),0.045,width*0.25,"rope",Vector3(0,0,PI*0.5))
	_box(at+Vector3(0,0.75,depth*0.52),Vector3(0.9,1.5,0.08),"darkwood")
	for x in [-0.27,0.27]: _box(at+Vector3(x,1.45,depth*0.55),Vector3(0.46,0.43,0.025),"redcloth" if shop else "jadecloth")
	for side in [-1.0,1.0]:
		_box(at+Vector3(side*width*0.506,height*0.53,0),Vector3(0.04,1.2,1.1),"darkwood")
		for z in [-0.42,-0.14,0.14,0.42]: _box(at+Vector3(side*width*0.515,height*0.53,z),Vector3(0.035,1.05,0.16),"wood")
	for x in [-width*0.42,width*0.42]:
		_cylinder(at+Vector3(x,0.46,depth*0.57),0.24,0.55,"darkwood")
		_cylinder(at+Vector3(x,0.72,depth*0.57),0.26,0.07,"rope")
	for x in [-0.25,0.25]: _cylinder(at+Vector3(x,0.8,depth*0.54+0.04),0.035,0.06,"bronze",Vector3(PI*0.5,0,0))
	_roof(at+Vector3(0,height,0),width+1.2,depth+1.1)
	for x in range(int(width*2)): _box(at+Vector3(-width*0.5+x*0.5,height-0.12,depth*0.48),Vector3(0.12,0.20,0.66),"wood")
	if shop:
		_box(at+Vector3(0,1.97,depth*0.52+0.08),Vector3(2.0,0.42,0.12),"black")
		_sign(at+Vector3(0,1.97,depth*0.52+0.16),"听雨工坊" if at.x < 0 else "渡头客栈",0.0045)
	if lights:
		for x in [-width*0.4,width*0.4]: _lantern(at+Vector3(x,height-0.45,depth*0.5+0.55),true)

func _roof(at: Vector3, width: float, depth: float, rise: float = 1.13) -> void:
	var strips := 8
	var half := depth*0.5
	for side in [-1.0,1.0]:
		for i in range(strips):
			var t0 := float(i)/strips
			var t1 := float(i+1)/strips
			var z0 := t0*half
			var z1 := t1*half
			var y0 := rise*pow(1.0-t0,1.35)+0.13*pow(t0,6)
			var y1 := rise*pow(1.0-t1,1.35)+0.13*pow(t1,6)
			var slope := atan2(y1-y0,z1-z0)
			var length := Vector2(z1-z0,y1-y0).length()
			_box(at+Vector3(0,(y0+y1)*0.5,side*(z0+z1)*0.5),Vector3(width,0.10,length+0.025),"tile",false,Vector3(-slope*side,0,0))
			for n in range(int(width/0.25)+1):
				var x := -width*0.5+n*0.25
				_cylinder(at+Vector3(x,(y0+y1)*0.5+0.07,side*(z0+z1)*0.5),0.053,length+0.06,"tileedge%d" % posmod(n+i,3),Vector3(PI*0.5-slope*side,0,0))
		_box(at+Vector3(0,0.13,side*half),Vector3(width+0.15,0.13,0.18),"tileedge")
		for n in range(int(width/0.25)+1):
			var x := -width*0.5+n*0.25
			_cylinder(at+Vector3(x,0.16,side*(half+0.10)),0.069,0.035,"tileedge%d" % posmod(n,3),Vector3(PI*0.5,0,0))
			_cylinder(at+Vector3(x,0.16,side*(half+0.121)),0.020,0.012,"tile",Vector3(PI*0.5,0,0))
	_cylinder(at+Vector3(0,rise+0.09,0),0.12,width+0.4,"tileedge",Vector3(0,0,PI*0.5))
	for x in [-width*0.5,width*0.5]: _box(at+Vector3(x,rise+0.15,0),Vector3(0.25,0.24,0.35),"tileedge")

func _lantern(at: Vector3, light: bool = true) -> void:
	if (at.z < -6.5 or absf(at.x) > 10.5) and _water_lights.size() < 16:
		_water_lights.append(Vector4(at.x,at.z,1.0 if light else 0.4,0.0))
	_cylinder(at+Vector3(0,0.35,0),0.016,0.4,"iron")
	_cylinder(at,0.18,0.46,"paper")
	for y in [-0.25,-0.17,0.17,0.25]: _cylinder(at+Vector3(0,y,0),0.19,0.035,"darkwood")
	for angle in range(8):
		var r := angle*TAU/8.0
		_box(at+Vector3(cos(r)*0.175,0,sin(r)*0.175),Vector3(0.014,0.43,0.014),"bronze")
	_box(at+Vector3(0,-0.38,0),Vector3(0.02,0.22,0.02),"redcloth")
	if light:
		var omni := OmniLight3D.new()
		omni.position = at
		omni.light_color = Color("ff9b47")
		omni.light_energy = 4.6
		omni.light_specular = 0.33
		omni.omni_range = 6.3
		omni.omni_attenuation = 1.5
		omni.shadow_enabled = false
		add_child(omni)

func _sign(at: Vector3, text: String, pixel: float) -> void:
	var label := Label3D.new()
	label.name = "CarvedSign"
	label.text = text
	label.font = _sign_font
	label.font_size = 64
	label.pixel_size = pixel
	label.position = at
	label.modulate = Color("dfc088")
	label.outline_size = 3
	label.outline_modulate = Color("241e1a")
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(label)

func _gate(at: Vector3) -> void:
	for x in [-1.2,1.2]:
		_box(at+Vector3(x,1.5,0),Vector3(0.22,3.0,0.22),"wood")
		_box(at+Vector3(x,0.18,0),Vector3(0.44,0.36,0.44),"foundation")
		_lantern(at+Vector3(x,2.2,0.35))
	_box(at+Vector3(0,2.9,0),Vector3(3.2,0.2,0.3),"darkwood")
	_box(at+Vector3(0,2.65,0.06),Vector3(1.15,0.44,0.12),"black")
	_sign(at+Vector3(0,2.65,0.13),"雨灯渡口",0.0036)
	_roof(at+Vector3(0,3,0),3.5,1.65)

func _stall(at: Vector3, cloth: String) -> void:
	_box(at+Vector3(0,0.65,0),Vector3(2.5,1.3,0.9),"wood",true)
	_box(at+Vector3(0,1.32,0),Vector3(2.65,0.10,1.0),"darkwood")
	for x in [-1.35,1.35]: _box(at+Vector3(x,1.2,0),Vector3(0.10,2.4,0.10),"darkwood")
	_box(at+Vector3(0,2.35,-0.15),Vector3(3.0,0.08,1.5),cloth,false,Vector3(-0.12,0,0))
	for x in range(-6,7): _box(at+Vector3(x*0.22,2.20,0.65),Vector3(0.2,0.2+(x%2)*0.04,0.04),cloth)
	for x in [-0.7,0.0,0.7]:
		_cylinder(at+Vector3(x,1.41,0),0.16,0.18,"bronze")
		_box(at+Vector3(x,1.53,0),Vector3(0.35,0.06,0.12),"iron",false,Vector3(0,0.4,0))
	_lantern(at+Vector3(-1.35,1.94,0.65))

func _notice(at: Vector3) -> void:
	for x in [-0.65,0.65]: _box(at+Vector3(x,0.95,0),Vector3(0.12,1.9,0.12),"darkwood")
	_box(at+Vector3(0,1.3,0),Vector3(1.55,1.1,0.12),"wood",true)
	for x in [-0.45,0.0,0.42]:
		_box(at+Vector3(x,1.35,0.075),Vector3(0.3,0.63,0.02),"cloth")
		for y in range(3): _box(at+Vector3(x,1.55-y*0.13,0.09),Vector3(0.2,0.017,0.01),"black")
	_roof(at+Vector3(0,1.95,0),1.9,0.8)

func _boat(at: Vector3, scale_factor: float, canopy: bool) -> void:
	for i in range(6):
		var length := 5.6-i*0.21
		_box(at+Vector3(0,i*0.09*scale_factor,0),Vector3(length,0.11,1.35+i*0.15)*scale_factor,"darkwood")
	_box(at+Vector3(0,0.56*scale_factor,0),Vector3(4.5,0.1,1.9)*scale_factor,"wood")
	for x in [-2.45,2.45]: _box(at+Vector3(x*scale_factor,0.5*scale_factor,0),Vector3(1.2,0.12,1.7)*scale_factor,"wood",false,Vector3(0,0,0.15*sign(x)))
	if canopy:
		for x in [-1.3,1.3]:
			for z in [-0.72,0.72]: _box(at+Vector3(x,1.25,z)*scale_factor,Vector3(0.09,1.5,0.09)*scale_factor,"wood")
		_box(at+Vector3(0,2.0,0)*scale_factor,Vector3(3.3,0.14,2.0)*scale_factor,"jadecloth")
		_lantern(at+Vector3(1.4,1.7,0.7)*scale_factor)
	_box(at+Vector3(0,0.7*scale_factor,1.2*scale_factor),Vector3(5.2,0.05,0.08)*scale_factor,"rope")

func _bridge(at: Vector3) -> void:
	for i in range(15):
		var z := -7.5+i
		var rise := sin((i+0.5)/15.0*PI)*1.4
		_box(at+Vector3(0,rise,z),Vector3(3.0,0.3,1.02),"foundation")
		for x in [-1.4,1.4]:
			_box(at+Vector3(x,rise+0.55,z),Vector3(0.14,1.0,0.15),"foundation")
			_box(at+Vector3(x,rise+0.9,z),Vector3(0.18,0.12,1.1),"foundation")
	for z in [-7.4,7.4]: _lantern(at+Vector3(1.3,1.8,z))

func _crate(at: Vector3, size: float = 0.8, solid: bool = true) -> void:
	# Keep the exact original collision box. The visible cargo is assembled from reusable boards.
	if solid: _collision(at+Vector3(0,size*0.5,0),Vector3.ONE*size)
	_box(at+Vector3(0,size*0.49,0),Vector3(size*0.91,size*0.94,size*0.91),"black")
	for i in range(5):
		var offset := (-0.4+i*0.2)*size
		for side in [-1.0,1.0]:
			_beveled(at+Vector3(offset,size*0.5,side*size*0.48),Vector3(size*0.183,size*0.88,size*0.06),"cargowood")
			_beveled(at+Vector3(side*size*0.48,size*0.5,offset),Vector3(size*0.06,size*0.88,size*0.183),"cargowood")
		var shortened := 0.84 if i==0 else 0.98
		_beveled(at+Vector3((0.98-shortened)*size*0.5,size*0.98,offset),Vector3(size*shortened,size*0.05,size*0.182),"cargowood")
	for side in [-1.0,1.0]:
		for x in [-0.40,0.40]: _beveled(at+Vector3(x*size,size*0.5,side*size*0.526),Vector3(size*0.07,size*0.98,size*0.055),"trimwood")
		for y in [0.105,0.875]: _beveled(at+Vector3(0,y*size,side*size*0.53),Vector3(size*0.98,size*0.10,size*0.06),"trimwood")
		_beveled(at+Vector3(0,size*0.50,side*size*0.56),Vector3(size*0.075,size*1.12,size*0.055),"trimwood",Vector3(0,0,-0.73))
		for x in [-0.39,0.39]:
			for y in [0.15,0.84]:
				_box(at+Vector3(x*size,y*size,side*size*0.57),Vector3(size*0.10,size*0.12,size*0.018),"agediron")
				_cylinder(at+Vector3(x*size,y*size,side*size*0.587),size*0.017,size*0.018,"agediron",Vector3(PI*0.5,0,0))
	# A worn red shipping seal is a quiet shape on the planks, not a new interactive label.
	_box(at+Vector3(size*0.12,size*0.60,size*0.516),Vector3(size*0.19,size*0.26,size*0.008),"redcloth",false,Vector3(0,0,-0.11))

func _barrel(at: Vector3) -> void:
	# Three inclined stave sections give a true bulging silhouette with no changed collision.
	for i in range(16):
		var angle := i*TAU/16.0
		for section in range(3):
			var y := 0.16+section*0.29
			var radius := 0.304 if section != 1 else 0.34
			var tilt := 0.13 if section==0 else (-0.13 if section==2 else 0.0)
			var basis := Basis(Vector3.UP,-angle)*Basis(Vector3.FORWARD,tilt)
			_beveled_basis(at+Vector3(cos(angle)*radius,y,sin(angle)*radius),Vector3(0.065,0.32,0.132),"barrelwood",basis)
	for y in [0.13,0.40,0.72]:
		var radius := 0.36 if y!=0.40 else 0.378
		_cylinder(at+Vector3(0,y,0),radius,0.052,"agediron")
		for angle in [0.2,2.0,3.7,5.3]:
			_sphere(at+Vector3(cos(angle)*(radius+0.005),y,sin(angle)*(radius+0.005)),Vector3.ONE*0.035,"agediron")
	_cylinder(at+Vector3(0,0.895,0),0.315,0.035,"endwood")
	for x in [-0.16,0.0,0.16]:
		_box(at+Vector3(x,0.915,0),Vector3(0.009,0.004,sqrt(0.315*0.315-x*x)*1.95),"darkwood")
	_cylinder(at+Vector3(0.08,0.923,-0.1),0.035,0.015,"trimwood")
	_collision(at+Vector3(0,0.45,0),Vector3(0.74,0.9,0.74))

func _decorations() -> void:
	for p in [Vector3(-9.3,0,-5),Vector3(9.2,0,4.9),Vector3(-9.1,0,4.9)]:
		_crate(p,0.9)
		_crate(p+Vector3(0.95,0,0.1),0.65)
		_barrel(p+Vector3(0,0,-0.9))
	for p in [Vector3(-9.7,0,-3),Vector3(9.7,0,-2.4),Vector3(-8.5,0,5.5),Vector3(8.5,0,5.5)]:
		_beveled(p+Vector3(0,1.35,0),Vector3(0.13,2.7,0.13),"postwood")
		_beveled(p+Vector3(-0.28,2.65,0),Vector3(0.7,0.10,0.1),"trimwood")
		_mooring_hitch(p+Vector3(0,0.68,0),0.12)
		_lantern(p+Vector3(-0.5,2.18,0))
	for x in [-10.45,10.45]: _box(Vector3(x,0.17,0),Vector3(0.05,0.05,12.8),"rope")
	for i in range(38):
		var x := _rng.randf_range(-10.3,10.3)
		var z := _rng.randf_range(-6.3,6.3)
		if abs(x)<7.5 and abs(z)<5: continue
		_box(Vector3(x,0.058,z),Vector3(0.08,0.015,0.23),"moss",false,Vector3(0,_rng.randf()*TAU,0))

func _rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "FineRain"
	rain.amount = 180
	rain.lifetime = 1.15
	rain.preprocess = 1.15
	rain.position = Vector3(0,8,0)
	rain.visibility_aabb = AABB(Vector3(-18,-12,-18),Vector3(36,25,36))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(16,0.5,15)
	process.direction = Vector3(-0.14,-1,0.08)
	process.spread = 1.5
	process.initial_velocity_min = 8.0
	process.initial_velocity_max = 10.0
	process.gravity = Vector3(0,-2,0)
	process.color = Color(0.51,0.69,0.80,0.22)
	rain.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012,0.22,0.012)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.6,0.76,0.85,0.32)
	mesh.material = material
	rain.draw_pass_1 = mesh
	add_child(rain)

func _bench(at: Vector3, length: float = 2.0) -> void:
	_box(at+Vector3(0,0.49,0),Vector3(length,0.13,0.48),"wood",true)
	for x in [-length*0.35,length*0.35]: _box(at+Vector3(x,0.22,0),Vector3(0.13,0.44,0.35),"darkwood")
	_box(at+Vector3(0,0.22,0),Vector3(length*0.8,0.08,0.10),"darkwood")

func _jar(at: Vector3, radius: float = 0.22) -> void:
	_sphere(at+Vector3(0,radius,0),Vector3(radius*2,radius*2.4,radius*2),"ceramic")
	_cylinder(at+Vector3(0,radius*2.2,0),radius*0.55,radius*0.3,"ceramic")
	_cylinder(at+Vector3(0,radius*2.36,0),radius*0.48,0.014,"black")

func _town_life() -> void:
	# Distinct centre and connected market routes, not the dungeon's empty battle rectangle.
	var well := Vector3(-3.7,0,1.65)
	_box(well+Vector3(0,0.12,0),Vector3(1.9,0.24,1.9),"foundation",true)
	_collision(well+Vector3(0,0.58,0),Vector3(1.55,1.15,1.55))
	_cylinder(well+Vector3(0,0.65,0),0.59,0.16,"black")
	for i in range(8):
		var angle := i*TAU/8.0
		for y in [0.36,0.64,0.92]: _box(well+Vector3(cos(angle)*0.68,y,sin(angle)*0.68),Vector3(0.24,0.25,0.60),"stone",false,Vector3(0,-angle,0))
	for x in [-0.91,0.91]: _box(well+Vector3(x,1.36,0),Vector3(0.12,2.5,0.12),"darkwood")
	_box(well+Vector3(0,2.42,0),Vector3(2.1,0.16,0.17),"wood")
	_cylinder(well+Vector3(0,2.14,0),0.16,0.17,"wood",Vector3(PI*0.5,0,0))
	_cylinder(well+Vector3(0,1.54,0),0.015,1.1,"rope")
	_roof(well+Vector3(0,2.5,0),2.55,1.7)
	_cylinder(well+Vector3(1.13,0.25,0.15),0.21,0.5,"wood")
	for y in [0.08,0.43]: _cylinder(well+Vector3(1.13,y,0.15),0.22,0.045,"iron")
	_bench(Vector3(-3.6,0,3.65),2.25)
	_bench(Vector3(2.9,0,-3.2),2.15)
	_stall(Vector3(-8.0,0,1.6),"jadecloth")
	_sign(Vector3(-8.0,1.68,2.15),"临川茶",0.0045)
	_bench(Vector3(-7.8,0,3.4),1.6)
	for x in [-8.6,-8.0,-7.4]: _jar(Vector3(x,1.37,1.6),0.13)
	_stall(Vector3(5.9,0,2.35),"cloth")
	_sign(Vector3(5.9,1.70,2.90),"山草药铺",0.0043)
	for x in [5.2,5.7,6.2,6.6]:
		_jar(Vector3(x,1.38,2.4),0.12)
		for n in range(3): _sphere(Vector3(x+n*0.10,1.44,2.15),Vector3(0.14,0.10,0.12),"fruit")
	_crate(Vector3(7.3,0,2.0),0.7)
	_jar(Vector3(7.3,0,3.0),0.30)
	var shrine := Vector3(3.6,0,-5.3)
	_box(shrine+Vector3(0,0.18,0),Vector3(1.85,0.36,1.2),"foundation",true)
	_box(shrine+Vector3(0,0.95,0),Vector3(1.3,1.3,0.7),"darkwood")
	_box(shrine+Vector3(0,1.06,0.38),Vector3(0.8,0.9,0.03),"black")
	_cylinder(shrine+Vector3(0,0.82,0.45),0.23,0.32,"bronze")
	_sphere(shrine+Vector3(0,1.13,0.45),Vector3(0.30,0.35,0.20),"bronze")
	_roof(shrine+Vector3(0,1.6,0),2.1,1.35)
	for x in [-0.54,0.54]: _jar(shrine+Vector3(x,0.35,0.62),0.12)
	_box(Vector3(3.65,1.55,-7.1),Vector3(3.1,0.17,0.25),"darkwood")
	for x in [2.2,5.1]: _box(Vector3(x,1.85,-7.1),Vector3(0.21,3.7,0.21),"wood")
	_roof(Vector3(3.65,3.6,-7.1),3.7,1.5)
	_roof(Vector3(3.65,2.6,-7.1),4.1,1.9)
	var tree := Vector3(-5.6,0,1.5)
	_box(tree+Vector3(0,0.12,0),Vector3(1.15,0.24,1.15),"foundation",true)
	_cylinder(tree+Vector3(0,1.15,0),0.14,2.3,"darkwood")
	_collision(tree+Vector3(0,1.0,0),Vector3(0.35,2.0,0.35))
	for side in [-1.0,1.0]: _cylinder(tree+Vector3(side*0.3,2.0,0),0.07,1.1,"wood",Vector3(0,0,side*-0.65))
	_foliage(tree+Vector3(0,2.65,0))
	for x in [-0.3,0.25]: _box(tree+Vector3(x,2.0,0.22),Vector3(0.05,0.65,0.025),"redcloth")

func _ferry_cargo() -> void:
	# Only the perimeter has cargo; central combat space remains unobstructed.
	for p in [Vector3(-8.8,0,-3.8),Vector3(8.8,0,-4.6)]:
		_crate(p,0.92)
		_crate(p+Vector3(0.14,0.92,0.05),0.65)
		_crate(p+Vector3(-0.9,0,0),0.65)
		_canvas(p+Vector3(0,1.56,0),1.23,1.05)
	for p in [Vector3(-9.4,0,2.3),Vector3(9.4,0,1.8)]:
		_cylinder(p+Vector3(0,0.35,0),0.33,0.7,"wood")
		for y in [0.08,0.62]: _cylinder(p+Vector3(0,y,0),0.55,0.10,"wood")
		for y in [0.22,0.3,0.38,0.46]: _cylinder(p+Vector3(0,y,0),0.40,0.07,"rope")
		_collision(p+Vector3(0,0.35,0),Vector3(1.1,0.7,1.1))
	_boat(Vector3(14.1,-0.43,1.8),1.1,true)
	_box(Vector3(11.3,0.06,1.8),Vector3(2.1,0.13,1.1),"wood")

func _foliage(at: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mm.mesh = plane
	mm.instance_count = 680
	for i in range(mm.instance_count):
		var cluster := Vector3(cos(float(i%7)*TAU/7.0)*0.60,float(i%3)*0.16,sin(float(i%7)*TAU/7.0)*0.40)
		var offset := Vector3(_rng.randf_range(-0.55,0.55),_rng.randf_range(-0.35,0.35),_rng.randf_range(-0.45,0.45))
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.8,0.8),_rng.randf()*TAU,_rng.randf_range(-0.8,0.8)))
		mm.set_instance_transform(i,Transform3D(basis.scaled_local(Vector3(0.13,1.0,0.23)),at+cluster+offset))
	var node := MultiMeshInstance3D.new()
	node.name = "CamphorLeaves"
	node.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/environment/waterfront_leaf.gdshader")
	node.material_override = mat
	add_child(node)


func _reflections() -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("lamp_count",_water_lights.size())
		while _water_lights.size() < 16: _water_lights.append(Vector4.ZERO)
		_water_material.set_shader_parameter("lamps",_water_lights)
	if RenderingServer.get_current_rendering_method() != "forward_plus": return
	var probe := ReflectionProbe.new()
	probe.name = "WetDockReflectionCapture"
	probe.position = Vector3(0,1.4,0)
	probe.size = Vector3(29,10,24)
	probe.origin_offset = Vector3(0,1,0)
	probe.box_projection = true
	probe.intensity = 0.85
	probe.max_distance = 70.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)

func _harbour() -> void:
	# Open canal replaces the close wall of bright houses. Low boats frame the rear edge.
	_cargo_ship(Vector3(-5.8,-0.25,-9.0))
	_loading_shelter(Vector3(-13.5,-0.15,-8.6),3.9,2.8,2.2)
	_loading_shelter(Vector3(14.2,-0.10,-12.8),4.2,3.2,2.5)
	# Separate landing clusters leave actual water mouths between them, instead of a continuous straight quay wall.
	var landings := [Vector3(-10,-10.8,7.3),Vector3(-0.5,-11.8,4.2),Vector3(8.9,-13.0,7.2),Vector3(-11,-15.8,8.0),Vector3(0.8,-17.3,9.0),Vector3(13,-18.3,7.0)]
	for landing in landings:
		var width: float = landing.z
		for plank in range(int(width/0.23)):
			var px: float = landing.x-width*0.5+(plank+0.5)*0.23
			_beveled(Vector3(px,-0.18,landing.y),Vector3(0.215,0.10,1.05),"postwood")
		for dz in [-0.35,0.35]: _beveled(Vector3(landing.x,-0.29,landing.y+dz),Vector3(width,0.12,0.09),"postwood")
		var count := maxi(2,int(width/2.7))
		for i in range(count+1):
			var x: float = landing.x-width*0.5+0.16+(width-0.32)*float(i)/count
			_box(Vector3(x,-0.55,landing.y),Vector3(0.16,1.5,0.16),"wood")
			_box(Vector3(x,0.48,landing.y-0.36),Vector3(0.09,1.1,0.09),"darkwood")
			if i==0: _lantern(Vector3(x,1.2,landing.y-0.36),false)
		_rope_curve(Vector3(landing.x-width*0.5+0.2,0.77,landing.y-0.36),Vector3(landing.x+width*0.5-0.2,0.77,landing.y-0.36),0.2,0.012)
	var links := [Vector3(-10,-13.3,5.0),Vector3(1,-14.55,5.5),Vector3(12,-15.65,5.3)]
	for link in links:
		var count := int(link.z/0.24)
		for plank in range(count):
			var t := (plank+0.5)/count
			var z: float = link.y+(t-0.5)*link.z
			var y := -0.2+sin(t*PI)*0.22
			_beveled(Vector3(link.x,y,z),Vector3(1.08,0.10,link.z/count-0.018),"postwood")
		# The bridge has open arched rails and visible water between its supports.
		for side in [-0.47,0.47]:
			var previous := Vector3(link.x+side,0.60,link.y-link.z*0.5)
			for segment in range(1,13):
				var t := float(segment)/12.0
				var point := Vector3(link.x+side,0.60+sin(t*PI)*0.22,link.y+(t-0.5)*link.z)
				_rod(previous,point,0.035,"postwood")
				if segment%3==0: _beveled(point-Vector3(0,0.41,0),Vector3(0.065,0.82,0.065),"postwood")
				previous=point
		for offset in [-link.z*0.43,link.z*0.43]: _box(Vector3(link.x,-0.55,link.y+offset),Vector3(0.15,1.4,0.15),"wood")
	# The lit shore follows the candidate view's depth diagonal, so its windows and eaves actually enter the upper quarter.
	var shore := [Vector3(-12.5,-0.18,-17.0),Vector3(-6.4,-0.18,-20.1),Vector3(3.2,-0.18,-19.2),Vector3(9.0,-0.18,-23.2)]
	var widths := [3.7,3.4,3.1,3.3]
	var heights := [1.85,3.10,1.75,3.50]
	for i in range(shore.size()):
		_wharf_shed(shore[i],widths[i],2.25,heights[i])
		# A projecting veranda and awning break the repeated straight wall silhouette.
		_box(shore[i]+Vector3(0,0.1,1.55),Vector3(widths[i]+0.6,0.18,1.1),"wood")
		for dx in [-widths[i]*0.43,widths[i]*0.43]:
			_box(shore[i]+Vector3(dx,1.05,1.8),Vector3(0.11,2.0,0.11),"darkwood")
		if i % 2 == 0: _canvas(shore[i]+Vector3(0,1.95,1.6),widths[i]+0.7,1.4)
	# One taller roof behind the front row supplies a second silhouette, rather than another full parallel wall.
	_wharf_shed(Vector3(7.0,-0.2,-25.0),2.8,2.8,4.1)
	for i in range(3):
		_lantern(Vector3(-9.8+i*8.9,2.15,-17.2-i*1.1),false)
	_boat(Vector3(6.0,-0.48,-14.8),0.8,false)
	if mode == "ferry": _ferry_cargo()
	else: _boat(Vector3(13.1,-0.48,2.4),0.95,true)
	# Foreground mooring columns and hanging lanterns frame the stage outside playable bounds.
	for p in [Vector3(-3.0,0,8.7),Vector3(12.4,0,6.4)]:
		_box(p+Vector3(0,1.9,0),Vector3(0.24,3.8,0.24),"darkwood")
		_box(p+Vector3(-0.45,3.5,0),Vector3(1.2,0.16,0.15),"wood")
		for y in [0.7,0.9,1.1]: _cylinder(p+Vector3(0,y,0),0.19,0.09,"rope")
		_lantern(p+Vector3(-0.8,2.85,0),true)
	# Sagging lashings and one fishing net add fine lines only around the perimeter.
	_rope_curve(Vector3(-9.7,0.78,-5.9),Vector3(-8.6,1.05,-8.0),0.30,0.018)
	_rope_curve(Vector3(-2.0,0.74,-6.3),Vector3(-1.7,0.95,-8.1),0.27,0.018)
	_rope_curve(Vector3(10.2,0.73,2.8),Vector3(12.3,0.9,2.0),0.42,0.018)
	for z in range(7):
		_rope_curve(Vector3(-10.36,0.85,-4.7+z*0.20),Vector3(-10.36,0.15,-4.9+z*0.20),0.10,0.008)
	for y in range(5):
		_rope_curve(Vector3(-10.36,0.16+y*0.14,-4.9),Vector3(-10.36,0.16+y*0.14,-3.4),0.08,0.008)
	# Three purposeful leaf/drift clusters stay low at cargo edges; the central battle floor stays quiet.
	for cluster in [Vector3(-8.1,0.079,-4.8),Vector3(8.9,0.079,2.8),Vector3(-5.8,0.079,5.55)]:
		for i in range(17):
			var angle := _rng.randf()*TAU
			var radius := _rng.randf_range(0.05,0.65)
			var at: Vector3 = cluster+Vector3(cos(angle)*radius,0,sin(angle)*radius*0.6)
			_box(at,Vector3(_rng.randf_range(0.055,0.10),0.008,_rng.randf_range(0.10,0.18)),"redcloth" if i%3==0 else "rope",false,Vector3(0,angle,0))
	_rope_coil(Vector3(8.55,0.10,4.65),0.26)
	_rope_coil(Vector3(-8.4,0.10,-2.15),0.21)
	_broken_basket(Vector3(-9.5,0.08,-1.45))
	# Outside the walkable perimeter, a low loading pile interrupts the long foreground edge without a roof over any player route.
	_box(Vector3(-8.5,-0.04,7.65),Vector3(2.6,0.12,1.3),"darkwood")
	_crate(Vector3(-8.9,0.02,7.7),0.90,false)
	_crate(Vector3(-7.75,0.02,7.9),0.72,false)
	_crate(Vector3(-8.9,0.92,7.72),0.55,false)
	_rope_curve(Vector3(-9.8,0.55,6.8),Vector3(-7.7,0.6,8.0),0.34,0.02)
	# This lower waterside store only cuts the foreground; its roof lies below every near-edge player's sightline.
	var store := Vector3(-3.6,0,10.6)
	_box(store+Vector3(0,0.15,0),Vector3(5.0,1.9,2.0),"darkwood")
	_roof(store+Vector3(0,1.1,0),5.6,2.5,0.65)
	for x in [-2.4,2.4]:
		_beveled(store+Vector3(x,0.15,0.91),Vector3(0.14,1.9,0.14),"postwood")
	_box(Vector3(-5.8,-0.24,8.2),Vector3(3.0,0.15,1.7),"postwood")
	# A coarse collapsed fishing net drapes across this lower landing, in one purposeful cluster.
	for row in range(7):
		if row in [2,5]: continue
		var x := -7.1+row*0.28+sin(row*1.7)*0.055
		_rope_curve(Vector3(x,0.55+cos(row)*0.07,7.5+sin(row)*0.06),Vector3(x+0.16+sin(row)*0.12,0.08,8.8+cos(row)*0.15),0.16+sin(row)*0.07,0.015)
	for row in range(6):
		if row == 3: continue
		var t := float(row)/5.0
		var y := lerpf(0.55,0.08,t)-sin(t*PI)*0.16
		_rope_curve(Vector3(-7.1+0.16*t,y,7.5+1.3*t),Vector3(-5.42+0.16*t+sin(row)*0.09,y,7.5+1.3*t),0.07+(row%3)*0.025,0.014)
	_rope_curve(Vector3(-6.48,0.32,7.9),Vector3(-6.08,-0.28,8.55),0.25,0.016)
	_rope_coil(Vector3(-5.0,0.01,7.9),0.34)
	# Sparse flags sit to the side, never in a telegraph lane.
	_box(Vector3(-10.2,1.3,-4.0),Vector3(0.10,2.6,0.10),"wood")
	_box(Vector3(-10.2,2.4,-4.0),Vector3(0.06,0.12,1.8),"wood")
	_box(Vector3(-10.2,1.75,-4.0),Vector3(0.025,1.3,0.65),"cloth")

func _loading_shelter(at: Vector3, width: float, depth: float, height: float) -> void:
	_box(at+Vector3(0,-0.16,0),Vector3(width+0.5,0.16,depth+0.5),"postwood")
	for x in [-width*0.44,width*0.44]:
		for z in [-depth*0.4,depth*0.4]:
			_beveled(at+Vector3(x,height*0.5,z),Vector3(0.17,height,0.17),"postwood")
		_beveled(at+Vector3(x,height-0.08,0),Vector3(0.13,0.17,depth+0.3),"trimwood")
	_canvas(at+Vector3(0,height,0),width+0.6,depth+0.6)
	# A partial rear plank screen leaves water and silhouetted cargo visible through the roof supports.
	for i in range(5): _beveled(at+Vector3(-width*0.36+i*0.2,0.65,-depth*0.42),Vector3(0.17,1.3,0.07),"postwood")
	_crate(at+Vector3(-width*0.25,0,-depth*0.15),0.7,false)
	_barrel(at+Vector3(width*0.27,0,-depth*0.15))
	_lantern(at+Vector3(width*0.36,height-0.35,depth*0.4),true)

func _canvas(at: Vector3, width: float, depth: float) -> void:
	# Real sagging woven canvas with irregular stitched hem; not an unbroken flat blue box.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 20
	var rows := 6
	for x in range(columns):
		for z in range(rows):
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for delta in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((x+delta.x)/columns,(z+delta.y)/rows)
				var sag := -sin(uv.x*PI)*0.13-sin(uv.y*PI)*0.10
				var fold := sin(uv.x*PI*12.0)*0.025*(0.4+uv.y)
				points.append(at+Vector3((uv.x-0.5)*width,sag+fold-uv.y*0.16,(uv.y-0.5)*depth))
				uvs.append(uv)
			for tri in [[0,1,2],[0,2,3]]:
				var normal := (points[tri[2]]-points[tri[0]]).cross(points[tri[1]]-points[tri[0]]).normalized()
				_surface_triangle(surface,points[tri[0]],points[tri[1]],points[tri[2]],normal,uvs[tri[0]],uvs[tri[1]],uvs[tri[2]])
	surface.generate_tangents()
	var node := MeshInstance3D.new()
	node.name = "SaggingStitchedAwning"
	node.mesh = surface.commit()
	node.material_override = _materials["canvas"]
	add_child(node)
	for i in range(15):
		var t := float(i)/14.0
		var hem_y := -sin(t*PI)*0.13+sin(t*PI*12.0)*0.035-0.16
		_box(at+Vector3((t-0.5)*width,hem_y-0.06,depth*0.5),Vector3(width/14.0*0.97,0.13,0.018),"cloth")

func _wharf_shed(at: Vector3, width: float, depth: float, height: float) -> void:
	_box(at+Vector3(0,height*0.5,0),Vector3(width,height,depth),"darkwood")
	for x in range(int(width/0.24)):
		_box(at+Vector3(-width*0.5+x*0.24,height*0.5,depth*0.51),Vector3(0.20,height,0.035),"wood")
	for y in [0.25,height-0.20]: _box(at+Vector3(0,y,depth*0.52),Vector3(width,0.16,0.09),"darkwood")
	for x in [-width*0.28,width*0.28]:
		_box(at+Vector3(x,height*0.6,depth*0.53),Vector3(0.65,1.0,0.05),"window")
		for k in range(4): _box(at+Vector3(x-0.3+k*0.2,height*0.6,depth*0.55),Vector3(0.045,1.0,0.05),"darkwood")
		_box(at+Vector3(x,height*0.6,depth*0.55),Vector3(0.67,0.045,0.05),"darkwood")
	for x in [-width*0.28,width*0.28]:
		for dx in [-0.38,0.38]: _beveled(at+Vector3(x+dx,height*0.6,depth*0.565),Vector3(0.065,1.12,0.065),"trimwood")
		for y in [-0.55,0.55]: _beveled(at+Vector3(x,height*0.6+y,depth*0.565),Vector3(0.82,0.065,0.065),"trimwood")
	if at.x>0.0:
		_beveled(at+Vector3(-width*0.28-0.32,height*0.6,depth*0.61),Vector3(0.22,1.01,0.055),"postwood",Vector3(0,-0.24,0))
	_box(at+Vector3(0,0.9,depth*0.53),Vector3(0.7,1.8,0.05),"black")
	_roof(at+Vector3(0,height,0),width+0.7,depth+0.6)
	_lantern(at+Vector3(-width*0.36,height-0.25,depth*0.6),true)
	_box(at+Vector3(0,-0.25,0),Vector3(width+0.6,0.2,depth+0.6),"wood")
	for x in [-width*0.45,width*0.45]:
		for z in [-depth*0.4,depth*0.4]: _box(at+Vector3(x,-0.6,z),Vector3(0.18,1.6,0.18),"darkwood")

func _cargo_ship(at: Vector3) -> void:
	_ship_hull(at,8.6,2.65)
	# Fully built timber cabin, unlike the earlier flat canvas rectangles.
	_box(at+Vector3(-0.3,1.175,0),Vector3(3.9,1.30,2.1),"darkwood")
	for x in [-1.7,-0.7,0.3,1.3]:
		_beveled(at+Vector3(x,1.175,1.08),Vector3(0.13,1.30,0.13),"trimwood")
		_box(at+Vector3(x+0.3,1.25,1.10),Vector3(0.45,0.65,0.04),"window")
		for y in [1.0,1.2,1.4]: _box(at+Vector3(x+0.3,y,1.14),Vector3(0.48,0.035,0.04),"darkwood")
	for height in [0.58,1.75]: _beveled(at+Vector3(-0.3,height,1.105),Vector3(3.95,0.12,0.11),"postwood")
	for x in [-2.15,1.65]:
		for y in [0.75,1.06,1.62]: _beveled(at+Vector3(x,y,0),Vector3(0.12,0.14,2.12),"postwood")
	_roof(at+Vector3(-0.3,1.85,0),4.7,2.7,0.65)
	_lantern(at+Vector3(-2.35,1.7,0.9),true)
	_lantern(at+Vector3(2.35,1.7,0.9),true)
	for x in [-2.6,2.5]: _crate(at+Vector3(x,0.7,0),0.6,false)
	# Bow steering oar, mast, and tied rope give the boat an individual silhouette.
	_box(at+Vector3(3.1,1.0,0),Vector3(1.7,0.08,0.12),"wood",false,Vector3(0,-0.3,-0.2))
	_box(at+Vector3(1.5,2.2,-0.2),Vector3(0.10,3.4,0.10),"darkwood")
	_box(at+Vector3(1.5,3.65,0),Vector3(0.10,0.12,1.5),"wood")


func _rod(from: Vector3, to: Vector3, radius: float, material: String) -> void:
	var difference := to-from
	if difference.length_squared() < 0.000001: return
	if not _cylinders.has(material): _cylinders[material] = []
	var basis := Basis(Quaternion(Vector3.UP,difference.normalized()))
	_cylinders[material].append(Transform3D(basis.scaled_local(Vector3(radius*2,difference.length(),radius*2)),(from+to)*0.5))

func _rope_curve(from: Vector3, to: Vector3, sag: float, radius: float = 0.016) -> void:
	var previous := from
	for i in range(1,13):
		var t := float(i)/12.0
		var next := from.lerp(to,t)+Vector3.DOWN*sin(t*PI)*sag
		_rod(previous,next,radius,"rope")
		previous = next

func _hull_point(at: Vector3, length: float, beam: float, ring: int, level: int) -> Vector3:
	var t := float(ring)/14.0*2.0-1.0
	var section := [Vector2(-1,0.70),Vector2(-0.93,0.28),Vector2(-0.55,-0.08),Vector2(0,-0.19),Vector2(0.55,-0.08),Vector2(0.93,0.28),Vector2(1,0.70)]
	var profile: Vector2 = section[level]
	var taper := sqrt(maxf(0.006,1.0-t*t))
	var rise := smoothstep(0.58,1.0,absf(t))*0.65
	return at+Vector3(t*length*0.5,profile.y+rise,profile.x*beam*0.5*taper)

func _ship_hull(at: Vector3, length: float, beam: float) -> void:
	# Curved, pointed sectioned hull and raised sheer remain visible beyond both cabin ends.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(14):
		for level in range(6):
			var a := _hull_point(at,length,beam,ring,level)
			var b := _hull_point(at,length,beam,ring+1,level)
			var c := _hull_point(at,length,beam,ring+1,level+1)
			var d := _hull_point(at,length,beam,ring,level+1)
			for point in [a,c,b,a,d,c]:
				surface.set_uv(Vector2(point.x*0.3,point.y))
				surface.add_vertex(point)
	# A real top deck closes the hull; the pointed ends are not rectangular slab extensions.
	for ring in range(14):
		var a := _hull_point(at,length,beam,ring,0)
		var b := _hull_point(at,length,beam,ring+1,0)
		var c := _hull_point(at,length,beam,ring+1,6)
		var d := _hull_point(at,length,beam,ring,6)
		for point in [a,b,c,a,c,d]:
			surface.set_uv(Vector2(point.x*0.2,point.z*0.5))
			surface.add_vertex(point)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "CurvedCargoHull"
	node.mesh = surface.commit()
	node.material_override = _materials["hullwood"]
	add_child(node)
	for side in [0,6]:
		for ring in range(14): _rod(_hull_point(at,length,beam,ring,side),_hull_point(at,length,beam,ring+1,side),0.065,"trimwood")
	for side in [1,5]:
		for ring in range(14):
			_rod(_hull_point(at,length,beam,ring,side),_hull_point(at,length,beam,ring+1,side),0.025,"postwood")
			for fraction in [0.34,0.68]:
				var outer := 0 if side==1 else 6
				var a := _hull_point(at,length,beam,ring,side).lerp(_hull_point(at,length,beam,ring,outer),fraction)
				var b := _hull_point(at,length,beam,ring+1,side).lerp(_hull_point(at,length,beam,ring+1,outer),fraction)
				_rod(a,b,0.018,"postwood")
			if ring%2==0: _rod(_hull_point(at,length,beam,ring,side),_hull_point(at,length,beam,ring,0 if side==1 else 6),0.028,"trimwood")
	_box(at+Vector3(length*0.5+0.25,0.48,0),Vector3(0.12,1.45,0.55),"darkwood",false,Vector3(0,0,0.18))
	_rod(at+Vector3(1.5,3.7,-0.2),at+Vector3(-3.1,1.0,-0.8),0.014,"rope")
	_rod(at+Vector3(1.5,3.7,-0.2),at+Vector3(3.4,1.1,0.9),0.014,"rope")

func _flush_deck() -> void:
	for variant in range(4):
		if _deck_batches[variant].is_empty(): continue
		var chip_x := 0.04+variant*0.025
		var chip_z := 0.008+variant*0.004
		var outline := [Vector2(-0.5,-0.5+chip_z),Vector2(-0.5+chip_x,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5-chip_z*2),Vector2(0.5-chip_x,0.5),Vector2(-0.5,0.5)]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(outline.size()):
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i+1)%outline.size()]
			for point in [Vector3(0,0.5,0),Vector3(a.x,0.5,a.y),Vector3(b.x,0.5,b.y)]:
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(point.x+0.5,point.z+0.5))
				surface.add_vertex(point)
			var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()
			for point in [Vector3(a.x,-0.5,a.y),Vector3(b.x,0.5,b.y),Vector3(a.x,0.5,a.y),Vector3(a.x,-0.5,a.y),Vector3(b.x,-0.5,b.y),Vector3(b.x,0.5,b.y)]:
				surface.set_normal(normal)
				surface.set_uv(Vector2(point.x+point.z,point.y+0.5))
				surface.add_vertex(point)
		# Normal maps need a valid tangent frame on these custom worn-board meshes.
		surface.generate_tangents()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = surface.commit()
		mm.instance_count = _deck_batches[variant].size()
		for i in range(mm.instance_count): mm.set_instance_transform(i,_deck_batches[variant][i])
		var node := MultiMeshInstance3D.new()
		node.name = "WornDockBoards%d" % variant
		node.multimesh = mm
		node.material_override = _materials["deck%d" % variant]
		add_child(node)
		_deck_batches[variant].clear()


func _rope_coil(at: Vector3, radius: float) -> void:
	for loop in range(3):
		var r := radius+loop*0.042
		for i in range(24):
			var angle := float(i)*TAU/24.0
			var next := float(i+1)*TAU/24.0
			_rod(at+Vector3(cos(angle)*r,loop*0.013,sin(angle)*r),at+Vector3(cos(next)*r,loop*0.013,sin(next)*r),0.016,"rope")
	_rope_curve(at+Vector3(radius+0.08,0.01,0),at+Vector3(radius+0.45,0.0,0.18),0.018,0.015)

func _broken_basket(at: Vector3) -> void:
	for i in range(10):
		var angle := i*TAU/10.0
		_rod(at+Vector3(cos(angle)*0.22,0,sin(angle)*0.22),at+Vector3(cos(angle)*0.34,0.48 if i<8 else 0.27,sin(angle)*0.34),0.014,"rope")
	for level in range(3):
		var y := 0.08+level*0.18
		var radius := 0.23+level*0.045
		for i in range(22 if level<2 else 16):
			var a := i*TAU/24.0
			var b := (i+1)*TAU/24.0
			_rod(at+Vector3(cos(a)*radius,y,sin(a)*radius),at+Vector3(cos(b)*radius,y,sin(b)*radius),0.012,"rope")


func _detail_materials() -> void:
	# Dedicated prop materials avoid multiplying an already dark albedo by another dark tint.
	var tints := {"postwood":Color(0.48,0.37,0.26),"trimwood":Color(0.52,0.41,0.29),"cargowood":Color(0.55,0.43,0.30),"barrelwood":Color(0.46,0.35,0.24),"endwood":Color(0.51,0.40,0.29),"hullwood":Color(0.38,0.30,0.23)}
	for key: String in tints:
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/environment/waterfront_propwood.gdshader")
		material.set_shader_parameter("base_tint",tints[key])
		material.set_shader_parameter("force_endgrain",key=="endwood")
		material.set_shader_parameter("world_grain",key=="hullwood")
		if ResourceLoader.exists("res://assets/environment/dock_aged_wood.png"):
			material.set_shader_parameter("albedo_tex",load("res://assets/environment/dock_aged_wood.png"))
			material.set_shader_parameter("use_albedo",true)
		_materials[key] = material
	var canvas := ShaderMaterial.new()
	canvas.shader = load("res://assets/environment/waterfront_canvas.gdshader")
	_materials["canvas"] = canvas
	var iron := ShaderMaterial.new()
	iron.shader = load("res://assets/environment/waterfront_agediron.gdshader")
	_materials["agediron"] = iron
	var rope := ShaderMaterial.new()
	rope.shader = load("res://assets/environment/waterfront_rope.gdshader")
	_materials["ropefine"] = rope
	for i in range(3):
		var tile := ShaderMaterial.new()
		tile.shader = load("res://assets/environment/waterfront_clay.gdshader")
		tile.set_shader_parameter("base_tint",Vector3(0.022+i*0.003,0.035+i*0.003,0.043+i*0.002))
		_materials["tileedge%d" % i] = tile
	var roof := ShaderMaterial.new()
	roof.shader = load("res://assets/environment/waterfront_clay.gdshader")
	roof.set_shader_parameter("base_tint",Vector3(0.016,0.026,0.034))
	_materials["tile"] = roof
	_materials["tileedge"] = _materials["tileedge1"]
	var window := ShaderMaterial.new()
	window.shader = load("res://assets/environment/waterfront_window.gdshader")
	_materials["window"] = window

func _beveled(at: Vector3, size: Vector3, material: String, rotation: Vector3 = Vector3.ZERO) -> void:
	_beveled_basis(at,size,material,Basis.from_euler(rotation))

func _beveled_basis(at: Vector3, size: Vector3, material: String, basis: Basis) -> void:
	if not _bevels.has(material): _bevels[material] = []
	_bevels[material].append(Transform3D(basis.scaled_local(size),at))

func _surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	# Godot front faces are CW: this guards the exact winding defect encountered in visual-v2.
	var points := [a,b,c]
	var uvs := [ua,ub,uc]
	if (b-a).cross(c-a).dot(normal)>0:
		points = [a,c,b]
		uvs = [ua,uc,ub]
	for i in range(3):
		surface.set_normal(normal)
		surface.set_uv(uvs[i])
		surface.add_vertex(points[i])

func _make_bevel_mesh() -> ArrayMesh:
	var outline := [Vector2(-0.42,-0.5),Vector2(0.42,-0.5),Vector2(0.5,-0.42),Vector2(0.5,0.42),Vector2(0.42,0.5),Vector2(-0.42,0.5),Vector2(-0.5,0.42),Vector2(-0.5,-0.42)]
	var ys := [-0.5,-0.45,0.45,0.5]
	var scales := [0.90,1.0,1.0,0.90]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(3):
		for i in range(8):
			var j := (i+1)%8
			var p: Vector2 = outline[i]
			var q: Vector2 = outline[j]
			var a := Vector3(p.x*scales[ring],ys[ring],p.y*scales[ring])
			var b := Vector3(q.x*scales[ring],ys[ring],q.y*scales[ring])
			var c := Vector3(q.x*scales[ring+1],ys[ring+1],q.y*scales[ring+1])
			var d := Vector3(p.x*scales[ring+1],ys[ring+1],p.y*scales[ring+1])
			var normal := (b-a).cross(c-a).normalized()
			if normal.dot((a+b+c+d)*0.25)<0: normal = -normal
			_surface_triangle(surface,a,b,c,normal,Vector2(i/8.0,ys[ring]+0.5),Vector2((i+1)/8.0,ys[ring]+0.5),Vector2((i+1)/8.0,ys[ring+1]+0.5))
			_surface_triangle(surface,a,c,d,normal,Vector2(i/8.0,ys[ring]+0.5),Vector2((i+1)/8.0,ys[ring+1]+0.5),Vector2(i/8.0,ys[ring+1]+0.5))
	for top in [false,true]:
		var y := 0.5 if top else -0.5
		var normal := Vector3.UP if top else Vector3.DOWN
		for i in range(8):
			var p: Vector2 = outline[i]*0.90
			var q: Vector2 = outline[(i+1)%8]*0.90
			_surface_triangle(surface,Vector3(0,y,0),Vector3(p.x,y,p.y),Vector3(q.x,y,q.y),normal,Vector2(0.5,0.5),p+Vector2.ONE*0.5,q+Vector2.ONE*0.5)
	surface.generate_tangents()
	return surface.commit()

func _mooring_hitch(at: Vector3, radius: float) -> void:
	for turn in range(2):
		for i in range(16):
			var a := i*TAU/16.0
			var b := (i+1)*TAU/16.0
			_rod(at+Vector3(cos(a)*radius,turn*0.055+i*0.0015,sin(a)*radius),at+Vector3(cos(b)*radius,turn*0.055+(i+1)*0.0015,sin(b)*radius),0.025,"ropefine")
	_rope_curve(at+Vector3(radius,0.07,0),at+Vector3(-radius,0.19,0.05),0.025,0.023)
	_rope_curve(at+Vector3(-radius,0.19,0.05),at+Vector3(-radius-0.09,-0.12,0.13),0.06,0.020)
