extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.save_enabled = false
	campaign.unlocked = 0
	campaign.collected_by_level.fill(0)
	campaign.stars_by_level.fill(0)
	campaign.completed.fill(false)
	campaign.reset()
	change_scene_to_file("res://main.tscn")
	await frames(5)
	var signatures := {}
	for index in campaign.LEVELS.size():
		var game = current_scene
		var config: Dictionary = campaign.current_level()
		check(campaign.level_index == index,"Next-stage progression")
		check(game.route_surfaces.size()==config.route.size(),"All route surfaces built")
		var signature := str(config.route)
		check(not signatures.has(signature),"Distinct route "+str(index))
		signatures[signature] = true
		check(game.player.health==3 and game.player.coins==0,"Fresh stage stats")
		check(paused and game.time_left==420.0,"Intro freezes world")
		var items := {"star":0,"key":0,"spring":0,"checkpoint":0}
		for obj in get_nodes_in_group("adventure_item"): items[obj.kind]+=1
		check(items.star==3 and items.checkpoint==config.checkpoints.size(),"Three optional stars and authored safe checkpoints")
		check(items.key==config.key_nodes.size() and items.spring==config.spring_nodes.size(),"Theme items")
		check(get_nodes_in_group("enemy").size()==config.enemy_nodes.size(),"Enemy count")
		game._show_selector()
		check(is_instance_valid(game.selector) and paused,"Stage selector opens")
		check(game.selector_grid.get_child_count()==10,"Ten worlds per chapter")
		game._change_selector_page(1)
		check(game.selector_grid.get_child_count()==10,"Chapter paging")
		game._close_selector()
		check(paused,"Selector returns to intro")
		game._on_overlay_button()
		await frames(5)
		check(game.game_started and game.player.active and not paused,"Stage starts")
		game._toggle_pause()
		var position: Vector3 = game.player.position
		var remaining: float = game.time_left
		await frames(5)
		check(game.player.position==position and game.time_left==remaining,"Pause freezes physics/timer")
		game._toggle_pause()
		game._show_selector()
		game._close_selector()
		check(not paused,"Selector returns to gameplay")
		game.time_left=0
		game._process(.016)
		check(not game.game_finished if config.get("tutorial",false) else game.game_finished and not game.game_won,"Only tutorial has no timeout")
		if config.get("tutorial",false): game._reload_stage()
		game._on_overlay_button()
		await frames(5)
		game=current_scene
		check(campaign.level_index==index and game.player.health==3,"Retry restores same stage")
		game._on_overlay_button()
		if game.required_keys>0:
			game._on_goal_entered(game.player)
			check(not game.game_finished,"Missing keys lock the goal")
			for k in game.required_keys: game.collect_special("key")
		for star in 3: game.collect_special("star")
		if is_instance_valid(game.postal):
			game.postal._collect(game.player)
			for station in 2: game.postal._deliver(game.player,station)
		game.player.coins=index+2
		game.player.position=game.stage_goal+Vector3.UP*.1
		game.player.velocity=Vector3.ZERO
		await frames(8)
		check(game.game_finished and game.game_won and paused,"Physical goal entry wins")
		check(campaign.completed[index] and campaign.stars_by_level[index]==3,"Best records saved in memory")
		check(campaign.unlocked==mini(index+1,campaign.LEVELS.size()-1),"Unlock next stage")
		var total: int=campaign.total_collected()
		game._end_game(true,"duplicate")
		check(total==campaign.total_collected(),"Duplicate goal ignored")
		if index==campaign.LEVELS.size()-1: check(game.overlay_title.text=="全部 %d 关通关！" % campaign.LEVELS.size(),"Final victory")
		game._on_overlay_button()
		game._on_overlay_button()
		await frames(5)
		print("PASS lifecycle/world: ",index+1," ",config.name)
	check(campaign.level_index==0 and campaign.unlocked==campaign.LEVELS.size()-1 and campaign.total_stars()==campaign.LEVELS.size()*3,"Replay preserves unlocked worlds and records")
	# Isolated persistence round trip without touching the player's save.
	var save_path: String=OS.get_environment("TMPDIR").path_join("campaign_%d.cfg" % OS.get_process_id())
	campaign.save_path=save_path
	campaign.save_enabled=true
	campaign.save_progress()
	campaign.unlocked=0
	campaign.stars_by_level.fill(0)
	campaign.load_progress()
	check(campaign.unlocked==campaign.LEVELS.size()-1 and campaign.total_stars()==campaign.LEVELS.size()*3,"Save/load round trip")
	campaign.save_enabled=false
	DirAccess.remove_absolute(save_path)
	paused=false
	current_scene.queue_free()
	await frames(3)
	print("Campaign failures: ",failures)
	quit(1 if failures else 0)
