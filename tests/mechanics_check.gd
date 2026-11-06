extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func load_stage(index: int) -> Node:
	root.get_node("Campaign").level_index=index
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(5)
	current_scene.audio_enabled=false
	current_scene.player.sound_enabled=false
	current_scene._on_overlay_button()
	for enemy in get_nodes_in_group("enemy"): enemy.queue_free()
	await frames(2)
	return current_scene
func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	var game=await load_stage(3)
	var p=game.player
	check(game.health_bar.max_value==IslandPlayer.MAX_HEALTH and game.health_bar.step==IslandPlayer.ENEMY_DAMAGE,"Health bar uses half-health steps")
	p.take_damage(p.global_position+Vector3.FORWARD)
	check(is_equal_approx(p.health,2.5),"Enemy contact removes half a health bar")
	p.invulnerable=0.0
	p.lose_life()
	check(is_equal_approx(p.health,1.5),"Falling removes one full health bar")
	p.reset_stats()
	var checkpoint: Area3D
	for obj in get_nodes_in_group("adventure_item"):
		if obj.kind=="checkpoint": checkpoint=obj
	p.position=checkpoint.global_position+Vector3.UP*.1
	p.velocity=Vector3.ZERO
	await frames(8)
	check(checkpoint.activated,"Checkpoint activates physically")
	p.position=Vector3(50,5,50)
	p.respawn()
	check(p.position.distance_to(checkpoint.global_position)<.3,"Respawn at checkpoint")
	var crumble=game.route_surfaces[3]
	p.position=crumble.position+Vector3.UP*.1
	p.velocity=Vector3.ZERO
	await frames(20)
	check(crumble.collapse_clock>=0,"Standing triggers crumble countdown")
	p.position=game.stage_spawn
	await frames(55)
	check(crumble.collider.disabled,"Crumble disables collision")
	await frames(190)
	check(not crumble.collider.disabled and crumble.visual.visible,"Crumble restores for retry")
	game=await load_stage(1)
	p=game.player
	var spring: Area3D
	for obj in get_nodes_in_group("adventure_item"):
		if obj.kind=="spring": spring=obj; break
	p.position=spring.global_position+Vector3.UP*.08
	p.velocity=Vector3.ZERO
	await frames(5)
	check(p.velocity.y>12 and p.launch_protection>0,"Spring launches without pressing jump")
	game=await load_stage(5)
	p=game.player
	var belt=game.route_surfaces[2]
	p.position=belt.position+Vector3.UP*.05
	p.velocity=Vector3.ZERO
	await frames(40)
	check(p.position.x-belt.position.x>.45,"Conveyor carries idle player")
	var fire: Area3D
	for obj in get_nodes_in_group("adventure_hazard"):
		if obj.kind=="fire": fire=obj; break
	p.position=fire.global_position+Vector3.UP*.05
	p.velocity=Vector3.ZERO
	fire.elapsed=0
	await frames(8)
	check(p.health==3 and not fire.hot,"Fire safe phase")
	fire.elapsed=3.1
	await frames(5)
	check(is_equal_approx(p.health,2.5) and fire.hot,"Telegraphed fire removes half a health bar")
	game=await load_stage(6)
	p=game.player
	var lift=game.route_surfaces[2]
	lift.elapsed=0
	await frames(1)
	p.position=lift.position+Vector3.UP*.08
	p.velocity=Vector3.ZERO
	await frames(130)
	check(p.position.y>lift.origin.y+1.5 and absf(p.position.y-lift.position.y)<.2,"Lift carries player upward")
	game=await load_stage(10)
	p=game.player
	var wind: Area3D
	for obj in get_nodes_in_group("adventure_hazard"):
		if obj.kind=="wind": wind=obj; break
	p.position=wind.global_position+Vector3.UP*.08
	p.velocity=Vector3.ZERO
	await frames(40)
	check(p.position.x-wind.global_position.x>.3,"Wind pushes idle player")
	# Actual downward contact defeats an enemy and rewards time.
	game=await load_stage(0)
	p=game.player
	var enemy:=IslandEnemy.new()
	enemy.position=game.stage_spawn+Vector3(0,0,-1)
	enemy.speed=0
	enemy.stomped.connect(game._on_enemy_stomped)
	game.add_child(enemy)
	p.position=enemy.position+Vector3.UP*3.5
	p.velocity=Vector3(0,-2,0)
	var time_before: float=game.time_left
	await frames(28)
	check(not is_instance_valid(enemy) or enemy.defeated,"Descending stomp defeats enemy")
	check(p.health==3 and game.time_left>time_before+2,"Stomp rewards time without player damage")
	paused=false
	current_scene.queue_free()
	await frames(4)
	print("Mechanics failures: ",failures)
	quit(1 if failures else 0)
