extends SceneTree
const Hud = preload("res://scripts/adventure_hud.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var icon = Hud.SkillIcon.new()
	root.add_child(icon)
	await process_frame
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/skill_icons.json"))
	var passed: bool = Hud.SkillIcon._atlas_texture != null and Hud.SkillIcon._atlas_regions.size()==20
	var checks: int = 0
	for role: String in ["shen","jiang","zhu","lu"]:
		for slot: int in range(5):
			icon.role=role
			icon.slot=slot
			var atlas_index: int = ["shen","jiang","zhu","lu"].find(icon.role)*5+icon.slot
			var frame: Dictionary = parsed.frames[atlas_index]
			var actual: Rect2 = Hud.SkillIcon._atlas_regions[atlas_index]
			var region: Array = frame.region
			var valid: bool = frame.role==role and frame.slot==slot and actual==Rect2(region[0],region[1],region[2],region[3])
			passed=passed and valid
			checks+=1
	print("HUD_ATLAS_RUNTIME checks=",checks," passed=",passed," loaded=",Hud.SkillIcon._atlas_texture!=null," texture_size=",Hud.SkillIcon._atlas_texture.get_size() if Hud.SkillIcon._atlas_texture!=null else Vector2.ZERO)
	icon.queue_free()
	quit(0 if passed else 1)
