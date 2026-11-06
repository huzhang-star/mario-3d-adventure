extends SceneTree
# Regression coverage for scenery on floors, clustered landmarks and blocked cameras.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func world_bounds(prop: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
func footprint(box: AABB) -> Rect2:
	return Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
func gap(a: Rect2, b: Rect2) -> float:
	var x := maxf(0, maxf(a.position.x-b.end.x, b.position.x-a.end.x))
	var z := maxf(0, maxf(a.position.y-b.end.y, b.position.y-a.end.y))
	return Vector2(x,z).length()
func shot(path: String) -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var campaign := root.get_node("Campaign")
	campaign.save_enabled = false
	root.get_node("Wardrobe").save_enabled = false
	var capture := "--capture" in OS.get_cmdline_user_args()
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	for level in 50:
		if not only.is_empty() and not str(level+1) in only: continue
		campaign.level_index = level
		change_scene_to_file("res://main.tscn")
		await scene_changed
		await process_frame
		var game := current_scene
		game.set_process(false)
		var props := get_nodes_in_group("background_scenery")
		var bounds: Array[AABB] = []
		check(props.size() >= 10, "Level %d retains all landmarks" % (level+1))
		for prop in props: bounds.append(world_bounds(prop))
		for i in props.size():
			var label := "Level %d %s" % [level+1,props[i].name]
			for j in range(i+1,props.size()):
				check(gap(footprint(bounds[i]),footprint(bounds[j])) >= 6.0, label+" separated from "+str(props[j].name))
			for platform in get_nodes_in_group("course_surface"):
				var half: Vector2 = Vector2(platform.size.x,platform.size.z)*0.5
				var start := Rect2(Vector2(platform.origin.x,platform.origin.z)-half,half*2)
				var finish := Rect2(start.position+Vector2(platform.travel.x,platform.travel.z),start.size)
				check(gap(footprint(bounds[i]),start.merge(finish)) >= game.CAMERA_MAX_DISTANCE+3.0, label+" clears floor and full camera orbit")
		# Exercise the real camera update at spawn, checkpoint and finish across
		# the supported pitch/zoom range; test the whole model's world bounds.
		var spawn: Vector3 = game.stage_spawn
		for platform_index in [0, int(game.level_config.checkpoint), game.route_surfaces.size()-1]:
			game.player.position = spawn if platform_index == 0 else game.route_surfaces[platform_index].position+Vector3.UP*.12
			for yaw_index in 12:
				for pitch in [.14,.42,1.05]:
					for distance in [7.0,game.CAMERA_MAX_DISTANCE]:
						game.camera_yaw = game.stage_spawn_yaw + yaw_index*TAU/12
						game.orbit_yaw = game.camera_yaw
						game.camera_pitch = pitch
						game.orbit_pitch = pitch
						game.camera_distance = distance
						game._process(0)
						var focus: Vector3 = game.player.position+Vector3.UP*.85
						for i in props.size():
							check(props[i].is_visible_in_tree(), "Background never hidden during orbit")
							check(bounds[i].grow(.3).intersects_segment(game.camera.position,focus)==null, "Level %d camera sightline clear at %d" % [level+1,platform_index])
		if capture:
			var output := "res://docs/scenery-layout"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280,800)
			game.overlay.hide()
			game.player.position = spawn
			game.camera_yaw = game.stage_spawn_yaw
			game.orbit_yaw = game.camera_yaw
			game.camera_pitch = .42
			game.orbit_pitch = .42
			game.camera_distance = 11.5
			game._process(0)
			await shot(output+"/level_%02d_start.png" % (level+1))
			game.camera_yaw += PI
			game.orbit_yaw = game.camera_yaw
			game._process(0)
			await shot(output+"/level_%02d_reverse.png" % (level+1))
			game.hud.hide()
			var center := Vector3.ZERO
			for platform in game.route_surfaces: center += platform.position
			center /= game.route_surfaces.size()
			game.camera.position = center + Vector3(0,150,75)
			game.camera.look_at(center)
			await shot(output+"/level_%02d_layout.png" % (level+1))
		print("Scenery checked: ",level+1)
	paused = false
	current_scene.queue_free()
	await process_frame
	print("Scenery checks: ",checks,"; failures: ",failures)
	quit(1 if failures else 0)
