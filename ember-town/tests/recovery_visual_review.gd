extends "res://tests/shen_attack_visual_review.gd"

# Short capture of the two replaced recoveries and the real back-facing Q arc.
var review_case: int = -1
const CASE_NAMES: Array[String] = ["front_basic", "right_basic", "back_Q"]

func _process(delta: float) -> bool:
	if not ready_to_run or quitting: return false
	var desired: int = mini(2, int(clock/0.8))
	if desired != review_case:
		review_case = desired
		segment = [0,3,1][desired]
		_prepare_segment()
		if desired==0:
			# Keep the real target in the melee cone without hiding the planted boots.
			game.enemies[0].node.position = game.hero.position+game.aim.rotated(Vector3.UP,deg_to_rad(40.0))*1.6
	game.combat_step(delta, false)
	clock += delta
	var local: float = clock-float(review_case)*0.8
	if local>=0.18 and fired.is_empty():
		fired.append(0.18)
		var target: Dictionary = game.enemies[0]
		var previous_hp: float = target.hp
		var before: float = game.elapsed
		if review_case==2: game.use_skill(0)
		else: game.use_basic()
		events.append({"time":clock,"segment":CASE_NAMES[review_case],"action":"Q" if review_case==2 else "basic","damage":previous_hp-float(target.hp),"simulation_seconds_before":before,"simulation_seconds_after":game.elapsed,"pose_row":game._shen_pose_row,"pose_column":_column()})
	var ground: Vector2 = game.camera.unproject_position(game.hero.global_position)
	frames.append({"time":clock,"segment":CASE_NAMES[review_case],"pose_row":game._shen_pose_row,"pose_column":_column(),"pixel_size":game.body.pixel_size,"offset":[game.body.offset.x,game.body.offset.y],"hero_ground_screen":[ground.x,ground.y]})
	game._update_preview_ui()
	review_label.text = "INTERNAL RECOVERY REVIEW\n%s t=%.3f" % [CASE_NAMES[review_case], clock]
	if clock>=2.35:
		quitting = true
		call_deferred("_finish")
	return false

func _finish() -> void:
	var failures: Array[String] = []
	if events.size()!=3: failures.append("Expected two real basics and one real back Q")
	for event: Dictionary in events:
		if float(event.damage)<=0.0 or int(event.pose_column)!=0 or event.simulation_seconds_before!=event.simulation_seconds_after:
			failures.append(str(event.segment)+" changed instantaneous contact damage")
	for name: String in CASE_NAMES:
		for column: int in range(4):
			var seen: bool = false
			for state: Dictionary in frames:
				if state.segment==name and int(state.pose_column)==column: seen = true
			if not seen: failures.append(name+" missing visible pose column "+str(column))
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Held-enemy production-action fixture: front/right recoveries and back Q; no full playthrough or visual approval","duration":clock,"scenery":scenery_evidence,"actions":events,"frame_states":frames,"failures":failures}))
	file.close()
	game.combat_clear()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 2)
