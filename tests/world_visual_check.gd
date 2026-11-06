extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	var highest_meshes:=0
	for level in range(5,50):
		root.get_node("Campaign").level_index=level
		change_scene_to_file("res://main.tscn")
		await scene_changed
		await process_frame
		var game:=current_scene
		check(game.route_surfaces.size()==game.level_config.route.size(),"Route count unchanged")
		for platform in game.route_surfaces:
			check(is_equal_approx(platform.collider.position.y,-.3),"Landing collision height preserved")
			if level>5:
				check(platform.visual.has_node("ThemePlatformFinish"),"Later platforms receive finishing")
		for hazard in get_nodes_in_group("adventure_hazard"):
			if hazard.kind=="fire":
				var original:=hazard.get_child(0).shape.size as Vector3
				check(original.is_equal_approx(Vector3(1.6,2.6,1.6)),"Original fire damage volume")
				for sample in [0.8,2.4,3.0,3.01,3.7,4.59,4.6,46.8]:
					hazard.elapsed=sample
					hazard._physics_process(0)
					check(hazard.hot==(fmod(sample,4.6)>3.0),"Fire timing preserved")
					var effect: Node3D=hazard.visual.get_child(0)
					check(effect.embers.visible==hazard.hot,"Embers match active danger")
					check(effect.glow.light_energy==0.0 if not hazard.hot else effect.glow.light_energy>0.0,"Safe phase has no flame light")
					for i in effect.embers.multimesh.instance_count:
						check(effect.embers.multimesh.get_instance_transform(i).is_finite(),"Bounded ember transforms")
			elif hazard.kind=="wind":
				check(hazard.visual.get_child(0).name=="WindEffect","Wind uses layered effect")
		for item in get_nodes_in_group("adventure_item"):
			if item.kind=="checkpoint":
				check(item.visual.has_node("CheckpointModel"),"Checkpoint has structured model")
				check(item.visual.get_node("CheckpointModel").has_node("WovenFlag"),"Checkpoint cloth flag exists")
		var meshes:=game.find_children("*","MeshInstance3D",true,false).size()
		highest_meshes=maxi(highest_meshes,meshes)
		print("World visuals checked: ",level+1)
	check(highest_meshes<5000,"Scenery remains bounded")
	paused=false
	current_scene.queue_free()
	await process_frame
	print("Largest world mesh count: ",highest_meshes)
	print("World visual failures: ",failures)
	quit(1 if failures else 0)
