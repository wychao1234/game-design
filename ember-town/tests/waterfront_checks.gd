extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_test")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WATERFRONT_FAIL " + description)

func _test() -> void:
	# Regression for observed sand-like aliasing: a mip sampler alone cannot supply missing imported mip levels.
	var timber: Texture2D = load("res://assets/environment/dock_aged_wood.png")
	var timber_image: Image = timber.get_image() if timber != null else null
	check(timber_image != null and timber_image.has_mipmaps(),"dock wood contains real mip levels for receding 3D surfaces")
	for stage in ["town","ferry","boss"]:
		var waterfront = load("res://scripts/waterfront.gd").new()
		waterfront.mode = stage
		root.add_child(waterfront)
		await physics_frame
		await physics_frame
		var space: PhysicsDirectSpaceState3D = waterfront.get_world_3d().direct_space_state
		for point in [Vector3(0,0,4),Vector3(0,0,0),Vector3(-5,0,-2),Vector3(5,0,-2)]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point+Vector3.DOWN*3,1))
			check(not hit.is_empty(),stage+" floor "+str(point))
			check(not hit.is_empty() and abs(hit.position.y)<0.01,stage+" flat collision surface")
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3.UP*0.75,Vector3.UP*0.75+direction*20,1))
			check(not hit.is_empty(),stage+" bounded "+str(direction))
			var expected := 10.5 if direction.x != 0 else 6.5
			check(not hit.is_empty() and abs(hit.position.length()-Vector3(expected,0.75,0).length())<0.05,stage+" exact perimeter")
		check(waterfront.get_spawn_points().size()>=4,stage+" spawn entries")
		if stage != "town": _check_rendered_deck(waterfront,stage)
		if stage == "town":
			check(waterfront.get_interaction_points().size()==3,"town three interactions")
			for item in waterfront.get_interaction_points():
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(item.position+Vector3.UP*0.8,item.position+Vector3.UP*1.0,1))
				check(hit.is_empty(),"town accessible interaction "+item.id)
			_check_town_routes(waterfront,space)
		waterfront.queue_free()
		await process_frame
	print("WATERFRONT_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)

func _check_town_routes(waterfront, space: PhysicsDirectSpaceState3D) -> void:
	# A character-radius sweep checks usable routes rather than only free target points.
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var open := {}
	for x in range(-20,21):
		for z in range(-12,13):
			query.transform = Transform3D(Basis.IDENTITY,Vector3(x*0.5,0.55,z*0.5))
			if space.intersect_shape(query,1).is_empty(): open[Vector2i(x,z)] = true
	var start := Vector2i(0,8)
	check(open.has(start),"town player spawn free")
	var queue: Array[Vector2i] = [start]
	var visited := {start:true}
	while not queue.is_empty():
		var position: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = position+direction
			if open.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	for item in waterfront.get_interaction_points():
		var point := Vector2i(roundi(item.position.x*2),roundi(item.position.z*2))
		check(visited.has(point),"town spawn route to "+item.id)
	check(visited.size()==open.size(),"town no disconnected walkable pockets")
	print("TOWN_CONNECTED_CELLS=",visited.size(),"/",open.size())


func _check_rendered_deck(waterfront, stage: String) -> void:
	# Regression for the observed dark-board defect: Godot front faces use clockwise winding.
	var batches := 0
	for child in waterfront.get_children():
		if not child is MultiMeshInstance3D or not str(child.name).begins_with("WornDockBoards"): continue
		batches += 1
		var arrays: Array = child.multimesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var correct_winding := true
		for i in range(0,vertices.size(),3):
			var cross := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if cross.length_squared()<0.00000001: continue
			if cross.normalized().dot(normals[i])>-0.95: correct_winding = false
		check(correct_winding,stage+" rendered board winding agrees with outward normal")
		check(tangents.size()==vertices.size()*4,stage+" normal-mapped board tangent frame present")
	check(batches>0,stage+" rendered deck surfaces present")
