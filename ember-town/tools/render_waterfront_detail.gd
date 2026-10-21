extends SceneTree

# Additional engine close-up only. Acceptance uses the unchanged production fixture; this close-up is diagnostic only.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var capture := ""
	var detail := "props"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--detail="): detail = arg.trim_prefix("--detail=")
	if not capture.is_absolute_path():
		push_error("--capture requires an absolute path")
		quit(2)
		return
	var focus := Vector3(-8.8,0.9,-4.3)
	if detail=="ship": focus=Vector3(-5.8,1.2,-9.0)
	elif detail=="roof": focus=Vector3(1.3,1.6,-13)
	var world := Node3D.new()
	root.add_child(world)
	var scenery = load("res://scripts/waterfront.gd").new()
	scenery.mode="ferry"
	world.add_child(scenery)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=5.6
	camera.position=focus+Vector3(8,14,24.5)
	camera.look_at(focus)
	camera.current=true
	scenery.configure_camera(camera)
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture.get_base_dir())
	var error := root.get_texture().get_image().save_png(capture)
	print("DETAIL_FRAME ",detail," size=5.6 error=",error)
	quit(0 if error==OK else 1)
