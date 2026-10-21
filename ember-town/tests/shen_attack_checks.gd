extends SceneTree

class ContactProbe extends "res://scripts/adventure_combat.gd":
	var contacts: Array[Dictionary] = []
	func _hit(enemy: Dictionary, amount: float, owner: String, cast_id: int, poise: float = 8.0) -> void:
		var before: float = float(enemy["hp"])
		var node: Node3D = enemy["node"] as Node3D
		var target_position: Vector3 = node.position
		var source: String = "other"
		for call: Dictionary in get_stack():
			if str(call.get("function",""))=="_melee": source = "melee"
			elif str(call.get("function",""))=="_update_projectiles": source = "projectile"
		var frame: int = clampi(floori((1.0-_shen_pose_time/SHEN_ATTACK_POSE_DURATION)*4.0),0,3) if _shen_pose_time>0.0 else -1
		super._hit(enemy,amount,owner,cast_id,poise)
		if float(enemy["hp"])<before:
			contacts.append({"simulation_seconds":elapsed,"source":source,"attack_asset_available":_shen_attack_frames.size()==16,"owner":owner,"cast_id":cast_id,"pose_row":_shen_pose_row,"pose_column":frame,"aim":[aim.x,aim.z],"hero":[hero.position.x,hero.position.z],"target":[target_position.x,target_position.z],"damage":before-float(enemy["hp"])})

var game: ContactProbe
var failures: Array[String] = []
var count: int = 0
func check(condition: bool, name: String) -> void:
	count += 1
	if not condition: failures.append(name)
func _initialize() -> void:
	call_deferred("_run")
func _new_run() -> void:
	var party: Array[String] = ["shen","jiang","zhu"]
	game.combat_begin(party,"ferry",0)
	game.aim = Vector3.FORWARD
	for enemy: Dictionary in game.enemies:
		enemy["stun"] = 999.0
		enemy["cd"] = 999.0
		(enemy["node"] as Node3D).position = Vector3(8,0,-5)
	var target: Dictionary = game.enemies[0]
	target["hp"] = 10000.0
	target["max_hp"] = 10000.0
	(target["node"] as Node3D).position = game.hero.position+game.aim*1.4
func _unlock() -> void:
	game.action_lock = 0.0
	game.attack_cd = 0.0
	game.switch_timer = 0.0
	game.dodge_time = 0.0
func _run() -> void:
	game = ContactProbe.new()
	root.add_child(game)
	await process_frame
	game._setup_camera()
	game._setup_hero()
	_new_run()
	await physics_frame
	check(game._prepare_shen_attack_atlas(),"valid authored atlas loads")
	check(game._shen_attack_frames.size()==16,"four directions each have four attack phases")
	var walk_scale: float = game.body.pixel_size
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/shen_attack.json")) as Dictionary
	var hp: float = float(game.enemies[0]["hp"])
	var expected_row: int = game._sprite_row(game.aim)
	game.use_basic()
	check(float(game.enemies[0]["hp"])<hp,"contact damage remains immediate")
	check(game.contacts.size()==1 and int(game.contacts[0]["pose_column"])==0,"actual hit event sees authored contact phase zero")
	check(game._shen_pose_time>0.0 and game._shen_pose_row==expected_row,"basic enters directional attack pose")
	check(game.body.texture==game._shen_attack_frames[expected_row*4],"contact texture is displayed immediately")
	var attack_scale: float = game.body.pixel_size
	var reference_height: float = float(metadata["reference_walk_body_height_pixels"])*walk_scale
	check(is_equal_approx(float(metadata["global_body_height_pixels"])*attack_scale,reference_height),"body height calibration excludes extended sword")
	for phase: int in range(4):
		game._show_shen_attack_frame(phase)
		var record: Dictionary = (metadata["frames"] as Array)[expected_row*4+phase]
		var region: Array = record["region"]
		var support_y: float = (float(region[3])-float(record["foot_y"])+game.body.offset.y)*game.body.pixel_size
		check(absf(support_y)<0.00001,"phase "+str(phase)+" soles on common ground")
		check(is_equal_approx(game.body.pixel_size,attack_scale),"phase "+str(phase)+" keeps fixed body scale")
		if metadata.has("reference_walk_support_x_by_row"):
			var anchor_x: float = (float(record["foot_x"])+game.body.offset.x)*game.body.pixel_size
			var old_offset: Vector2 = (game._role_offsets["shen"] as Array)[expected_row*4]
			var expected_x: float = (float((metadata["reference_walk_support_x_by_row"] as Array)[expected_row])+old_offset.x)*walk_scale
			check(absf(anchor_x-expected_x)<0.00001,"phase "+str(phase)+" shares walk support anchor")
	game.combat_step(0.08,false)
	check(game.body.texture==game._shen_attack_frames[expected_row*4+1],"follow through advances on simulation clock")
	game.aim = Vector3.RIGHT
	game.combat_step(0.08,false)
	check(game._shen_pose_row==expected_row,"pose direction remains coherent during recovery")
	check(game.aim==Vector3.RIGHT,"visual pose never locks actual aim")
	game.combat_step(0.13,false)
	check(game._shen_pose_time==0.0,"pose ends after short duration")
	check(is_equal_approx(game.body.pixel_size,walk_scale),"return to walk restores original pixel size")
	var walk_index: int = game._sprite_row(game.aim)*4
	check(game.body.texture==(game._role_atlases["shen"] as Array)[walk_index],"walk direction and texture restored")
	check(game.body.offset==(game._role_offsets["shen"] as Array)[walk_index],"walk offsets restored")
	_unlock()
	game._start_shen_attack_pose()
	check(game.switch_member(1),"legal switch during attack recovery")
	check(game._shen_pose_time==0.0,"switch clears old pose clock")
	check(is_equal_approx(game.body.pixel_size,float(game._role_sizes["jiang"])),"switch restores new character scale")
	game.combat_step(0.4,false)
	check(game._shen_pose_time==0.0 and game.active_member()=="jiang","offfield animation never resumes")
	_unlock()
	game.switch_member(0)
	_unlock()
	game._start_shen_attack_pose()
	game.combat_hurt(1000.0)
	check(game.active_member()!="shen" and game._shen_pose_time==0.0,"downed owner clears pose before forced swap")
	_new_run()
	await physics_frame
	for skill: int in [0,1]:
		_unlock()
		if skill==1:
			(game.enemies[0]["node"] as Node3D).position = game.hero.position+game.aim*3.5
			await physics_frame
		hp = float(game.enemies[0]["hp"])
		check(game.use_skill(skill),"Shen skill "+str(skill)+" still casts")
		check(game._shen_pose_time>0.0,"Shen melee skill "+str(skill)+" uses contact pose")
		check(float(game.enemies[0]["hp"])<hp and int(game.contacts[-1]["pose_column"])==0,"Shen melee skill "+str(skill)+" deals damage in contact phase")
	_unlock()
	game.awakening_energy = 100.0
	check(game.use_awakening() and game._shen_pose_time>0.0,"Shen awakening uses authored melee pose")
	_unlock()
	check(game.use_skill(2) and game._shen_pose_time==0.0,"ranged talisman does not retain sword contact pose")
	game._start_shen_attack_pose()
	game._dodge(Vector3.RIGHT)
	check(game._shen_pose_time>0.0,"committed skill keeps existing dodge restriction")
	game.combat_step(0.1,false)
	game._dodge(Vector3.RIGHT)
	check(game._shen_pose_time==0.0,"legal dodge cancel restores walk")
	game.combat_clear()
	check(game._shen_pose_time==0.0,"run exit clears pose state")
	_new_run()
	var texture_before: Texture2D = game.body.texture
	check(not game._prepare_shen_attack_atlas("res://assets/characters/missing_pilot.png","res://assets/characters/shen_attack.json"),"missing attack asset safely rejects")
	_unlock()
	hp = float(game.enemies[0]["hp"])
	game.use_basic()
	check(float(game.enemies[0]["hp"])<hp and game._shen_pose_time==0.0,"missing asset keeps immediate gameplay and old walk fallback")
	check(game.body.texture==texture_before and is_equal_approx(game.body.pixel_size,walk_scale),"missing asset cannot alter walk presentation")
	var bad_path: String = "user://linchuan_shen_bad_attack_test.json"
	var file: FileAccess = FileAccess.open(bad_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":{},"animation":"attack"}))
	file.close()
	check(not game._prepare_shen_attack_atlas("res://assets/characters/shen_attack.png",bad_path),"wrong metadata types safely reject")
	var bad: Dictionary = metadata.duplicate(true)
	(bad["frames"] as Array)[0]["foot_x"] = 99999
	file = FileAccess.open(bad_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	check(not game._prepare_shen_attack_atlas("res://assets/characters/shen_attack.png",bad_path),"out of cell foot anchor safely rejects")
	check(game._shen_pose_time==0.0 and game.body.texture==texture_before,"bad metadata preserves exact walk fallback")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	check(game._prepare_shen_attack_atlas(),"valid atlas can reload after rejected metadata")
	game._start_shen_attack_pose()
	game.combat_clear()
	check(game._shen_pose_time==0.0,"clear while active resets pose")
	var ranged_party: Array[String] = ["lu","shen"]
	game.combat_begin(ranged_party,"ferry",0)
	await physics_frame
	game.use_basic()
	check(game._shen_pose_time==0.0 and game.projectiles.size()==1,"ranged character retains original bow action")
	game.combat_clear()
	print("SHEN_CONTACT_EVENTS ",JSON.stringify(game.contacts))
	print("SHEN_ATTACK_CHECKS ",count," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
