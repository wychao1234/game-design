extends "res://scripts/adventure_combat.gd"

const PROGRESS_SCRIPT = preload("res://scripts/adventure_progress.gd")
const HUD_SCRIPT = preload("res://scripts/adventure_hud.gd")
const WATERFRONT_SCRIPT = preload("res://scripts/waterfront.gd")
const VIEW_FOCUS := Vector3(-1,0,-2)
const VIEW_OFFSET := Vector3(8,14,24.5)
const VIEW_SIZE := 13.0
const VIEW_FOV := 26.0

var progress: RefCounted
var hud_view: CanvasLayer
var scenery: Node3D
var area := "town"
var run_id := ""
var run_difficulty := 0
var last_reward: Dictionary = {}
var world_time := 0.0
var notice_text := ""
var notice_left := 0.0
var ui_elapsed := 0.0
var input_block := 0
var capture_at := 6.0
var demo_duration := 0.0
var initial_area := "town"
var transitions := 0
var _tone_cache: Dictionary = {}
var _sound_pool: Array[AudioStreamPlayer] = []
var _sound_index := 0
var _last_sound := -10.0
var _demo_finished_at := -1.0
var town_npcs: Array[Node3D] = []

func _ready() -> void:
	save_path="user://linchuan_preview_v2.json"
	for argument:String in OS.get_cmdline_user_args():
		if argument=="--demo":demo=true
		if argument.begins_with("--capture="):capture_path=argument.trim_prefix("--capture=")
		if argument.begins_with("--capture-at="):capture_at=maxf(0.1,float(argument.trim_prefix("--capture-at=")))
		if argument.begins_with("--demo-duration="):demo_duration=float(argument.trim_prefix("--demo-duration="))
		if argument.begins_with("--scene="):initial_area=argument.trim_prefix("--scene=")
		if argument.begins_with("--stage="):initial_area=argument.trim_prefix("--stage=")
		if argument.begins_with("--test-profile="):save_path=argument.trim_prefix("--test-profile=")
		if argument.begins_with("--save-path="):save_path=argument.trim_prefix("--save-path=")
		if argument.begins_with("--party="):
			# A launch-time lineup belongs only to an explicitly isolated QA profile.
			pass
	font=load("res://assets/fonts/NotoSansCJKJP-Regular.woff2") as Font
	progress=PROGRESS_SCRIPT.new()
	progress.load_game(save_path)
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--party=") and save_path!="user://linchuan_preview_v2.json":
			progress.set_party(Array(argument.trim_prefix("--party=").split(",")))
	_setup_camera()
	_reset_view()
	_setup_hero()
	hero.position=Vector3(0,0,4)
	sword.scale=Vector3(0.5,0.65,0.85)
	hud_view=HUD_SCRIPT.new();add_child(hud_view);hud_view.setup(font,PROGRESS_SCRIPT.ITEMS);hud_view.action.connect(_on_ui_action)
	_setup_audio()
	_enter_town()
	if not progress.save_enabled:
		_show_message(progress.warning,15)
	else:
		progress.save_game()
		_show_message("临川雨夜 · 靠近渡口按 T，或按 M 选择关卡。I 整理装备，P 调整三人编队。",9)
	if initial_area in ["ferry","boss"]: _start_stage(initial_area,0)
	_update_preview_ui()

func _process(_delta:float)->void:
	pass

func _physics_process(delta:float)->void:
	world_time+=delta
	notice_left=maxf(0.0,notice_left-delta)
	if notice_left<=0:notice_text=""
	if _pressed(KEY_ESCAPE):
		if preview_slot>=0:cancel_skill_preview();input_block=2
		elif hud_view.is_open():_close_panel()
		else:_open_pause()
	if _pressed(KEY_I) or _pressed(KEY_B):
		if hud_view.is_open() and hud_view.menu_kind=="inventory":_close_panel()
		else:_open_inventory()
	if area=="town" and not hud_view.is_open():
		if _pressed(KEY_M):_open_map()
		if _pressed(KEY_P):_open_party()
	if not hud_view.is_open():
		if area=="town":_town_step(delta)
		elif not combat_finished:
			var before:int=active_slot
			combat_step(delta,input_block<=0)
			progress.data.active_character=active_member()
			if active_slot!=before:_play_sound("switch")
		elif _pressed(KEY_T):_enter_town()
		if area=="town" and _pressed(KEY_T):_interact_town()
	if input_block>0:input_block-=1
	_follow_view(delta)
	ui_elapsed+=delta
	if ui_elapsed>=0.08:_update_preview_ui();ui_elapsed=0.0
	if demo:
		if hud_view.is_open() and hud_view.menu_kind=="results" and _demo_finished_at<0:_demo_finished_at=world_time
		if demo_duration>0 and world_time>=demo_duration:get_tree().quit()
	if not capture_path.is_empty() and not captured and world_time>=capture_at:
		captured=true;call_deferred("_capture")

func _town_step(delta:float)->void:
	elapsed+=delta
	var move:=Vector3.ZERO
	if demo:
		aim=Vector3.FORWARD
	else:
		var axes:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var right:Vector3=camera.global_basis.x;right.y=0
		var back:Vector3=camera.global_basis.z;back.y=0
		move=(right.normalized()*axes.x+back.normalized()*axes.y).limit_length(1)
		if move.length_squared()>0.01:aim=move.normalized()
	(hero as CharacterBody3D).move_and_collide(move*MOVE_SPEED*delta)
	hero.position.x=clampf(hero.position.x,-10.3,10.3);hero.position.z=clampf(hero.position.z,-6.3,6.3)
	_update_role_visual(move)

func _reset_view()->void:
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=VIEW_FOV
	camera.size=VIEW_SIZE
	camera.position=VIEW_FOCUS+VIEW_OFFSET
	camera.look_at(VIEW_FOCUS)

func _follow_view(delta:float)->void:
	# Mild perspective gives the far shore depth. Follow the near corners enough
	# to keep the player's feet clear of the bottom edge during a dodge.
	var drift:=Vector3(clampf(hero.position.x*0.4,-4,4),0,clampf(hero.position.z*0.45,-2.9,2.9))
	var focus:=VIEW_FOCUS+drift
	var target:=focus+VIEW_OFFSET
	camera.position=camera.position.lerp(target,minf(1.0,delta*3.2))
	camera.look_at(camera.position-VIEW_OFFSET)

func _set_scenery(mode:String)->void:
	for npc: Node3D in town_npcs:
		if is_instance_valid(npc): npc.queue_free()
	town_npcs.clear()
	if is_instance_valid(scenery):remove_child(scenery);scenery.queue_free()
	scenery=WATERFRONT_SCRIPT.new();scenery.mode=mode;add_child(scenery);scenery.configure_camera(camera)
	_reset_view()
	if mode=="town": _spawn_town_npcs()
	transitions+=1

func _enter_town()->void:
	if progress.in_run:
		progress.end_run()
		if progress.in_run:_show_message(progress.warning,10);return
	combat_clear()
	area="town";run_id=""
	_set_scenery("town")
	combat_party.clear()
	for id:String in progress.data.party:combat_party.append(id)
	active_slot=0
	_refresh_combat_stats()
	member_hp.clear();skill_timers.clear()
	for id:String in combat_party:member_hp[id]=_max_hp(id);skill_timers[id]=[0.0,0.0,0.0,0.0]
	hero.position=Vector3(0,0,4);aim=Vector3.FORWARD
	dodge_time=0;dodge_charges=2;dodge_recharge=0;awakening_energy=0;attack_cd=0;swing_time=0
	_apply_role_visual()
	_close_panel()
	_update_preview_ui()

func _start_stage(stage:String,difficulty:int)->bool:
	if not stage in ["ferry","boss"]:return false
	if progress.in_run:
		progress.end_run()
		if progress.in_run:_show_message(progress.warning,10);return false
	var new_id:String=progress.begin_run(stage,difficulty)
	if new_id.is_empty():_show_message(progress.warning if not progress.warning.is_empty() else "无法出发，请检查存档状态。",10);return false
	combat_clear();area=stage;run_id=new_id;run_difficulty=difficulty
	_set_scenery(stage)
	_refresh_combat_stats()
	var party:Array[String]=[]
	for id:String in progress.data.party:party.append(id)
	combat_begin(party,stage,difficulty)
	_close_panel()
	_show_message("渡口三段封锁 · 聚拢敌群，再轮换衔接。" if stage=="ferry" else "缚潮舟主 · 留意钩尖、锁链与地面潮纹。",5)
	_update_preview_ui()
	return true

func _refresh_combat_stats()->void:
	combat_stats.clear()
	for id:String in PROGRESS_SCRIPT.CHARACTERS:
		var stat:Dictionary=progress.get_equipment_stats(id)
		var level:int=int(progress.data.characters[id].level)
		combat_stats[id]={"damage":1.0+float(stat.attack)/24.0+(level-1)*0.045,"max_hp":100.0+(level-1)*8.0,"defense":stat.defense,"mechanism":not str(stat.mechanism).is_empty(),"mechanism_id":stat.mechanism}

func on_combat_message(text:String)->void:
	_show_message(text,2.6)
	if text.contains("觉醒"):_play_sound("awakening")
	elif text.contains("召") or text.contains("灯"):_play_sound("bell")

func on_enemy_reward(enemy:Dictionary)->void:
	progress.data.active_character=active_member()
	var reward:Dictionary=progress.grant_kill(bool(enemy.get("elite",false)) or bool(enemy.get("boss",false)))
	if not bool(reward.get("ok",false)):_show_message(str(reward.get("error","奖励保存失败")),8);return
	for item:Dictionary in reward.get("items",[]):_show_loot(item,enemy.get("position",hero.position))

func on_combat_victory()->void:
	progress.data.active_character=active_member()
	var reward:Dictionary=progress.grant_clear(run_id,area,run_difficulty)
	if not bool(reward.get("ok",false)):
		_show_message(str(reward.get("error","结算保存失败")),12)
		return
	last_reward=reward
	for item:Dictionary in reward.get("items",[]):_show_loot(item,hero.position+Vector3(1.4,0,-1))
	progress.end_run()
	_play_sound("loot")
	input_block=2;cancel_skill_preview();hud_view.show_results(reward,true,area)
	_update_preview_ui()

func on_combat_defeat()->void:
	progress.end_run()
	input_block=2;cancel_skill_preview();hud_view.show_results({},false,area)
	_show_message("暂时退下也无妨，已经获得的成长都在。",6)
	_update_preview_ui()

func _show_loot(item:Dictionary,location:Vector3)->void:
	var template:Dictionary=PROGRESS_SCRIPT.ITEMS.get(item.get("template_id",""),{})
	if template.is_empty():return
	var color:Color={"普通":Color("b5c4ce"),"精良":Color("8bd8b7"),"稀有":Color("67cfff")}.get(template.rarity,Color("b5c4ce"))
	var marker:=Node3D.new();marker.position=location;add_child(marker)
	marker.name="AcquiredLoot_"+str(template.slot)
	_loot_equipment(marker,str(template.slot),str(template.character),color)
	var ground_ring:=TorusMesh.new();ground_ring.inner_radius=0.31;ground_ring.outer_radius=0.33;ground_ring.rings=32;ground_ring.ring_segments=8
	_loot_piece(marker,ground_ring,Vector3(0,0.035,0),color*Color(1,1,1,0.65),0.0,true)
	if template.rarity=="稀有":
		var beam:=QuadMesh.new();beam.size=Vector2(0.10,1.9)
		var material:=ShaderMaterial.new();material.shader=load("res://assets/effects/loot_beam.gdshader");material.set_shader_parameter("light_color",color)
		var pillar:=MeshInstance3D.new();pillar.name="RareLootBeam";pillar.mesh=beam;pillar.material_override=material;pillar.position.y=1.02;marker.add_child(pillar)
		for index:int in range(3):
			var spark_mesh:=SphereMesh.new();spark_mesh.radius=0.018;spark_mesh.height=0.036;spark_mesh.radial_segments=6;spark_mesh.rings=4
			var spark:=_loot_piece(marker,spark_mesh,Vector3(sin(index*2.1)*0.16,0.28+index*0.21,cos(index*2.1)*0.16),color,0.0,true)
			var tween:=spark.create_tween().set_loops();tween.tween_property(spark,"position:y",spark.position.y+0.23,0.8+index*0.15);tween.tween_property(spark,"position:y",spark.position.y,0.8+index*0.15)
	var label:=Label3D.new();label.text=template.rarity+" · "+template.name+"\n已入行囊";label.font=font;label.font_size=22;label.pixel_size=0.0055;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.outline_size=6;label.position=camera.global_basis.x*0.42+Vector3.UP*0.30;label.modulate=color;marker.add_child(label)
	drops.append({"node":marker,"life":8.0})
	_show_message("获得「"+template.name+"」· 已收入行囊",3)
	_play_sound("loot")

func _loot_piece(parent:Node3D,mesh:Mesh,at:Vector3,color:Color,metallic:float=0.0,glow:bool=false)->MeshInstance3D:
	var piece:=MeshInstance3D.new();piece.mesh=mesh;piece.position=at
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.metallic=metallic;material.roughness=0.32;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	if color.a<1.0:material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	else:material.emission_enabled=true;material.emission=color*0.18;material.emission_energy_multiplier=0.35
	piece.material_override=material;parent.add_child(piece)
	return piece

func _loot_box(parent:Node3D,at:Vector3,size_value:Vector3,color:Color,metallic:float=0.0)->MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size_value
	return _loot_piece(parent,mesh,at,color,metallic)

func _loot_cylinder(parent:Node3D,at:Vector3,radius:float,height_value:float,color:Color,open_ends:bool=false)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height_value;mesh.radial_segments=20;mesh.cap_top=not open_ends;mesh.cap_bottom=not open_ends
	return _loot_piece(parent,mesh,at,color,0.7)

func _loot_equipment(parent:Node3D,slot:String,owner:String,color:Color)->void:
	var model:=Node3D.new();model.name="EquipmentModel";model.position.y=0.22;model.rotation.y=-0.55;parent.add_child(model)
	var steel:=Color("396780").lerp(color,0.28)
	var trim:=Color("c8b17d")
	match slot:
		"bracers":
			model.position.y=0.33
			model.rotation.z=1.10;model.rotation.y=-0.75
			_loot_cylinder(model,Vector3.ZERO,0.18,0.62,steel,true)
			_loot_cylinder(model,Vector3.ZERO,0.142,0.62,Color("102334"),true)
			for end:float in [-0.31,0.31]:
				var rim:=TorusMesh.new();rim.inner_radius=0.14;rim.outer_radius=0.20;rim.rings=24;rim.ring_segments=8
				_loot_piece(model,rim,Vector3(0,end,0),trim,0.85)
			var band:=TorusMesh.new();band.inner_radius=0.175;band.outer_radius=0.19;band.rings=24;band.ring_segments=8
			_loot_piece(model,band,Vector3.ZERO,color,0.7)
		"pendant":
			var ring:=TorusMesh.new();ring.inner_radius=0.07;ring.outer_radius=0.085;ring.rings=20;ring.ring_segments=6
			_loot_piece(model,ring,Vector3(0,0.15,0),trim,0.8).rotation.x=PI*0.5
			var gem:=PrismMesh.new();gem.size=Vector3(0.24,0.29,0.12)
			_loot_piece(model,gem,Vector3.ZERO,color,0.35).rotation.z=PI
		"ring":
			model.position.y=0.13
			var ring:=TorusMesh.new();ring.inner_radius=0.13;ring.outer_radius=0.16;ring.rings=24;ring.ring_segments=8
			_loot_piece(model,ring,Vector3.ZERO,trim,0.8).rotation.x=0.8
			var gem:=SphereMesh.new();gem.radius=0.065;gem.height=0.10
			_loot_piece(model,gem,Vector3(0,0.10,0.10),color,0.4)
		"boots":
			model.position.y=0.10
			for side:float in [-0.12,0.12]:
				_loot_box(model,Vector3(side,0,0.04),Vector3(0.18,0.15,0.36),Color("293a43"))
				_loot_box(model,Vector3(side,0.10,-0.05),Vector3(0.18,0.24,0.18),steel)
				_loot_box(model,Vector3(side,0.23,-0.05),Vector3(0.19,0.035,0.19),trim,0.6)
		"clothing":
			model.position.y=0.09
			_loot_box(model,Vector3.ZERO,Vector3(0.58,0.14,0.40),steel)
			_loot_box(model,Vector3(0,0.08,0),Vector3(0.10,0.035,0.42),trim)
			_loot_box(model,Vector3(0,0.08,-0.14),Vector3(0.52,0.025,0.045),color)
		"weapon":
			model.position.y=0.10 if owner!="zhu" else 0.15
			match owner:
				"zhu":
					var bell:=CylinderMesh.new();bell.top_radius=0.075;bell.bottom_radius=0.18;bell.height=0.24;bell.radial_segments=16
					_loot_piece(model,bell,Vector3.ZERO,trim,0.75)
					var loop:=TorusMesh.new();loop.inner_radius=0.045;loop.outer_radius=0.06;loop.rings=16;loop.ring_segments=6
					_loot_piece(model,loop,Vector3(0,0.16,0),color,0.6).rotation.x=PI*0.5
				"lu":
					for side:float in [-1.0,1.0]:
						_loot_box(model,Vector3(0.06,0,side*0.20),Vector3(0.05,0.05,0.44),steel,0.6).rotation.y=side*0.35
					_loot_box(model,Vector3(0.12,0,0),Vector3(0.016,0.016,0.80),trim,0.5)
					_loot_box(model,Vector3.ZERO,Vector3(0.11,0.08,0.22),Color("5e4533"))
				"jiang":
					_loot_box(model,Vector3.ZERO,Vector3(0.045,0.045,1.0),Color("674c39"))
					var point:=PrismMesh.new();point.size=Vector3(0.17,0.30,0.05)
					_loot_piece(model,point,Vector3(0,0,-0.62),color,0.85).rotation.x=-PI*0.5
				_:
					_loot_box(model,Vector3(0,0,-0.15),Vector3(0.10,0.055,0.72),color,0.85)
					_loot_box(model,Vector3(0,0,0.24),Vector3(0.30,0.06,0.06),trim,0.8)
					_loot_box(model,Vector3(0,0,0.38),Vector3(0.07,0.07,0.23),Color("3c3030"))

func _update_preview_ui()->void:
	if not is_instance_valid(hud_view) or progress==null:return
	hud_view.update_state(progress.data,combat_snapshot(),area,notice_text,_interaction_hint())
	hud_view.update_map(hero.position,enemies,area)
	for i:int in range(drops.size()-1,-1,-1):
		# Loot is already transactionally acquired; these are temporary visual markers.
		var d:Dictionary=drops[i]
		if d.has("life"):
			d.life=float(d.life)-0.08
			if d.life<=0:
				if is_instance_valid(d.get("node")):d.node.queue_free()
				drops.remove_at(i)

func _interaction_hint()->String:
	if area!="town" or not is_instance_valid(scenery):return ""
	var closest:Dictionary=_nearest_interaction()
	return "T  "+str(closest.get("title","")) if not closest.is_empty() else "M 选关 · I 装备 · P 编队"

func _nearest_interaction()->Dictionary:
	var result:Dictionary={};var distance:float=3.2
	for point:Dictionary in scenery.get_interaction_points():
		var separation:float=hero.position.distance_to(point.position)
		if separation<distance:distance=separation;result=point
	return result

func _interact_town()->void:
	var point:Dictionary=_nearest_interaction()
	if point.is_empty():_show_message("靠近渡口、器物摊或告示牌按 T；也可以按 M 选关。",4);return
	match point.id:
		"gate":_open_map()
		"craft":_open_inventory()
		"notice":cancel_skill_preview();hud_view.show_note();input_block=2

func _open_map()->void:
	if area!="town":return
	cancel_skill_preview();input_block=2;hud_view.show_map(progress.data)

func _open_party()->void:
	if area!="town":return
	cancel_skill_preview();input_block=2;hud_view.show_party(progress.data)

func _open_inventory()->void:
	cancel_skill_preview();input_block=2;hud_view.show_inventory(progress.data,area!="town")

func _open_pause()->void:
	cancel_skill_preview();input_block=2;hud_view.show_pause()

func _close_panel()->void:
	if is_instance_valid(hud_view):hud_view.close_menu()
	cancel_skill_preview();input_block=2
	for key:int in [KEY_I,KEY_M,KEY_P,KEY_T,KEY_ESCAPE]:previous_keys[key]=Input.is_physical_key_pressed(key)

func _on_ui_action(command:String,payload:Variant)->void:
	_play_sound("click")
	match command:
		"close":_close_panel()
		"open_map":_open_map()
		"open_inventory":_open_inventory()
		"open_party":_open_party()
		"open_shop":
			if area=="town":hud_view.show_shop(progress.data)
		"start":_start_stage(str(payload.stage),int(payload.difficulty))
		"retry":_start_stage(str(payload),run_difficulty)
		"town":_enter_town()
		"target":
			if area=="town" and progress.set_target(str(payload)):_show_message("已更新本趟追求目标。",3)
		"party":
			if area=="town" and progress.set_party(payload):_enter_town();_show_message("三人编队已保存。",3)
			else:_show_message("请选择三位不同的同行者。",4)
		"equip":
			if area=="town" and progress.equip_item(str(payload.id),str(payload.character)):_refresh_combat_stats();hud_view.show_inventory(progress.data);_show_message("装备已更换，下次出发使用新配置。",3)
			else:_show_message("这件装备暂时无法给该角色使用。",4)
		"lock":
			if area=="town" and progress.toggle_lock(str(payload)):hud_view.show_inventory(progress.data)
		"buy":
			if area!="town":return
			var result:Dictionary=progress.buy_item(str(payload))
			_show_message("指定器物已收入行囊。" if bool(result.get("ok",false)) else str(result.get("error","兑换失败")),4);hud_view.show_shop(progress.data)
		"preview_scrap":
			if area=="town":hud_view.show_scrap(progress.preview_dismantle(payload))
		"scrap":
			if area!="town":return
			var result:Dictionary=progress.dismantle(payload)
			_show_message("拆解完成，获得灵尘 %d。"%int(result.get("dust",0)) if bool(result.get("ok",false)) else str(result.get("error","拆解失败")),4);hud_view.show_inventory(progress.data)
		"quit":
			if progress.in_run:progress.end_run()
			if progress.save_game():get_tree().quit()
			else:_show_message(progress.warning,12)
	_update_preview_ui()

func _show_message(text:String,duration:float=4)->void:
	notice_text=text;notice_left=duration

func _save_progress()->void:
	# The inherited mine helper must never write the legacy profile in this scene.
	if progress!=null:progress.save_game()

func _setup_audio()->void:
	for i in range(5):
		var player:=AudioStreamPlayer.new();player.volume_db=-19;add_child(player);_sound_pool.append(player)

func _play_sound(kind:String)->void:
	if _sound_pool.is_empty() or (world_time-_last_sound<0.07 and kind!="loot"):return
	_last_sound=world_time
	if not _tone_cache.has(kind):
		var rate:int=22050;var duration:float=0.12 if kind in ["click","switch"] else 0.4
		var bytes:=PackedByteArray();bytes.resize(int(rate*duration)*2)
		var frequency:float={"click":520.0,"switch":690.0,"bell":880.0,"loot":1046.5,"awakening":220.0,"swing":240.0,"hit":140.0,"dodge":360.0}.get(kind,440.0)
		for i in range(int(rate*duration)):
			var t:float=float(i)/rate;var envelope:float=pow(1.0-t/duration,2)
			var value:float=(sin(TAU*frequency*t)+0.35*sin(TAU*frequency*1.5*t))*envelope*0.28
			bytes.encode_s16(i*2,int(value*32767))
		var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=rate;wave.data=bytes;_tone_cache[kind]=wave
	var player:AudioStreamPlayer=_sound_pool[_sound_index];_sound_index=(_sound_index+1)%_sound_pool.size();player.stream=_tone_cache[kind];player.play()

func _spawn_town_npcs() -> void:
	var ids: Array[String]=["jiang","zhu","lu"]
	var positions: Array[Vector3]=[Vector3(-2.5,0,-3.1),Vector3(3.0,0,-3.7),Vector3(-5.7,0,-2.3)]
	for index: int in range(ids.size()):
		var node: Node3D=Node3D.new()
		node.position=positions[index]
		add_child(node)
		town_npcs.append(node)
		var sprite: Sprite3D=Sprite3D.new()
		sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded=false
		sprite.modulate=ACTOR_NIGHT_TINT
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		var path: String="res://assets/characters/"+ids[index]+".png"
		var metadata_path: String="res://assets/characters/"+ids[index]+".json"
		if ResourceLoader.exists(path) and FileAccess.file_exists(metadata_path):
			var metadata: Variant=JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
			if metadata is Dictionary and not metadata.get("frames",[]).is_empty():
				var frame: Dictionary=metadata.frames[0]
				var region: Array=frame.region
				var texture: AtlasTexture=AtlasTexture.new()
				texture.atlas=load(path)
				texture.region=Rect2(region[0],region[1],region[2],region[3])
				sprite.texture=texture
				sprite.centered=false
				sprite.offset=Vector2(-float(frame.foot_x),float(frame.foot_y)-float(region[3]))
				sprite.pixel_size=2.1*ACTOR_VISUAL_SCALE/float(frame.bbox[3])
				sprite.position.y=0.035
		if sprite.texture==null:
			sprite.texture=_pixel_actor(ROLE_COLORS[ids[index]],Color("233646"),false)
			sprite.pixel_size=2.1*ACTOR_VISUAL_SCALE/24.0
			sprite.position.y=1.05*ACTOR_VISUAL_SCALE
		node.add_child(sprite)
		var label: Label3D=Label3D.new()
		label.text=COMBAT_NAMES[ids[index]]
		label.font=font
		label.font_size=35
		label.pixel_size=0.006
		label.position.y=2.55
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(label)


func on_combat_feedback(kind: String, _location: Vector3) -> void:
	_play_sound(kind)
