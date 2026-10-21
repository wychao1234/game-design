extends SceneTree

# Isolated scene-only visual check. No adventure/progress class, no user save access.
# Godot --path PROJECT --script res://tools/render_waterfront.gd -- --scene=town --capture=/absolute/frame.png
func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var mode := "town"
	var capture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="): mode = argument.trim_prefix("--scene=")
		if argument.begins_with("--capture="): capture = argument.trim_prefix("--capture=")
	if mode not in ["town","ferry","boss"] or capture.is_empty() or not capture.is_absolute_path():
		push_error("Set --scene=town|ferry|boss and --capture=/absolute/frame.png")
		quit(2)
		return
	var world := Node3D.new()
	root.add_child(world)
	var waterfront = load("res://scripts/waterfront.gd").new()
	waterfront.mode = mode
	world.add_child(waterfront)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.position = Vector3(12,18,20)
	camera.look_at(Vector3(0,0,-0.5))
	camera.current = true
	waterfront.configure_camera(camera)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(capture)
	print("WATERFRONT_CAPTURE ",capture," error=",error)
	quit(0 if error==OK else 1)
