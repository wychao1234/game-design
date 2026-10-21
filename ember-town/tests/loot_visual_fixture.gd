extends SceneTree

# Isolated renderer fixture. Seeds marker inputs only; it is not a played clear or drop-rate test.
var game: Node3D
var capture: String=""
var profile: String=""
var checks: int=0
var failures: Array[String]=[]
func check(condition:bool,label:String)->void:
	checks+=1
	print("LOOT_FIXTURE ","PASS " if condition else "FAIL ",label)
	if not condition:failures.append(label)
func _initialize()->void:
	call_deferred("_run")
func _run()->void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):capture=argument.trim_prefix("--capture=")
		if argument.begins_with("--test-profile="):profile=argument.trim_prefix("--test-profile=")
	if not profile.is_absolute_path() or not profile.contains("linchuan-loot-fixture-"):
		push_error("Use isolated absolute linchuan-loot-fixture- profile")
		quit(2);return
	# Root entry consumes the same profile argument; no player save is read or written.
	game=load("res://adventure.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(game.progress.save_path==profile,"isolated preview profile selected")
	check(game._start_stage("ferry",0),"fixture opens real ferry geometry")
	game.combat_clear()
	var before:String=JSON.stringify(game.progress.data)
	game._show_loot({"template_id":"not_an_item"},Vector3.ZERO)
	check(game.drops.is_empty(),"unknown template makes no marker")
	var items:Array[String]=["ferry_bracers","tide_pendant","plain_ring","plain_clothing","plain_boots","shen_plain","jiang_plain","zhu_plain","lu_plain","plain_bracers"]
	for index:int in range(items.size()):
		game._show_loot({"template_id":items[index]},Vector3((index%5-2)*1.4,0,(index/5)*1.4))
		var marker:Node3D=game.drops.back().node
		var model:Node3D=marker.get_node("EquipmentModel")
		check(model.get_child_count()>0,"actual equipment mesh "+items[index])
	var cuff:Node3D=game.drops[0].node.get_node("EquipmentModel")
	var tube:MeshInstance3D=cuff.get_child(0)
	check(tube.mesh is CylinderMesh and not tube.mesh.cap_top and not tube.mesh.cap_bottom,"blue bracer has physically open ends")
	check(cuff.get_child(2).mesh is TorusMesh and cuff.get_child(3).mesh is TorusMesh,"bracer has separate metal mouth rims")
	check(game.drops[0].node.has_node("RareLootBeam") and not game.drops[5].node.has_node("RareLootBeam"),"rare soft beam differs from ordinary loot")
	check(JSON.stringify(game.progress.data)==before,"visual fixture cannot grant items, XP, currency or clears")
	if not capture.is_empty():
		# Only a rare bracer and fine bracer remain, to inspect item shape at the real camera scale.
		for index:int in range(game.drops.size()-1,-1,-1):
			if index not in [0,9]:game.drops[index].node.queue_free();game.drops.remove_at(index)
		game.drops[0].node.position=Vector3(4.2,0,3.4)
		game.drops[1].node.position=Vector3(-2.0,0,3.0)
		var layer:=CanvasLayer.new();root.add_child(layer)
		var caption:=Label.new();caption.text="掉落模型检视夹具 · 非游玩掉落或通关证明";caption.add_theme_font_override("font",game.font);caption.add_theme_font_size_override("font_size",20);caption.position=Vector2(420,80);layer.add_child(caption)
		game.hud_view.update_state(game.progress.data,game.combat_snapshot(),"ferry","","")
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture)==OK,"actual Forward+ loot frame written")
	for index:int in range(102):game._update_preview_ui()
	await process_frame
	check(game.drops.is_empty(),"existing eight-second marker cleanup remains effective")
	check(JSON.stringify(game.progress.data)==before,"marker lifetime cleanup preserves all progress")
	game.queue_free();await process_frame
	print("LOOT_FIXTURE_RESULT checks=",checks," failures=",failures.size()," renderer=",RenderingServer.get_current_rendering_method())
	quit(0 if failures.is_empty() else 1)
