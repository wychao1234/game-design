extends "res://tests/recovery_visual_review.gd"

# Isolated front trial; the production loader still enables only right recovery14.
func _setup() -> void:
	await super._setup()
	if not ready_to_run: return
	ready_to_run = false
	var candidate: String = ProjectSettings.globalize_path("res://../docs/candidates/shen-front-recovery-v2/front-recovery-v2.png")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="): candidate = arg.trim_prefix("--candidate=")
	var expected_sha: String = "faf497af69be46f2a6067326b4d376e9047b7a5f3dde30e31edcfc5415000f7e"
	if not candidate.is_absolute_path() or not FileAccess.file_exists(candidate) or FileAccess.get_sha256(candidate)!=expected_sha:
		push_error("Front candidate fixture requires the exact isolated v2 PNG")
		quit(2)
		return
	var image: Image = Image.load_from_file(candidate)
	if image==null or image.get_size()!=Vector2i(1314,1197):
		push_error("Front candidate fixture source dimensions/format changed")
		quit(2)
		return
	if not game._prepare_shen_attack_atlas():
		push_error("Front candidate fixture requires the valid production attack cache")
		quit(2)
		return
	var source_size: Vector2i = image.get_size()
	var factor: float = 269.0/965.0
	image.resize(roundi(source_size.x*factor),roundi(source_size.y*factor),Image.INTERPOLATE_NEAREST)
	var ratio: Vector2 = Vector2(image.get_size())/Vector2(source_size)
	var candidate_texture: ImageTexture = ImageTexture.create_from_image(image)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/shen_attack.json")) as Dictionary
	var horizontal_bias: float = (float((metadata["reference_walk_support_x_by_row"] as Array)[0])+(game._role_offsets["shen"][0] as Vector2).x)*float(game._role_sizes["shen"])/game._shen_attack_pixel_size
	var candidate_offset: Vector2 = Vector2(-418.0*ratio.x+horizontal_bias,1102.0*ratio.y-image.get_height())
	game._shen_attack_frames[2] = candidate_texture
	game._shen_attack_offsets[2] = candidate_offset
	var evidence: Dictionary = {"scope":"ISOLATED FRONT CANDIDATE ONLY; production mapping unchanged; no visual approval", "source_path":candidate,"source_sha256":expected_sha,"source_size":[source_size.x,source_size.y],"source_body_height_pixels":965,"normalization_body_height_pixels":269,"normalized_size":[image.get_width(),image.get_height()],"source_foot":[418,1102],"runtime_offset":[candidate_offset.x,candidate_offset.y],"runtime_pixel_size":game._shen_attack_pixel_size,"replacement_index":2,"sole_ground_error_m":(float(image.get_height())-1102.0*ratio.y+candidate_offset.y)*game._shen_attack_pixel_size,"production_combat_sha256":FileAccess.get_sha256("res://scripts/adventure_combat.gd"),"production_atlas_sha256":FileAccess.get_sha256("res://assets/characters/shen_attack.png")}
	var file: FileAccess = FileAccess.open(output.get_basename()+"-candidate.json",FileAccess.WRITE)
	if file==null:
		push_error("Front candidate fixture could not write loading evidence")
		quit(2)
		return
	file.store_string(JSON.stringify(evidence))
	file.close()
	print("FRONT_CANDIDATE_LOADED ",JSON.stringify(evidence))
	ready_to_run = true
