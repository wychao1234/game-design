extends SceneTree

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var isolated:=false
	var review_size := 0.0
	var perspective_fov := 0.0
	var follow_x := 0.3
	var follow_z := 0.25
	var review_focus := Vector3(INF,0,INF)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--test-profile="):isolated=arg.trim_prefix("--test-profile=").is_absolute_path()
		if arg.begins_with("--view-size="):review_size=float(arg.trim_prefix("--view-size="))
		if arg.begins_with("--perspective-fov="):perspective_fov=float(arg.trim_prefix("--perspective-fov="))
		if arg.begins_with("--follow-x="):follow_x=float(arg.trim_prefix("--follow-x="))
		if arg.begins_with("--follow-z="):follow_z=float(arg.trim_prefix("--follow-z="))
		if arg.begins_with("--focus-x="):review_focus.x=float(arg.trim_prefix("--focus-x="))
		if arg.begins_with("--focus-z="):review_focus.z=float(arg.trim_prefix("--focus-z="))
	if not isolated:
		push_error("Camera review requires an isolated absolute test profile")
		quit(2);return
	var game:Node3D=load("res://adventure.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._start_stage("ferry",0)
	if review_size>0.0: game.camera.size=review_size
	if perspective_fov>0.0:
		game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
		game.camera.fov=perspective_fov
	var size:Vector2=game.camera.get_viewport().get_visible_rect().size
	var failures:Array[String]=[]
	for point:Vector3 in [Vector3.ZERO,Vector3(0,0,4),Vector3(-9.8,0,-6),Vector3(9.8,0,-6),Vector3(-9.8,0,6),Vector3(9.8,0,6)]:
		game.hero.position=point
		game._follow_view(1.0)
		if is_finite(review_focus.x) and is_finite(review_focus.z):
			var drift:=Vector3(clampf(point.x*follow_x,-4,4),0,clampf(point.z*follow_z,-2.9,2.9))
			var focus:=review_focus+drift
			game.camera.position=focus+game.VIEW_OFFSET
			game.camera.look_at(focus)
		var feet:Vector2=game.camera.unproject_position(point)
		var head:Vector2=game.camera.unproject_position(point+Vector3.UP*2.5)
		if feet.x<size.x*0.06 or feet.x>size.x*0.94 or feet.y>size.y*0.87 or head.y<size.y*0.12:
			failures.append(str(point)+" head="+str(head)+" feet="+str(feet))
		if not _attack_outline_visible(game.camera,point,size):failures.append("attack outline clipped at "+str(point))
		print("CAMERA_VISIBLE ",point," head=",head," feet=",feet," viewport=",size)
	# Exercise the production follow at normal speed and short dodge bursts.
	# Settled corner positions alone miss clipping while the camera catches up.
	game.hero.position=Vector3(0,0,4)
	game._reset_view()
	var moving_samples := 0
	var aiming_samples := 0
	var worst_foot_y := 0.0
	for target:Vector3 in [Vector3(9.8,0,6),Vector3(9.8,0,-6),Vector3(-9.8,0,-6),Vector3(-9.8,0,6),Vector3(0,0,4)]:
		var frame := 0
		while game.hero.position.distance_to(target)>0.01 and frame<600:
			var speed:float=game.MOVE_SPEED*(3.1 if frame%90<14 else 1.0)
			game.hero.position=game.hero.position.move_toward(target,speed/60.0)
			game._follow_view(1.0/60.0)
			var foot:Vector2=game.camera.unproject_position(game.hero.position)
			var head:Vector2=game.camera.unproject_position(game.hero.position+Vector3.UP*2.5)
			worst_foot_y=maxf(worst_foot_y,foot.y/size.y)
			if foot.x<size.x*0.04 or foot.x>size.x*0.96 or foot.y>size.y*0.93 or head.y<size.y*0.08:
				if failures.size()<12:failures.append("moving toward "+str(target)+" head="+str(head)+" feet="+str(foot))
			if not _attack_outline_visible(game.camera,game.hero.position,size) and failures.size()<12:
				failures.append("moving attack outline clipped toward "+str(target))
			moving_samples+=1
			if frame%30==0:
				for offset:Vector3 in [Vector3(-2,0,-2),Vector3(2,0,2)]:
					var expected:Vector3=game.hero.position+offset
					var screen:Vector2=game.camera.unproject_position(expected)
					var origin:Vector3=game.camera.project_ray_origin(screen)
					var direction:Vector3=game.camera.project_ray_normal(screen)
					var hit:Vector3=origin+direction*(-origin.y/direction.y)
					if hit.distance_to(expected)>0.002:failures.append("ground aim roundtrip "+str(expected)+" -> "+str(hit))
					aiming_samples+=1
			frame+=1
	print("CAMERA_BOUNDS_REVIEW ",JSON.stringify({"positions":6,"moving_samples":moving_samples,"ground_aim_samples":aiming_samples,"worst_moving_foot_y_ratio":worst_foot_y,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _attack_outline_visible(camera:Camera3D,foot:Vector3,viewport:Vector2)->bool:
	# Conservative authored Shen envelope, including the sword, in billboard axes.
	# Head/feet tests alone would miss the blade at the horizontal viewport edges.
	for x:float in [-2.15,2.15]:
		for y:float in [0.0,2.65]:
			var world:Vector3=foot+Vector3.UP*0.035+camera.global_basis.x*x+camera.global_basis.y*y
			var pixel:Vector2=camera.unproject_position(world)
			if pixel.x<viewport.x*0.015 or pixel.x>viewport.x*0.985 or pixel.y<viewport.y*0.015 or pixel.y>viewport.y*0.985:return false
	return true
