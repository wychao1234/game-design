extends RefCounted

const CHARACTERS: Dictionary = {
	"shen": {"name": "沈砚", "weapon": "契刀"},
	"jiang": {"name": "江照野", "weapon": "长枪"},
	"zhu": {"name": "祝听澜", "weapon": "符铃"},
	"lu": {"name": "陆惊弦", "weapon": "机巧弓"}
}
const SLOTS: Array[String] = ["weapon", "clothing", "bracers", "boots", "pendant", "ring"]
const ITEMS: Dictionary = {
	"shen_plain": {"name":"旧铁契刀", "slot":"weapon", "character":"shen", "rarity":"普通", "attack":0, "defense":0, "mechanism":"", "set_id":"", "cost":0},
	"jiang_plain": {"name":"旧卫长枪", "slot":"weapon", "character":"jiang", "rarity":"普通", "attack":0, "defense":0, "mechanism":"", "set_id":"", "cost":0},
	"zhu_plain": {"name":"青铜符铃", "slot":"weapon", "character":"zhu", "rarity":"普通", "attack":0, "defense":0, "mechanism":"", "set_id":"", "cost":0},
	"lu_plain": {"name":"行旅机巧弓", "slot":"weapon", "character":"lu", "rarity":"普通", "attack":0, "defense":0, "mechanism":"", "set_id":"", "cost":0},
	"shen_echo": {"name":"回潮契刀", "slot":"weapon", "character":"shen", "rarity":"稀有", "attack":3, "defense":0, "mechanism":"shen_echo", "set_id":"", "cost":100},
	"jiang_break": {"name":"镇埠长枪", "slot":"weapon", "character":"jiang", "rarity":"稀有", "attack":3, "defense":0, "mechanism":"jiang_break", "set_id":"", "cost":100},
	"zhu_command": {"name":"引潮符铃", "slot":"weapon", "character":"zhu", "rarity":"稀有", "attack":3, "defense":0, "mechanism":"zhu_command", "set_id":"", "cost":100},
	"lu_pierce": {"name":"贯潮机巧弓", "slot":"weapon", "character":"lu", "rarity":"稀有", "attack":3, "defense":0, "mechanism":"lu_pierce", "set_id":"", "cost":100},
	"plain_clothing": {"name":"行旅衣装", "slot":"clothing", "character":"", "rarity":"普通", "attack":0, "defense":2, "mechanism":"", "set_id":"", "cost":0},
	"plain_bracers": {"name":"行旅护腕", "slot":"bracers", "character":"", "rarity":"精良", "attack":1, "defense":1, "mechanism":"", "set_id":"", "cost":0},
	"plain_boots": {"name":"行旅鞋履", "slot":"boots", "character":"", "rarity":"普通", "attack":0, "defense":1, "mechanism":"", "set_id":"", "cost":0},
	"plain_ring": {"name":"铜纹戒", "slot":"ring", "character":"", "rarity":"精良", "attack":1, "defense":0, "mechanism":"", "set_id":"", "cost":0},
	"ferry_clothing": {"name":"守渡衣装", "slot":"clothing", "character":"", "rarity":"稀有", "attack":0, "defense":3, "mechanism":"", "set_id":"ferry", "cost":80},
	"ferry_bracers": {"name":"守渡护腕", "slot":"bracers", "character":"", "rarity":"稀有", "attack":2, "defense":1, "mechanism":"", "set_id":"ferry", "cost":80},
	"ferry_boots": {"name":"守渡鞋履", "slot":"boots", "character":"", "rarity":"稀有", "attack":0, "defense":2, "mechanism":"", "set_id":"ferry", "cost":80},
	"tide_pendant": {"name":"潮纹佩饰", "slot":"pendant", "character":"", "rarity":"稀有", "attack":2, "defense":1, "mechanism":"", "set_id":"", "cost":60}
}
const NORMAL_POOL: Array[String] = ["plain_clothing", "plain_bracers", "plain_boots", "plain_ring", "shen_plain", "jiang_plain", "zhu_plain", "lu_plain"]
const CHASE_POOL: Array[String] = ["shen_echo", "jiang_break", "zhu_command", "lu_pierce", "ferry_clothing", "ferry_bracers", "ferry_boots", "tide_pendant"]

var data: Dictionary = {}
var save_path: String = ""
var save_enabled: bool = true
var warning: String = ""
var in_run: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	data = _new_data()

func _new_data() -> Dictionary:
	var result: Dictionary = {"version":2, "preview_mode":true, "party":["shen", "jiang", "zhu"], "characters":{}, "inventory":[], "equipped":{}, "coins":0, "dust":0, "seals":0, "first_clears":{}, "rewarded_runs":[], "next_item_id":1, "next_run_id":1, "total_kills":0, "active_character":"shen", "target_item":"", "unlocked_items":[], "current_run":{}}
	for character_id: String in CHARACTERS:
		result.characters[character_id] = {"name":CHARACTERS[character_id].name, "xp":0, "level":1}
		result.equipped[character_id] = {}
		for slot: String in SLOTS: result.equipped[character_id][slot] = ""
		var instance: Dictionary = {"id":"item_%d" % result.next_item_id, "template_id":character_id + "_plain", "locked":false, "protected":true}
		result.next_item_id += 1
		result.inventory.append(instance)
		result.equipped[character_id].weapon = instance.id
	return result

func load_game(path: String) -> bool:
	save_path = path
	warning = ""
	save_enabled = true
	in_run = false
	data = _new_data()
	if path.is_empty() or path.get_file() == "ember_save.json":
		save_enabled = false
		warning = "试玩存档路径无效：旧矿井存档受到保护。"
		return false
	var loaded: Dictionary = _read_valid(path)
	if loaded.is_empty():
		loaded = _read_valid(path + ".bak")
		if not loaded.is_empty():
			warning = "主存档异常：已从有效备份恢复。"
		elif FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			save_enabled = false
			warning = "存档和备份均损坏：保留原文件并停用保存。"
			return false
	if not loaded.is_empty():
		data = loaded
		# A restarted process abandons enemies, never already granted items or experience.
		data.current_run = {}
	else:
		warning = "隔离代表试玩：四名角色预置开放，进度与正式剧情及旧矿井存档独立。"
	return true

func save_game() -> bool:
	if not save_enabled or save_path.is_empty() or save_path.get_file() == "ember_save.json": return false
	if not _valid(data):
		warning = "当前进度校验失败，未覆盖存档。"
		return false
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		warning = "无法创建存档目录。"
		return false
	var temporary: String = absolute_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		warning = "无法写入存档临时文件。"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if _read_valid(temporary).is_empty():
		warning = "临时存档校验失败，原存档已保留。"
		return false
	if not _read_valid(save_path).is_empty():
		var backup_temporary: String = absolute_path + ".bak.tmp"
		if DirAccess.copy_absolute(absolute_path, backup_temporary) != OK or _read_valid(backup_temporary).is_empty() or DirAccess.rename_absolute(backup_temporary, absolute_path + ".bak") != OK:
			warning = "备份更新失败，未覆盖存档。"
			return false
	if DirAccess.rename_absolute(temporary, absolute_path) != OK:
		warning = "存档原子替换失败，旧存档与备份已保留。"
		return false
	return true

func _commit(previous: Dictionary) -> bool:
	if save_game(): return true
	data = previous
	return false

func begin_run(stage: String, difficulty: int) -> String:
	if in_run or not ["ferry", "boss"].has(stage) or difficulty < 0 or difficulty > 1: return ""
	var previous: Dictionary = data.duplicate(true)
	var run_id: String = "run_%d_%d" % [Time.get_unix_time_from_system() * 1000000, data.next_run_id]
	data.next_run_id += 1
	data.current_run = {"id":run_id, "stage":stage, "difficulty":difficulty, "completed":false}
	if not _commit(previous): return ""
	in_run = true
	return run_id

func grant_kill(elite: bool = false) -> Dictionary:
	if not in_run or data.current_run.is_empty() or data.current_run.completed: return {"ok":false, "error":"没有可奖励的战斗。"}
	var previous: Dictionary = data.duplicate(true)
	var coins: int = 18 if elite else 5
	var xp: int = 35 if elite else 12
	data.total_kills += 1
	data.coins += coins
	data.dust += 2 if elite else 1
	_award_xp(xp)
	var obtained: Array = []
	if rng.randf() < (0.65 if elite else 0.24):
		obtained.append(_add_item(NORMAL_POOL[rng.randi_range(0, NORMAL_POOL.size() - 1)]))
	if not _commit(previous): return {"ok":false, "error":warning}
	return {"ok":true, "coins":coins, "dust":2 if elite else 1, "xp":xp, "items":obtained, "target_roll":false}

func grant_clear(run_id: String, stage: String, difficulty: int) -> Dictionary:
	if not in_run or data.current_run.is_empty() or data.current_run.id != run_id or data.current_run.stage != stage or int(data.current_run.difficulty) != difficulty or data.current_run.completed or data.rewarded_runs.has(run_id):
		return {"ok":false, "error":"本趟奖励无效或已领取。"}
	var previous: Dictionary = data.duplicate(true)
	var first: bool = not data.first_clears.has(stage)
	var obtained: Array = []
	data.seals += 10
	data.coins += 40 if stage == "ferry" else 70
	_award_xp(90 if stage == "ferry" else 150)
	# Ordinary loot, first clear and the single selected chase roll are separate rewards.
	obtained.append(_add_item(NORMAL_POOL[rng.randi_range(0, NORMAL_POOL.size() - 1)]))
	if first:
		data.first_clears[stage] = true
		data.coins += 60
		obtained.append(_add_item("shen_echo" if stage == "ferry" else "tide_pendant", true))
		for template_id: String in CHASE_POOL:
			if not data.unlocked_items.has(template_id): data.unlocked_items.append(template_id)
	var target: String = data.target_item
	var target_drop: bool = not target.is_empty() and CHASE_POOL.has(target) and rng.randf() < 0.05
	if target_drop: obtained.append(_add_item(target))
	data.rewarded_runs.append(run_id)
	data.current_run.completed = true
	if not _commit(previous): return {"ok":false, "error":warning}
	return {"ok":true, "seals":10, "coins":(40 if stage == "ferry" else 70) + (60 if first else 0), "xp":90 if stage == "ferry" else 150, "items":obtained, "first_clear":first, "target_roll":not target.is_empty(), "target_drop":target_drop}

func end_run() -> void:
	if not in_run: return
	var previous: Dictionary = data.duplicate(true)
	data.current_run = {}
	if _commit(previous): in_run = false

func set_party(ids: Array) -> bool:
	if in_run or ids.size() != 3: return false
	var seen: Array = []
	for character_id: Variant in ids:
		if not character_id is String or not CHARACTERS.has(character_id) or seen.has(character_id): return false
		seen.append(character_id)
	var previous: Dictionary = data.duplicate(true)
	data.party = ids.duplicate()
	if not ids.has(data.active_character): data.active_character = ids[0]
	return _commit(previous)

func set_target(template_id: String) -> bool:
	if in_run or (not template_id.is_empty() and not CHASE_POOL.has(template_id)): return false
	var previous: Dictionary = data.duplicate(true)
	data.target_item = template_id
	return _commit(previous)

func equip_item(instance_id: String, character_id: String) -> bool:
	if in_run or not CHARACTERS.has(character_id): return false
	var instance: Dictionary = _find_item(instance_id)
	if instance.is_empty(): return false
	var item: Dictionary = ITEMS[instance.template_id]
	if not item.character.is_empty() and item.character != character_id: return false
	if _equipped_owner(instance_id) != "" and _equipped_owner(instance_id) != character_id: return false
	var previous: Dictionary = data.duplicate(true)
	data.equipped[character_id][item.slot] = instance_id
	return _commit(previous)

func buy_item(template_id: String) -> Dictionary:
	if in_run or not ITEMS.has(template_id) or not data.unlocked_items.has(template_id): return {"ok":false, "error":"城镇中完成首通后才可兑换。"}
	var cost: int = ITEMS[template_id].cost
	if cost <= 0 or data.seals < cost: return {"ok":false, "error":"秘境印记不足。"}
	var previous: Dictionary = data.duplicate(true)
	data.seals -= cost
	var instance: Dictionary = _add_item(template_id)
	if not _commit(previous): return {"ok":false, "error":warning}
	return {"ok":true, "item":instance, "cost":cost}

func toggle_lock(instance_id: String) -> bool:
	if in_run: return false
	var instance: Dictionary = _find_item(instance_id)
	if instance.is_empty(): return false
	var previous: Dictionary = data.duplicate(true)
	instance.locked = not instance.locked
	return _commit(previous)

func preview_dismantle(ids: Array) -> Dictionary:
	var eligible: Array = []
	var blocked: Array = []
	var dust: int = 0
	for raw_id: Variant in ids:
		if not raw_id is String or eligible.has(raw_id) or blocked.has(raw_id): continue
		var instance: Dictionary = _find_item(raw_id)
		if instance.is_empty() or instance.locked or instance.get("protected", false) or not _equipped_owner(raw_id).is_empty():
			blocked.append(raw_id)
			continue
		eligible.append(raw_id)
		dust += 8 if ITEMS[instance.template_id].rarity == "稀有" else 2
	return {"ok":not in_run, "ids":eligible, "blocked":blocked, "dust":dust, "count":eligible.size()}

func dismantle(ids: Array) -> Dictionary:
	if in_run: return {"ok":false, "error":"关卡中不能拆解。"}
	var preview: Dictionary = preview_dismantle(ids)
	if preview.ids.is_empty(): return {"ok":false, "error":"没有可安全拆解的物品。", "blocked":preview.blocked}
	var previous: Dictionary = data.duplicate(true)
	for index: int in range(data.inventory.size() - 1, -1, -1):
		if preview.ids.has(data.inventory[index].id): data.inventory.remove_at(index)
	data.dust += preview.dust
	if not _commit(previous): return {"ok":false, "error":warning}
	return {"ok":true, "dust":preview.dust, "count":preview.count, "blocked":preview.blocked}

func get_equipment_stats(character_id: String) -> Dictionary:
	var result: Dictionary = {"attack":0.0, "defense":0.0, "mechanism":"", "set_count":0, "set_bonus":0}
	if not CHARACTERS.has(character_id): return result
	for slot: String in SLOTS:
		var instance: Dictionary = _find_item(data.equipped[character_id][slot])
		if instance.is_empty(): continue
		var item: Dictionary = ITEMS[instance.template_id]
		result.attack += item.attack
		result.defense += item.defense
		if not item.mechanism.is_empty(): result.mechanism = item.mechanism
		if item.set_id == "ferry": result.set_count += 1
	if result.set_count >= 2: result.defense += 2
	if result.set_count >= 3: result.attack += 2
	result.set_bonus = 3 if result.set_count >= 3 else (2 if result.set_count >= 2 else 0)
	return result

func _award_xp(base: int) -> void:
	var maximum: int = 1
	for character_id: String in CHARACTERS: maximum = maxi(maximum, data.characters[character_id].level)
	for character_id: String in CHARACTERS:
		var rate: float = 1.0 if character_id == data.active_character else (0.9 if data.party.has(character_id) else 0.8)
		if maximum - int(data.characters[character_id].level) >= 3: rate = 1.5
		data.characters[character_id].xp += int(round(base * rate))
		data.characters[character_id].level = mini(50, 1 + int(data.characters[character_id].xp) / 100)

func _add_item(template_id: String, protect: bool = false) -> Dictionary:
	var instance: Dictionary = {"id":"item_%d" % data.next_item_id, "template_id":template_id, "locked":false, "protected":protect}
	data.next_item_id += 1
	data.inventory.append(instance)
	return instance.duplicate(true)

func _find_item(instance_id: String) -> Dictionary:
	for instance: Dictionary in data.inventory:
		if instance.id == instance_id: return instance
	return {}

func _equipped_owner(instance_id: String) -> String:
	if instance_id.is_empty(): return ""
	for character_id: String in CHARACTERS:
		if data.equipped[character_id].values().has(instance_id): return character_id
	return ""

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data if _valid(parser.data) else {}

func _integer(value: Variant, maximum: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and float(value) == floor(float(value))

func _valid(value: Dictionary) -> bool:
	if value.get("version") != 2 or value.get("preview_mode") != true: return false
	for field: String in ["coins", "dust", "seals", "next_item_id", "next_run_id", "total_kills"]:
		if not _integer(value.get(field)): return false
	if value.next_item_id < 1 or value.next_run_id < 1: return false
	if not value.get("party") is Array or value.party.size() != 3: return false
	var seen: Array = []
	for character_id: Variant in value.party:
		if not character_id is String or not CHARACTERS.has(character_id) or seen.has(character_id): return false
		seen.append(character_id)
	if not CHARACTERS.has(value.get("active_character", "")) or not value.party.has(value.active_character): return false
	if not value.get("characters") is Dictionary or value.characters.size() != 4 or not value.get("equipped") is Dictionary or value.equipped.size() != 4: return false
	if not value.get("inventory") is Array: return false
	var instances: Dictionary = {}
	for instance: Variant in value.inventory:
		if not instance is Dictionary or not instance.get("id") is String or not instance.get("template_id") is String or not instance.get("locked") is bool or not instance.get("protected", false) is bool: return false
		if not ITEMS.has(instance.template_id) or instances.has(instance.id) or not instance.id.begins_with("item_"): return false
		var serial: String = instance.id.trim_prefix("item_")
		if not serial.is_valid_int() or int(serial) < 1 or int(serial) >= value.next_item_id: return false
		instances[instance.id] = instance
	var equipped_instances: Array = []
	for character_id: String in CHARACTERS:
		var character: Variant = value.characters.get(character_id)
		var equipment: Variant = value.equipped.get(character_id)
		if not character is Dictionary or not character.get("name") is String or not _integer(character.get("xp")) or not _integer(character.get("level"), 50) or character.level < 1: return false
		if int(character.level) != mini(50, 1 + int(character.xp) / 100): return false
		if not equipment is Dictionary or equipment.size() != 6: return false
		for slot: String in SLOTS:
			if not equipment.get(slot) is String: return false
			var instance_id: String = equipment[slot]
			if instance_id.is_empty(): continue
			if not instances.has(instance_id) or equipped_instances.has(instance_id): return false
			var item: Dictionary = ITEMS[instances[instance_id].template_id]
			if item.slot != slot or (not item.character.is_empty() and item.character != character_id): return false
			equipped_instances.append(instance_id)
	if not value.get("first_clears") is Dictionary or not value.get("rewarded_runs") is Array or not value.get("unlocked_items") is Array or not value.get("current_run") is Dictionary: return false
	for stage: Variant in value.first_clears:
		if not ["ferry", "boss"].has(stage) or value.first_clears[stage] != true: return false
	seen.clear()
	for run_id: Variant in value.rewarded_runs:
		if not run_id is String or run_id.is_empty() or seen.has(run_id): return false
		seen.append(run_id)
	for template_id: Variant in value.unlocked_items:
		if not CHASE_POOL.has(template_id): return false
	if not value.get("target_item") is String or (not value.target_item.is_empty() and not CHASE_POOL.has(value.target_item)): return false
	var run: Dictionary = value.current_run
	if not run.is_empty():
		if not run.get("id") is String or run.id.is_empty() or not ["ferry", "boss"].has(run.get("stage")) or not _integer(run.get("difficulty"), 1) or not run.get("completed") is bool: return false
		if bool(run.completed) != value.rewarded_runs.has(run.id): return false
	return true
