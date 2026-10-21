extends SceneTree

# Independent QA: invokes production actions on a real main scene.
# Never run against the player's save; --test-profile must name a QA file.
var game: Node
var failures: Array[String] = []
var checks := 0
var qa_case := "combat"

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, description: String) -> void:
	checks += 1
	print("QA ", "PASS " if value else "FAIL ", description)
	if not value: failures.append(description)

func _run() -> void:
	var isolated := false
	var isolated_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-case="): qa_case = argument.trim_prefix("--qa-case=")
		if argument.begins_with("--test-profile="):
			isolated = true
			isolated_path = argument.trim_prefix("--test-profile=")
	if not isolated:
		push_error("QA refuses to use a player save: supply --test-profile")
		quit(2)
		return
	if qa_case == "recover-main":
		_write_text(isolated_path, "{broken-primary")
	elif qa_case == "protect-corrupt":
		_write_text(isolated_path, "{broken-primary")
		_write_text(isolated_path + ".bak", "{broken-backup")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	if qa_case == "combat":
		_combat()
	elif qa_case == "save-write":
		_save_write()
	elif qa_case == "save-read":
		_save_read()
	elif qa_case == "collision":
		await _collision()
	elif qa_case == "recover-main":
		_check(game.rare_unlocked and game.rare_equipped and game.kills >= 1, "new process recovers real earned progress from valid backup")
		_check(game.saves_allowed and not game.progress_warning.is_empty(), "recovery allows saving and informs player")
		game._save_progress()
		_check(not game._read_progress(game.save_path).is_empty(), "recovery creates valid main save")
		_check(not game._read_progress(game.save_path + ".bak").is_empty(), "recovery does not replace valid backup with corrupt main")
	elif qa_case == "protect-corrupt":
		_check(not game.saves_allowed and not game.progress_warning.is_empty(), "double corruption disables automatic saving and informs player")
		game._save_progress()
		_check(FileAccess.get_file_as_string(game.save_path) == "{broken-primary", "failed recovery preserves corrupt primary for repair")
		_check(FileAccess.get_file_as_string(game.save_path + ".bak") == "{broken-backup", "failed recovery preserves corrupt backup for repair")
	else:
		_check(false, "unknown QA case")
	print("QA_RESULT ", JSON.stringify({"case": qa_case, "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 2)

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _combat() -> void:
	game.hero.position = Vector3.ZERO
	for enemy in game.enemies:
		enemy["node"].position = Vector3(30, 0, 30)
	var target: Dictionary = game.enemies[0]
	for degrees in [0.0, 22.5, 45.0, 67.5, 90.0, 135.0, 180.0, 270.0]:
		var direction := Vector3(sin(deg_to_rad(degrees)), 0, -cos(deg_to_rad(degrees)))
		game.aim = direction
		game.attack_cd = 0.0
		game.rare_equipped = false
		target["hp"] = 1000.0
		target["node"].position = direction * 1.8
		game._attack()
		_check(float(target["hp"]) < 1000.0, "on-axis hit %s deg" % degrees)
		game.attack_cd = 0.0
		target["hp"] = 1000.0
		target["node"].position = -direction * 1.8
		game._attack()
		_check(is_equal_approx(float(target["hp"]), 1000.0), "behind hero miss %s deg" % degrees)
		game.attack_cd = 0.0
		target["hp"] = 1000.0
		target["node"].position = direction * 3.2
		game._attack()
		_check(is_equal_approx(float(target["hp"]), 1000.0), "outside range miss %s deg" % degrees)
	game.aim = Vector3.FORWARD
	target["hp"] = 1000.0
	target["node"].position = Vector3(0, 0, -1.8)
	game.attack_cd = 0.0
	game.rare_unlocked = true
	game.rare_equipped = false
	game._attack()
	var ordinary_damage := 1000.0 - float(target["hp"])
	game._switch_weapon()
	target["hp"] = 1000.0
	target["node"].position = Vector3(0, 0, -1.8)
	game.attack_cd = 0.0
	var projectile_count: int = game.projectiles.size()
	game._attack()
	_check(1000.0 - float(target["hp"]) > ordinary_damage, "equipped rare weapon increases actual hit damage")
	_check(game.projectiles.size() > projectile_count, "equipped rare weapon adds actual projectile")
	game.health = 1.0
	game.dodge_time = 0.0
	game._hurt(1000.0)
	_check(game.revive_time > 0.0, "lethal hit starts actual revival")
	game._process(2.1)
	_check(game.health == 100.0 and game.rare_unlocked and game.rare_equipped, "revival retains equipment and restores health")

func _save_write() -> void:
	_check(not game.rare_unlocked, "writer starts with an isolated fresh save")
	var elite: Dictionary = game.enemies[2]
	game.hero.position = elite["node"].position
	game._damage_enemy(elite, 1000.0)
	_check(game.drops.size() == 1, "first elite kill drops equipment")
	game._interact()
	_check(game.rare_unlocked and game.rare_equipped and game.drops.is_empty(), "actual pickup consumes drop and equips weapon")
	var previous_kills: int = game.kills
	game._damage_enemy(elite, 1000.0)
	_check(game.kills == previous_kills and game.drops.is_empty(), "dead elite cannot grant duplicate reward")
	game._save_progress()
	_check(FileAccess.file_exists(game.save_path), "writer created a real save file")

func _save_read() -> void:
	_check(game.rare_unlocked and game.rare_equipped, "new process loaded acquired and equipped rare weapon")
	_check(game.kills == 1, "new process loaded earned kill progress")
	var elite: Dictionary = game.enemies[2]
	game._damage_enemy(elite, 1000.0)
	_check(game.drops.is_empty(), "new process cannot duplicate already-owned unique equipment")
	var after_kill: int = game.kills
	game._damage_enemy(elite, 1000.0)
	_check(game.kills == after_kill and game.drops.is_empty(), "repeated death callback remains idempotent")

func _collision() -> void:
	for enemy in game.enemies:
		enemy["node"].position = Vector3(30, 0, 30)
	var destination: Dictionary = game.enemies[0]
	destination["node"].position = Vector3(-6, 0, -4.4)
	destination["ranged"] = true
	destination["cd"] = 999.0
	destination["hp"] = 10000.0
	game.hero.position = Vector3(-10, 0, -4.4)
	await physics_frame
	game.demo = true
	game.attack_cd = 999.0
	game.ice_cd = 999.0
	game.summon_cd = 999.0
	for index in range(90):
		game._process(1.0 / 60.0)
	game.demo = false
	print("QA_POSITION ", game.hero.position)
	_check(game.hero.position.x > -9.9 and game.hero.position.x < -8.8, "actual movement stops before solid pillar")
	game._projectile(Vector3(-10, 0.7, -4.4), Vector3(10, 0, 0), 25.0, true, Color.WHITE, 5.0)
	game._update_projectiles(0.5)
	_check(game.projectiles.is_empty(), "actual projectile is blocked by pillar before lifetime expires")
	game.hero.position = Vector3(-9.3, 0, -4.4)
	destination["node"].position = Vector3(-7.0, 0, -4.4)
	destination["hp"] = 1000.0
	game.aim = Vector3.RIGHT
	game.rare_equipped = false
	game.attack_cd = 0.0
	await physics_frame
	game._attack()
	_check(is_equal_approx(float(destination["hp"]), 1000.0), "melee cannot damage enemy through solid pillar")
	destination["node"].position = Vector3(-9.3, 0, -6.4)
	game.aim = Vector3.FORWARD
	game.attack_cd = 0.0
	await physics_frame
	game._attack()
	_check(float(destination["hp"]) < 1000.0, "same melee damages target on unobstructed side")
	# Regression: the sword-wave spawn offset can lie inside a thick pillar.
	game.hero.position = Vector3(-9.3, 0, -4.4)
	destination["node"].position = Vector3(-7.3, 0, -4.4)
	destination["hp"] = 1000.0
	game.aim = Vector3.RIGHT
	game.rare_equipped = true
	game.attack_cd = 0.0
	await physics_frame
	game._attack()
	game._update_projectiles(0.1)
	print("QA_PILLAR_WAVE hp=", destination["hp"], " shots=", game.projectiles.size())
	_check(is_equal_approx(float(destination["hp"]), 1000.0), "rare sword wave cannot damage through pillar from inside spawn")
	_check(game.projectiles.is_empty(), "pillar-blocked sword wave is removed")
	# A start-inside ray fix alone misses thin walls already behind the spawn.
	var thin_wall := StaticBody3D.new()
	thin_wall.position = Vector3(0, 1, 0)
	var thin_shape := CollisionShape3D.new()
	var thin_box := BoxShape3D.new()
	thin_box.size = Vector3(0.1, 2.0, 3.0)
	thin_shape.shape = thin_box
	thin_wall.add_child(thin_shape)
	game.add_child(thin_wall)
	game.hero.position = Vector3(-0.7, 0, 0)
	destination["node"].position = Vector3(1.3, 0, 0)
	destination["hp"] = 1000.0
	game.aim = Vector3.RIGHT
	game.attack_cd = 0.0
	await physics_frame
	game._attack()
	game._update_projectiles(0.1)
	print("QA_THIN_WALL_WAVE hp=", destination["hp"], " shots=", game.projectiles.size())
	_check(is_equal_approx(float(destination["hp"]), 1000.0), "rare sword wave cannot skip thin wall behind its spawn point")
	_check(game.projectiles.is_empty(), "thin-wall-blocked sword wave is not retained")
	game.hero.position = Vector3(-0.45, 0, 0)
	destination["node"].position = Vector3(1.25, 0, 0)
	destination["hp"] = 1000.0
	game.ice_cd = 0.0
	await physics_frame
	game._cast_ice()
	game._update_projectiles(0.1)
	_check(is_equal_approx(float(destination["hp"]), 1000.0), "ice projectile cannot skip thin wall behind former spawn offset")
	_check(game.projectiles.is_empty(), "thin-wall-blocked ice projectile is removed")
	thin_wall.queue_free()
	await process_frame
	await physics_frame
	game.ice_cd = 0.0
	game._cast_ice()
	game._update_projectiles(0.17)
	_check(float(destination["hp"]) < 1000.0 and game.projectiles.is_empty(), "unobstructed ice projectile still actually damages target")
	destination["hp"] = 1000.0
	destination["node"].position = Vector3(2.65, 0, 0)
	game.attack_cd = 0.0
	game._attack()
	var before_wave: float = destination["hp"]
	game._update_projectiles(0.31)
	_check(is_equal_approx(before_wave, 1000.0) and float(destination["hp"]) < before_wave and game.projectiles.is_empty(), "unobstructed rare sword wave still actually damages out-of-melee target")
