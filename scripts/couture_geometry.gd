extends RefCounted

const S = preload("res://scripts/sculpt.gd")
const PETAL_SEGMENTS := 24

static func _petal_t(index: int) -> float:
	# Denser sampling at the tips keeps pointed petals softly curved.
	return (1.0-cos(PI*float(index)/PETAL_SEGMENTS))*.5

static func satin(color: Color, metallic := .0, glow := .0) -> StandardMaterial3D:
	var mat := S.material(color,.48 if metallic<.2 else .29,metallic,glow)
	mat.rim_enabled=true
	mat.rim=.15
	mat.rim_tint=.7
	return mat

static func orb(parent: Node3D, pos: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius=1
	shape.height=2
	var large:=maxf(radii.x,maxf(radii.y,radii.z))>=.075
	shape.radial_segments=48 if large else 24
	shape.rings=28 if large else 16
	return S.mesh(parent,shape,pos,radii,mat)

# Tubes follow curved jewellery, seams, vine stems and wing veins.
static func tube(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material, tip_scale := 1.0) -> MeshInstance3D:
	# Border builders can repeat a petal tip. Remove zero-length spans before
	# computing tangents, and join closed loops instead of capping their seam.
	var clean:=PackedVector3Array()
	for point in points:
		if clean.is_empty() or clean[-1].distance_squared_to(point)>0.0000000001:
			clean.append(point)
	points=clean
	if points.size()<2: return null
	var closed:=points.size()>3 and points[0].distance_squared_to(points[-1])<0.0000000001
	if closed: points.remove_at(points.size()-1)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 16
	var rings: Array[PackedVector3Array]=[]
	var normal_rings: Array[PackedVector3Array]=[]
	var tangents:=PackedVector3Array()
	var axes:=PackedVector3Array()
	for i in points.size():
		var before: int=posmod(i-1,points.size()) if closed else maxi(0,i-1)
		var after: int=(i+1)%points.size() if closed else mini(i+1,points.size()-1)
		var direction: Vector3=(points[after]-points[before]).normalized()
		tangents.append(direction)
		var axis: Vector3
		if i==0:
			axis=direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT).normalized()
		else:
			# Transport the frame instead of flipping it at a fixed world axis.
			axis=Quaternion(tangents[i-1],direction)*axes[i-1]
			axis=(axis-direction*axis.dot(direction)).normalized()
		axes.append(axis)
	var closure_twist:=0.0
	if closed:
		var returned: Vector3=Quaternion(tangents[-1],tangents[0])*axes[-1]
		closure_twist=returned.signed_angle_to(axes[0],tangents[0])
	for i in points.size():
		var direction:=tangents[i]
		var axis:=axes[i].rotated(direction,closure_twist*float(i)/points.size())
		var other:=direction.cross(axis).normalized()
		var ring:=PackedVector3Array()
		var normals:=PackedVector3Array()
		for j in sides:
			var angle:=TAU*j/sides
			var normal:=cos(angle)*axis+sin(angle)*other
			ring.append(points[i]+normal*radius*lerpf(1.0,tip_scale,float(i)/(points.size()-1)))
			normals.append(normal)
		rings.append(ring)
		normal_rings.append(normals)
	for i in (points.size() if closed else points.size()-1):
		var following: int=(i+1)%points.size()
		for j in sides:
			var next: int=(j+1)%sides
			for pair in [Vector2i(i,j),Vector2i(following,j),Vector2i(i,next),Vector2i(i,next),Vector2i(following,j),Vector2i(following,next)]:
				surface.set_normal(normal_rings[pair.x][pair.y])
				surface.add_vertex(rings[pair.x][pair.y])
	for end in [0,points.size()-1]:
		if closed: break
		var normal: Vector3=(points[end]-points[1 if end==0 else end-1]).normalized()
		for j in sides:
			var cap: Array[Vector3]=[points[end],rings[end][j],rings[end][(j+1)%sides]]
			if end!=0: cap.reverse()
			for vertex in cap:
				surface.set_normal(normal)
				surface.add_vertex(vertex)
	return S.mesh(parent,surface.commit(),Vector3.ZERO,Vector3.ONE,mat)

static func curve(parent: Node3D, start: Vector3, middle: Vector3, end: Vector3, width: float, mat: Material, tip_scale := 1.0) -> MeshInstance3D:
	var points := PackedVector3Array()
	for i in 33:
		var t := i/32.0
		points.append(start*(1-t)*(1-t)+middle*2*t*(1-t)+end*t*t)
	return tube(parent,points,width,mat,tip_scale)

# Double-curved leaf surface, thick enough to read from front and back.
static func petal(parent: Node3D, start: Vector3, end: Vector3, width: float, mat: Material, curl := .06) -> MeshInstance3D:
	var direction := end-start
	var side := direction.cross(Vector3.FORWARD).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := PETAL_SEGMENTS
	for face in [-1,1]:
		for i in segments:
			for j in 10:
				var verts: Array[Vector3]=[]
				for uv in [Vector2(i,j),Vector2(i+1,j),Vector2(i,j+1),Vector2(i+1,j+1)]:
					var t: float=_petal_t(int(uv.x))
					var across: float=uv.y/5.0-1
					var bulge := pow(maxf(0.0,sin(PI*t)),.7)
					verts.append(start+direction*t+side*across*width*bulge+Vector3(0,0,curl*sin(PI*t)+face*.018*bulge*(1-across*across)))
				var order := [0,2,1,1,2,3] if face==1 else [0,1,2,1,3,2]
				for k in order:
					surface.set_smooth_group(0)
					surface.add_vertex(verts[k])
	surface.generate_normals()
	return S.mesh(parent,surface.commit(),Vector3.ZERO,Vector3.ONE,mat)

static func gem(parent: Node3D, pos: Vector3, size: float, mat: Material, gold: Material = null) -> void:
	var mesh := SphereMesh.new()
	mesh.radius=1
	mesh.height=2
	mesh.radial_segments=32 if size>=.028 else 16
	mesh.rings=18 if size>=.028 else 10
	S.mesh(parent,mesh,pos,Vector3(size,size*1.35,size*.60),mat)
	if gold:
		var setting:=S.ring(parent,pos-Vector3(0,0,.006),size*1.06,size*.10,gold)
		setting.rotation.x=PI/2
		setting.scale.z=1.35

# The piping follows the actual petal edge instead of crossing empty space.
static func petal_border(parent: Node3D, start: Vector3, end: Vector3, width: float, curl: float, mat: Material) -> void:
	var direction:=end-start
	var side:=direction.cross(Vector3.FORWARD).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	var edge:=PackedVector3Array()
	for sign_value in [-1,1]:
		for i in PETAL_SEGMENTS+1:
			var t:=_petal_t(i if sign_value<0 else PETAL_SEGMENTS-i)
			edge.append(start+direction*t+side*sign_value*width*pow(maxf(0,sin(PI*t)),.7)+Vector3(0,0,curl*sin(PI*t)))
	tube(parent,edge,.0035,mat)

static func rosette(parent: Node3D, pos: Vector3, size: float, mat: Material, core: Material) -> void:
	for layer in 2:
		for i in (7 if layer==0 else 5):
			var a:=TAU*i/(7 if layer==0 else 5)+layer*.35
			var radius:=size*(.65 if layer==0 else .34)
			var petal_mesh:=orb(parent,pos+Vector3(cos(a)*radius,sin(a)*radius,layer*size*.2),Vector3(size*.43,size*.27,size*.19),mat)
			petal_mesh.rotation.z=a
	orb(parent,pos+Vector3(0,0,size*.4),Vector3.ONE*size*.2,core)

static func chain(parent: Node3D, start: Vector3, middle: Vector3, end: Vector3, mat: Material, count := 12, radius := .014) -> void:
	for i in count:
		var t:=float(i)/(count-1)
		orb(parent,start*(1-t)*(1-t)+middle*2*t*(1-t)+end*t*t,Vector3.ONE*radius,mat)

static func star(parent: Node3D, pos: Vector3, size: float, mat: Material) -> void:
	for angle in [0.0,PI/2]:
		var shape:=orb(parent,pos,Vector3(size*.22,size,size*.18),mat)
		shape.rotation.z=angle

static func skirt(parent: Node3D, color: Color, trim: Material, layers := 2) -> void:
	for layer in layers:
		var mat:=satin(color.lightened(layer*.10))
		var y:=.055-layer*.050
		var radius:=.25+layer*.04
		var shape:=_fabric_lathe(parent,Vector3(0,y,0),[Vector2(.17,.13),Vector2(.20,.07),Vector2(radius,-.065),Vector2(radius*.94,-.075)],mat)
		shape.scale.z=.72
		var hem:=S.ring(parent,Vector3(0,y-.063,0),radius,.009,trim)
		hem.scale.z=.72

static func crown(parent: Node3D, gold: Material, stone: Material, high := false) -> void:
	var y := .735
	S.ring(parent,Vector3(0,y,0),.245,.016,gold).scale.z=.86
	for i in 9:
		var a:=TAU*i/9
		var height:=.14 if not high else .20+sin(a)*.05
		var start:=Vector3(cos(a)*.24,y,sin(a)*.20)
		var top:=start+Vector3(0,height,0)
		curve(parent,start,top+Vector3(cos(a)*.06,0,sin(a)*.06),top,.009,gold)
		gem(parent,top,.024,stone,gold)
		var next:=TAU*(i+1)/9
		var next_base:=Vector3(cos(next)*.24,y,sin(next)*.20)
		curve(parent,top,top.lerp(next_base,.4)+Vector3(0,-.08,0),next_base,.006,gold)
	chain(parent,Vector3(-.23,y,.11),Vector3(0,y-.10,.32),Vector3(.23,y,.11),gold,17,.01)

static func feather_fan(parent: Node3D, side: int, color: Color, gold: Material, count := 7, spread := 1.0) -> Node3D:
	var wing := Node3D.new()
	wing.name="CoutureWingLeft" if side<0 else "CoutureWingRight"
	wing.position=Vector3(side*.17,.25,-.20)
	parent.add_child(wing)
	for i in count:
		var t:=float(i)/(count-1)
		var end:=Vector3(side*(.32+.30*sin(t*PI*.85))*spread,.56-t*.68,-.09-t*.02)
		var start:=Vector3(0,.08-t*.10,0)
		var mat:=satin(color.lerp(Color("fff4e6"),t*.38),.08)
		petal(wing,start,end,.075,mat,.045)
		curve(wing,start,(start+end)*.5+Vector3(0,0,.045),end*.92,.004,gold)
	for i in 4:
		var end:=Vector3(side*(.25+i*.075),.22-i*.08,.045)
		petal(wing,Vector3.ZERO,end,.07,satin(color.lightened(.12)),.03)
	return wing

static func _fabric_lathe(parent: Node3D, pos: Vector3, profile: Array, mat: Material) -> MeshInstance3D:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size()-1:
		var a: Vector2=profile[row]
		var b: Vector2=profile[row+1]
		for i in 64:
			var u:=TAU*i/64
			var v:=TAU*(i+1)/64
			var vertices: Array[Vector3]=[Vector3(cos(u)*a.x,a.y,sin(u)*a.x),Vector3(cos(v)*a.x,a.y,sin(v)*a.x),Vector3(cos(u)*b.x,b.y,sin(u)*b.x),Vector3(cos(v)*b.x,b.y,sin(v)*b.x)]
			# Descending fabric profile: this winding faces the outside.
			for index in [0,2,1,1,2,3]:
				surface.set_smooth_group(0)
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	return S.mesh(parent,surface.commit(),pos,Vector3.ONE,mat)

# Tailored cloth uses continuous surfaces, with open-front capes and shaped hems.
static func cloth(parent: Node3D, profile: Array, mat: Material, trim: Material, start := 0.0, sweep := TAU, pleat := .0) -> Node3D:
	var garment:=Node3D.new()
	parent.add_child(garment)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Twelve pleats need enough samples per wave for an unbroken hem highlight.
	var columns:=144 if pleat>0.0 else 96
	for row in profile.size()-1:
		for i in columns:
			var points: Array[Vector3]=[]
			for corner in [Vector2i(row,i),Vector2i(row,i+1),Vector2i(row+1,i),Vector2i(row+1,i+1)]:
				var a: float=start+sweep*corner.y/columns
				var p: Vector2=profile[corner.x]
				var radius:=p.x+sin(a*12)*pleat*float(corner.x)/(profile.size()-1)
				points.append(Vector3(cos(a)*radius,p.y,sin(a)*radius*.78))
			for index in [0,2,1,1,2,3]:
				surface.set_smooth_group(0)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var fabric: Material=mat.duplicate()
	if fabric is StandardMaterial3D: fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	S.mesh(garment,surface.commit(),Vector3.ZERO,Vector3.ONE,fabric)
	var hem:=PackedVector3Array()
	var end: Vector2=profile[-1]
	for i in columns+1:
		var a:=start+sweep*i/columns
		var r:=end.x+sin(a*12)*pleat
		hem.append(Vector3(cos(a)*r,end.y,sin(a)*r*.78))
	tube(garment,hem,.006,trim)
	return garment

static func silk(color: Color, highlight: Color) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 sheen_color : source_color;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
 float rim = pow(1.0-max(dot(normalize(NORMAL), normalize(VIEW)),0.0), 2.3);
 float weave = sin(local_pos.y*180.0)*sin(local_pos.x*180.0)*0.003;
 float band = 0.5+0.5*sin(local_pos.y*10.0+local_pos.x*6.0+TIME*0.38);
 ALBEDO = mix(base_color.rgb, sheen_color.rgb, rim*0.32+band*0.08)+weave;
 ROUGHNESS=0.47; METALLIC=0.16; SPECULAR=0.38;
 EMISSION=sheen_color.rgb*rim*0.06;
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("sheen_color",highlight)
	return mat

static func bubble(color: Color) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;
uniform vec4 tint : source_color;
void fragment() {
 float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),2.8);
 ALBEDO=mix(tint.rgb,vec3(1.0),rim*0.55);
 EMISSION=tint.rgb*rim*0.18;
 ALPHA=0.035+rim*0.55;
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("tint",color)
	return mat

static func opal(color: Color) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
uniform vec4 tint : source_color;
varying vec3 object_pos;
void vertex() { object_pos=VERTEX; }
void fragment() {
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float film=0.5+0.5*sin((1.0-facing)*6.0+object_pos.x*2.3+object_pos.y*1.7);
 vec3 cool=mix(tint.rgb,vec3(0.68,0.87,0.92),0.28);
 vec3 warm=vec3(0.94,0.73,0.66);
 ALBEDO=mix(cool,warm,pow(film,3.0)*0.20);
 ROUGHNESS=0.22; METALLIC=0.24; SPECULAR=0.5;
 EMISSION=cool*pow(1.0-facing,3.0)*0.07;
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("tint",color)
	return mat

static func hair_cap(parent: Node3D, mat: Material) -> void:
	# One continuous sculpted shell: the asymmetric hairline is part of the mesh.
	# This prevents exposed skin seams between independent fringe pieces.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge:=PackedVector3Array()
	for row in 28:
		for column in 80:
			var points: Array[Vector3]=[]
			for corner in [Vector2i(row,column),Vector2i(row,column+1),Vector2i(row+1,column),Vector2i(row+1,column+1)]:
				var a: float=TAU*corner.y/80
				var front:=maxf(sin(a),0.0)
				var limit:=lerpf(2.26,1.075,pow(front,1.4))+.11*cos(a)*front
				var t: float=limit*corner.x/28
				var sculpt:=.0025*sin(a*10+t*2)*sin(t)
				points.append(_hair_surface(a,t,sculpt))
			for index in [0,2,1,1,2,3]:
				surface.set_smooth_group(0)
				surface.add_vertex(points[index])
	for column in 81:
		var a:=TAU*column/80
		var front:=maxf(sin(a),0.0)
		var t:=lerpf(2.26,1.075,pow(front,1.4))+.11*cos(a)*front
		var sculpt:=.0025*sin(a*10+t*2)*sin(t)
		edge.append(_hair_surface(a,t,sculpt))
	surface.generate_normals()
	var cap:=S.mesh(parent,surface.commit(),Vector3.ZERO,Vector3.ONE,mat)
	cap.name="ContinuousHair"
	tube(parent,edge,.0045,mat)

static func _hair_surface(a: float, t: float, sculpt: float) -> Vector3:
	var point:=Vector3(cos(a)*sin(t)*(.278+sculpt),.483+cos(t)*.267,-.015+sin(a)*sin(t)*(.292 if sin(a)>0 else .24))
	var face_center:=Vector3(0,.461,.099)
	var delta:=point-face_center
	var distance: float=(delta/Vector3(.236,.218,.176)).length()
	if distance<1.035: point=face_center+delta*(1.035/distance)
	return point
