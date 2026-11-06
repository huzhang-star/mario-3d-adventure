extends SceneTree
var output:="res://docs/world-polish"
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	image.resize(1280,800,Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	var selected:=PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): selected=arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	for level in range(5,50):
		if not selected.is_empty() and not str(level+1) in selected: continue
		root.get_node("Campaign").level_index=level
		change_scene_to_file("res://main.tscn")
		await scene_changed
		for i in 3: await process_frame
		var game:=current_scene
		game.set_process(false)
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,800)
		game.hud.hide()
		game.overlay.hide()
		var route: Array=game.level_config.route
		var focus:=Vector3(route[2][0],route[2][1],route[2][2])
		game.camera.position=focus+Vector3(14,15,20)
		game.camera.look_at(focus+Vector3(0,1,-7))
		await shot(output+"/level_%02d.png" % (level+1))
		var scenery:=game.get_node("Scenery_"+game.level_config.theme)
		var landmark: Node3D=scenery.get_child(1)
		for prop in scenery.get_children(): if prop is Node3D: prop.visible=true
		game.camera.position=landmark.global_position+Vector3(9,7,11)
		game.camera.look_at(landmark.global_position+Vector3(0,2,0))
		await shot(output+"/landmark_%02d.png" % (level+1))
		if level==5:
			var fire: Area3D
			for hazard in get_nodes_in_group("adventure_hazard"):
				if hazard.kind=="fire": fire=hazard; break
			game.camera.position=fire.global_position+Vector3(3.5,2.8,4.0)
			game.camera.look_at(fire.global_position+Vector3(0,1.1,0))
			for phase in [0.8,2.4,3.15,3.7,4.45,4.8]:
				fire.elapsed=phase
				fire._physics_process(0)
				await shot(output+"/vent_%03d.png" % int(phase*100))
			if "--clip" in OS.get_cmdline_user_args():
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+"/vent-motion"))
				for frame in 96:
					fire.elapsed=2.0+frame/24.0
					fire._physics_process(0)
					await shot(output+"/vent-motion/%03d.png" % frame)
		print("Rendered world ",level+1)
	paused=false
	current_scene.queue_free()
	await process_frame
	quit()
