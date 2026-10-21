extends Node3D

const ROOM_SCENE = preload("res://scripts/room.gd")
const MOVE_SPEED: float = 5.2
const NORMAL_DAMAGE: float = 24.0
const RARE_DAMAGE: float = 46.0
const ATTACK_RANGE: float = 2.55

var hero: Node3D
var body: Sprite3D
var sword: MeshInstance3D
var camera: Camera3D
var hud: Label
var notice: Label
var inventory: PanelContainer
var inventory_text: Label
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var summons: Array[Dictionary] = []
var aim: Vector3 = Vector3.FORWARD
var health: float = 100.0
var attack_cd: float = 0.0
var ice_cd: float = 0.0
var summon_cd: float = 0.0
var dodge_cd: float = 0.0
var dodge_time: float = 0.0
var dodge_dir: Vector3 = Vector3.ZERO
var swing_time: float = 0.0
var elapsed: float = 0.0
var message_time: float = 0.0
var revive_time: float = 0.0
var rare_unlocked: bool = false
var rare_equipped: bool = false
var kills: int = 0
var wave: int = 1
var paused: bool = false
var demo: bool = false
var test_mode: bool = false
var capture_path: String = ""
var captured: bool = false
var save_path: String = "user://ember_save.json"
var font: Font
var previous_keys: Dictionary = {}
var _enemy_texture: Texture2D
var saves_allowed: bool = true
var progress_warning: String = ""

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--demo": demo = true
		if argument == "--test": test_mode = true
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--test-profile="): save_path = argument.trim_prefix("--test-profile=")
	if test_mode and save_path == "user://ember_save.json": save_path = "user://ember_test_save.json"
	if ResourceLoader.exists("res://assets/fonts/NotoSansCJKJP-Regular.woff2"): font = load("res://assets/fonts/NotoSansCJKJP-Regular.woff2") as Font
	var room: Node3D = ROOM_SCENE.new()
	add_child(room)
	_setup_camera()
	if room.has_method("configure_camera"): room.call("configure_camera", camera)
	_setup_hero()
	_setup_ui()
	_load_progress()
	_spawn_wave()
	_message(progress_warning if not progress_warning.is_empty() else "废矿试炼：击败赤色守卫，拾取「回响刃」。Q 冰弹 · E 召唤", 12.0 if not progress_warning.is_empty() else 7.0)
	if test_mode: call_deferred("_run_test")

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(12.0, 18.0, 20.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.far = 120.0
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true

func _setup_hero() -> void:
	hero = CharacterBody3D.new()
	var hero_body: CharacterBody3D = hero as CharacterBody3D
	hero_body.collision_layer = 4
	hero_body.collision_mask = 3
	_add_collider(hero, 0.32)
	hero.position = Vector3(0.0, 0.0, 3.0)
	add_child(hero)
	body = Sprite3D.new()
	if ResourceLoader.exists("res://assets/hero_sheet.png"):
		body.texture = load("res://assets/hero_sheet.png") as Texture2D
		body.hframes = 4
		body.vframes = 4
		body.pixel_size = 0.035
	else:
		body.texture = _pixel_actor(Color("72d9da"), Color("16304f"), false)
		body.pixel_size = 0.1
	body.position.y = 1.0
	body.shaded = true
	body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	hero.add_child(body)
	var shadow: MeshInstance3D = _disc(0.5, Color(0.0, 0.0, 0.0, 0.6))
	shadow.position.y = 0.025
	hero.add_child(shadow)
	sword = MeshInstance3D.new()
	var blade: BoxMesh = BoxMesh.new()
	blade.size = Vector3(0.16, 0.12, 1.55)
	sword.mesh = blade
	sword.material_override = _material(Color("d4dce7"), true)
	hero.add_child(sword)

func _setup_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var title: Label = _label("余 烬 镇  /  废矿试炼", 27, Color("f3d8a0"))
	column.add_child(title)
	hud = _label("", 18, Color("e2edf1"))
	column.add_child(hud)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	notice = _label("", 20, Color("ffe59a"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom: PanelContainer = PanelContainer.new()
	var bottom_style: StyleBoxFlat = StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.025, 0.035, 0.055, 0.86)
	bottom_style.content_margin_left = 16.0
	bottom_style.content_margin_right = 16.0
	bottom_style.content_margin_top = 10.0
	bottom_style.content_margin_bottom = 10.0
	bottom_style.border_color = Color("6a654b")
	bottom_style.border_width_top = 1
	bottom.add_theme_stylebox_override("panel", bottom_style)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)
	var bottom_column: VBoxContainer = VBoxContainer.new()
	bottom_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_column)
	bottom_column.add_child(notice)
	var controls: Label = _label("WASD 移动   鼠标瞄准 / 左键挥砍   空格 闪避   Q 冰弹   E 召唤\nF 拾取 / 重返试炼   R 换武器   B 装备   Esc 暂停", 17, Color("a9bbc8"))
	bottom_column.add_child(controls)
	inventory = PanelContainer.new()
	inventory.position = Vector2(360.0, 160.0)
	inventory.custom_minimum_size = Vector2(480.0, 300.0)
	inventory.visible = false
	layer.add_child(inventory)
	var panel_margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]: panel_margin.add_theme_constant_override("margin_" + side, 24)
	inventory.add_child(panel_margin)
	inventory_text = _label("", 20, Color("f3e7cb"))
	panel_margin.add_child(inventory_text)

func _label(value: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null: label.add_theme_font_override("font", font)
	return label

func _process(delta: float) -> void:
	if _pressed(KEY_ESCAPE):
		paused = not paused
		_message("已暂停 · Esc 继续" if paused else "继续冒险", 2.0)
	if _pressed(KEY_B):
		inventory.visible = not inventory.visible
	_update_hud()
	if paused or inventory.visible: return
	elapsed += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	ice_cd = maxf(0.0, ice_cd - delta)
	summon_cd = maxf(0.0, summon_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	swing_time = maxf(0.0, swing_time - delta)
	message_time -= delta
	if message_time <= 0.0: notice.text = ""
	if revive_time > 0.0:
		revive_time -= delta
		if revive_time <= 0.0:
			hero.position = Vector3(0.0, 0.0, 5.8)
			health = 100.0
			_message("在营火旁苏醒。已获得的武器与击杀进度全部保留。", 5.0)
		return
	var move: Vector3 = Vector3.ZERO
	if demo:
		move = _demo_actions()
	else:
		move = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0.0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var screen_right: Vector3 = camera.global_basis.x
		var screen_back: Vector3 = camera.global_basis.z
		screen_right.y = 0.0
		screen_back.y = 0.0
		move = screen_right.normalized() * move.x + screen_back.normalized() * move.z
		var pointer: Vector2 = get_viewport().get_mouse_position()
		var ray_start: Vector3 = camera.project_ray_origin(pointer)
		var ray_direction: Vector3 = camera.project_ray_normal(pointer)
		if absf(ray_direction.y) > 0.001:
			var ground_point: Vector3 = ray_start + ray_direction * (-ray_start.y / ray_direction.y)
			var facing: Vector3 = ground_point - hero.position
			facing.y = 0.0
			if facing.length_squared() > 0.01: aim = facing.normalized()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _attack()
		if _pressed(KEY_Q): _cast_ice()
		if _pressed(KEY_E): _summon()
		if _pressed(KEY_SPACE): _dodge(move)
		if _pressed(KEY_R): _switch_weapon()
		if _pressed(KEY_F): _interact()
	if move.length_squared() > 1.0: move = move.normalized()
	if dodge_time > 0.0: move = dodge_dir * 3.0
	var hero_body: CharacterBody3D = hero as CharacterBody3D
	hero_body.move_and_collide(move * MOVE_SPEED * delta)
	hero.position.x = clampf(hero.position.x, -10.0, 10.0)
	hero.position.z = clampf(hero.position.z, -7.0, 7.0)
	_update_hero_visual(move)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_summons(delta)
	_update_drops(delta)
	_update_sparks(delta)
	if not capture_path.is_empty() and not captured and elapsed > 6.5:
		captured = true
		call_deferred("_capture")

func _pressed(keycode: int) -> bool:
	var current: bool = Input.is_physical_key_pressed(keycode)
	var was: bool = bool(previous_keys.get(keycode, false))
	previous_keys[keycode] = current
	return current and not was

func _update_hero_visual(move: Vector3) -> void:
	if body.hframes == 4:
		var row: int = _sprite_row(aim)
		var frame_index: int = int(elapsed * 9.0) % 4 if move.length_squared() > 0.05 else 0
		body.frame = row * 4 + frame_index
	body.modulate = Color("a9efff") if dodge_time > 0.0 else Color.WHITE
	var visual_aim: Vector3 = aim
	if swing_time > 0.0: visual_aim = aim.rotated(Vector3.UP, (swing_time / 0.22 - 0.5) * 2.5)
	sword.position = visual_aim * 0.95 + Vector3.UP * 0.8
	sword.rotation.y = atan2(visual_aim.x, visual_aim.z)

func _attack() -> void:
	if attack_cd > 0.0 or revive_time > 0.0: return
	attack_cd = 0.40 if rare_equipped else 0.48
	swing_time = 0.22
	var damage: float = RARE_DAMAGE if rare_equipped else NORMAL_DAMAGE
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0: continue
		var node: Node3D = enemy["node"] as Node3D
		var offset: Vector3 = node.position - hero.position
		if offset.length() <= ATTACK_RANGE and (offset.length() < 0.6 or aim.dot(offset.normalized()) > 0.25):
			if _wall_between(hero.position, node.position): continue
			_damage_enemy(enemy, damage)
			if is_instance_valid(node): node.position += aim * 0.28
	_spawn_spark(hero.position + aim * 1.4 + Vector3.UP * 0.65, Color("74eaff") if rare_equipped else Color("ffe7a0"), 0.36)
	if rare_equipped: _projectile(hero.position + Vector3.UP * 0.7, aim * 10.0, 25.0, true, Color("70e4ff"), 1.0)

func _cast_ice() -> void:
	if ice_cd > 0.0: return
	ice_cd = 2.8
	_projectile(hero.position + Vector3.UP * 0.7, aim * 10.0, 34.0, true, Color("a2f5ff"), 1.8)
	_message("冰弹：命中减速，接近后用剑追击。", 1.8)

func _summon() -> void:
	if summon_cd > 0.0: return
	summon_cd = 6.0
	if summons.size() > 0:
		summons[0]["life"] = 24.0
		_message("守灯灵：持续时间已刷新。", 2.0)
		return
	var node: Node3D = Node3D.new()
	node.position = hero.position + Vector3(1.0, 0.0, 0.0)
	add_child(node)
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = load("res://assets/summon.png") as Texture2D if ResourceLoader.exists("res://assets/summon.png") else _pixel_actor(Color("8fffe0"), Color("3267a3"), false)
	if ResourceLoader.exists("res://assets/summon_sheet.png"):
		sprite.texture = load("res://assets/summon_sheet.png") as Texture2D
		sprite.hframes = 4
		sprite.vframes = 1
	sprite.pixel_size = 1.3 / (float(sprite.texture.get_height()) / float(sprite.vframes))
	sprite.shaded = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position.y = 0.8
	node.add_child(sprite)
	var ring: MeshInstance3D = _disc(0.45, Color("228fb5"))
	ring.position.y = 0.035
	node.add_child(ring)
	summons.append({"node": node, "sprite": sprite, "life": 24.0, "cd": 0.0})
	_message("守灯灵已加入：自动寻找敌人，远程协助战斗。", 3.0)

func _dodge(move: Vector3) -> void:
	if dodge_cd > 0.0: return
	dodge_cd = 1.3
	dodge_time = 0.20
	dodge_dir = move.normalized() if move.length_squared() > 0.01 else aim

func _spawn_wave() -> void:
	_spawn_enemy(Vector3(-4.8, 0.0, -2.0), false, false)
	_spawn_enemy(Vector3(4.5, 0.0, -3.0), true, false)
	_spawn_enemy(Vector3(0.0, 0.0, -4.3), false, true)
	_message("试炼 %d：赤色守卫携带稀有武器。" % wave, 4.0)

func _spawn_enemy(location: Vector3, ranged: bool, elite: bool) -> void:
	var node: CharacterBody3D = CharacterBody3D.new()
	node.collision_layer = 2
	node.collision_mask = 5
	_add_collider(node, 0.40 if elite else 0.30)
	node.position = location
	add_child(node)
	var sprite: Sprite3D = Sprite3D.new()
	var color: Color = Color("dc7057") if elite else (Color("bc91d8") if ranged else Color("9bb172"))
	var texture_path: String = "res://assets/enemy_elite.png" if elite else ("res://assets/enemy_ranged.png" if ranged else "res://assets/enemy_melee.png")
	sprite.texture = load(texture_path) as Texture2D if ResourceLoader.exists(texture_path) else _pixel_actor(color, Color("352536"), elite)
	if ResourceLoader.exists("res://assets/enemy_sheet.png"):
		sprite.texture = load("res://assets/enemy_sheet.png") as Texture2D
		sprite.hframes = 4
		sprite.vframes = 4
	sprite.pixel_size = (2.65 if elite else 2.2) / (float(sprite.texture.get_height()) / float(sprite.vframes))
	if elite: sprite.modulate = Color("ffb4a0")
	elif ranged: sprite.modulate = Color("bea5ef")
	sprite.shaded = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.position.y = 1.1 if elite else 0.9
	node.add_child(sprite)
	var bar: Label3D = Label3D.new()
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.position.y = 2.5 if elite else 1.9
	bar.font_size = 32
	bar.pixel_size = 0.008
	bar.modulate = Color("ffc58a") if elite else Color("dddddd")
	if font != null: bar.font = font
	node.add_child(bar)
	var hp: float = 190.0 if elite else (65.0 if ranged else 85.0)
	enemies.append({"node": node, "sprite": sprite, "label": bar, "hp": hp, "max_hp": hp, "ranged": ranged, "elite": elite, "cd": 1.5, "windup": 0.0, "slow": 0.0, "warn": null})

func _update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0: continue
		var node: Node3D = enemy["node"] as Node3D
		var sprite: Sprite3D = enemy["sprite"] as Sprite3D
		var bar: Label3D = enemy["label"] as Label3D
		var offset: Vector3 = hero.position - node.position
		var distance: float = offset.length()
		enemy["cd"] = maxf(0.0, float(enemy["cd"]) - delta)
		enemy["slow"] = maxf(0.0, float(enemy["slow"]) - delta)
		bar.text = ("赤焰守卫 " if bool(enemy["elite"]) else "") + "%d / %d" % [maxi(0, int(enemy["hp"])), int(enemy["max_hp"])]
		sprite.modulate = Color("a7eaff") if float(enemy["slow"]) > 0.0 else (Color("ffb4a0") if bool(enemy["elite"]) else (Color("bea5ef") if bool(enemy["ranged"]) else Color.WHITE))
		if sprite.hframes == 4:
			var walking: bool = distance > (5.8 if bool(enemy["ranged"]) else 1.35) and float(enemy["windup"]) <= 0.0
			sprite.frame = _sprite_row(offset) * 4 + (int(elapsed * 7.0) % 4 if walking else 0)
		if float(enemy["windup"]) > 0.0:
			enemy["windup"] = float(enemy["windup"]) - delta
			if float(enemy["windup"]) <= 0.0:
				var warning: Node3D = enemy["warn"] as Node3D
				if is_instance_valid(warning): warning.queue_free()
				enemy["warn"] = null
				if bool(enemy["ranged"]):
					_projectile(node.position + Vector3.UP * 0.7, offset.normalized() * 5.5, 13.0, false, Color("e5a0ff"), 3.0)
				else:
					var radius: float = 2.1 if bool(enemy["elite"]) else 1.35
					_spawn_spark(node.position + Vector3.UP * 0.1, Color("f5763f"), radius)
					if distance < radius and not _wall_between(node.position, hero.position): _hurt(23.0 if bool(enemy["elite"]) else 11.0)
				enemy["cd"] = 1.5
			continue
		var stop_range: float = 5.8 if bool(enemy["ranged"]) else 1.35
		if distance > stop_range:
			var speed: float = (1.25 if bool(enemy["elite"]) else 1.65) * (0.4 if float(enemy["slow"]) > 0.0 else 1.0)
			var enemy_body: CharacterBody3D = node as CharacterBody3D
			enemy_body.move_and_collide(offset.normalized() * speed * delta)
		elif float(enemy["cd"]) <= 0.0:
			enemy["windup"] = 0.75 if bool(enemy["elite"]) else 0.55
			var warning: MeshInstance3D = _disc(2.1 if bool(enemy["elite"]) else 1.35, Color(0.95, 0.22, 0.12, 0.55))
			warning.position.y = 0.04
			node.add_child(warning)
			enemy["warn"] = warning

func _damage_enemy(enemy: Dictionary, damage: float) -> void:
	if float(enemy["hp"]) <= 0.0: return
	enemy["hp"] = float(enemy["hp"]) - damage
	var node: Node3D = enemy["node"] as Node3D
	_spawn_spark(node.position + Vector3.UP, Color("fff0c2"), 0.3)
	if float(enemy["hp"]) <= 0.0:
		kills += 1
		if bool(enemy["elite"]) and not rare_unlocked: _drop_sword(node.position)
		node.queue_free()
		_save_progress()
		var living: int = 0
		for other: Dictionary in enemies:
			if float(other["hp"]) > 0.0: living += 1
		if living == 0: _message("试炼完成！F 拾取附近装备；在营火旁按 F 再次挑战。", 12.0)

func _hurt(damage: float) -> void:
	if dodge_time > 0.0 or revive_time > 0.0: return
	health = maxf(0.0, health - damage)
	_spawn_spark(hero.position + Vector3.UP, Color("ff6258"), 0.35)
	if health <= 0.0:
		revive_time = 2.0
		_save_progress()
		_message("倒下了……正在返回营火，已获得的装备不会丢失。", 4.0)

func _projectile(location: Vector3, velocity: Vector3, damage: float, friendly: bool, color: Color, life: float) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.18 if friendly else 0.24
	sphere.height = sphere.radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = _material(color, true)
	mesh.position = location
	add_child(mesh)
	projectiles.append({"node": mesh, "velocity": velocity, "damage": damage, "friendly": friendly, "life": life})

func _update_projectiles(delta: float) -> void:
	for index: int in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var node: Node3D = shot["node"] as Node3D
		var previous_position: Vector3 = node.position
		node.position += (shot["velocity"] as Vector3) * delta
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous_position, node.position, 1)
		ray_query.hit_from_inside = true
		var blocked: bool = not get_world_3d().direct_space_state.intersect_ray(ray_query).is_empty()
		shot["life"] = float(shot["life"]) - delta
		var hit: bool = blocked
		if bool(shot["friendly"]) and not blocked:
			for enemy: Dictionary in enemies:
				if float(enemy["hp"]) <= 0.0: continue
				var target: Node3D = enemy["node"] as Node3D
				var offset: Vector3 = target.position - node.position
				offset.y = 0.0
				if offset.length() < 0.8:
					enemy["slow"] = 2.5
					_damage_enemy(enemy, float(shot["damage"]))
					hit = true
					break
		elif not blocked:
			var offset: Vector3 = hero.position - node.position
			offset.y = 0.0
			if offset.length() < 0.6:
				_hurt(float(shot["damage"]))
				hit = true
		if hit or float(shot["life"]) <= 0.0:
			node.queue_free()
			projectiles.remove_at(index)

func _update_summons(delta: float) -> void:
	for index: int in range(summons.size() - 1, -1, -1):
		var data: Dictionary = summons[index]
		var summon_sprite: Sprite3D = data["sprite"] as Sprite3D
		if summon_sprite.hframes == 4: summon_sprite.frame = int(elapsed * 7.0) % 4
		var node: Node3D = data["node"] as Node3D
		data["life"] = float(data["life"]) - delta
		data["cd"] = float(data["cd"]) - delta
		var destination: Vector3 = hero.position + Vector3(cos(elapsed) * 1.6, 0.0, sin(elapsed) * 1.6)
		node.position = node.position.lerp(destination, minf(1.0, delta * 4.0))
		if float(data["cd"]) <= 0.0:
			var target: Dictionary = _nearest_enemy(node.position)
			if not target.is_empty():
				var target_node: Node3D = target["node"] as Node3D
				var direction: Vector3 = (target_node.position - node.position).normalized()
				_projectile(node.position + Vector3.UP * 0.7, direction * 8.0, 17.0, true, Color("81ffd5"), 2.0)
				data["cd"] = 1.0
		if float(data["life"]) <= 0.0:
			node.queue_free()
			summons.remove_at(index)

func _drop_sword(location: Vector3) -> void:
	var node: Node3D = Node3D.new()
	node.position = location
	add_child(node)
	var pillar: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.18, 2.6, 0.18)
	pillar.mesh = box
	pillar.position.y = 1.3
	pillar.material_override = _material(Color("efbe50"), true)
	node.add_child(pillar)
	var ring: MeshInstance3D = _disc(0.65, Color("b78932"))
	ring.position.y = 0.045
	node.add_child(ring)
	var label: Label3D = Label3D.new()
	label.text = "稀有 · 回响刃\n靠近按 F 拾取"
	label.position.y = 2.9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color("ffdf72")
	if font != null: label.font = font
	node.add_child(label)
	drops.append({"node": node, "type": "rare_sword"})
	_message("稀有装备掉落！赤焰守卫留下了「回响刃」——靠近按 F 拾取。", 8.0)

func _update_drops(_delta: float) -> void:
	for drop: Dictionary in drops:
		var node: Node3D = drop["node"] as Node3D
		node.rotation.y = sin(elapsed * 1.5) * 0.15

func _interact() -> void:
	for index: int in range(drops.size() - 1, -1, -1):
		var node: Node3D = drops[index]["node"] as Node3D
		if hero.position.distance_to(node.position) < 2.4:
			rare_unlocked = true
			rare_equipped = true
			node.queue_free()
			drops.remove_at(index)
			_apply_weapon()
			_save_progress()
			_message("获得「回响刃」！伤害 24 → 46，每次挥砍释放剑气。R 可对比切换。", 8.0)
			return
	var living: int = 0
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) > 0.0: living += 1
	if living == 0 and hero.position.distance_to(Vector3(0.0, 0.0, 5.8)) < 3.5:
		enemies.clear()
		wave += 1
		health = 100.0
		_spawn_wave()
	else:
		_message("靠近光柱按 F 拾取。清场后回南侧营火按 F，再次试验你的新武器。", 3.0)

func _switch_weapon() -> void:
	if not rare_unlocked:
		_message("尚未获得第二把武器：击败赤色守卫，拾取回响刃。", 3.0)
		return
	rare_equipped = not rare_equipped
	_apply_weapon()
	_save_progress()
	_message("已装备：" + ("回响刃 · 46伤害 + 剑气" if rare_equipped else "旧铁剑 · 24伤害"), 3.0)

func _apply_weapon() -> void:
	sword.material_override = _material(Color("67e8ff") if rare_equipped else Color("d4dce7"), true)
	sword.scale = Vector3(1.6, 1.4, 1.15) if rare_equipped else Vector3.ONE

func _nearest_enemy(location: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var best: float = 10000.0
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0: continue
		var node: Node3D = enemy["node"] as Node3D
		var distance: float = location.distance_squared_to(node.position)
		if distance < best:
			best = distance
			result = enemy
	return result

func _demo_actions() -> Vector3:
	var target: Dictionary = _nearest_enemy(hero.position)
	if not target.is_empty():
		var node: Node3D = target["node"] as Node3D
		var offset: Vector3 = node.position - hero.position
		if offset.length_squared() > 0.01: aim = offset.normalized()
		_attack()
		_cast_ice()
		_summon()
		if health < 50.0: _dodge(Vector3(-aim.z, 0.0, aim.x))
		return aim if offset.length() > 1.6 else Vector3.ZERO
	if not drops.is_empty():
		var node: Node3D = drops[0]["node"] as Node3D
		var offset: Vector3 = node.position - hero.position
		if offset.length() < 2.0: _interact()
		return offset.normalized()
	var home: Vector3 = Vector3(0.0, 0.0, 5.8) - hero.position
	if home.length() < 1.0: _interact()
	return home.normalized()

func _update_hud() -> void:
	if hud == null: return
	hud.text = "生命 %d / 100   击杀 %d   试炼 %d\n%s   Q %.1fs   E %.1fs   闪避 %.1fs" % [int(health), kills, wave, "回响刃 · 稀有 · 剑气" if rare_equipped else "旧铁剑 · 普通", ice_cd, summon_cd, dodge_cd]
	inventory_text.text = "冒险者装备  [ B 关闭 ]\n\n当前：%s\n近战伤害：%d\n\n旧铁剑：朴素可靠的近战武器。\n回响刃：%s\n\nQ 冰弹：伤害并减速\nE 守灯灵：召唤伙伴，持续24秒\n\n装备与击杀进度会自动保存。" % ["回响刃" if rare_equipped else "旧铁剑", int(RARE_DAMAGE if rare_equipped else NORMAL_DAMAGE), "已获得，R切换；挥砍释放剑气" if rare_unlocked else "未获得，击败赤焰守卫掉落"]

func _message(value: String, duration: float) -> void:
	if notice != null: notice.text = value
	message_time = duration

func _save_progress() -> void:
	if not saves_allowed:
		_message("存档和备份均损坏：已保留原文件，自动保存已停用。", 8.0)
		return
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档：" + save_path)
		return
	file.store_string(JSON.stringify({"version": 1, "rare_unlocked": rare_unlocked, "rare_equipped": rare_equipped, "kills": kills}))
	file.flush()
	file.close()
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	if not _read_progress(save_path).is_empty(): DirAccess.copy_absolute(absolute_path, absolute_path + ".bak")
	var result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute_path)
	if result != OK: push_warning("存档替换失败：" + str(result))

func _read_progress(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return {}
	var data: Dictionary = parsed as Dictionary
	var version: Variant = data.get("version")
	if not (version is int or version is float): return {}
	if float(version) != 1.0: return {}
	if not data.get("rare_unlocked") is bool or not data.get("rare_equipped") is bool: return {}
	var count: Variant = data.get("kills")
	if not (count is int or count is float): return {}
	if float(count) < 0.0: return {}
	return data

func _load_progress() -> void:
	progress_warning = ""
	saves_allowed = true
	var data: Dictionary = _read_progress(save_path)
	if data.is_empty():
		data = _read_progress(save_path + ".bak")
		if not data.is_empty():
			progress_warning = "主存档异常：已从有效备份恢复装备与击杀进度。"
		elif FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
			saves_allowed = false
			progress_warning = "存档和备份均损坏：原文件已保留，自动保存已停用。"
	if not progress_warning.is_empty(): _message(progress_warning, 12.0)
	if data.is_empty(): return
	rare_unlocked = bool(data["rare_unlocked"])
	rare_equipped = bool(data["rare_equipped"]) and rare_unlocked
	kills = maxi(0, int(data["kills"]))
	_apply_weapon()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.3
	if color.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _disc(radius: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.025
	cylinder.radial_segments = 32
	node.mesh = cylinder
	node.material_override = _material(color, true)
	return node

func _spawn_spark(location: Vector3, color: Color, radius: float) -> void:
	var node: MeshInstance3D = _disc(radius, color)
	node.position = location
	add_child(node)
	sparks.append({"node": node, "life": 0.18, "max_life": 0.18})

func _update_sparks(delta: float) -> void:
	for index: int in range(sparks.size() - 1, -1, -1):
		var data: Dictionary = sparks[index]
		data["life"] = float(data["life"]) - delta
		var node: Node3D = data["node"] as Node3D
		node.scale = Vector3.ONE * (0.6 + float(data["life"]) * 2.0)
		if float(data["life"]) <= 0.0:
			node.queue_free()
			sparks.remove_at(index)

func _wall_between(start: Vector3, finish: Vector3) -> bool:
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.7, finish + Vector3.UP * 0.7, 1)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _sprite_row(direction: Vector3) -> int:
	var right: Vector3 = camera.global_basis.x
	var back: Vector3 = camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	var horizontal: float = direction.dot(right.normalized())
	var vertical: float = direction.dot(back.normalized())
	if absf(horizontal) > absf(vertical): return 3 if horizontal > 0.0 else 2
	return 0 if vertical > 0.0 else 1

func _add_collider(node: Node3D, radius: float) -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.4
	shape.shape = capsule
	shape.position.y = 0.75
	node.add_child(shape)

func _pixel_actor(coat: Color, dark: Color, elite: bool) -> Texture2D:
	var image: Image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(5, 2, 6, 7), Color("cfb190"))
	image.fill_rect(Rect2i(4, 1, 8, 3), dark)
	image.fill_rect(Rect2i(3, 9, 10, 9), coat)
	image.fill_rect(Rect2i(1, 10, 3, 7), dark)
	image.fill_rect(Rect2i(12, 10, 3, 7), dark)
	image.fill_rect(Rect2i(4, 18, 3, 5), dark)
	image.fill_rect(Rect2i(9, 18, 3, 5), dark)
	image.fill_rect(Rect2i(5, 6, 2, 1), Color("ffef9a") if elite else Color("172238"))
	image.fill_rect(Rect2i(9, 6, 2, 1), Color("ffef9a") if elite else Color("172238"))
	image.fill_rect(Rect2i(7, 10, 2, 7), coat.lightened(0.3))
	return ImageTexture.create_from_image(image)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(capture_path)
	print("CAPTURE ", capture_path, " error=", error)
	get_tree().quit(0 if error == OK else 3)

func get_test_state() -> Dictionary:
	return {"aim": [aim.x, aim.z], "attack_range": ATTACK_RANGE, "damage": RARE_DAMAGE if rare_equipped else NORMAL_DAMAGE, "rare_unlocked": rare_unlocked, "rare_equipped": rare_equipped, "kills": kills, "save_path": save_path, "saves_allowed": saves_allowed, "progress_warning": progress_warning, "enemy_count": enemies.size(), "drops": drops.size(), "summons": summons.size()}

func _run_test() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	if enemies.size() != 3: failures.append("enemy population")
	print("TEST population ", enemies.size())
	var target: Dictionary = enemies[0]
	var target_node: Node3D = target["node"] as Node3D
	hero.position = Vector3.ZERO
	aim = Vector3.FORWARD
	target_node.position = Vector3(0.0, 0.0, -1.4)
	var before: float = float(target["hp"])
	attack_cd = 0.0
	rare_equipped = false
	_attack()
	if not is_equal_approx(float(target["hp"]), before - NORMAL_DAMAGE): failures.append("real melee damage")
	print("TEST real melee before=", before, " after=", target["hp"])
	attack_cd = 0.0
	aim = Vector3.BACK
	before = float(target["hp"])
	_attack()
	if not is_equal_approx(float(target["hp"]), before): failures.append("melee facing restriction")
	print("TEST facing restriction hp=", target["hp"])
	_cast_ice()
	if projectiles.is_empty(): failures.append("ice projectile")
	_summon()
	if summons.size() != 1: failures.append("summon lifecycle")
	rare_unlocked = false
	var elite: Dictionary = enemies[2]
	var elite_node: Node3D = elite["node"] as Node3D
	hero.position = elite_node.position
	_damage_enemy(elite, 1000.0)
	if drops.size() != 1: failures.append("elite unique drop")
	_interact()
	if not rare_unlocked or not rare_equipped: failures.append("pickup unlock")
	if not drops.is_empty(): failures.append("drop consumed")
	_damage_enemy(elite, 1000.0)
	if not drops.is_empty(): failures.append("duplicate elite reward")
	_save_progress()
	rare_unlocked = false
	rare_equipped = false
	_load_progress()
	if not rare_unlocked or not rare_equipped: failures.append("saved unlock persistence")
	print("TEST_STATE ", JSON.stringify(get_test_state()))
	if failures.is_empty():
		print("TEST_OK melee, facing, ice, summon, elite_drop, pickup, duplicate_guard, save_load")
		get_tree().quit(0)
	else:
		for failure: String in failures: push_error("TEST_FAIL " + failure)
		get_tree().quit(2)
