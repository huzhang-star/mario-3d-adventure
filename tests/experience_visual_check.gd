extends SceneTree
var failures := 0
var output := "res://docs/experience-upgrade"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func frames(count: int) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func stage(index: int) -> Node:
	root.get_node("Campaign").level_index=index
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(3)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,800)
	return current_scene
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var c:=root.get_node("Campaign")
	c.save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	var game=await stage(0)
	await capture("01-intro")
	game._on_overlay_button()
	game.banner_label.text=""
	await capture("02-gameplay")
	game._show_settings()
	await capture("03-settings")
	game._close_settings()
	game._show_selector()
	await capture("04-map")
	game._close_selector()
	game.stars=3
	game.elapsed_time=c.speed_target()+80
	game._end_game(true,"Test")
	await capture("05-exploration-result")
	game=await stage(6)
	game._on_overlay_button()
	game.banner_label.text=""
	await capture("06-post-office")
	game.player.position=game.postal.mailboxes[0].global_position+Vector3.UP*.2
	game.player.velocity=Vector3.ZERO
	await frames(6)
	game._toggle_pause()
	game.overlay.hide()
	game.camera_yaw=-.55
	game.orbit_yaw=-.55
	game.camera_pitch=.52
	game.orbit_pitch=.52
	game._process(0)
	await capture("07-mailbox")
	game._toggle_pause()
	game.postal._collect(game.player)
	for station in 2: game.postal._deliver(game.player,station)
	game.player.position=game.route_surfaces[7].position+Vector3.UP*.1
	game.player.velocity=Vector3.ZERO
	game.camera_yaw=PI
	game.orbit_yaw=PI
	game._process(0)
	game.banner_label.text="投递完成 · 薄荷云桥已开启"
	await capture("08-cloud-bridge")
	game.player.launch(11.7)
	for i in 8: await physics_frame
	game._toggle_pause()
	game.overlay.hide()
	game.player._update_landing_marker()
	game._process(0)
	await capture("09-landing-guide")
	# Widescreen and narrow-window bounds for the in-game HUD.
	for dimensions in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(900,720)]:
		root.size=dimensions
		await frames(4)
		var viewport_size: Vector2=game.get_viewport().get_visible_rect().size
		for node: Control in [game.time_label,game.special_label,game.sound_button,game.fullscreen_button]:
			var rect:=node.get_global_rect()
			check(rect.position.x>=0 and rect.end.x<=viewport_size.x+1,"HUD fits "+str(dimensions))
		if dimensions.x==900: await capture("10-narrow-window")
	paused=false
	current_scene.queue_free()
	await frames(4)
	print("Visual layout failures: ",failures)
	quit(1 if failures else 0)
