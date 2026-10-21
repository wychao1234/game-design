extends SceneTree

func _initialize() -> void:
	call_deferred("_capture_live_encounter")

func _capture_live_encounter() -> void:
	var destination := ""
	var isolated := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): destination = argument.trim_prefix("--qa-output=")
		if argument.begins_with("--test-profile="): isolated = true
	if destination.is_empty() or not isolated:
		push_error("visual QA requires --qa-output and isolated --test-profile")
		quit(2)
		return
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo = true
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var status := screenshot.save_png(destination)
	print("QA_RENDER ", JSON.stringify({"path": destination, "error": status,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"elapsed": game.elapsed, "state": game.get_test_state()}))
	quit(0 if status == OK else 3)
