extends "res://tests/shen_attack_visual_review.gd"

# Short production-hit review. The long independent body-pose movie remains
# separate evidence; this fixture only reviews the changed transient feedback.
var feedback_case: int = -1
var expired_checks: Array[bool] = []
var body_frames: Array[Dictionary] = []

func _process(delta: float) -> bool:
	if not ready_to_run or quitting: return false
	var desired: int = mini(3,int(clock/0.8))
	if desired != feedback_case:
		feedback_case = desired
		segment = [0,2,3,2][desired]
		_prepare_segment()
		if desired==0:
			# Still inside the real melee arc, but leaves the front support legs
			# visible instead of hiding them behind the frontal target.
			game.enemies[0].node.position = game.hero.position+game.aim.rotated(Vector3.UP,deg_to_rad(40.0))*1.6
	game.combat_step(delta,false)
	clock += delta
	var local: float = clock-float(feedback_case)*0.8
	if local>=0.25 and fired.is_empty():
		fired.append(0.25)
		if feedback_case<3:
			_fire_action()
		else:
			# Fixture seeds the same mark that the real talisman projectile adds.
			# F then uses its normal production damage/feedback path.
			var enemy: Dictionary = game.enemies[0]
			enemy.shen_mark = 4.0
			var previous_hp: float = enemy.hp
			var before: float = game.elapsed
			game.use_skill(3)
			events.append({"action":"F_marked_fixture","damage":previous_hp-float(enemy.hp),"simulation_seconds_before":before,"simulation_seconds_after":game.elapsed,"pose_column":_column()})
		for effect: Dictionary in game.sparks:
			var source: Node3D = effect.node
			var cylinder: bool = false
			for child: Node in source.get_children():
				if child is MeshInstance3D and child.mesh is CylinderMesh: cylinder = true
			frames.append({"case":feedback_case,"at_hit":true,"source_y":source.position.y,"life":effect.life,"solid_cylinder":cylinder})
	if local>=0.6 and expired_checks.size()==feedback_case:
		expired_checks.append(game.sparks.is_empty())
	var ground: Vector2 = game.camera.unproject_position(game.hero.global_position)
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	body_frames.append({"time":clock,"case":feedback_case,"pose_row":game._shen_pose_row,"pose_column":_column(),"pixel_size":game.body.pixel_size,"offset":[game.body.offset.x,game.body.offset.y],"hero":[game.hero.position.x,game.hero.position.z],"hero_ground_screen":[ground.x,ground.y],"logical_viewport":[viewport_size.x,viewport_size.y]})
	review_label.text = "INTERNAL HIT FEEDBACK REVIEW\n%s t=%.3f" % [["front basic 40-degree target","left basic","right basic","F seeded-mark fixture"][feedback_case],clock]
	if clock>=3.1:
		quitting = true
		call_deferred("_finish")
	return false

func _finish() -> void:
	var failures: Array[String] = []
	if events.size()!=4: failures.append("Expected three real basics and one seeded-mark real F")
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		if float(event.damage)<=0.0 or event.simulation_seconds_before!=event.simulation_seconds_after:
			failures.append("Hit timing or damage changed")
		if index<3 and int(event.pose_column)!=0: failures.append("Basic did not hit in contact column zero")
	for source: Dictionary in frames:
		if bool(source.solid_cylinder): failures.append("Solid legacy disc leaked into hit feedback")
	if expired_checks.size()!=4 or false in expired_checks: failures.append("Source effect survived its action")
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Internal short production-hit fixture; F mark is fixture-seeded. No full-playthrough or motion-quality approval.","duration":clock,"scenery":scenery_evidence,"actions":events,"source_feedback":frames,"frame_states":body_frames,"expired_checks":expired_checks,"failures":failures}))
	file.close()
	print("COMBAT_FEEDBACK_VISUAL_REVIEW ",JSON.stringify({"actions":events.size(),"failures":failures}))
	game.combat_clear()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 2)
