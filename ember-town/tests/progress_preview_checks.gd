extends SceneTree

const Progress = preload("res://scripts/adventure_progress.gd")
var failures: Array[String] = []
var checks: int = 0
var directory: String = "/tmp/ember-progress-check-%d" % Time.get_ticks_usec()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var p = Progress.new()
	var path: String = directory.path_join("progress.json")
	check(p.load_game(path), "new isolated profile")
	check(p.data.inventory.size() == 4 and p.data.party == ["shen", "jiang", "zhu"], "four starter instances and three party members")
	check(not p.set_party(["shen", "shen", "lu"]), "duplicate party rejected")
	check(p.set_party(["lu", "zhu", "jiang"]), "fourth character selectable")
	check(p.set_party(["shen", "jiang", "zhu"]), "party restored")
	check(p.set_target("zhu_command"), "one target chosen before run")
	check(not p.buy_item("shen_echo").ok, "catalog locked before real first clear")
	var run: String = p.begin_run("ferry", 0)
	check(not run.is_empty() and p.in_run, "begin run saved")
	check(not p.equip_item("item_1", "shen") and not p.set_party(["shen", "jiang", "lu"]) and not p.set_target("lu_pierce"), "loadout and target locked in dungeon")
	p.rng.seed = 42
	var killed: Dictionary = p.grant_kill(false)
	check(killed.ok and killed.xp == 12 and killed.coins == 5 and not killed.target_roll, "kill grants actual rewards without chase roll")
	check(p.data.characters.shen.xp == 12 and p.data.characters.jiang.xp == 11 and p.data.characters.lu.xp == 10, "active background bench xp differ")
	var replay = Progress.new()
	check(replay.load_game(path) and not replay.in_run and replay.data.total_kills == 1 and replay.data.characters.shen.xp == 12, "interrupted run keeps earned progress without restoring combat")
	var first: Dictionary = p.grant_clear(run, "ferry", 0)
	check(first.ok and first.first_clear and first.seals == 10 and first.items.size() >= 2, "first clear regular loot plus protected mechanism")
	check(p.data.first_clears.has("ferry") and p.data.unlocked_items.has("zhu_command"), "catalog unlock follows actual clear")
	var before: int = p.data.seals
	check(not p.grant_clear(run, "ferry", 0).ok and p.data.seals == before, "same run cannot claim twice")
	p.end_run()
	check(not p.in_run, "return allows equipment")
	var first_id: String = first.items[1].id
	check(p.equip_item(first_id, "shen"), "new mechanism equipped")
	check(p.get_equipment_stats("shen").mechanism == "shen_echo", "equipped mechanism exposes combat contract")
	check(not p.equip_item(first_id, "zhu"), "weapon ownership enforced")
	check(p.preview_dismantle([first_id, "item_1"]).count == 0, "equipped and protected gear excluded")
	var second_run: String = p.begin_run("ferry", 0)
	check(not p.grant_clear(second_run, "boss", 0).ok, "mismatched stage cannot award")
	var second: Dictionary = p.grant_clear(second_run, "ferry", 0)
	check(second.ok and not second.first_clear and p.data.seals == 20, "new run earns repeat rewards without duplicate first grant")
	p.end_run()
	check(not p.buy_item("zhu_command").ok and p.data.seals == 20, "insufficient funds neither deduct nor issue")
	for index: int in range(8):
		var next: String = p.begin_run("ferry", 0)
		check(p.grant_clear(next, "ferry", 0).ok, "legitimate repeated clear %d" % index)
		p.end_run()
	var purchase: Dictionary = p.buy_item("zhu_command")
	check(purchase.ok and purchase.cost == 100 and p.data.seals == 0, "ten clear precise mechanism exchange")
	check(p.toggle_lock(purchase.item.id), "lock inventory item")
	check(not p.dismantle([purchase.item.id]).ok, "locked item cannot dismantle")
	check(p.toggle_lock(purchase.item.id), "unlock inventory item")
	var duplicate_list: Array = [purchase.item.id, purchase.item.id]
	var preview: Dictionary = p.preview_dismantle(duplicate_list)
	check(preview.count == 1 and preview.dust == 8, "duplicate request cannot multiply returns")
	var old_dust: int = p.data.dust
	check(p.dismantle(duplicate_list).ok and p.data.dust == old_dust + 8, "one transaction removes item and returns dust")
	check(not p.dismantle(duplicate_list).ok, "already removed instance cannot dismantle again")
	# Catch-up is replacement of the bench multiplier, not an extra product.
	p.data.characters.shen.xp = 400
	p.data.characters.shen.level = 5
	p.data.characters.lu.xp = 0
	p.data.characters.lu.level = 1
	var catch_run: String = p.begin_run("boss", 1)
	check(not catch_run.is_empty(), "catch up fixture saved")
	p.grant_kill(false)
	check(p.data.characters.lu.xp == 18, "bench catch-up gets 150 percent base")
	p.end_run()
	var loaded = Progress.new()
	check(loaded.load_game(path) and loaded.data.inventory == p.data.inventory and loaded.data.equipped == p.data.equipped and loaded.data.seals == p.data.seals, "round-trip instance equipment and currency")
	# Disk failure must roll back both sides of a transaction.
	var transaction_before: Dictionary = p.data.duplicate(true)
	p.save_path = "/proc/ember-preview-impossible.json"
	check(not p.set_party(["lu", "jiang", "zhu"]) and p.data == transaction_before, "failed persistence rolls back mutation")
	p.save_path = path
	var valid_text: String = FileAccess.get_file_as_string(path)
	_write(path, "{broken")
	var recovered = Progress.new()
	check(recovered.load_game(path) and recovered.save_enabled and not recovered.warning.is_empty(), "valid backup restores bad main")
	check(recovered.save_game(), "recovery can save without copying damaged main over valid backup")
	check(not FileAccess.get_file_as_string(path + ".bak").begins_with("{broken"), "backup protected during recovery")
	_write(path, "bad main")
	_write(path + ".bak", "bad backup")
	var broken = Progress.new()
	check(not broken.load_game(path) and not broken.save_enabled and not broken.save_game(), "dual damage blocks automatic overwrite")
	check(FileAccess.get_file_as_string(path) == "bad main" and FileAccess.get_file_as_string(path + ".bak") == "bad backup", "dual damaged original bytes unchanged")
	# Valid JSON with a broken foreign key is also corruption.
	var malformed: Dictionary = JSON.parse_string(valid_text)
	malformed.equipped.shen.weapon = "missing_instance"
	var malformed_path: String = directory.path_join("malformed.json")
	_write(malformed_path, JSON.stringify(malformed))
	check(not Progress.new().load_game(malformed_path), "invalid equipment reference rejected")
	var old_path: String = directory.path_join("ember_save.json")
	_write(old_path, "legacy sentinel")
	var legacy = Progress.new()
	check(not legacy.load_game(old_path) and not legacy.save_game() and FileAccess.get_file_as_string(old_path) == "legacy sentinel", "legacy save never overwritten")
	_test_probability()
	print("PROGRESS_CHECKS ", checks, " failures=", failures.size())
	for failure: String in failures: print("FAIL ", failure)
	quit(0 if failures.is_empty() else 1)

func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _test_probability() -> void:
	# Exercise the public reward path with disk IO disabled only in this test subclass.
	var p = MemoryProgress.new()
	p.rng.seed = 91013
	p.set_target("lu_pierce")
	var target_count: int = 0
	var ordinary_count: int = 0
	for index: int in range(1200):
		var run: String = p.begin_run("ferry", 0)
		var reward: Dictionary = p.grant_clear(run, "ferry", 0)
		if reward.target_drop: target_count += 1
		ordinary_count += 1 if reward.items.size() >= 1 else 0
		p.end_run()
	check(target_count >= 30 and target_count <= 95, "seeded target sampling is rare and independent of ordinary guaranteed clear drop")
	check(ordinary_count == 1200 and p.data.seals == 12000, "all clears earn ordinary item and exact currency irrespective of target")
	check(p.data.inventory.size() == 4 + 1200 + 1 + target_count, "no hidden second target grant or repeated first clear")

class MemoryProgress extends "res://scripts/adventure_progress.gd":
	func save_game() -> bool:
		return true
