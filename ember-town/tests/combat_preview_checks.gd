extends SceneTree
var game: Node3D
var failures: Array[String] = []
var checked: int = 0
func verify(condition: bool, title: String) -> void:
	checked += 1
	if not condition: failures.append(title)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	game = load("res://scripts/adventure_combat.gd").new()
	root.add_child(game)
	await process_frame
	game._setup_camera()
	game._setup_hero()
	var party: Array[String] = ["shen","jiang","zhu"]
	game.combat_begin(party,"ferry",0)
	await physics_frame
	verify(game.enemies.size()==4,"first wave population")
	var target: Dictionary = game.enemies[0]
	(target["node"] as Node3D).position = Vector3(0,0,2.5)
	game.aim = Vector3.FORWARD
	var hp: float = target["hp"]
	game.use_basic()
	verify(float(target["hp"])<hp,"manual directional melee hits")
	verify(game.awakening_energy==8.0,"cast energy one credit")
	game._credit_cast(game._cast_serial)
	verify(game.awakening_energy==8.0,"same cast cannot credit twice")
	game.action_lock = 0.0
	game.attack_cd = 0.0
	game.aim = Vector3.BACK
	hp = target["hp"]
	game.use_basic()
	verify(float(target["hp"])==hp,"backwards melee misses")
	game.action_lock = 0.0
	game.use_skill(0)
	var cooldown: float = game.skill_timers["shen"][0]
	game.action_lock = 0.0
	verify(game.switch_member(1),"switch to second slot")
	game.combat_step(0.5,false)
	verify(game.skill_timers["shen"][0]<cooldown,"offfield cooldown advances")
	verify(game.dodge_charges==2,"switch does not consume or refresh dodge")
	game.action_lock = 0.0
	game._dodge(Vector3.RIGHT)
	verify(game.dodge_charges==1,"dodge spends shared charge")
	game.dodge_time = 0.0
	game.action_lock = 0.0
	game.switch_timer = 0.0
	game.switch_member(2)
	verify(game.dodge_charges==1,"switch preserves spent charge")
	game.action_lock = 0.0
	verify(not game.use_skill(2),"command unavailable without lamp")
	verify(float(game.skill_timers["zhu"][2])==0.0,"failed command does not consume cooldown")
	game._spawn_lamp("zhu")
	game._spawn_lamp("zhu")
	verify(game.summons.size()==1,"same summon replaces own")
	game._place_field("jiang","flag",Vector3.ZERO,3.0,8.0)
	game._place_field("zhu","bind",Vector3.ZERO,2.0,6.0)
	game._place_field("zhu","bind",Vector3.ONE,2.0,6.0)
	verify(game.combat_fields.size()==2,"source field replacement preserves other source")
	var energy: float = game.awakening_energy
	game._update_summons(1.5)
	game._update_projectiles(0.1)
	verify(game.awakening_energy==energy,"automatic summon no energy")
	game.combat_hurt(1000.0)
	verify(game.member_hp["zhu"]==0.0,"independent downed hp")
	verify(game.active_member()!="zhu","forced switch to survivor")
	verify(game.summons.is_empty(),"downed owner summon cleared")
	verify(game.combat_fields.size()==1,"downed owner field cleared selectively")
	verify(not game.switch_member(2),"cannot select downed member")
	game.combat_clear()
	verify(game.projectiles.is_empty() and game.combat_fields.is_empty() and game.summons.is_empty(),"run clears all effects")
	party = ["lu","shen","jiang"]
	game.combat_begin(party,"boss",1)
	await physics_frame
	verify(game.enemies.size()==1 and bool(game.enemies[0]["boss"]),"separate boss arena")
	var boss: Dictionary = game.enemies[0]
	boss["hp"] = float(boss["max_hp"])*0.6
	game.combat_step(0.1,false)
	verify(game.boss_phase==2,"boss phase two threshold")
	verify(game.enemies.size()==3,"boss finite two adds")
	boss["hp"] = float(boss["max_hp"])*0.3
	game.combat_step(0.1,false)
	verify(game.boss_phase==3,"boss phase three threshold")
	boss["cd"] = 0.0
	game.combat_step(0.1,false)
	verify(not game.combat_hazards.is_empty(),"boss creates delayed danger")
	verify(not bool(game.combat_hazards[0]["struck"]),"danger prewarn before damage")
	game._hit(boss,100000.0,"lu",-1)
	verify(game.combat_finished,"boss kill completes despite surviving timed adds")
	game.combat_clear()
	party = ["lu","shen","jiang"]
	game.combat_begin(party,"ferry",0)
	await physics_frame
	game.aim = Vector3.FORWARD
	game.use_basic()
	verify(game.projectiles.size()==1,"bow ordinary attack projectile")
	for role: String in ["shen","jiang","zhu","lu"]:
		party = [role]
		game.combat_begin(party,"ferry",0)
		await physics_frame
		for slot: int in range(4):
			game.action_lock = 0.0
			if role=="zhu" and slot==2: game._spawn_lamp("zhu")
			if role=="zhu" and slot==1:
				verify(game.use_skill(slot),"ground field preview")
				verify(game.preview_slot==1,"preview entered")
				game.cancel_skill_preview()
				verify(float(game.skill_timers["zhu"][1])==0.0,"cancel preview no cooldown")
				verify(game._cast_skill(1,Vector3.ZERO),"field release commit")
			else: verify(game.use_skill(slot),role+" skill "+str(slot))
		game.action_lock = 0.0
		game.awakening_energy = 100.0
		verify(game.use_awakening(),role+" awakening")
		verify(game.awakening_energy==0.0,role+" awakening consumes shared bar")
	game.combat_clear()
	party = ["shen","jiang","zhu"]
	game.combat_begin(party,"ferry",1)
	await physics_frame
	verify(game.enemies.size()==5,"difficulty adds real ranged pressure")
	for expected_wave: int in range(1,4):
		verify(game.combat_wave==expected_wave,"wave order "+str(expected_wave))
		for victim: Dictionary in game.enemies.duplicate(): game._hit(victim,100000.0,"shen",-1)
		await process_frame
		if expected_wave<3:
			verify(not game.combat_finished,"intermediate wave no premature victory")
			game.combat_step(1.4,false)
	verify(game.combat_finished,"third wave finishes run")
	game.combat_begin(party,"ferry",0)
	await physics_frame
	var source_target: Dictionary = game.enemies[0]
	game.combat_stats = {"zhu":{"damage":2.0},"shen":{"damage":0.1}}
	hp = source_target["hp"]
	energy = game.awakening_energy
	game._hit(source_target,10.0,"zhu",-1)
	verify(is_equal_approx(hp-float(source_target["hp"]),20.0),"background effect uses source stats")
	verify(game.awakening_energy==energy,"direct automatic hit earns zero energy")
	game._spawn_lamp("zhu")
	game._spawn_lamp("jiang")
	game._spawn_lamp("shen")
	verify(game.summons.size()==2,"global autonomous cap two")
	game._update_summons(11.0)
	verify(game.summons.is_empty(),"summon finite lifetime")
	game._place_field("zhu","bind",Vector3.ZERO,2.0,0.1)
	game._update_fields(0.2)
	verify(game.combat_fields.is_empty(),"field finite lifetime")
	game._update_projectiles(10.0)
	verify(game.projectiles.is_empty(),"projectile finite lifetime")
	game.combat_clear()
	print("COMBAT_PREVIEW_CHECKS ",checked," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
