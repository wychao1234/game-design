extends "res://scripts/game.gd"

# Reuses platform helpers only; the legacy mine and its persistence never run.
const COMBAT_IDS: Array[String] = ["shen", "jiang", "zhu", "lu"]
const COMBAT_NAMES: Dictionary = {"shen":"沈砚", "jiang":"江照野", "zhu":"祝听澜", "lu":"陆惊弦"}
const SKILL_NAMES: Dictionary = {"shen":["回锋斩","掠影步","灵火签","引印"],"jiang":["扫堂","拖枪","震关","镇旗"],"zhu":["唤灯","缚影阵","驱令","铃震"],"lu":["连珠","退羽","定星","裂帛"]}
const SKILL_COOLDOWNS: Dictionary = {"shen":[2.8,4.0,4.5,6.0],"jiang":[3.2,5.0,5.5,9.0],"zhu":[7.0,7.5,3.5,5.0],"lu":[3.8,5.0,4.5,6.0]}
const ACTOR_VISUAL_SCALE: float = 1.1
const SHEN_ATTACK_POSE_DURATION: float = 0.28
const ACTOR_NIGHT_TINT: Color = Color("c5d5e5")
const ROLE_COLORS: Dictionary = {"shen":Color("87dfff"),"jiang":Color("e4bb76"),"zhu":Color("8ceec5"),"lu":Color("dcb7fa")}
var combat_party: Array[String] = []
var active_slot: int = 0
var member_hp: Dictionary = {}
var skill_timers: Dictionary = {}
var switch_timer: float = 0.0
var dodge_charges: int = 2
var dodge_recharge: float = 0.0
var awakening_energy: float = 0.0
var combat_stage: String = ""
var combat_difficulty: int = 0
var combat_finished: bool = true
var combat_stats: Dictionary = {}
var combat_fields: Array[Dictionary] = []
var combat_hazards: Array[Dictionary] = []
var combat_wave: int = 0
var boss_phase: int = 1
var action_lock: float = 0.0
var hit_protection: float = 0.0
var preview_slot: int = -1
var preview_node: MeshInstance3D
var preview_point: Vector3 = Vector3.ZERO
var _next_wave: float = -1.0
var _cast_serial: int = 0
var _cast_credits: Dictionary = {}
var _run_serial: int = 0
var _pull_bonus: Dictionary = {}
var _demo_switch_time: float = -5.0
var _combo_index: int = 0
var _combo_timer: float = 0.0
var _boss_turn: int = 0
var _key_was: Dictionary = {}
var _combat_running: bool = false
var _role_atlases: Dictionary = {}
var _role_offsets: Dictionary = {}
var _role_sizes: Dictionary = {}
var _role_has_texture: bool = false
var suppress_mouse_until_release: bool = false
var _foe_atlases: Dictionary = {}
var _foe_offsets: Dictionary = {}
var _foe_sizes: Dictionary = {}
var _healthbar_material: ShaderMaterial
var _shen_attack_checked: bool = false
var _shen_attack_frames: Array[Texture2D] = []
var _shen_attack_offsets: Array[Vector2] = []
var _shen_attack_pixel_size: float = 0.0
var _shen_pose_time: float = 0.0
var _shen_pose_row: int = 0

func _ready() -> void:
	pass
func _process(_delta: float) -> void:
	pass

func active_member() -> String:
	return combat_party[active_slot] if not combat_party.is_empty() else "shen"

func _max_hp(id: String) -> float:
	return float((combat_stats.get(id, {}) as Dictionary).get("max_hp", 100.0))

func combat_begin(party: Array[String], stage: String, difficulty: int) -> void:
	combat_clear()
	combat_party.clear()
	for id: String in party:
		if id in COMBAT_IDS and id not in combat_party and combat_party.size() < 3: combat_party.append(id)
	if combat_party.is_empty(): combat_party.append("shen")
	combat_stage = stage
	combat_difficulty = difficulty
	combat_finished = false
	_combat_running = true
	active_slot = 0
	member_hp.clear()
	skill_timers.clear()
	for id: String in combat_party:
		member_hp[id] = _max_hp(id)
		skill_timers[id] = [0.0, 0.0, 0.0, 0.0]
	dodge_charges = 2
	dodge_recharge = 0.0
	awakening_energy = 0.0
	switch_timer = 0.0
	dodge_time = 0.0
	attack_cd = 0.0
	action_lock = 0.0
	hit_protection = 0.0
	combat_wave = 0
	boss_phase = 1
	_boss_turn = 0
	_combo_timer = 0.0
	_combo_index = 0
	_next_wave = -1.0
	_key_was.clear()
	hero.position = Vector3(0, 0, 4)
	health = float(member_hp[active_member()])
	_apply_role_visual()
	if stage == "boss": _spawn_boss()
	else: _spawn_ferry_wave()

func combat_clear() -> void:
	_clear_shen_attack_pose()
	_run_serial += 1
	_combat_running = false
	combat_finished = true
	cancel_skill_preview()
	for collection: Array in [enemies, projectiles, summons, sparks, drops, combat_fields, combat_hazards]:
		for effect: Dictionary in collection: _release_node(effect)
		collection.clear()
	_cast_credits.clear()
	_pull_bonus.clear()
	awakening_energy = 0.0

func _release_node(record: Dictionary) -> void:
	# A dead enemy's retained reward record may refer to an already freed object.
	var raw: Variant = record.get("node")
	if is_instance_valid(raw): (raw as Node).queue_free()

func combat_snapshot() -> Dictionary:
	var max_health: Dictionary = {}
	for id: String in combat_party: max_health[id] = _max_hp(id)
	var boss_hp_ratio: float = 0.0
	for enemy: Dictionary in enemies:
		if bool(enemy.get("boss",false)): boss_hp_ratio = float(enemy["hp"])/float(enemy["max_hp"])
	return {"party":combat_party.duplicate(),"active_slot":active_slot,"active_id":active_member(),"hp":member_hp.duplicate(),"max_hp":max_health,"cooldowns":skill_timers.duplicate(true),"skill_names":SKILL_NAMES.get(active_member(),[]),"switch_timer":switch_timer,"dodge_charges":dodge_charges,"dodge_recharge":dodge_recharge,"awakening_energy":awakening_energy,"wave":combat_wave,"boss_phase":boss_phase,"boss_hp_ratio":boss_hp_ratio,"enemies_alive":_living_count(),"finished":combat_finished,"preview_slot":preview_slot,"stage":combat_stage,"difficulty":combat_difficulty}

func combat_step(delta: float, read_input: bool = true) -> void:
	if not _combat_running or combat_finished: return
	elapsed += delta
	_step_shen_attack_pose(delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	swing_time = maxf(0.0, swing_time - delta)
	action_lock = maxf(0.0, action_lock - delta)
	hit_protection = maxf(0.0, hit_protection - delta)
	switch_timer = maxf(0.0, switch_timer - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0: _combo_index = 0
	for id: String in skill_timers:
		var timers: Array = skill_timers[id]
		for slot: int in range(4): timers[slot] = maxf(0.0, float(timers[slot]) - delta)
	for id: String in _pull_bonus: _pull_bonus[id] = maxf(0.0, float(_pull_bonus[id]) - delta)
	for cast_id: Variant in _cast_credits.keys():
		if elapsed - float(_cast_credits[cast_id]) > 20.0: _cast_credits.erase(cast_id)
	if dodge_charges < 2:
		dodge_recharge -= delta
		if dodge_recharge <= 0.0:
			dodge_charges += 1
			dodge_recharge = 4.0 if dodge_charges < 2 else 0.0
	var move: Vector3 = Vector3.ZERO
	if read_input:
		if demo: move = _combat_demo()
		else: move = _combat_input()
	if combat_finished: return
	if dodge_time > 0.0: move = dodge_dir * 3.1
	elif action_lock > 0.12: move *= 0.35
	_move_hero(move * MOVE_SPEED * delta)
	_update_role_visual(move)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_summons(delta)
	_update_fields(delta)
	_update_hazards(delta)
	_update_sparks(delta)
	if _next_wave >= 0.0:
		_next_wave -= delta
		if _next_wave <= 0.0:
			_next_wave = -1.0
			_spawn_ferry_wave()

func _input_edge(key: int) -> bool:
	var down: bool = Input.is_physical_key_pressed(key)
	var old: bool = bool(_key_was.get(key, false))
	_key_was[key] = down
	return down and not old

func _combat_input() -> Vector3:
	var axes: Vector2 = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var right: Vector3 = camera.global_basis.x
	var back: Vector3 = camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	var move: Vector3 = (right.normalized()*axes.x + back.normalized()*axes.y).limit_length(1.0)
	var origin: Vector3 = camera.project_ray_origin(get_viewport().get_mouse_position())
	var ray: Vector3 = camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(ray.y) > 0.001:
		var ground: Vector3 = origin + ray * (-origin.y/ray.y)
		var facing: Vector3 = ground - hero.position
		facing.y = 0.0
		if facing.length_squared() > 0.01: aim = facing.normalized()
		preview_point = hero.position + facing.limit_length(6.0)
		preview_point.x = clampf(preview_point.x,-10.0,10.0)
		preview_point.z = clampf(preview_point.z,-6.0,6.0)
	if preview_slot >= 0:
		if is_instance_valid(preview_node): preview_node.position = preview_point + Vector3.UP*0.07
		if _input_edge(KEY_SPACE): _dodge(move)
		elif _input_edge(KEY_1): switch_member(0)
		elif _input_edge(KEY_2): switch_member(1)
		elif _input_edge(KEY_3): switch_member(2)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or _input_edge(KEY_ESCAPE): cancel_skill_preview()
		elif not Input.is_physical_key_pressed(KEY_E):
			var landing: Vector3 = preview_point
			cancel_skill_preview(false)
			_cast_skill(1,landing)
		return move
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): suppress_mouse_until_release = false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not suppress_mouse_until_release: use_basic()
	if _input_edge(KEY_Q): use_skill(0)
	if _input_edge(KEY_E): use_skill(1)
	if _input_edge(KEY_R): use_skill(2)
	if _input_edge(KEY_F): use_skill(3)
	if _input_edge(KEY_X): use_awakening()
	if _input_edge(KEY_SPACE): _dodge(move)
	if _input_edge(KEY_1): switch_member(0)
	if _input_edge(KEY_2): switch_member(1)
	if _input_edge(KEY_3): switch_member(2)
	if _input_edge(KEY_TAB):
		for offset: int in range(1,combat_party.size()):
			var index: int = (active_slot+offset)%combat_party.size()
			if float(member_hp[combat_party[index]]) > 0.0:
				switch_member(index)
				break
	return move

func cancel_skill_preview(suppress_mouse: bool = true) -> void:
	if suppress_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): suppress_mouse_until_release = true
	preview_slot = -1
	if is_instance_valid(preview_node): preview_node.queue_free()
	preview_node = null
	for key: int in [KEY_Q,KEY_E,KEY_R,KEY_F,KEY_X,KEY_SPACE,KEY_TAB,KEY_1,KEY_2,KEY_3]: _key_was[key] = Input.is_physical_key_pressed(key)

func _can_act() -> bool:
	return _combat_running and not combat_finished and dodge_time <= 0.0 and action_lock <= 0.12 and float(member_hp.get(active_member(),0.0)) > 0.0
func _new_cast() -> int:
	_cast_serial += 1
	return _cast_serial
func _credit_cast(cast_id: int, amount: float = 8.0) -> void:
	if cast_id < 0 or _cast_credits.has(cast_id): return
	_cast_credits[cast_id] = elapsed
	awakening_energy = minf(100.0,awakening_energy+amount)
func _damage_scale(owner: String) -> float:
	return maxf(0.1,float((combat_stats.get(owner,{}) as Dictionary).get("damage",1.0)))
func _mechanism(owner: String) -> bool:
	return bool((combat_stats.get(owner,{}) as Dictionary).get("mechanism",false))

func use_basic() -> void:
	if not _can_act() or attack_cd > 0.0 or preview_slot >= 0: return
	var owner: String = active_member()
	var cast_id: int = _new_cast()
	_combo_index = (_combo_index%3)+1
	_combo_timer = 1.1
	attack_cd = 0.36 if owner == "shen" else 0.46
	action_lock = 0.19
	swing_time = 0.22
	on_combat_feedback("swing",hero.position)
	if owner=="shen": _start_shen_attack_pose()
	if owner == "zhu" or owner == "lu":
		_fire(hero.position,aim*13.0,18.0 if owner == "zhu" else 23.0,owner,cast_id,ROLE_COLORS[owner],false,2.0)
	else:
		_melee(owner,cast_id,21.0*(1.35 if _combo_index == 3 else 1.0),3.0 if owner == "jiang" else 2.5,0.1)
	_arc_feedback(ROLE_COLORS[owner],2.2 if owner == "jiang" else 1.6)

func use_skill(slot: int) -> bool:
	if slot < 0 or slot > 3 or not _can_act() or preview_slot >= 0: return false
	if float((skill_timers[active_member()] as Array)[slot]) > 0.0: return false
	if active_member() == "zhu" and slot == 1:
		preview_slot = slot
		preview_point = hero.position + aim*3.0
		preview_node = _field_ring(2.2,Color(0.25,0.9,0.7,0.6))
		preview_node.position = preview_point + Vector3.UP*0.07
		add_child(preview_node)
		return true
	return _cast_skill(slot,hero.position+aim*3.5)

func _cast_skill(slot: int, landing: Vector3) -> bool:
	if not _can_act() or float((skill_timers[active_member()] as Array)[slot]) > 0.0: return false
	var owner: String = active_member()
	if owner == "zhu" and slot == 2 and summons.is_empty():
		on_combat_message("灯灵尚未在场：先使用唤灯，驱令未进入冷却。")
		return false
	var cast_id: int = _new_cast()
	(skill_timers[owner] as Array)[slot] = float((SKILL_COOLDOWNS[owner] as Array)[slot])
	action_lock = 0.28 if slot == 3 else 0.21
	swing_time = 0.24
	if owner=="shen":
		if slot in [0,1]: _start_shen_attack_pose()
		else: _clear_shen_attack_pose()
	match owner:
		"shen":
			match slot:
				0: _melee(owner,cast_id,44.0,2.8,-0.35)
				1:
					_move_hero(aim*2.7)
					_melee(owner,cast_id,34.0,2.1,-0.1)
				2: _fire(hero.position,aim*12.0,24.0,owner,cast_id,Color("79dfff"),false,2.0,"shen")
				3: _detonate(owner,cast_id,"shen_mark",65.0)
		"jiang":
			match slot:
				0: _melee(owner,cast_id,39.0,3.2,-0.4,0.5)
				1:
					var hit: bool = _melee(owner,cast_id,24.0,5.0,0.45,-1.5)
					if hit and _mechanism(owner): _pull_bonus[owner] = 6.0
				2:
					var bonus: float = 1.6 if float(_pull_bonus.get(owner,0.0)) > 0.0 else 1.0
					_melee(owner,cast_id,52.0,3.0,-0.2,0.0,35.0*bonus)
					_pull_bonus.erase(owner)
				3: _place_field(owner,"flag",hero.position,3.0,8.0)
		"zhu":
			match slot:
				0: _spawn_lamp(owner)
				1:
					if _wall_between(hero.position,landing): landing = hero.position + aim*1.5
					_place_field(owner,"bind",landing,2.2,6.0)
				2: _command_lamps(cast_id)
				3: _melee(owner,cast_id,38.0,2.8,-1.0,1.4)
		"lu":
			match slot:
				0:
					for angle: float in [-0.08,0.0,0.08]: _fire(hero.position,aim.rotated(Vector3.UP,angle)*15.0,19.0,owner,cast_id,Color("d4c5ff"),false,2.0)
				1:
					_fire(hero.position,aim*14.0,31.0,owner,cast_id,Color("ddc0ff"),false,2.0)
					_move_hero(-aim*2.8)
				2: _fire(hero.position,aim*15.0,28.0,owner,cast_id,Color("ffdd91"),false,2.0,"lu")
				3: _detonate(owner,cast_id,"lu_mark",76.0)
	_arc_feedback(ROLE_COLORS[owner],2.7)
	return true

func switch_member(slot: int) -> bool:
	if slot < 0 or slot >= combat_party.size() or slot == active_slot or not _can_act() or switch_timer > 0.0: return false
	if float(member_hp[combat_party[slot]]) <= 0.0: return false
	cancel_skill_preview(false)
	_clear_shen_attack_pose()
	active_slot = slot
	switch_timer = 1.0
	action_lock = 0.1
	health = float(member_hp[active_member()])
	_apply_role_visual()
	on_combat_message("换人："+str(COMBAT_NAMES[active_member()]))
	return true

func _dodge(direction: Vector3) -> void:
	if not _can_act() or dodge_charges <= 0: return
	_clear_shen_attack_pose()
	cancel_skill_preview(false)
	dodge_dir = direction.normalized() if direction.length_squared() > 0.01 else aim
	dodge_time = 0.24
	action_lock = 0.0
	dodge_charges -= 1
	on_combat_feedback("dodge",hero.position)
	if dodge_recharge <= 0.0: dodge_recharge = 4.0

func use_awakening() -> bool:
	if not _can_act() or awakening_energy < 100.0 or preview_slot >= 0: return false
	awakening_energy = 0.0
	var owner: String = active_member()
	action_lock = 0.55
	if owner=="shen": _start_shen_attack_pose()
	match owner:
		"shen": _melee(owner,-1,200.0,5.0,-0.8,0.0,45.0)
		"jiang": _melee(owner,-1,170.0,6.0,-0.3,1.2,65.0)
		"zhu":
			for enemy: Dictionary in enemies:
				if _enemy_in_range(enemy,hero.position,7.0): _hit(enemy,155.0,owner,-1)
			_spawn_lamp(owner)
		"lu":
			for offset: float in [-0.18,-0.09,0.0,0.09,0.18]: _fire(hero.position,aim.rotated(Vector3.UP,offset)*17.0,56.0,owner,-1,Color("f5d8ff"),true,2.0)
	_arc_feedback(ROLE_COLORS[owner],5.0)
	on_combat_message(str(COMBAT_NAMES[owner])+" · 觉醒")
	return true

func combat_hurt(amount: float) -> void:
	if combat_finished or dodge_time > 0.0 or amount <= 0.0: return
	var owner: String = active_member()
	var defense: float = maxf(0.0,float((combat_stats.get(owner,{}) as Dictionary).get("defense",0.0)))
	member_hp[owner] = maxf(0.0,float(member_hp[owner])-amount/(1.0+defense*0.025))
	health = float(member_hp[owner])
	_spawn_spark(hero.position+Vector3.UP,Color("f36f62"),0.4)
	if hit_protection <= 0.0 and not _inside_flag(hero.position):
		action_lock = maxf(action_lock,0.22)
		hit_protection = 0.65
	if health > 0.0: return
	_clear_shen_attack_pose()
	_clear_owner_effects(owner)
	cancel_skill_preview()
	for slot: int in range(combat_party.size()):
		if float(member_hp[combat_party[slot]]) > 0.0:
			active_slot = slot
			health = float(member_hp[active_member()])
			action_lock = 0.12
			switch_timer = 1.0
			_apply_role_visual()
			on_combat_message(str(COMBAT_NAMES[owner])+"倒地，"+str(COMBAT_NAMES[active_member()])+"接战。")
			return
	combat_finished = true
	awakening_energy = 0.0
	call_deferred("_notify_end",false,_run_serial)

func _hurt(amount: float) -> void:
	combat_hurt(amount)
func _damage_enemy(enemy: Dictionary, damage: float) -> void:
	_hit(enemy,damage,active_member(),-1)
func _save_progress() -> void:
	pass
func _notify_end(victory: bool, serial: int) -> void:
	if serial != _run_serial: return
	if victory: on_combat_victory()
	else: on_combat_defeat()
func on_combat_feedback(_kind: String, _location: Vector3) -> void:
	pass
func on_combat_message(_text: String) -> void:
	pass
func on_enemy_reward(_enemy: Dictionary) -> void:
	pass
func on_combat_victory() -> void:
	pass
func on_combat_defeat() -> void:
	pass

func _move_hero(displacement: Vector3) -> void:
	if hero is CharacterBody3D: (hero as CharacterBody3D).move_and_collide(displacement)
	else: hero.position += displacement
	hero.position.x = clampf(hero.position.x,-10.5,10.5)
	hero.position.z = clampf(hero.position.z,-6.5,6.5)

func _apply_role_visual() -> void:
	if body == null: return
	_clear_shen_attack_pose(false)
	body.shaded = false
	var id: String = active_member()
	var path: String = "res://assets/characters/"+id+".png"
	_role_has_texture = ResourceLoader.exists(path)
	if _role_has_texture:
		var texture: Texture2D = load(path) as Texture2D
		var metadata_path: String = "res://assets/characters/"+id+".json"
		if not _role_atlases.has(id) and FileAccess.file_exists(metadata_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
			if parsed is Dictionary:
				var frames: Array = (parsed as Dictionary).get("frames",[])
				if frames.size()==16:
					var textures: Array[Texture2D] = []
					var offsets: Array[Vector2] = []
					var height: float = 1.0
					for frame: Dictionary in frames:
						var region: Array = frame["region"]
						var atlas: AtlasTexture = AtlasTexture.new()
						atlas.atlas = texture
						atlas.region = Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
						textures.append(atlas)
						var row_centers: Array[float] = []
						var row_index: int = int(frame["row"])
						for sibling: Dictionary in frames:
							if int(sibling["row"])==row_index: row_centers.append(float(sibling["foot_x"]))
						row_centers.sort()
						var foot_x: float = (row_centers[1]+row_centers[2])*0.5
						# Non-centered Sprite3D Y begins at the lower image edge.
						offsets.append(Vector2(-foot_x,float(frame["foot_y"])-float(region[3])))
						height = maxf(height,float((frame["bbox"] as Array)[3]))
					_role_atlases[id] = textures
					_role_offsets[id] = offsets
					_role_sizes[id] = (2.25 if id=="jiang" else 2.15)/height*ACTOR_VISUAL_SCALE
		if _role_atlases.has(id):
			body.hframes = 1
			body.vframes = 1
			body.centered = false
			body.pixel_size = float(_role_sizes[id])
			body.position.y = 0.035
			_show_role_frame(0)
		else:
			body.texture = texture
			body.hframes = 4
			body.vframes = 4
			body.centered = true
			body.offset = Vector2.ZERO
			body.position.y = 1.0*ACTOR_VISUAL_SCALE
			body.pixel_size = 2.0/(float(texture.get_height())/4.0)*ACTOR_VISUAL_SCALE
	else:
		var fallback: String = "res://assets/hero_sheet.png"
		body.centered = true
		body.offset = Vector2.ZERO
		body.position.y = 1.0*ACTOR_VISUAL_SCALE
		if ResourceLoader.exists(fallback):
			body.texture = load(fallback) as Texture2D
			body.hframes = 4
			body.vframes = 4
			body.pixel_size = 2.0/(float(body.texture.get_height())/4.0)*ACTOR_VISUAL_SCALE
		else:
			body.texture = _pixel_actor(ROLE_COLORS[id],Color("1d3048"),false)
			body.hframes = 1
			body.vframes = 1
			body.pixel_size = 2.0/24.0*ACTOR_VISUAL_SCALE
	body.modulate = ACTOR_NIGHT_TINT if _role_has_texture else ROLE_COLORS[id]*ACTOR_NIGHT_TINT
	if sword != null: sword.visible = false

func _show_role_frame(index: int) -> void:
	var id: String = active_member()
	if _role_atlases.has(id):
		body.hframes = 1
		body.vframes = 1
		body.centered = false
		body.position.y = 0.035
		body.pixel_size = float(_role_sizes[id])
		body.texture = (_role_atlases[id] as Array)[index]
		body.offset = (_role_offsets[id] as Array)[index]
	else: body.frame = clampi(index,0,body.hframes*body.vframes-1)

func _update_role_visual(move: Vector3) -> void:
	if body == null: return
	if active_member()=="shen" and _shen_pose_time>0.0 and _shen_attack_frames.size()==16:
		var column: int = clampi(floori((1.0-_shen_pose_time/SHEN_ATTACK_POSE_DURATION)*4.0),0,3)
		_show_shen_attack_frame(column)
	else:
		var index: int = _sprite_row(aim)*4+(int(elapsed*10.0)%4 if move.length_squared()>0.05 or swing_time>0.0 else 0)
		_show_role_frame(index)
	body.modulate = Color("b1eaff") if dodge_time > 0.0 else (ACTOR_NIGHT_TINT if _role_has_texture else ROLE_COLORS[active_member()]*ACTOR_NIGHT_TINT)

# Dedicated authored Shen contact/recovery poses. Gameplay hit and cooldown timing
# remain in the existing actions; this cache only chooses what Sprite3D draws.
func _prepare_shen_attack_atlas(png_path: String = "res://assets/characters/shen_attack.png", metadata_path: String = "res://assets/characters/shen_attack.json") -> bool:
	_clear_shen_attack_pose()
	_shen_attack_checked = true
	_shen_attack_frames.clear()
	_shen_attack_offsets.clear()
	_shen_attack_pixel_size = 0.0
	if not _role_atlases.has("shen") or not _role_sizes.has("shen"): return false
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(png_path): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not parsed is Dictionary: return false
	var metadata: Dictionary = parsed as Dictionary
	if not _pose_number(metadata.get("schema_version")) or float(metadata["schema_version"])!=1.0: return false
	if metadata.get("animation")!="attack": return false
	var raw_frames: Variant = metadata.get("frames")
	if not raw_frames is Array or (raw_frames as Array).size()!=16: return false
	var global_height: Variant = metadata.get("global_body_height_pixels")
	var walk_height: Variant = metadata.get("reference_walk_body_height_pixels")
	if not _pose_number(global_height) or not _pose_number(walk_height): return false
	if float(global_height)<=0.0 or float(walk_height)<=0.0: return false
	var texture: Texture2D = load(png_path) as Texture2D
	if texture == null: return false
	var pixel_size: float = float(_role_sizes["shen"])*float(walk_height)/float(global_height)
	if not is_finite(pixel_size) or pixel_size<=0.0: return false
	var support_x: Array = []
	var raw_support: Variant = metadata.get("reference_walk_support_x_by_row")
	if metadata.has("reference_walk_support_x_by_row") and (not raw_support is Array or (raw_support as Array).size()!=4): return false
	if raw_support is Array and (raw_support as Array).size()==4:
		for value: Variant in raw_support:
			if not _pose_number(value): return false
			support_x.append(float(value))
	var textures: Array[Texture2D] = []
	var offsets: Array[Vector2] = []
	for index: int in range(16):
		var raw: Variant = (raw_frames as Array)[index]
		if not raw is Dictionary: return false
		var frame: Dictionary = raw as Dictionary
		var row: int = floori(float(index)/4.0)
		for key: String in ["index","row","column"]:
			if not _pose_number(frame.get(key)): return false
		if float(frame["index"])!=float(index) or float(frame["row"])!=float(row) or float(frame["column"])!=float(index%4): return false
		var raw_region: Variant = frame.get("region")
		if not raw_region is Array or (raw_region as Array).size()!=4: return false
		var region: Array = raw_region as Array
		for value: Variant in region:
			if not _pose_number(value) or float(value)!=floorf(float(value)): return false
		var rect: Rect2 = Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
		if rect.position.x<0.0 or rect.position.y<0.0 or rect.size.x<=0.0 or rect.size.y<=0.0: return false
		if rect.end.x>float(texture.get_width()) or rect.end.y>float(texture.get_height()): return false
		var foot_x: Variant = frame.get("foot_x")
		var foot_y: Variant = frame.get("foot_y")
		var body_height: Variant = frame.get("body_height_pixels")
		if not _pose_number(foot_x) or not _pose_number(foot_y) or not _pose_number(body_height): return false
		if float(foot_x)<0.0 or float(foot_x)>rect.size.x or float(foot_y)<0.0 or float(foot_y)>rect.size.y: return false
		if float(body_height)<=0.0 or float(body_height)>rect.size.y: return false
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = rect
		atlas.filter_clip = true
		textures.append(atlas)
		var horizontal_bias: float = 0.0
		if support_x.size()==4:
			var walk_offsets: Array = _role_offsets["shen"]
			horizontal_bias = (float(support_x[row])+(walk_offsets[row*4] as Vector2).x)*float(_role_sizes["shen"])/pixel_size
		offsets.append(Vector2(-float(foot_x)+horizontal_bias,float(foot_y)-rect.size.y))
	_shen_attack_frames = textures
	_shen_attack_offsets = offsets
	_shen_attack_pixel_size = pixel_size
	return true

func _pose_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _start_shen_attack_pose() -> bool:
	if active_member()!="shen" or not _role_has_texture: return false
	if not _shen_attack_checked: _prepare_shen_attack_atlas()
	if _shen_attack_frames.size()!=16 or _shen_attack_pixel_size<=0.0: return false
	_shen_pose_time = SHEN_ATTACK_POSE_DURATION
	_shen_pose_row = _sprite_row(aim)
	_show_shen_attack_frame(0)
	return true

func _clear_shen_attack_pose(restore_walk: bool = true) -> void:
	var was_active: bool = _shen_pose_time>0.0
	_shen_pose_time = 0.0
	_shen_pose_row = 0
	if was_active and restore_walk and is_instance_valid(body): _apply_role_visual()

func _step_shen_attack_pose(delta: float) -> void:
	if _shen_pose_time<=0.0: return
	if active_member()!="shen":
		_clear_shen_attack_pose()
		return
	_shen_pose_time = maxf(0.0,_shen_pose_time-delta)

func _show_shen_attack_frame(column: int) -> void:
	var index: int = _shen_pose_row*4+clampi(column,0,3)
	body.hframes = 1
	body.vframes = 1
	body.centered = false
	body.position.y = 0.035
	body.texture = _shen_attack_frames[index]
	body.offset = _shen_attack_offsets[index]
	body.pixel_size = _shen_attack_pixel_size


func _arc_feedback(color: Color, radius: float) -> void:
	# Layered crescent: colored falloff, saturated edge, then a thin bright core.
	# All layers are one short-lived source effect and leave danger markings visible.
	var trail: Node3D = Node3D.new()
	var authored_sword: bool = active_member()=="shen" and _shen_pose_time>0.0
	trail.position = hero.position+Vector3.UP*(1.5 if authored_sword else 0.85)
	trail.rotation.y = atan2(aim.x,aim.z)
	add_child(trail)
	# One source light belongs to the same short-lived trail, never to a timer
	# that can outlive its attack. It affects wet scenery, not unshaded actors.
	var glow_light: OmniLight3D = OmniLight3D.new()
	glow_light.light_color = Color("83ceff") if active_member()=="shen" else color
	glow_light.light_energy = 0.45
	glow_light.light_specular = 0.35
	glow_light.omni_range = 3.0
	glow_light.shadow_enabled = false
	glow_light.position.y = 0.2
	trail.add_child(glow_light)
	var outer: Color = color
	outer.a = 0.23
	var edge: Color = color.lightened(0.15)
	edge.a = 0.66
	var core: Color = color.lerp(Color.WHITE,0.85)
	core.a = 0.96
	for layer: int in range(3):
		var width: float = float([0.34,0.17,0.052][layer])
		var tint: Color = [outer,edge,core][layer]
		var node: MeshInstance3D = _sword_crescent(radius,width,tint)
		node.position.y = float(layer)*0.012
		trail.add_child(node)
	var fragments: MeshInstance3D = MeshInstance3D.new()
	var shard_mesh: ImmediateMesh = ImmediateMesh.new()
	shard_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(6):
		var angle: float = -0.84+float(index)*0.34
		var distance: float = radius+0.08+float(index%3)*0.11
		var point: Vector3 = Vector3(sin(angle),0.04,cos(angle))*distance
		var tangent: Vector3 = Vector3(cos(angle),0,-sin(angle))*0.10
		var crosswise: Vector3 = Vector3(sin(angle),0,cos(angle))*0.032
		for vertex: Vector3 in [point-tangent,point+crosswise,point+tangent,point-tangent,point+tangent,point-crosswise]: shard_mesh.surface_add_vertex(vertex)
	shard_mesh.surface_end()
	fragments.mesh = shard_mesh
	var shard_material: StandardMaterial3D = _material(core,true)
	shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fragments.material_override = shard_material
	trail.add_child(fragments)
	# The authored sword is already returning to guard in column two.
	var lifetime: float = 0.14 if authored_sword else 0.20
	sparks.append({"node":trail,"life":lifetime,"max_life":lifetime})

func _spawn_spark(location: Vector3, color: Color, radius: float) -> void:
	# A hit is a few separate sharp chips, not the legacy solid ground disc.
	# Keep one source and the existing spark lifetime/cleanup for every call site.
	var source: Node3D = Node3D.new()
	source.position = location
	add_child(source)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var right: Vector3 = camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT
	var up: Vector3 = camera.global_basis.y if is_instance_valid(camera) else Vector3.UP
	var extent: float = maxf(0.08,radius)
	for index: int in range(6):
		var angle: float = TAU*float(index)/6.0+0.17
		var outward: Vector3 = right*cos(angle)+up*sin(angle)
		var tangent: Vector3 = -right*sin(angle)+up*cos(angle)
		var tip: Vector3 = outward*extent*(0.82+float(index%2)*0.18)
		var tail: Vector3 = outward*extent*0.16
		var middle: Vector3 = outward*extent*0.49
		var width: Vector3 = tangent*minf(0.045,extent*0.095)
		for vertex: Vector3 in [tail,middle+width,tip,tail,tip,middle-width]: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var fragments: MeshInstance3D = MeshInstance3D.new()
	fragments.mesh = mesh
	var material: StandardMaterial3D = _material(color.lightened(0.12),true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fragments.material_override = material
	source.add_child(fragments)
	sparks.append({"node":source,"life":0.18,"max_life":0.18})

func _sword_crescent(radius: float, width: float, color: Color) -> MeshInstance3D:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(32):
		var u: float = float(index)/32.0
		var v: float = float(index+1)/32.0
		var first: float = -1.12+2.24*u
		var second: float = -1.12+2.24*v
		var a: Vector3 = Vector3(sin(first),0,cos(first))
		var b: Vector3 = Vector3(sin(second),0,cos(second))
		var inner_a: float = maxf(0.1,radius-width*pow(sin(PI*u),0.65))
		var inner_b: float = maxf(0.1,radius-width*pow(sin(PI*v),0.65))
		for vertex: Vector3 in [a*inner_a,a*radius,b*radius,a*inner_a,b*radius,b*inner_b]: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	var material: StandardMaterial3D = _material(color,true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	return node

func _field_ring(radius: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = maxf(0.05,radius-0.045)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 8
	node.mesh = torus
	node.material_override = _material(color,true)
	return node

func _field_marker(parent: Node3D, type: String) -> void:
	var pole: MeshInstance3D = MeshInstance3D.new()
	var pole_mesh: BoxMesh = BoxMesh.new()
	pole_mesh.size = Vector3(0.035,1.0,0.035)
	pole.mesh = pole_mesh
	pole.position = Vector3(0,0.5,0)
	pole.material_override = _material(Color("8b7356"),false)
	parent.add_child(pole)
	var paper: MeshInstance3D = MeshInstance3D.new()
	var paper_mesh: BoxMesh = BoxMesh.new()
	paper_mesh.size = Vector3(0.4,0.3,0.025) if type=="flag" else Vector3(0.16,0.32,0.025)
	paper.mesh = paper_mesh
	paper.position = Vector3(0.19,0.8,0) if type=="flag" else Vector3(0,0.85,0)
	paper.material_override = _material(Color("d7b469") if type=="flag" else Color("98e5cf"),false)
	paper.rotation.z = -0.08 if type=="flag" else 0.12
	parent.add_child(paper)

func _enemy_in_range(enemy: Dictionary, origin: Vector3, radius: float) -> bool:
	if float(enemy.get("hp",0.0)) <= 0.0: return false
	var raw: Variant = enemy.get("node")
	if not is_instance_valid(raw): return false
	var node: Node3D = raw as Node3D
	return node.position.distance_to(origin) <= radius and not _wall_between(origin,node.position)

func _melee(owner: String, cast_id: int, damage: float, radius: float, facing: float, displacement: float = 0.0, poise: float = 12.0) -> bool:
	var hit: bool = false
	for enemy: Dictionary in enemies:
		if not _enemy_in_range(enemy,hero.position,radius): continue
		var node: Node3D = enemy["node"] as Node3D
		var offset: Vector3 = node.position-hero.position
		if offset.length()>0.5 and aim.dot(offset.normalized()) < facing: continue
		_hit(enemy,damage,owner,cast_id,poise)
		hit = true
		if float(enemy["hp"]) > 0.0 and not bool(enemy.get("boss",false)) and not bool(enemy.get("elite",false)):
			var push: Vector3 = offset.normalized()*displacement
			if node is CharacterBody3D: (node as CharacterBody3D).move_and_collide(push)
	return hit

func _detonate(owner: String, cast_id: int, key: String, damage: float) -> void:
	var targets: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if float(enemy.get(key,0.0))>0.0 and _enemy_in_range(enemy,hero.position,8.0): targets.append(enemy)
	if targets.is_empty():
		on_combat_message("没有有效印记：先命中"+("灵火签" if owner == "shen" else "定星")+"。")
		return
	if owner == "lu" and _mechanism(owner):
		_fire(hero.position,aim*16.0,damage,owner,cast_id,Color("ffdcff"),true,2.0,"lu_detonate")
		return
	var processed: Array[Dictionary] = []
	for enemy: Dictionary in targets:
		if _mechanism(owner) and processed.size()>=3: break
		enemy[key] = 0.0
		if enemy in processed: continue
		processed.append(enemy)
		_hit(enemy,damage*(0.85 if _mechanism(owner) else 1.0),owner,cast_id,24.0)
		var node: Node3D = enemy["node"] as Node3D
		_spawn_spark(node.position+Vector3.UP*0.2,ROLE_COLORS[owner],1.1)
		if _mechanism(owner):
			var extra: int = 0
			for other: Dictionary in enemies:
				if other in targets or other in processed: continue
				if processed.size()>=3: break
				if _enemy_in_range(other,node.position,2.4):
					processed.append(other)
					_hit(other,damage*0.5,owner,cast_id)
					extra += 1
					if extra >= 2: break

func _hit(enemy: Dictionary, damage: float, owner: String, cast_id: int, poise: float = 8.0) -> void:
	if combat_finished or float(enemy.get("hp",0.0)) <= 0.0: return
	var raw: Variant = enemy.get("node")
	if not is_instance_valid(raw): return
	var node: Node3D = raw as Node3D
	var multiplier: float = 1.25 if float(enemy.get("broken",0.0)) > 0.0 else 1.0
	enemy["hp"] = maxf(0.0,float(enemy["hp"])-damage*_damage_scale(owner)*multiplier)
	_sync_enemy_healthbar(enemy)
	_credit_cast(cast_id)
	on_combat_feedback("hit",node.position)
	_spawn_spark(node.position+Vector3.UP*0.8,Color("e5f5ed"),0.22)
	if bool(enemy.get("boss",false)) or bool(enemy.get("elite",false)):
		if float(enemy.get("poise_guard",0.0))<=0.0 and float(enemy.get("windup",0.0)) <= 0.0:
			enemy["poise"] = float(enemy.get("poise",0.0))+poise
			if float(enemy["poise"]) >= (140.0 if bool(enemy.get("boss",false)) else 70.0):
				enemy["poise"] = 0.0
				enemy["broken"] = 1.8
				enemy["poise_guard"] = 7.0
	else: enemy["stun"] = maxf(float(enemy.get("stun",0.0)),0.13)
	if float(enemy["hp"]) > 0.0: return
	kills += 1
	on_enemy_reward({"elite":bool(enemy.get("elite",false)),"boss":bool(enemy.get("boss",false)),"position":node.position,"owner":owner})
	_clear_enemy_warning(enemy)
	node.queue_free()
	if bool(enemy.get("boss",false)) or _living_count() == 0:
		if bool(enemy.get("boss",false)) or combat_wave >= 3:
			combat_finished = true
			awakening_energy = 0.0
			call_deferred("_notify_end",true,_run_serial)
		else:
			_next_wave = 1.3
			on_combat_message("清场！下一波即将抵达。")

func _living_count() -> int:
	var count: int = 0
	for enemy: Dictionary in enemies:
		if float(enemy.get("hp",0.0))>0.0: count += 1
	return count

func _spawn_ferry_wave() -> void:
	combat_wave += 1
	for enemy: Dictionary in enemies: _release_node(enemy)
	enemies.clear()
	var points: Array[Vector3] = [Vector3(-4,0,-3),Vector3(3,0,-3),Vector3(5,0,0),Vector3(-5,0,0),Vector3(0,0,-4)]
	var amount: int = 3+combat_wave+(1 if combat_difficulty>0 else 0)
	for index: int in range(amount):
		var pos: Vector3 = points[index%points.size()]+Vector3(float(index/5)*0.8,0,0)
		_spawn_combat_enemy(pos,index%3 == 1,combat_wave == 3 and index == amount-1,false)
	on_combat_message("雨灯渡口 · 第%d / 3波%s"%[combat_wave," · 困难远程增援" if combat_difficulty>0 else ""])

func _spawn_boss() -> void:
	combat_wave = 1
	_spawn_combat_enemy(Vector3(0,0,-2),false,true,true)
	on_combat_message("缚潮舟主：留意钩链方向，避开后抓住收招。")

func _prepare_foe_art() -> bool:
	if not _foe_atlases.is_empty(): return true
	var path: String = "res://assets/characters/foes.png"
	var meta_path: String = "res://assets/characters/foes.json"
	if not ResourceLoader.exists(path) or not FileAccess.file_exists(meta_path): return false
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if not metadata is Dictionary: return false
	var frames: Array = (metadata as Dictionary).get("frames",[])
	if frames.size()!=16: return false
	var texture: Texture2D = load(path) as Texture2D
	for row: int in range(4):
		var textures: Array[Texture2D] = []
		var offsets: Array[Vector2] = []
		var centers: Array[float] = []
		var height: float = 1.0
		for column: int in range(4):
			var frame: Dictionary = frames[row*4+column]
			centers.append(float(frame["foot_x"]))
			height = maxf(height,float((frame["bbox"] as Array)[3]))
		centers.sort()
		var foot_x: float = (centers[1]+centers[2])*0.5
		for column: int in range(4):
			var frame: Dictionary = frames[row*4+column]
			var region: Array = frame["region"]
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
			textures.append(atlas)
			offsets.append(Vector2(-foot_x,float(frame["foot_y"])-float(region[3])))
		_foe_atlases[row] = textures
		_foe_offsets[row] = offsets
		_foe_sizes[row] = float([2.0,2.0,2.6,3.7][row])/height*ACTOR_VISUAL_SCALE
	return true

func _show_foe_frame(sprite: Sprite3D, row: int, frame: int) -> void:
	sprite.texture = (_foe_atlases[row] as Array)[frame]
	sprite.offset = (_foe_offsets[row] as Array)[frame]
	if sprite.flip_h: sprite.offset.x = -sprite.offset.x-float(sprite.texture.get_width())

func _make_enemy_healthbar(elite: bool) -> MeshInstance3D:
	if _healthbar_material == null:
		var shader: Shader = Shader.new()
		shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
instance uniform float hp_ratio = 1.0;
instance uniform float elite_border = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV;
	bool edge = p.x < 0.02 || p.x > 0.98 || p.y < 0.18 || p.y > 0.82;
	vec3 border = mix(vec3(0.035,0.040,0.048),vec3(0.48,0.34,0.14),elite_border);
	vec3 shade = vec3(0.055,0.045,0.052);
	if (p.x > 0.035 && p.x < 0.035 + clamp(hp_ratio,0.0,1.0)*0.93 && p.y > 0.25 && p.y < 0.75) {
		shade = mix(vec3(0.58,0.12,0.12),vec3(0.77,0.24,0.20),step(p.y,0.42));
	}
	ALBEDO = edge ? border : shade;
	ALPHA = 0.96;
}
"""
		_healthbar_material = ShaderMaterial.new()
		_healthbar_material.shader = shader
	var bar: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.28 if elite else 1.05,0.115)
	bar.mesh = quad
	bar.material_override = _healthbar_material
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.set_instance_shader_parameter("hp_ratio",1.0)
	bar.set_instance_shader_parameter("elite_border",1.0 if elite else 0.0)
	return bar

func _sync_enemy_healthbar(enemy: Dictionary) -> void:
	var raw: Variant = enemy.get("hp_bar")
	if not is_instance_valid(raw): return
	var bar: MeshInstance3D = raw as MeshInstance3D
	bar.set_instance_shader_parameter("hp_ratio",clampf(float(enemy["hp"])/maxf(1.0,float(enemy["max_hp"])),0.0,1.0))

func _spawn_combat_enemy(location: Vector3, ranged: bool, elite: bool, boss: bool, lifetime: float = -1.0) -> void:
	var node: CharacterBody3D = CharacterBody3D.new()
	node.collision_layer = 2
	node.collision_mask = 7
	_add_collider(node,0.8 if boss else 0.4)
	node.position = location
	add_child(node)
	var sprite: Sprite3D = Sprite3D.new()
	var tex_path: String = "res://assets/enemy_sheet.png"
	sprite.texture = load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else _pixel_actor(Color("c48064"),Color("382b39"),elite)
	if ResourceLoader.exists(tex_path):
		sprite.hframes = 4
		sprite.vframes = 4
	sprite.pixel_size = (3.7 if boss else (2.6 if elite else 2.0))/(float(sprite.texture.get_height())/float(sprite.vframes))*ACTOR_VISUAL_SCALE
	var foe_row: int = 3 if boss else (2 if elite else (1 if ranged else 0))
	if _prepare_foe_art():
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.centered = false
		sprite.pixel_size = float(_foe_sizes[foe_row])
		sprite.position.y = 0.035
		_show_foe_frame(sprite,foe_row,0)
	else:
		foe_row = -1
		sprite.position.y = (1.65 if boss else 1.0)*ACTOR_VISUAL_SCALE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	node.add_child(sprite)
	var shadow: MeshInstance3D = _disc(0.85 if boss else 0.4,Color(0,0,0,0.4))
	shadow.position.y = 0.03
	node.add_child(shadow)
	var label: Label3D = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = (3.95 if boss else 3.05)*ACTOR_VISUAL_SCALE
	label.font_size = 22
	label.modulate = Color("d9c8a7")
	label.outline_size = 4
	label.pixel_size = 0.008
	if font != null: label.font = font
	node.add_child(label)
	var hp_bar: MeshInstance3D = null
	if not boss:
		hp_bar = _make_enemy_healthbar(elite)
		hp_bar.position.y = (2.83 if elite else 2.23)*ACTOR_VISUAL_SCALE
		node.add_child(hp_bar)
	var hp: float = 1400.0 if boss else (220.0 if elite else (72.0 if ranged else 96.0))
	if combat_difficulty>0: hp *= 1.2
	enemies.append({"node":node,"sprite":sprite,"label":label,"hp":hp,"max_hp":hp,"ranged":ranged,"elite":elite,"boss":boss,"cd":1.5,"windup":0.0,"slow":0.0,"stun":0.0,"warn":null,"locked_dir":Vector3.FORWARD,"broken":0.0,"poise":0.0,"poise_guard":0.0,"shen_mark":0.0,"lu_mark":0.0,"life":lifetime,"phase":1,"foe_row":foe_row,"hp_bar":hp_bar})

func _update_enemies(delta: float) -> void:
	var adds: Array[Vector3] = []
	for enemy: Dictionary in enemies:
		if float(enemy["hp"]) <= 0.0: continue
		var node: CharacterBody3D = enemy["node"] as CharacterBody3D
		if not is_instance_valid(node): continue
		for key: String in ["cd","slow","stun","broken","poise_guard","shen_mark","lu_mark"]: enemy[key] = maxf(0.0,float(enemy[key])-delta)
		if float(enemy["life"])>0.0:
			enemy["life"] = float(enemy["life"])-delta
			if float(enemy["life"])<=0.0:
				enemy["hp"] = 0.0
				node.queue_free()
				continue
		var offset: Vector3 = hero.position-node.position
		var distance: float = offset.length()
		var sprite: Sprite3D = enemy["sprite"] as Sprite3D
		var label: Label3D = enemy["label"] as Label3D
		label.text = ("缚潮舟主" if bool(enemy["boss"]) else "")+(" · 破势" if float(enemy["broken"])>0.0 else "")
		_sync_enemy_healthbar(enemy)
		var tag_tint: Color = Color.WHITE
		if float(enemy["slow"])>0.0: tag_tint = Color("a6efff")
		elif not bool(enemy["boss"]):
			if bool(enemy["elite"]): tag_tint = Color("ffb195")
			elif bool(enemy["ranged"]): tag_tint = Color("c2ade2")
		sprite.modulate = tag_tint*ACTOR_NIGHT_TINT
		if int(enemy.get("foe_row",-1))>=0:
			sprite.flip_h = offset.dot(camera.global_basis.x)>0.0
			_show_foe_frame(sprite,int(enemy["foe_row"]),int(elapsed*7.0)%4)
		elif sprite.hframes==4: sprite.frame = _sprite_row(offset)*4+int(elapsed*7.0)%4
		if bool(enemy["boss"]):
			var ratio: float = float(enemy["hp"])/float(enemy["max_hp"])
			var phase: int = 3 if ratio<=0.35 else (2 if ratio<=0.7 else 1)
			if phase>int(enemy["phase"]):
				enemy["phase"] = phase
				boss_phase = phase
				enemy["cd"] = maxf(1.3,float(enemy["cd"]))
				on_combat_message("舟主第%d阶段：%s"%[phase,"潮带与短命增援" if phase==2 else "钩链组合与收潮，观察安全带"])
				if phase == 2:
					adds.append(Vector3(-5,0,-3))
					adds.append(Vector3(5,0,-3))
			_update_boss(enemy,delta,offset)
			continue
		if float(enemy["broken"])>0.0 or float(enemy["stun"])>0.0: continue
		if float(enemy["windup"])>0.0:
			enemy["windup"] = float(enemy["windup"])-delta
			if float(enemy["windup"])<=0.0:
				_clear_enemy_warning(enemy)
				if bool(enemy["ranged"]):
					var dir: Vector3 = enemy["locked_dir"]
					_fire(node.position,dir*6.0,13.0,"",-1,Color("f69c91"),false,3.0)
					if combat_difficulty>0: _fire(node.position,dir.rotated(Vector3.UP,0.18)*6.0,11.0,"",-1,Color("eeb096"),false,3.0)
				elif distance< (2.0 if bool(enemy["elite"]) else 1.6) and not _wall_between(node.position,hero.position): combat_hurt(22.0 if bool(enemy["elite"]) else 11.0)
				enemy["cd"] = 1.6
			continue
		var stop: float = 5.5 if bool(enemy["ranged"]) else 1.4
		if distance>stop:
			var speed: float = (1.2 if bool(enemy["elite"]) else 1.65)*(0.3 if float(enemy["slow"])>0.0 else 1.0)
			node.move_and_collide(offset.normalized()*speed*delta)
		elif float(enemy["cd"])<=0.0:
			enemy["windup"] = 0.85 if bool(enemy["elite"]) else 0.65
			enemy["locked_dir"] = offset.normalized()
			if not bool(enemy["ranged"]):
				var warn: MeshInstance3D = _disc(2.0 if bool(enemy["elite"]) else 1.6,Color(1,0.25,0.12,0.32))
				warn.position.y = 0.06
				node.add_child(warn)
				enemy["warn"] = warn
	for point: Vector3 in adds: _spawn_combat_enemy(point,true,false,false,18.0)

func _update_boss(enemy: Dictionary, delta: float, offset: Vector3) -> void:
	if float(enemy["broken"])>0.0: return
	var node: CharacterBody3D = enemy["node"] as CharacterBody3D
	if float(enemy["cd"])>0.0:
		if float(enemy["cd"])>1.3 and offset.length()>3.5: node.move_and_collide(offset.normalized()*0.65*delta)
		return
	_boss_turn += 1
	var phase: int = int(enemy["phase"])
	var dir: Vector3 = offset.normalized()
	if phase>=2 and _boss_turn%3==0:
		for index: int in range(3): _hazard(Vector3(0,0,-3.2+index*2.6),Vector3.FORWARD,Vector2(14,1.2),1.1+index*0.4,22.0,"band")
		if phase==3:
			_hazard(Vector3(-6.5,0,0),Vector3.FORWARD,Vector2(2.5,11),1.8,24.0,"band")
			enemy["cd"] = 4.5
		else: enemy["cd"] = 4.0
	else:
		if _boss_turn%2==1:
			_hazard(node.position+dir*4.0,dir,Vector2(1.5,8.0),1.0,28.0,"line")
			if phase==3: _hazard(node.position,dir,Vector2(3.3,3.3),1.8,24.0,"sweep")
		else:
			_hazard(node.position,dir,Vector2(3.5,3.5),0.95,26.0,"sweep")
			if combat_difficulty>0: _fire(node.position,dir*4.5,12.0,"",-1,Color("f1ac73"),false,3.0)
		enemy["cd"] = 3.0 if phase<3 else 3.6

func _clear_enemy_warning(enemy: Dictionary) -> void:
	var warn: Variant = enemy.get("warn")
	if is_instance_valid(warn): (warn as Node).queue_free()
	enemy["warn"] = null

func _sector(radius: float, half_angle: float, color: Color) -> MeshInstance3D:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(24):
		var first: float = -half_angle+2.0*half_angle*float(index)/24.0
		var second: float = -half_angle+2.0*half_angle*float(index+1)/24.0
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(first),0,cos(first))*radius)
		mesh.surface_add_vertex(Vector3(sin(second),0,cos(second))*radius)
	mesh.surface_end()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	var material: StandardMaterial3D = _material(color,true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	return node

func _hazard(center: Vector3, direction: Vector3, size: Vector2, delay: float, damage: float, shape: String) -> void:
	var node: MeshInstance3D
	if shape == "sweep":
		node = _sector(size.x,1.2,Color(1,0.3,0.1,0.3))
		node.rotation.y = atan2(direction.x,direction.z)
	else:
		node = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(size.x,0.035,size.y)
		node.mesh = box
		node.material_override = _material(Color(1,0.28,0.1,0.3),true)
		node.rotation.y = atan2(direction.x,direction.z)
	node.position = center+Vector3.UP*0.07
	add_child(node)
	combat_hazards.append({"node":node,"center":center,"dir":direction,"size":size,"delay":delay,"damage":damage,"shape":shape,"struck":false,"life":delay+0.25})

func _update_hazards(delta: float) -> void:
	for index: int in range(combat_hazards.size()-1,-1,-1):
		var hazard: Dictionary = combat_hazards[index]
		hazard["delay"] = float(hazard["delay"])-delta
		hazard["life"] = float(hazard["life"])-delta
		if not bool(hazard["struck"]) and float(hazard["delay"])<=0.0:
			hazard["struck"] = true
			var offset: Vector3 = hero.position-(hazard["center"] as Vector3)
			var dir: Vector3 = hazard["dir"]
			var size: Vector2 = hazard["size"]
			var inside: bool = (offset.length()<size.x and (offset.length()<0.3 or dir.dot(offset.normalized())>cos(1.2))) if str(hazard["shape"])=="sweep" else (absf(offset.dot(dir))<size.y*0.5 and absf(offset.dot(Vector3(dir.z,0,-dir.x)))<size.x*0.5)
			if inside and not _wall_between(hazard["center"],hero.position): combat_hurt(float(hazard["damage"]))
			_spawn_spark(hazard["center"]+Vector3.UP*0.1,Color("f4aa6b"),1.4)
		if float(hazard["life"])<=0.0:
			_release_node(hazard)
			combat_hazards.remove_at(index)

func _fire(location: Vector3, velocity: Vector3, damage: float, owner: String, cast_id: int, color: Color, piercing: bool, lifetime: float, mark: String = "") -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.13 if not owner.is_empty() else 0.21
	mesh.height = mesh.radius*2.0
	node.mesh = mesh
	node.material_override = _material(color,true)
	node.position = location+Vector3.UP*0.7
	add_child(node)
	projectiles.append({"node":node,"velocity":velocity,"damage":damage,"owner":owner,"cast_id":cast_id,"life":lifetime,"piercing":piercing,"hits":[],"max_hits":3,"mark":mark})

func _projectile(location: Vector3, velocity: Vector3, damage: float, friendly: bool, color: Color, lifetime: float) -> void:
	_fire(location-Vector3.UP*0.7,velocity,damage,active_member() if friendly else "",-1,color,false,lifetime)

func _segment_distance(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment: Vector3 = finish-start
	var ratio: float = clampf((point-start).dot(segment)/maxf(0.0001,segment.length_squared()),0.0,1.0)
	return point.distance_to(start+segment*ratio)

func _update_projectiles(delta: float) -> void:
	# A hit can down a character and remove its other shots. Snapshot iteration
	# prevents index corruption when that real cleanup occurs during this loop.
	for shot: Dictionary in projectiles.duplicate():
		if shot not in projectiles: continue
		var node: Node3D = shot["node"] as Node3D
		var start: Vector3 = node.position
		node.position += (shot["velocity"] as Vector3)*delta
		shot["life"] = float(shot["life"])-delta
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start,node.position,1)
		query.hit_from_inside = true
		var consumed: bool = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if not consumed and not str(shot["owner"]).is_empty():
			for enemy: Dictionary in enemies:
				if float(enemy["hp"])<=0.0 or enemy in (shot["hits"] as Array): continue
				var target: Node3D = enemy["node"] as Node3D
				if _segment_distance(target.position+Vector3.UP*0.7,start,node.position)<(0.9 if bool(enemy["boss"]) else 0.6):
					(shot["hits"] as Array).append(enemy)
					var hit_damage: float = float(shot["damage"])
					if str(shot["mark"])=="lu_detonate":
						hit_damage *= 1.0 if float(enemy["lu_mark"])>0.0 else 0.5
						enemy["lu_mark"] = 0.0
					elif not str(shot["mark"]).is_empty(): enemy[str(shot["mark"])+"_mark"] = 9.0
					_hit(enemy,hit_damage,str(shot["owner"]),int(shot["cast_id"]))
					if not bool(shot["piercing"]) or (shot["hits"] as Array).size()>=int(shot.get("max_hits",3)):
						consumed = true
						break
		elif not consumed and _segment_distance(hero.position+Vector3.UP*0.7,start,node.position)<0.5:
			combat_hurt(float(shot["damage"]))
			consumed = true
		if consumed or float(shot["life"])<=0.0:
			node.queue_free()
			projectiles.erase(shot)

func _place_field(owner: String, type: String, point: Vector3, radius: float, lifetime: float) -> void:
	for index: int in range(combat_fields.size()-1,-1,-1):
		if str(combat_fields[index]["owner"])==owner and str(combat_fields[index]["type"])==type:
			_release_node(combat_fields[index])
			combat_fields.remove_at(index)
	var node: MeshInstance3D = _field_ring(radius,Color(0.25,0.8,0.65,0.55) if type=="bind" else Color(0.9,0.65,0.25,0.5))
	node.position = point+Vector3.UP*0.065
	_field_marker(node,type)
	add_child(node)
	combat_fields.append({"node":node,"owner":owner,"type":type,"life":lifetime,"radius":radius})

func _update_fields(delta: float) -> void:
	for index: int in range(combat_fields.size()-1,-1,-1):
		var field: Dictionary = combat_fields[index]
		field["life"] = float(field["life"])-delta
		var node: Node3D = field["node"] as Node3D
		if str(field["type"])=="bind":
			for enemy: Dictionary in enemies:
				if _enemy_in_range(enemy,node.position,float(field["radius"])): enemy["slow"] = 0.2
		if float(field["life"])<=0.0:
			node.queue_free()
			combat_fields.remove_at(index)

func _inside_flag(point: Vector3) -> bool:
	for field: Dictionary in combat_fields:
		if str(field["type"])=="flag" and (field["node"] as Node3D).position.distance_to(point)<float(field["radius"]): return true
	return false

func _spawn_lamp(owner: String) -> void:
	for index: int in range(summons.size()-1,-1,-1):
		if str(summons[index].get("owner",""))==owner:
			_release_node(summons[index])
			summons.remove_at(index)
	while summons.size()>=2:
		_release_node(summons[0])
		summons.remove_at(0)
	var node: Node3D = Node3D.new()
	node.position = hero.position+Vector3(1,0,0)
	add_child(node)
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = load("res://assets/summon_sheet.png") as Texture2D if ResourceLoader.exists("res://assets/summon_sheet.png") else _pixel_actor(Color("96ffe0"),Color("3789a8"),false)
	if ResourceLoader.exists("res://assets/summon_sheet.png"):
		sprite.hframes = 4
		sprite.vframes = 4
	sprite.pixel_size = 1.4/(float(sprite.texture.get_height())/float(sprite.vframes))
	sprite.position.y = 1.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.add_child(sprite)
	summons.append({"node":node,"sprite":sprite,"owner":owner,"life":10.0,"cd":0.4})

func _command_lamps(cast_id: int) -> void:
	var target: Dictionary = {}
	var best: float = INF
	for enemy: Dictionary in enemies:
		if not _enemy_in_range(enemy,hero.position,8.0): continue
		var candidate: Node3D = enemy["node"] as Node3D
		var offset: Vector3 = candidate.position-hero.position
		if offset.length()>0.5 and aim.dot(offset.normalized())<0.35: continue
		var score: float = candidate.position.distance_squared_to(hero.position+aim*4.0)
		if score<best:
			best = score
			target = enemy
	if target.is_empty(): return
	var target_node: Node3D = target["node"] as Node3D
	for lamp: Dictionary in summons:
		if str(lamp["owner"]) != "zhu": continue
		var node: Node3D = lamp["node"] as Node3D
		_fire(node.position,(target_node.position-node.position).normalized()*14.0,58.0,"zhu",cast_id,Color("acffe6"),_mechanism("zhu"),2.0)
		if _mechanism("zhu") and not projectiles.is_empty(): projectiles[-1]["max_hits"] = 2
		lamp["cd"] = 0.8

func _update_summons(delta: float) -> void:
	for index: int in range(summons.size()-1,-1,-1):
		var lamp: Dictionary = summons[index]
		lamp["life"] = float(lamp["life"])-delta
		lamp["cd"] = float(lamp["cd"])-delta
		var node: Node3D = lamp["node"] as Node3D
		var sprite: Sprite3D = lamp["sprite"] as Sprite3D
		if sprite.hframes==4: sprite.frame = int(elapsed*6.0)%4
		if float(lamp["cd"])<=0.0:
			var target: Dictionary = _nearest_enemy(node.position)
			if not target.is_empty():
				var target_node: Node3D = target["node"] as Node3D
				_fire(node.position,(target_node.position-node.position).normalized()*8.0,16.0,str(lamp["owner"]),-1,Color("82e7c5"),false,2.0)
			lamp["cd"] = 1.1
		if float(lamp["life"])<=0.0:
			node.queue_free()
			summons.remove_at(index)

func _clear_owner_effects(owner: String) -> void:
	for collection: Array in [summons,combat_fields,projectiles]:
		for index: int in range(collection.size()-1,-1,-1):
			if str(collection[index].get("owner",""))==owner:
				_release_node(collection[index])
				collection.remove_at(index)
	_pull_bonus.erase(owner)
	for enemy: Dictionary in enemies: enemy[owner+"_mark"] = 0.0

func _combat_demo() -> Vector3:
	var target: Dictionary = _nearest_enemy(hero.position)
	if target.is_empty(): return Vector3.ZERO
	var node: Node3D = target["node"] as Node3D
	var offset: Vector3 = node.position-hero.position
	if offset.length_squared()>0.001: aim = offset.normalized()
	use_basic()
	if active_member()=="zhu":
		if summons.is_empty(): _cast_skill(0,hero.position)
		_cast_skill(2,node.position)
		_cast_skill(1,node.position)
	else:
		use_skill(2)
		use_skill(0)
		use_skill(3)
	if awakening_energy>=100.0: use_awakening()
	if not combat_hazards.is_empty(): _dodge(Vector3(-aim.z,0,aim.x))
	if elapsed-_demo_switch_time>5.0:
		if switch_member((active_slot+1)%combat_party.size()): _demo_switch_time = elapsed
	var range_target: float = 4.0 if active_member() in ["lu","zhu"] else 1.9
	return aim if offset.length()>range_target else Vector3.ZERO
