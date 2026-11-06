extends SceneTree
const STYLES=preload("res://scripts/skin_style.gd")
const MODEL=preload("res://assets/kenney/models/character.glb")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	var model: Node3D=MODEL.instantiate()
	root.add_child(model)
	var animation: AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	var counts: Dictionary={}
	var winged: Array[String]=[]
	var largest_mesh_count:=0
	var largest_triangle_count:=0
	var catalog: Array=STYLES.SKINS.duplicate()
	catalog.push_front(STYLES.get_skin("classic"))
	for pass_index in 2:
		for data in catalog:
			STYLES.apply(model,data.id)
			await process_frame
			check(model.find_children("CoutureBase","Node3D",true,false).size()==1,"Exactly one rebuilt body")
			check(model.find_children("CoutureLimb","Node3D",true,false).size()==4,"Four animated limbs after repeated swaps")
			check(model.find_children("SkinAccessories","Node3D",true,false).size()==1,"Old accessory set removed")
			check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"Cosmetics do not change collisions")
			var count:=model.find_children("*","MeshInstance3D",true,false).size()
			largest_mesh_count=maxi(largest_mesh_count,count)
			if pass_index==0:
				var triangles:=0
				for part in model.find_children("*","MeshInstance3D",true,false):
					if not part.mesh: continue
					for surface in part.mesh.get_surface_count():
						var arrays: Array=part.mesh.surface_get_arrays(surface)
						var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
						var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
						triangles+=int((vertices.size() if indices.is_empty() else indices.size())/3)
				largest_triangle_count=maxi(largest_triangle_count,triangles)
			if pass_index==0: counts[data.id]=count
			else: check(counts[data.id]==count,"Repeated swaps never accumulate meshes: "+data.id)
			if data.get("couture",false):
				var motion:=model.get_node("CoutureMotion")
				if pass_index==0 and not motion.wings.is_empty(): winged.append(data.id)
				for time in [0.0,1.25,60.0,7200.0,43200.0]:
					motion.elapsed=time
					motion._process(0)
					for ornament in motion.ornaments:
						check(ornament.transform.is_finite(),"Ornaments stay finite over extended preview: "+data.id)
					for effect in motion.effects:
						check(effect.transform.is_finite(),"Theme effects stay finite: "+data.id)
						check(effect.position.distance_to(effect.get_meta("origin"))<.04,"Theme effects stay near their safe origin: "+data.id)
				check(motion.effects.size()==8,"Each couture theme owns one bounded effect set")
			for clip in ["idle","walk","jump"]:
				animation.play(clip)
				animation.seek(animation.current_animation_length*.35,true)
				animation.pause()
				for eye in model.get_node("CoutureMotion").eyes:
					check(is_instance_valid(eye) and eye.global_transform.is_finite(),"Animated geometry stays valid")
			model.get_node("CoutureMotion").elapsed=4.685
			model.get_node("CoutureMotion")._process(0)
			check(model.get_node("CoutureMotion").eyes[0].scale.y<.1,"Blink reaches closed pose")
			model.get_node("CoutureMotion").elapsed=0
			model.get_node("CoutureMotion")._process(0)
			check(is_equal_approx(model.get_node("CoutureMotion").eyes[0].scale.y,1),"Blink opens fully")
			model.get_node("CoutureMotion").elapsed=60
			model.get_node("CoutureMotion")._process(0)
			for orbit in model.get_node("CoutureMotion").ornaments:
				if orbit.get_meta("vertical",false):
					check(is_zero_approx(orbit.rotation.y),"Rear star halo stays behind face after prolonged animation")
	check(winged==["glass_butterfly"],"Only the butterfly couture skin has wings")
	check(largest_mesh_count<350,"New outfits keep geometry count bounded")
	check(largest_triangle_count<400000,"Smooth cosmetics stay within the per-character triangle budget")
	print("Largest model mesh count: ",largest_mesh_count)
	print("Largest model triangle count: ",largest_triangle_count)
	model.queue_free()
	await process_frame
	await process_frame
	print("Couture geometry/animation failures: ",failures)
	quit(1 if failures else 0)
