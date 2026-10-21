extends SceneTree

# Fixed review fixture: the real first wave, production materials and actions.
# This is a controlled visual check, not an unassisted gameplay recording.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ""
	var profile := ""
	var camera_position := Vector3(8, 14, 24)
	var focus_z := -2.0
	var focus_x := -1.0
	var view_size := 13.0
	var actor_scale := 1.0
	var hide_ui := false
	var action := false
	var unshaded_actors := false
	var stage := "ferry"
	var perspective_fov := 0.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--test-profile="): profile = arg.trim_prefix("--test-profile=")
		if arg.begins_with("--camera-y="): camera_position.y = float(arg.trim_prefix("--camera-y="))
		if arg.begins_with("--camera-x="): camera_position.x = float(arg.trim_prefix("--camera-x="))
		if arg.begins_with("--camera-z="): camera_position.z = float(arg.trim_prefix("--camera-z="))
		if arg.begins_with("--focus-z="): focus_z = float(arg.trim_prefix("--focus-z="))
		if arg.begins_with("--focus-x="): focus_x = float(arg.trim_prefix("--focus-x="))
		if arg.begins_with("--view-size="): view_size = float(arg.trim_prefix("--view-size="))
		if arg.begins_with("--actor-scale="): actor_scale = float(arg.trim_prefix("--actor-scale="))
		if arg == "--no-ui": hide_ui = true
		if arg == "--action": action = true
		if arg == "--unshaded-actors": unshaded_actors = true
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
		if arg.begins_with("--perspective-fov="): perspective_fov = float(arg.trim_prefix("--perspective-fov="))
	if not output.is_absolute_path() or not profile.is_absolute_path():
		push_error("Art capture requires absolute output and isolated profile paths")
		quit(2)
		return
	if stage not in ["ferry","boss"]:
		push_error("Art capture stage must be ferry or boss")
		quit(2)
		return
	var game: Node3D = load("res://adventure.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._start_stage(stage, 0)
	game.set_physics_process(false)
	game.hero.position = Vector3(0, 0, 3)
	game.aim = Vector3(0, 0, -1)
	game.camera.position = camera_position + Vector3(focus_x, 0, focus_z + 0.5)
	game.camera.look_at(Vector3(focus_x, 0, focus_z))
	game.camera.size = view_size
	if perspective_fov>0.0:
		game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		game.camera.fov = perspective_fov
	await physics_frame
	game.combat_step(0.0, false)
	if unshaded_actors:
		game.body.shaded = false
		game.body.modulate = Color("c5d5e5")
		for enemy: Dictionary in game.enemies:
			var sprite: Sprite3D = enemy.sprite
			sprite.shaded = false
			sprite.modulate = Color("c5d5e5")
	game.notice_text = ""
	game._update_preview_ui()
	game.hud_view.visible = not hide_ui
	await create_timer(2.5).timeout
	if action:
		game.use_skill(0)
		game._update_preview_ui()
	# Explicit inspection-only scale candidate; production actors are not changed here.
	game.body.pixel_size *= actor_scale
	for enemy: Dictionary in game.enemies:
		var sprite: Sprite3D = enemy.sprite
		sprite.pixel_size *= actor_scale
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := root.get_texture().get_image().save_png(output)
	print("ART_FIXED_FRAME camera=", game.camera.position, " action=", action,
		" stage=", stage,
		" focus=", Vector3(focus_x,0,focus_z), " view_size=", view_size,
		" perspective_fov=", perspective_fov,
		" inspection_actor_scale=", actor_scale, " ui=", not hide_ui, " error=", error)
	game.queue_free()
	await process_frame
	quit(0 if error == OK else 3)
