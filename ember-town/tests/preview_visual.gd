extends SceneTree

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var view:String="town"
	var output:String=""
	var isolated:bool=false
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--view="):view=argument.trim_prefix("--view=")
		if argument.begins_with("--out="):output=argument.trim_prefix("--out=")
		if argument.begins_with("--test-profile="):isolated=argument.trim_prefix("--test-profile=").is_absolute_path()
	if not isolated or output.is_empty() or not view in ["town","ferry","boss","map","inventory"]:
		push_error("Visual check requires a temporary absolute test profile, known view and output path")
		quit(2);return
	var game:Node=load("res://adventure.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if view in ["ferry","boss"]:game._start_stage(view,0)
	elif view=="map":game._open_map()
	elif view=="inventory":game._open_inventory()
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result:Error=image.save_png(output)
	print("VISUAL_CAPTURE ",view," ",output," error=",result)
	quit(0 if result==OK else 3)
