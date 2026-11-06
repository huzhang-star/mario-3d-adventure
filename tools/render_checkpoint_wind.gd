extends SceneTree

var output := "res://docs/world-polish"

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.resize(1280,800,Image.INTERPOLATE_LANCZOS)
	image.save_png(path)

func run() -> void:
	root.get_node("Campaign").save_enabled = false
	root.get_node("Wardrobe").save_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.get_node("Campaign").level_index = 10
	change_scene_to_file("res://main.tscn")
	await scene_changed
	for i in 4: await process_frame
	var game := current_scene
	game.set_process(false)
	game.hud.hide()
	game.overlay.hide()
	var checkpoint: Area3D
	var wind: Area3D
	for item in get_nodes_in_group("adventure_item"):
		if item.kind == "checkpoint": checkpoint = item
	for hazard in get_nodes_in_group("adventure_hazard"):
		if hazard.kind == "wind": wind = hazard; break
	if checkpoint:
		game.camera.position = checkpoint.global_position + Vector3(5.6,3.4,7.1)
		game.camera.look_at(checkpoint.global_position + Vector3(0,1.05,0))
		checkpoint.activated = false
		checkpoint._process(0.0)
		await shot(output+"/checkpoint_cold.png")
		checkpoint.activated = true
		checkpoint._process(0.0)
		checkpoint.checkpoint_model.update_effect(checkpoint.elapsed + .7, true)
		await shot(output+"/checkpoint_active.png")
	if wind:
		game.camera.position = wind.global_position + Vector3(-7.8,3.5,8.2)
		game.camera.look_at(wind.global_position + Vector3(0,1.0,0))
		for phase in [0.0,1.15,2.55,3.7]:
			wind.elapsed = phase
			wind._physics_process(0)
			await shot(output+"/wind_%03d.png" % int(phase*100))
	paused = false
	current_scene.queue_free()
	await process_frame
	quit()
