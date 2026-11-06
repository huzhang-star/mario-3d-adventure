extends SceneTree
var failures := 0
var game: Node3D

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func stage(index: int) -> void:
	paused=false
	root.get_node("Campaign").level_index=index
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(4)
	game=current_scene
	game.audio_enabled=false
	game.player.sound_enabled=false

func walk_to(target: Vector3, limit := 160) -> void:
	for i in limit:
		var distance := Vector2(target.x-game.player.position.x,target.z-game.player.position.z)
		if distance.length()<.3 or game.game_finished: break
		# Convert the desired world direction into the current camera frame.
		var direction := Vector3(distance.x,0,distance.y).normalized()
		var right: Vector3=(game.camera.global_basis.x*Vector3(1,0,1)).normalized()
		var forward := Vector3.UP.cross(right)
		game.player.set_virtual_move(Vector2(direction.dot(right),direction.dot(forward)))
		await frames(1)
	game.player.set_virtual_move(Vector2.ZERO)
	await frames(12)
	check(game.game_won or Vector2(target.x-game.player.position.x,target.z-game.player.position.z).length()<.8,"Reach tutorial route point "+str(target))

func capture() -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tutorial-preview.png")

func run() -> void:
	var c := root.get_node("Campaign")
	c.save_enabled=false
	c.unlock_all_levels=false
	c.unlocked=0
	root.get_node("Wardrobe").save_enabled=false
	await stage(0)
	check(is_instance_valid(game.tutorial) and not game.tutorial.panel.visible,"Tutorial hidden during intro")
	check(get_nodes_in_group("enemy").is_empty(),"Tutorial has no enemies")
	game._on_overlay_button()
	await frames(10)
	check(game.tutorial.step==0,"Starts with movement lesson")
	await capture()
	await walk_to(game.route_surfaces[1].position)
	check(game.player.coins>0 and game.tutorial.step==2,"Walking across connected start collects coins and teaches jump")
	game._set_device("gamepad")
	game.tutorial.update()
	check("A 键" in game.tutorial.instruction.text,"Gamepad jump prompt")
	game._set_device("touch")
	game.tutorial.update()
	check("右侧跳跃按钮" in game.tutorial.instruction.text,"Touch jump prompt")
	game._set_device("keyboard")
	await walk_to(Vector3(0,0,-4.6))
	Input.action_press("jump")
	await walk_to(game.route_surfaces[2].position)
	Input.action_release("jump")
	check(game.tutorial.step==3 and game.player.is_on_floor(),"Real jump crosses gap and advances only on landing")
	await walk_to(game.route_surfaces[3].position)
	check(game.player.checkpoint_index==3 and game.tutorial.step==4,"Physical checkpoint contact advances lesson")
	game._toggle_pause()
	game.tutorial.update()
	check(not game.tutorial.panel.visible,"Pause hides guidance")
	game._on_overlay_button()
	var health: float=game.player.health
	game.player.position.y=-10
	await frames(60)
	check(game.player.active and game.player.health==health,"Fall respawns without damage")
	check(game.player.position.distance_to(game.player.spawn_position)<.3 and game.tutorial.step==4,"Fall retains checkpoint and lesson")
	game.time_left=.01
	game._process(1.0)
	check(not game.game_finished and game.time_label.text=="练习不限时","Tutorial cannot time out")
	for index in range(4,8): await walk_to(game.route_surfaces[index].position)
	check(game.stars==3,"All tutorial stars are reachable on foot")
	check(game.game_won and c.unlocked==1,"Physical goal unlocks second level")
	await stage(0)
	check(game.tutorial.step==0 and game.player.checkpoint_index==-1,"Replay resets tutorial")
	game._on_overlay_button()
	game.player.position=game.stage_goal+Vector3.UP*.1
	await frames(12)
	check(game.game_won and game.stars==0,"Optional collectibles and skipped prompts never lock exit")
	await stage(1)
	check(game.tutorial==null,"Second level has no tutorial")
	game._on_overlay_button()
	game.time_left=.01
	game._process(1.0)
	check(game.game_finished and not game.game_won,"Second level keeps normal timeout")
	paused=false
	current_scene.queue_free()
	await frames(3)
	print("Tutorial failures: ",failures)
	quit(1 if failures else 0)
