extends SceneTree
const G=preload("res://scripts/couture_geometry.gd")
var failures:=0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	var holder:=Node3D.new()
	root.add_child(holder)
	var points:=PackedVector3Array()
	for i in 65:
		var a:=TAU*i/64.0
		points.append(Vector3(cos(a),sin(a*2)*.12,sin(a)))
		if i==16: points.append(points[-1])
	var tube:=G.tube(holder,points,.025,G.satin(Color.WHITE))
	var arrays:=tube.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var edges: Dictionary={}
	for i in range(0,vertices.size(),3):
		var a:=vertices[i]
		var b:=vertices[i+1]
		var c:=vertices[i+2]
		check((b-a).cross(c-a).length_squared()>1e-16,"No collapsed tube triangles")
		for j in 3:
			var u:=vertices[i+j].snapped(Vector3.ONE*.000001)
			var v:=vertices[i+(j+1)%3].snapped(Vector3.ONE*.000001)
			var ends: Array[String]=[str(u),str(v)]
			ends.sort()
			var key:=ends[0]+"/"+ends[1]
			edges[key]=int(edges.get(key,0))+1
	for count in edges.values(): check(count==2,"Closed piping has no open seam or internal cap")
	for i in vertices.size():
		check(vertices[i].is_finite() and normals[i].is_finite(),"Finite surface geometry")
		check(absf(normals[i].length()-1.0)<.001,"Unit surface normals")
		var center:=Vector3(vertices[i].x,0,vertices[i].z).normalized()
		center.y=sin(atan2(center.z,center.x)*2)*.12
		check(normals[i].dot((vertices[i]-center).normalized())>.85,"Smooth outward tube normals")
	holder.queue_free()
	await process_frame
	print("Couture continuous-surface failures: ",failures)
	quit(1 if failures else 0)
