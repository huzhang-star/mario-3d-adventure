extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func radius(surface: Node3D) -> float:
	if surface.collider.shape is CylinderShape3D: return surface.collider.shape.radius
	return minf(surface.size.x,surface.size.z)*.5-.06
func run() -> void:
	var campaign=root.get_node("Campaign")
	campaign.save_enabled=false
	for stage in campaign.LEVELS.size():
		campaign.level_index=stage
		change_scene_to_file("res://main.tscn")
		await frames(5)
		var game=current_scene
		var player=game.player
		player.sound_enabled=false
		game._on_overlay_button()
		for enemy in get_nodes_in_group("enemy"): enemy.queue_free()
		for hazard in get_nodes_in_group("adventure_hazard"): hazard.queue_free()
		player.fell.disconnect(game._on_player_fell)
		game.get_node("Goal").body_entered.disconnect(game._on_goal_entered)
		for obj in get_nodes_in_group("adventure_item"):
			if obj.kind != "spring": obj.queue_free()
		for platform in game.route_surfaces:
			platform.set_physics_process(false)
			platform.sync_to_physics=false
			platform.position=platform.origin
		await frames(3)
		var pairs: Array=[]
		for index in game.route_surfaces.size()-1: pairs.append([game.route_surfaces[index],game.route_surfaces[index+1]])
		for bonus in get_nodes_in_group("bonus_surface"):
			var nearest: Node3D=game.route_surfaces[bonus.get_meta("source_index")]
			pairs.append([nearest,bonus])
			pairs.append([bonus,nearest])
		if is_instance_valid(game.postal):
			game.postal._collect(player)
			for station in 2: game.postal._deliver(player,station)
			await frames(2)
			var previous: Node3D=game.route_surfaces[7]
			for bridge in game.postal.shortcut:
				pairs.append([previous,bridge])
				previous=bridge
			pairs.append([previous,game.route_surfaces[-1]])
		var count:=0
		for pair in pairs:
			var start: Node3D=pair[0]
			var target: Node3D=pair[1]
			var is_spring:=false
			for obj in start.get_children():
				if obj.get_script()==load("res://scripts/adventure_item.gd") and obj.kind=="spring": is_spring=true
			if start.kind=="lift": start.position=start.origin+start.travel
			var direction: Vector3=(target.position-start.position)*Vector3(1,0,1)
			direction=direction.normalized()
			var landing: Vector3=target.position-direction*(radius(target)-1.15)
			# Joined tutorial floors share an edge: aim beyond the overlapping collision.
			if Vector2(target.position.x-start.position.x,target.position.z-start.position.z).length()<radius(start)+radius(target):
				landing=target.position
			game._release_control_actions()
			player.active=true
			player.position=start.position+direction*(radius(start)-1.0)+Vector3.UP*.08
			if is_spring:
				player.position=start.position+Vector3.UP*.08
				for obj in start.get_children():
					if obj.get_script()==load("res://scripts/adventure_item.gd") and obj.kind=="spring": obj.cooldown=0
			player.velocity=Vector3.ZERO
			player.launch_protection=0
			player.facing_yaw=atan2(direction.x,direction.z)
			game.camera_yaw=player.facing_yaw
			game.orbit_yaw=player.facing_yaw
			await frames(8 if not is_spring else 3)
			Input.action_press("move_forward")
			if not is_spring: Input.action_press("jump")
			var target_spring: Area3D = null
			for obj in target.get_children():
				if obj.get_script()==load("res://scripts/adventure_item.gd") and obj.kind=="spring": target_spring=obj
			var airborne:=false
			var landed:=false
			for tick in 100:
				var to_goal: Vector3=(landing-player.position)*Vector3(1,0,1)
				if to_goal.dot(direction)<.45: Input.action_release("move_forward")
				await frames(1)
				if is_instance_valid(target_spring) and target_spring.cooldown > .3 and player.position.distance_to(target.position)<2.5:
					landed=true
					break
				if not player.is_on_floor(): airborne=true
				if airborne and player.is_on_floor():
					for j in player.get_slide_collision_count():
						if player.get_slide_collision(j).get_collider()==target: landed=true
					if landed: break
			game._release_control_actions()
			if not landed:
				failures+=1
				print("FAIL stage ",stage+1," ",start.name," -> ",target.name," at ",player.position," target ",target.position," spring ",is_spring)
			if start.kind=="lift": start.position=start.origin
			count+=1
		print("Checked stage ",stage+1," jumps and bonus returns: ",count)
	paused=false
	current_scene.queue_free()
	await frames(5)
	print("Jump failures: ",failures)
	quit(1 if failures else 0)
