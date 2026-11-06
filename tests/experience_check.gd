extends SceneTree
var failures := 0
var c: Node
var w: Node
var test_dir := ""
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func load_stage(index: int) -> Node:
	c.level_index=index
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(4)
	current_scene.audio_enabled=false
	current_scene.player.sound_enabled=false
	return current_scene
func run() -> void:
	c=root.get_node("Campaign")
	w=root.get_node("Wardrobe")
	test_dir=OS.get_environment("TMPDIR").path_join("island_experience_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(test_dir)
	c.save_path=test_dir.path_join("progress.cfg")
	c.legacy_path=test_dir.path_join("legacy.cfg")
	c.settings_path=test_dir.path_join("settings.cfg")
	w.save_path=test_dir.path_join("wallet.cfg")
	w.legacy_path=test_dir.path_join("legacy_wallet.cfg")
	c.save_enabled=true
	w.save_enabled=true
	# Legacy all-unlocked builds must preserve real wins without granting all progression.
	var legacy:=ConfigFile.new()
	legacy.set_value("progress","unlocked",49)
	legacy.set_value("progress","level",49)
	legacy.set_value("progress","completed",[true,true,false])
	legacy.set_value("progress","stars",[3,2,0])
	legacy.set_value("progress","coins",[21,18,0])
	legacy.save(c.legacy_path)
	c.load_progress()
	check(c.unlocked==2 and c.level_index==2 and c.total_stars()==5,"Legacy migration uses wins, preserves records, clamps locked selection")
	check(FileAccess.file_exists(c.save_path) and FileAccess.file_exists(c.legacy_path),"Migration writes new file and retains original")
	w.load_wallet()
	check(w.balance==39,"Finite wallet migrates earned coin records")
	w.earn(200)
	w.purchase("daisy")
	c.select_level(1)
	var adventure_coins: int=w.balance
	check(not c.set_free_mode(true) and not w.infinite_coins,"Free mode is unavailable")
	c.select_level(49)
	check(c.level_index==2,"Normal progression prevents selecting locked levels")
	check(w.balance==adventure_coins and w.equipped=="daisy","Normal mode preserves earned wallet and outfit")
	var settings:=ConfigFile.new()
	settings.set_value("settings","free_mode",true)
	settings.save(c.settings_path)
	c.load_settings()
	check(not c.unlock_all_levels,"Legacy free-mode setting cannot unlock levels")
	c._clear_records()
	c.save_progress()
	w.balance=0
	w.award_claims={}
	w.save_wallet()
	var game=await load_stage(0)
	check(not game.touch_controls.visible,"Desktop defaults to unobstructed controls")
	game._set_device("touch")
	check(game.touch_controls.visible,"Touch input reveals controls")
	game._set_device("gamepad")
	check(not game.touch_controls.visible and "右摇杆" in game.input_hint.text,"Gamepad gets camera hint")
	game._set_device("keyboard")
	game._show_settings()
	check(paused and is_instance_valid(game.settings_panel),"Settings pause the world")
	c.camera_sensitivity=1.5
	game._close_settings()
	check(paused,"Closing settings retains intro pause")
	c.camera_sensitivity=1
	c.load_settings()
	check(is_equal_approx(c.camera_sensitivity,1.5),"Camera settings persist")
	game._on_overlay_button()
	game.player.launch(11.7)
	await frames(8)
	game.player._update_landing_marker()
	check(game.player.landing_marker.visible,"Airborne player has a surface marker")
	check(absf(game.player.landing_marker.global_position.y-.035)<.1,"Marker sits on the floor below the player")
	game.player.position=game.stage_spawn
	game.player.velocity=Vector3.ZERO
	game.stars=3
	game.elapsed_time=c.speed_target()+90
	game._end_game(true,"test")
	check(not game.result_pending and c.stars_by_level[0]==3 and not c.speed_medals[0],"Slow full exploration grants its own medal")
	check(w.balance==180,"First clear plus three first stars rewards exploration independently of speed")
	game._end_game(true,"duplicate")
	check(w.balance==180,"Duplicate goal cannot credit reward twice")
	game=await load_stage(0)
	game._on_overlay_button()
	game.stars=3
	game.elapsed_time=c.speed_target()
	game._end_game(true,"test")
	check(c.speed_medals[0] and w.balance==245,"Speed target is inclusive; replay only grants base and new speed medal")
	game=await load_stage(0)
	game._on_overlay_button()
	game.stars=3
	game.elapsed_time=c.speed_target()
	var normal_path: String=w.save_path
	w.save_path=test_dir.path_join("missing/wallet.cfg")
	game._end_game(true,"test")
	check(game.result_pending and w.balance==245,"Failed wallet write rolls back and offers save retry")
	w.save_path=normal_path
	game._on_overlay_button()
	check(not game.result_pending and w.balance==275,"Retry grants exactly the missing reward")
	# Failure after the wallet succeeds must not credit a second payout on retry.
	game=await load_stage(1)
	game._on_overlay_button()
	game.elapsed_time=999
	var normal_campaign: String=c.save_path
	c.save_path=test_dir.path_join("missing/progress.cfg")
	game._end_game(true,"test")
	var credited: int=w.balance
	check(game.result_pending and game.reward_saved,"Progress save failure retains already-credited reward")
	c.save_path=normal_campaign
	game._on_overlay_button()
	check(not game.result_pending and w.balance==credited,"Progress retry does not repeat wallet payment")
	game=await load_stage(6)
	game._on_overlay_button()
	var postal: Node3D=game.postal
	await frames(5)
	check(postal.carrying,"Starting near the post desk collects letters physically")
	game._on_goal_entered(game.player)
	check(not game.game_finished,"Unfinished deliveries lock postal goal")
	for index in 2:
		game.player.position=postal.mailboxes[index].global_position-Vector3.UP*.4
		game.player.velocity=Vector3.ZERO
		await frames(8)
		check(postal.delivered[index],"Physical mailbox contact delivers letter "+str(index))
		postal._deliver(game.player,index)
		check(postal.delivered_count()==index+1,"Mailbox cannot deliver twice")
	check(postal.is_complete(),"Both deliveries complete")
	await frames(2)
	for platform in postal.shortcut: check(platform.visible and not platform.collider.disabled,"Delivery opens a solid shortcut")
	game.player.respawn()
	check(postal.is_complete(),"Falls retain delivery progress")
	game=await load_stage(6)
	check(not game.postal.carrying and game.postal.delivered_count()==0,"Full retry resets postal mission")
	for platform in game.postal.shortcut: check(not platform.visible and platform.collider.disabled,"Shortcut resets on retry")
	game=await load_stage(49)
	check(game.level_config.checkpoints.size()>=2,"Long finale has multiple safe checkpoints")
	game._on_overlay_button()
	var checkpoints: Array=[]
	for item in get_nodes_in_group("adventure_item"):
		if item.kind=="checkpoint": checkpoints.append(item)
	checkpoints.sort_custom(func(a: Node,b: Node): return a.route_index<b.route_index)
	checkpoints[-1]._entered(game.player)
	var saved: Vector3=game.player.spawn_position
	checkpoints[0]._entered(game.player)
	check(game.player.spawn_position==saved,"Returning for collectibles never moves checkpoint backwards")
	c.level_index=13
	check(c.current_level().width>c.LEVELS[13].width and c.current_level().enemy_speed<c.LEVELS[13].enemy_speed,"Chapter rest stage eases pressure")
	check(c.speed_target(49)>c.speed_target(0),"Long levels receive distinct speed targets")
	# A milestone gift is cosmetic and is persisted with its award.
	check(w.grant_completion({"coins":0,"claims":{}},30),"Milestone save succeeds")
	check(w.owned.has("mint") and w.owned.has("witch") and not w.owned.has("astral"),"Star milestones grant correct skins")
	paused=false
	current_scene.queue_free()
	await frames(3)
	for name in DirAccess.get_files_at(test_dir): DirAccess.remove_absolute(test_dir.path_join(name))
	DirAccess.remove_absolute(test_dir)
	print("Experience upgrade failures: ",failures)
	quit(1 if failures else 0)
