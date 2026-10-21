extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = load("res://scripts/adventure_combat.gd").new()
	root.add_child(game)
	await process_frame
	game._setup_camera()
	game.camera.size = 12.0
	game._setup_hero()
	game.combat_party.assign(["shen"])
	game._apply_role_visual()
	game.body.visible = false
	game.hero.position = Vector3.ZERO
	var floor_node: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(16,0.1,10)
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.05
	floor_node.material_override = game._material(Color("40576b"),true)
	game.add_child(floor_node)
	if "--foe-probe" in OS.get_cmdline_user_args():
		await _render_foes(game)
		return
	for column: int in range(3):
		var sprite: Sprite3D = game.body.duplicate() as Sprite3D
		sprite.visible = true
		sprite.position = Vector3((column-1)*3.5,0.035,0)
		sprite.shaded = false
		var atlas_height: float = sprite.texture.get_height()
		var foot_y: float = atlas_height+game.body.offset.y
		if column==0: sprite.offset.y = -foot_y
		if column==1: sprite.offset.y = foot_y
		if column==2: sprite.offset.y = foot_y-atlas_height
		game.add_child(sprite)
		var ring: MeshInstance3D = game._disc(0.4,Color("e9cf69"))
		ring.position = Vector3(sprite.position.x,0.015,0)
		game.add_child(ring)
		var label: Label3D = Label3D.new()
		label.text = ["negative foot_y","positive foot_y","correct foot_y - height"][column]
		label.position = Vector3(sprite.position.x,0.3,2.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		game.add_child(label)
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("/workspace/scratch/75c92baf237b/combat-foot-probe.png")
	print("COMBAT_RENDER_PROBE ",result)
	quit(result)

func _render_foes(game: Node3D) -> void:
	if not game._prepare_foe_art():
		push_error("foes art is not imported yet")
		quit(2)
		return
	game.camera.size = 17.0
	for row: int in range(4):
		for mirrored: int in range(2):
			var sprite: Sprite3D = Sprite3D.new()
			sprite.centered = false
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.pixel_size = float(game._foe_sizes[row])
			sprite.position = Vector3((row-1.5)*3.4,0.035,float(mirrored)*5.0-2.5)
			sprite.flip_h = mirrored==1
			game._show_foe_frame(sprite,row,0)
			game.add_child(sprite)
			var marker: MeshInstance3D = game._disc(0.35,Color("e9cf69"))
			marker.position = Vector3(sprite.position.x,0.015,sprite.position.z)
			game.add_child(marker)
			var label: Label3D = Label3D.new()
			label.text = ["melee","ranged","elite","boss"][row]+(" mirrored" if mirrored else "")
			label.position = sprite.position+Vector3(0,0.1,1.3)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			game.add_child(label)
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("/workspace/scratch/75c92baf237b/combat-foe-probe.png")
	print("COMBAT_FOE_RENDER_PROBE ",result)
	quit(result)
