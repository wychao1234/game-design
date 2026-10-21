extends SceneTree

# Independent production-action checks. Only temporary absolute QA profiles are allowed.
var failures: Array[String] = []
var checks: int = 0
var qa_case: String = "progress"
var profile: String = ""
var game: Node
var progress: RefCounted

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	print("PREVIEW_QA ", "PASS " if condition else "FAIL ", description)
	if not condition: failures.append(description)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-case="): qa_case = argument.trim_prefix("--preview-case=")
		if argument.begins_with("--test-profile="): profile = argument.trim_prefix("--test-profile=")
	if not profile.is_absolute_path() or not profile.contains("linchuan-preview-qa-"):
		push_error("Refusing player save: QA needs an isolated absolute linchuan-preview-qa- profile")
		quit(2)
		return
	if qa_case in ["progress", "save-write", "save-read", "recover-main", "protect-corrupt"]:
		await _progress_cases()
	else:
		await _game_cases()
	print("PREVIEW_QA_RESULT ", JSON.stringify({"case":qa_case, "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 2)

func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _new_progress() -> RefCounted:
	return load("res://scripts/adventure_progress.gd").new()

func _complete_run(stage: String = "ferry") -> Dictionary:
	var run: String = progress.begin_run(stage, 0)
	var result: Dictionary = progress.grant_clear(run, stage, 0)
	progress.end_run()
	return result

func _progress_cases() -> void:
	if qa_case == "recover-main": _write(profile, "{broken-primary")
	if qa_case == "protect-corrupt":
		_write(profile, "{broken-primary")
		_write(profile + ".bak", "{broken-backup")
	progress = _new_progress()
	var loaded: bool = progress.load_game(profile)
	if qa_case == "progress":
		_check(loaded and progress.save_enabled, "fresh isolated preview loads without using legacy save")
		_check(not progress.set_party(["shen", "shen", "lu"]), "duplicate party member rejected")
		_check(progress.set_party(["shen", "lu", "zhu"]), "valid three-character party committed")
		var run: String = progress.begin_run("ferry", 0)
		_check(not run.is_empty(), "real dungeon run begins")
		var before: String = JSON.stringify(progress.data)
		_check(not progress.set_party(["shen", "jiang", "zhu"]) and not progress.equip_item("item_1", "shen"), "party and equipment changes rejected inside dungeon")
		_check(not progress.buy_item("shen_echo").ok and not progress.dismantle(["item_1"]).ok, "exchange and dismantle rejected inside dungeon")
		_check(JSON.stringify(progress.data) == before, "rejected in-run town actions preserve all assets")
		_check(progress.grant_kill(true).ok, "real elite reward grants experience and material")
		var earned: Dictionary = progress.data.duplicate(true)
		_check(int(earned.characters.shen.xp) > int(earned.characters.lu.xp) and int(earned.characters.lu.xp) > int(earned.characters.jiang.xp), "active/selected/background experience rates differ as designed")
		_check(not progress.grant_clear("wrong_run", "ferry", 0).ok, "forged run id cannot award clear")
		var result: Dictionary = progress.grant_clear(run, "ferry", 0)
		_check(result.ok and result.first_clear and int(progress.data.seals) == 10, "first real clear grants exact currency and first-clear reward")
		before = JSON.stringify(progress.data)
		_check(not progress.grant_clear(run, "ferry", 0).ok and JSON.stringify(progress.data) == before, "duplicate settlement cannot duplicate currency or items")
		progress.end_run()
		for index: int in range(19):
			result = _complete_run()
			if index == 0: _check(result.ok and not result.first_clear, "a new legitimate repeat run still earns ordinary rewards")
		_check(int(progress.data.seals) == 200 and progress.data.rewarded_runs.size() == 20, "twenty separate clears preserve rewards and unique run ledger")
		var purchase: Dictionary = progress.buy_item("lu_pierce")
		_check(purchase.ok and int(progress.data.seals) == 100, "exact weapon exchange deducts one hundred seals")
		var weapon: String = str(purchase.get("item", {}).get("id", ""))
		_check(not progress.equip_item(weapon, "shen") and progress.equip_item(weapon, "lu"), "weapon ownership prevents wrong-character equip and allows its owner")
		var equipped_dust: int = progress.data.dust
		_check(not progress.dismantle([weapon, "item_1"]).ok and int(progress.data.dust) == equipped_dust, "equipped and starter-protected gear cannot be dismantled")
		purchase = progress.buy_item("tide_pendant")
		var pendant: String = str(purchase.get("item", {}).get("id", ""))
		_check(purchase.ok and progress.toggle_lock(pendant), "exact accessory exchange and locking succeed")
		_check(not progress.dismantle([pendant]).ok, "locked unequipped item cannot be dismantled")
		_check(progress.toggle_lock(pendant), "item can be intentionally unlocked")
		var preview: Dictionary = progress.preview_dismantle([pendant, pendant, "item_1"])
		_check(preview.count == 1 and preview.blocked.has("item_1"), "dismantle preview deduplicates selection and reports protected item")
		var old_dust: int = progress.data.dust
		result = progress.dismantle([pendant, pendant, "item_1"])
		_check(result.ok and int(progress.data.dust) == old_dust + int(preview.dust), "confirmed dismantle matches preview once")
		before = JSON.stringify(progress.data)
		_check(not progress.buy_item("lu_pierce").ok and JSON.stringify(progress.data) == before, "insufficient-currency exchange preserves inventory and currency")
		var reloaded: RefCounted = _new_progress()
		_check(reloaded.load_game(profile) and JSON.parse_string(JSON.stringify(reloaded.data)) == JSON.parse_string(JSON.stringify(progress.data)), "save reload preserves exact equipment, exchange, dismantle and run ledger")
		var defeat_run: String = progress.begin_run("boss", 0)
		result = progress.grant_kill()
		earned = progress.data.duplicate(true)
		progress.end_run()
		_check(not defeat_run.is_empty() and result.ok and progress.data.total_kills == earned.total_kills and progress.data.characters == earned.characters and progress.data.inventory == earned.inventory, "failure-style end_run retains already earned experience and items")
	elif qa_case == "save-write":
		_check(loaded and progress.data.total_kills == 0, "writer starts with clean independent progress")
		var run: String = progress.begin_run("ferry", 0)
		progress.grant_kill(true)
		progress.grant_clear(run, "ferry", 0)
		progress.end_run()
		var weapon_id: String = ""
		for item: Dictionary in progress.data.inventory:
			if item.template_id == "shen_echo": weapon_id = item.id
		_check(not weapon_id.is_empty() and progress.equip_item(weapon_id, "shen"), "writer obtains actual first-clear mechanism weapon and equips it")
		_check(progress.set_party(["shen", "lu", "jiang"]) and progress.save_game(), "writer persists earned progress and chosen party")
	elif qa_case == "save-read":
		_check(loaded and progress.data.total_kills == 1 and progress.data.seals == 10, "second engine process loads real kill and clear progress")
		_check(progress.data.party == ["shen", "lu", "jiang"] and progress.get_equipment_stats("shen").mechanism == "shen_echo", "second process restores party and mechanism equipment")
		_check(not progress.in_run and progress.data.current_run.is_empty(), "process restart never resumes stale dungeon combat")
	elif qa_case == "recover-main":
		_check(loaded and progress.save_enabled and not progress.warning.is_empty(), "valid backup recovers broken primary with warning")
		_check(progress.data.total_kills == 1 and progress.get_equipment_stats("shen").mechanism == "shen_echo", "backup recovery retains acquired and equipped mechanism")
		_check(progress.save_game() and not progress._read_valid(profile).is_empty() and not progress._read_valid(profile + ".bak").is_empty(), "recovery writes valid primary without destroying valid backup")
	elif qa_case == "protect-corrupt":
		_check(not loaded and not progress.save_enabled and not progress.warning.is_empty(), "double corruption disables saving and warns")
		_check(not progress.save_game() and FileAccess.get_file_as_string(profile) == "{broken-primary" and FileAccess.get_file_as_string(profile + ".bak") == "{broken-backup", "double corruption cannot silently overwrite repairable files")

func _game_cases() -> void:
	if qa_case == "integration":
		await _integration()
		return
	game = load("res://scripts/adventure_combat.gd").new()
	root.add_child(game)
	game._setup_camera()
	game._setup_hero()
	await physics_frame
	if qa_case == "combat": await _combat()
	elif qa_case == "effects": await _effects()
	elif qa_case == "collision": await _collision()
	else: _check(false, "unknown production-action case")
	game.combat_clear()
	game.queue_free()
	await process_frame

func _begin(role: String = "shen", stage: String = "ferry") -> void:
	var party: Array[String] = [role]
	for id: String in ["shen", "jiang", "zhu", "lu"]:
		if id not in party and party.size() < 3: party.append(id)
	game.combat_begin(party, stage, 0)
	game.hero.position = Vector3.ZERO
	game.aim = Vector3.FORWARD
	for enemy: Dictionary in game.enemies:
		enemy.node.position = Vector3(20, 0, 20)
		enemy.cd = 999.0
		enemy.hp = 10000.0
	var target: Dictionary = game.enemies[0]
	target.node.position = Vector3(0, 0, -1.8)
	target.ranged = true
	target.hp = 1000.0

func _tick(seconds: float) -> void:
	for index: int in range(int(ceil(seconds * 60.0))): game.combat_step(1.0 / 60.0, false)

func _combat() -> void:
	for role: String in ["shen", "jiang", "zhu", "lu"]:
		_begin(role)
		var target: Dictionary = game.enemies[0]
		game.use_basic()
		_tick(0.22)
		_check(float(target.hp) < 1000.0, role + " basic attack causes actual directional damage")
		for slot: int in range(4):
			_begin(role)
			target = game.enemies[0]
			if role == "shen" and slot == 1: target.node.position = Vector3(0, 0, -3.6)
			if role in ["shen", "lu"] and slot == 3:
				_check(game.use_skill(2), role + " mark cast accepted")
				_tick(0.25)
				_check(float(target.get(role + "_mark", 0.0)) > 0.0, role + " projectile applies its own mark")
			if role == "zhu" and slot == 2:
				_check(not game.use_skill(2) and float(game.skill_timers.zhu[2]) == 0.0, "command without a live lamp does not waste cooldown")
				game.use_skill(0)
				_tick(0.25)
			var previous_hp: float = target.hp
			var cast: bool = game.use_skill(slot)
			if role == "zhu" and slot == 1:
				_check(cast and game.preview_slot == 1 and float(game.skill_timers.zhu[1]) == 0.0, "bind begins a cancellable preview without cooldown")
				game.cancel_skill_preview()
				_check(game.preview_slot == -1 and float(game.skill_timers.zhu[1]) == 0.0, "cancelled ground preview consumes no cooldown")
				cast = game._cast_skill(1, target.node.position)
			_tick(0.3)
			var worked: bool = float(target.hp) < previous_hp
			if role == "jiang" and slot == 3: worked = game.combat_fields.size() == 1 and game._inside_flag(game.hero.position)
			if role == "zhu" and slot == 0: worked = game.summons.size() == 1
			if role == "zhu" and slot == 1: worked = float(target.slow) > 0.0
			_check(cast and worked and float(game.skill_timers[role][slot]) > 0.0, "%s skill %d performs its actual damage or support behavior" % [role, slot])
			_check(not game.use_skill(slot), "%s skill %d cooldown rejects immediate reuse" % [role, slot])
		_begin(role)
		target = game.enemies[0]
		game.awakening_energy = 100.0
		_check(game.use_awakening(), role + " has an independently executable awakening")
		_tick(0.3)
		_check(float(target.hp) < 1000.0 and is_zero_approx(float(game.awakening_energy)) and not game.use_awakening(), role + " awakening damages once and consumes shared energy without refund")
	_begin()
	game.use_skill(0)
	_tick(0.3)
	var cooldown: float = game.skill_timers.shen[0]
	var energy: float = game.awakening_energy
	game._dodge(Vector3.RIGHT)
	_tick(0.3)
	_check(game.switch_member(1), "ordinary switch succeeds after action and dodge window")
	_check(game.dodge_charges == 1 and float(game.awakening_energy) == energy, "switching cannot replenish shared dodge or awakening")
	_tick(1.1)
	_check(float(game.skill_timers.shen[0]) < cooldown and float(game.skill_timers.shen[0]) > 0.0, "off-field character cooldown keeps counting down")
	_check(game.switch_member(0) and game.dodge_charges == 1, "switching back still cannot reset shared dodge")
	_check(game.hero.find_children("*", "Sprite3D", true, false).size() == 1, "controlled hero has exactly one human character sprite")
	_begin("jiang")
	for index: int in range(3): game.enemies[index].node.position = Vector3(-0.4 + index * 0.4, 0, -1.8)
	game.use_skill(0)
	_check(is_equal_approx(float(game.awakening_energy), 8.0), "one manual multi-target cast receives only one awakening credit")
	game.combat_stats = {}
	_begin("shen")
	game.combat_hurt(20.0)
	var unarmored_loss: float = 100.0 - float(game.member_hp.shen)
	game.combat_stats = {"shen":{"defense":20.0}}
	_begin("shen")
	game.combat_hurt(20.0)
	var armored_loss: float = 100.0 - float(game.member_hp.shen)
	_check(is_equal_approx(unarmored_loss, 20.0) and armored_loss > 0.0 and armored_loss < unarmored_loss, "real incoming damage respects armor while ordinary damage still hurts")
	game.combat_stats = {}
	_begin("shen", "ferry")
	for wave_index: int in range(1, 4):
		_check(game.combat_wave == wave_index and not game.combat_finished, "ferry enters actual wave %d" % wave_index)
		for enemy: Dictionary in game.enemies: game._hit(enemy, 100000.0, "shen", -1)
		if wave_index < 3: _tick(1.4)
	_check(game.combat_finished, "ferry finishes only after all three real enemy waves")
	_begin("shen", "boss")
	_check(game.enemies.size() == 1 and game.enemies[0].boss, "boss stage creates a separate boss encounter")
	var boss: Dictionary = game.enemies[0]
	game._hit(boss, 500.0, "shen", -1)
	_tick(0.05)
	_check(game.boss_phase == 2 and game.enemies.size() > 1, "boss health threshold triggers second phase and reinforcements")
	game._hit(boss, 450.0, "shen", -1)
	_tick(0.05)
	_check(game.boss_phase == 3, "boss reaches third phase through actual damage")
	game._hit(boss, 10000.0, "shen", -1)
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) > 0.0: enemy.cd = 999.0; enemy.node.position = Vector3(20, 0, 20)
	_tick(18.1)
	_check(game.combat_finished, "defeated boss cannot stall completion while temporary reinforcements remain")

func _effects() -> void:
	_begin("zhu")
	game.use_skill(0)
	_tick(0.25)
	game._cast_skill(1, Vector3(0,0,-1.8))
	_tick(0.25)
	var life_before: float = game.summons[0].life
	game.combat_stats = {"zhu":{"damage":2.0}, "shen":{"damage":0.1}}
	_check(game.switch_member(1), "summoner can leave deployed lamp and bind field")
	var target: Dictionary = game.enemies[0]
	var previous_hp: float = target.hp
	game.awakening_energy = 0.0
	_tick(1.5)
	_check(float(target.hp) < previous_hp and is_zero_approx(float(game.awakening_energy)), "off-field autonomous lamp still damages but cannot generate energy")
	_check(game.summons.size() == 1 and float(game.summons[0].life) < life_before, "off-field summon lifetime counts down without reset")
	var owned_shot: bool = false
	for shot: Dictionary in game.projectiles:
		if str(shot.owner) == "zhu": owned_shot = true
	_check(owned_shot or float(target.hp) < previous_hp - 20.0, "deployed damage retains summoner source while another character controls")
	_tick(1.0)
	_check(game.switch_member(0), "can return to summoner")
	game.dodge_time = 0.0
	game.combat_hurt(10000.0)
	_check(game.active_member() != "zhu" and float(game.member_hp.zhu) == 0.0, "lethal damage forces a surviving member on field")
	var cleared: bool = true
	for collection: Array in [game.summons, game.combat_fields, game.projectiles]:
		for effect: Dictionary in collection:
			if effect.get("owner", "") == "zhu": cleared = false
	_check(cleared and not game.switch_member(0), "downed source loses all persistent effects and cannot be manually selected")
	game.dodge_time = 0.0
	game.combat_hurt(10000.0)
	game.combat_hurt(10000.0)
	_check(game.combat_finished and game.awakening_energy == 0.0, "whole-party defeat ends the run and clears shared awakening")
	_begin("zhu")
	game.use_skill(0)
	game.action_lock = 0.0
	game.skill_timers.zhu[0] = 0.0
	game.use_skill(0)
	_check(game.summons.size() == 1, "same summon skill replaces rather than stacks its own lamp")
	game._place_field("jiang", "flag", Vector3.ZERO, 3.0, 8.0)
	game._place_field("zhu", "bind", Vector3.ZERO, 2.2, 6.0)
	game._place_field("zhu", "bind", Vector3.FORWARD, 2.2, 6.0)
	_check(game.combat_fields.size() == 2, "replacing one source field does not delete a teammate's field")
	game.combat_clear()
	_check(game.summons.is_empty() and game.projectiles.is_empty() and game.combat_fields.is_empty() and game.awakening_energy == 0.0, "run exit clears temporary effects and shared energy")
	_weapon_mechanisms()

func _weapon_mechanisms() -> void:
	for role: String in ["shen", "jiang", "zhu", "lu"]:
		var outcomes: Array[float] = []
		for enabled: bool in [false,true]:
			game.combat_stats = {role:{"damage":1.0,"mechanism":enabled}}
			_begin(role)
			var target: Dictionary = game.enemies[0]
			var collateral: Dictionary = game.enemies[1]
			collateral.hp = 10000.0
			collateral.ranged = true
			match role:
				"shen":
					collateral.node.position = Vector3(1.5,0,-1.8)
					game.use_skill(2)
					_tick(0.25)
					game.use_skill(3)
					outcomes.append(10000.0-float(collateral.hp))
				"jiang":
					target.elite = true
					game.use_skill(1)
					_tick(0.25)
					game.use_skill(2)
					outcomes.append(float(target.poise))
				"zhu":
					collateral.node.position = Vector3(-0.78,0,-3.2)
					game.use_skill(0)
					_tick(0.25)
					game.use_skill(2)
					_tick(0.4)
					outcomes.append(10000.0-float(collateral.hp))
				"lu":
					collateral.node.position = Vector3(0,0,-3.5)
					game.use_skill(2)
					_tick(0.25)
					game.use_skill(3)
					_tick(0.3)
					outcomes.append(10000.0-float(collateral.hp))
		_check(outcomes.size() == 2 and outcomes[1] > outcomes[0], role + " mechanism changes actual area/poise/piercing behavior instead of only displaying a stat")
	game.combat_stats = {}

func _collision() -> void:
	_begin("shen")
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.4)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(0, 1, -1.0)
	game.add_child(wall)
	await physics_frame
	var target: Dictionary = game.enemies[0]
	target.node.position = Vector3(0,0,-2.0)
	game.use_basic()
	_check(float(target.hp) == 1000.0, "near melee target across a solid wall is not damaged")
	game.action_lock = 0.0
	game.use_skill(1)
	_check(game.hero.position.z > -0.5, "dash skill cannot teleport through a wall")
	game.hero.position = Vector3(3,0,0)
	target.node.position = Vector3(3,0,-1.8)
	game.action_lock = 0.0
	game.attack_cd = 0.0
	game.use_basic()
	_check(float(target.hp) < 1000.0, "same melee still hits a target on the open side")
	game.hero.position = Vector3.ZERO
	target.hp = 1000.0
	target.node.position = Vector3(0,0,-3)
	game._fire(Vector3.ZERO, Vector3.FORWARD * 12.0, 20.0, "shen", -1, Color.WHITE, false, 2.0)
	game._update_projectiles(0.3)
	_check(float(target.hp) == 1000.0 and game.projectiles.is_empty(), "projectile segment is blocked by solid geometry")
	wall.queue_free()
	await physics_frame

func _integration() -> void:
	game = load("res://adventure.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_check(game.area == "town" and game.progress.save_path == profile and not game.progress.in_run, "real entry opens town using isolated QA save")
	_check(game.scenery.mode == "town" and not game.hud_view.is_open(), "real town geometry and interactive HUD are connected")
	_check(game.hud_view.title_label.get_theme_font("font").has_char("临".unicode_at(0)), "actual HUD title font contains the Chinese glyphs it displays")
	_mouse(true)
	game._physics_process(1.0/60.0)
	_check(game.attack_cd == 0.0, "town left click cannot cast a combat attack")
	_mouse(false)
	game._physics_process(1.0/60.0)
	game._open_map()
	_check(game.hud_view.is_open() and game.hud_view.menu_kind == "map", "town opens actual dungeon selection UI")
	var starts: Array[Button] = _buttons("进入关卡  →")
	_check(starts.size() == 2, "selection menu exposes ferry and independent boss")
	if starts.size() != 2: return
	_check(starts[0].get_theme_font("font").has_char("进".unicode_at(0)), "actual interactive button font contains its Chinese glyphs")
	await _click_button(starts[0])
	_check(game.area == "ferry" and game.progress.in_run and game.scenery.mode == "ferry", "actual first selection button starts ferry run and geometry")
	_check(_skill_labels_match(), "ferry HUD displays all four actual skill names or cooldowns")
	await physics_frame
	for enemy: Dictionary in game.enemies: enemy.cd = 999.0
	game._open_inventory()
	var before: Dictionary = game.combat_snapshot()
	var location: Vector3 = game.hero.position
	_mouse(true)
	_key(KEY_Q, true)
	_key(KEY_SPACE, true)
	for index: int in range(5): game._physics_process(1.0/60.0)
	_check(game.hero.position == location and game.combat_snapshot().cooldowns == before.cooldowns and game.dodge_charges == before.dodge_charges and game.attack_cd == 0.0, "inventory truly pauses movement, skill clocks and mouse attacks")
	_key(KEY_Q, false)
	_key(KEY_SPACE, false)
	game.hud_view.action.emit("close", null)
	for index: int in range(5): game._physics_process(1.0/60.0)
	_check(game.attack_cd == 0.0, "mouse click used to close UI cannot become an attack while still held")
	_mouse(false)
	game._physics_process(1.0/60.0)
	_mouse(true)
	_check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "synthetic mouse press reaches engine input state")
	game._physics_process(1.0/60.0)
	_check(game.attack_cd > 0.0, "fresh mouse click after UI closure still performs attack")
	_mouse(false)
	game.action_lock = 0.0
	game.switch_timer = 0.0
	game.switch_member(2)
	game.action_lock = 0.0
	_check(game.use_skill(1) and game.preview_slot == 1, "actual summoner can start ground-skill preview")
	_key(KEY_ESCAPE, true)
	_check(Input.is_physical_key_pressed(KEY_ESCAPE), "synthetic physical Escape reaches engine input state")
	game._physics_process(1.0/60.0)
	_check(game.preview_slot == -1 and not game.hud_view.is_open(), "Escape first cancels ground preview without opening pause")
	_key(KEY_ESCAPE, false)
	game._physics_process(1.0/60.0)
	_key(KEY_ESCAPE, true)
	game._physics_process(1.0/60.0)
	_check(game.hud_view.is_open() and game.hud_view.menu_kind == "pause", "next separate Escape opens pause")
	_key(KEY_ESCAPE, false)
	game._close_panel()
	game.dodge_time = 0.0
	game.combat_hurt(10.0)
	for wave_index: int in range(1,4):
		for enemy: Dictionary in game.enemies: game._hit(enemy,100000.0,game.active_member(),-1)
		if wave_index < 3: _tick(1.4)
	await process_frame
	_check(game.combat_finished and not game.progress.in_run and game.hud_view.menu_kind == "results", "real three-wave victory commits rewards and opens settlement")
	_check(game.progress.data.seals == 10 and game.progress.data.total_kills > 0, "integrated kills and clear persist real currency and experience")
	var assets: String = JSON.stringify(game.progress.data)
	game.on_combat_victory()
	_check(JSON.stringify(game.progress.data) == assets, "repeated victory callback cannot double integrated settlement")
	var town_buttons: Array[Button] = _buttons("回城整备")
	_check(town_buttons.size() == 1, "settlement contains connected return-to-town action")
	if town_buttons.size() != 1: return
	await _click_button(town_buttons[0])
	var restored: bool = game.area == "town"
	for id: String in game.combat_party: restored = restored and float(game.member_hp[id]) == game._max_hp(id)
	_check(restored and game.awakening_energy == 0.0 and game.dodge_charges == 2, "returning town restores party health and resets temporary run resources")
	var mechanism: String = ""
	for item: Dictionary in game.progress.data.inventory:
		if item.template_id == "shen_echo": mechanism = item.id
	game.hud_view.action.emit("equip", {"id":mechanism,"character":"shen"})
	_check(not mechanism.is_empty() and game.combat_stats.shen.mechanism, "integrated equipment action activates actually earned mechanism")
	game._close_panel()
	game._open_map()
	starts = _buttons("进入关卡  →")
	await _click_button(starts[1])
	_check(game.area == "boss" and game.enemies.size() == 1 and game.enemies[0].boss, "actual second selection button starts separate boss stage")
	_check(_skill_labels_match(), "boss HUD displays all four actual skill names or cooldowns")
	game._hit(game.enemies[0],100000.0,"shen",-1)
	await process_frame
	_check(game.hud_view.menu_kind == "results" and game.progress.data.first_clears.has("boss") and game.progress.data.seals == 20, "boss kill reaches its own persistent settlement")
	var retries: Array[Button] = _buttons("再次挑战")
	await _click_button(retries[0])
	_check(game.area == "boss" and game.progress.in_run and game.awakening_energy == 0.0, "retry starts a new run with empty awakening")
	game._spawn_combat_enemy(Vector3(-3,0,-2),false,false,false)
	game._hit(game.enemies.back(),100000.0,"shen",-1)
	assets = JSON.stringify(game.progress.data.inventory)
	var earned_xp: Dictionary = game.progress.data.characters.duplicate(true)
	game.dodge_time = 0.0
	for index: int in range(3): game.combat_hurt(100000.0)
	await process_frame
	_check(game.hud_view.menu_kind == "results" and not game.progress.in_run and JSON.stringify(game.progress.data.inventory) == assets and game.progress.data.characters == earned_xp, "integrated total defeat keeps acquired items and XP in failure settlement")
	game.hud_view.action.emit("town", null)
	var restored_progress: RefCounted = _new_progress()
	_check(restored_progress.load_game(profile) and JSON.parse_string(JSON.stringify(restored_progress.data)) == JSON.parse_string(JSON.stringify(game.progress.data)), "whole integrated loop survives a real disk reload")
	_check(not FileAccess.file_exists("user://ember_save.json"), "new integrated loop never writes legacy mine save")
	game.queue_free()
	await process_frame

func _buttons(text: String) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in game.hud_view.modal.find_children("*", "Button", true, false):
		if node.text == text: result.append(node)
	return result

func _skill_labels_match() -> bool:
	game._update_preview_ui()
	var snapshot: Dictionary = game.combat_snapshot()
	var names: Array = snapshot.skill_names
	var cooldowns: Array = snapshot.cooldowns[snapshot.active_id]
	for slot: int in range(4):
		var expected: String = "%.1fs" % float(cooldowns[slot]) if float(cooldowns[slot]) > 0.05 else str(names[slot])
		if str(game.hud_view.skills[slot].name.text) != expected: return false
	return true

func _click_button(button: Button) -> void:
	# Real viewport GUI hit testing; parse_input_event alone updates state but headless GUI needs push_input.
	await process_frame
	var center: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event, true)
	await process_frame

func _key(code: int, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _mouse(down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
