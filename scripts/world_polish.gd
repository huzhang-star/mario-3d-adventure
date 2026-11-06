extends RefCounted
const S=preload("res://scripts/sculpt.gd")
const G=preload("res://scripts/couture_geometry.gd")
const WOOD=["bamboo","windmill","library","pirate","shrine","music","balloon","sakura","treetop","kite"]
const METAL=["clock","anvil","train","neon","satellite","solar","portal","crown","astrolabe"]
const CRYSTAL=["crystal","astral","igloo","prism","meteor","aurora","stalactite"]
static var box_cache: Dictionary={}

# Round the visible edges while retaining each mesh's original outer bounds.
static func bevel_box(size: Vector3) -> ArrayMesh:
	var key:=str(size)
	if box_cache.has(key): return box_cache[key]
	var half:=size*.5
	var radius:=minf(.14,minf(half.x,minf(half.y,half.z))*.42)
	var inner:=half-Vector3.ONE*radius
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u_axis: int=(axis+1)%3
		var v_axis: int=(axis+2)%3
		var u_values: Array[float]=[-half[u_axis],-inner[u_axis]-radius*.707,-inner[u_axis],inner[u_axis],inner[u_axis]+radius*.707,half[u_axis]]
		var v_values: Array[float]=[-half[v_axis],-inner[v_axis]-radius*.707,-inner[v_axis],inner[v_axis],inner[v_axis]+radius*.707,half[v_axis]]
		for sign_value in [-1,1]:
			for u in 5:
				for v in 5:
					var positions: Array[Vector3]=[]
					var normals: Array[Vector3]=[]
					for corner in [Vector2i(u,v),Vector2i(u+1,v),Vector2i(u,v+1),Vector2i(u+1,v+1)]:
						var raw:=Vector3.ZERO
						raw[axis]=half[axis]*sign_value
						raw[u_axis]=u_values[corner.x]
						raw[v_axis]=v_values[corner.y]
						var center:=raw.clamp(-inner,inner)
						var normal: Vector3=(raw-center).normalized()
						positions.append(center+normal*radius)
						normals.append(normal)
					for index in ([0,2,1,1,2,3] if sign_value==1 else [0,1,2,1,3,2]):
						surface.set_normal(normals[index])
						surface.add_vertex(positions[index])
	var result:=surface.commit()
	box_cache[key]=result
	return result

static func surface_material(source: StandardMaterial3D, theme: String) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
uniform vec4 tint : source_color;
uniform float surface_roughness;
uniform float metal;
uniform float grain_kind;
varying vec3 position;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
 vec3 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(position*6.0);
 float grain=n;
 if(grain_kind<.5) grain=.5+.5*sin(position.x*28.0+noise(position*1.7)*4.0);
 if(grain_kind>1.5) grain=.5+.2*sin(position.z*65.0+n*.4);
 ALBEDO=tint.rgb*(.975+grain*.035);
 ROUGHNESS=clamp(surface_roughness+(n-.5)*.065,.18,1.0);
 METALLIC=metal;
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("tint",source.albedo_color)
	mat.set_shader_parameter("surface_roughness",source.roughness)
	mat.set_shader_parameter("metal",source.metallic)
	mat.set_shader_parameter("grain_kind",0.0 if theme in WOOD else (2.0 if theme in METAL else 1.0))
	return mat

static func refine(root: Node3D, theme: String) -> void:
	var materials: Dictionary={}
	for part in root.find_children("*","MeshInstance3D",true,false):
		if part.mesh is BoxMesh:
			part.mesh=bevel_box(part.mesh.size)
		elif part.mesh is SphereMesh:
			part.mesh.radial_segments=32
			part.mesh.rings=18
		elif part.mesh is CylinderMesh and part.mesh.radial_segments>=24:
			part.mesh.radial_segments=48
		var source: Material=part.material_override
		if source is StandardMaterial3D and not source.emission_enabled:
			var key:=source.get_instance_id()
			if not materials.has(key): materials[key]=surface_material(source,theme)
			part.material_override=materials[key]

static func platform_detail(platform: Node3D, theme: String, width: float, accent: Color, round_shape: bool) -> void:
	refine(platform.visual,theme)
	var root:=Node3D.new()
	root.name="ThemePlatformFinish"
	platform.visual.add_child(root)
	var trim:=S.material(accent.darkened(.15),.46,.22)
	var dark:=S.material(accent.darkened(.62),.72)
	# Insets sit beneath the landing surface and move with the existing body.
	if round_shape:
		S.ring(root,Vector3(0,-.37,0),width*.45,.023,trim)
		for i in 8:
			var a:=TAU*i/8
			S.orb(root,Vector3(cos(a)*width*.465,-.20,sin(a)*width*.465),Vector3.ONE*.033,trim)
	else:
		for side in [-1,1]:
			S.box(root,Vector3(0,-.23,side*(width*.5+.005)),Vector3(width*.85,.025,.015),trim)
			S.box(root,Vector3(side*(width*.5+.005),-.23,0),Vector3(.015,.025,width*.85),trim)
		if theme in WOOD:
			for i in [-2,-1,1,2]:
				S.box(root,Vector3(i*width/6,.002,0),Vector3(.012,.004,width*.88),dark)
		elif theme in METAL:
			for x in [-1,1]:
				for z in [-1,1]:
					S.cylinder(root,Vector3(x*width*.4,.006,z*width*.4),.055,.012,trim,-1,8)
		else:
			for side in [-1,1]:
				S.box(root,Vector3(side*width*.29,.002,0),Vector3(.012,.004,width*.86),dark)

static func edge_detail(parent: Node3D, theme: String, width: float, accent: Color, index: int, round_shape: bool) -> void:
	var root:=Node3D.new()
	root.name="ThemeEdgeDetail"
	parent.add_child(root)
	var edge:=width*(.28 if round_shape else .40)
	root.position=Vector3(edge,0,-edge)
	var mat:=S.material(accent,.38,.2)
	var stem:=S.material(Color("526d63"),.75)
	if theme in METAL:
		S.cylinder(root,Vector3(0,.12,0),.16,.24,stem)
		S.ring(root,Vector3(0,.26,0),.15,.035,mat)
		S.orb(root,Vector3(0,.32,0),Vector3(.10,.07,.10),S.material(accent,.3,.1,.3))
	elif theme in CRYSTAL:
		for i in 3:
			var crystal:=S.cylinder(root,Vector3(-i*.14,.18+i*.04,0),.085,.4+i*.08,mat,0,6)
			crystal.rotation.z=(i-1)*.22
	else:
		for i in 3:
			var pos:=Vector3(-i*.16,.12,0)
			G.curve(root,pos-Vector3.UP*.12,pos+Vector3.UP*.18,pos+Vector3(.03,.23,0),.012,stem)
			G.petal(root,pos,pos+Vector3(-.19,.12,.03),.055,mat,.035)
			G.petal(root,pos+Vector3.UP*.06,pos+Vector3(.16,.23,0),.042,stem,.02)

static func landmark_detail(root: Node3D, theme: String, trim: Material, cream: Material, accent: Material) -> void:
	if theme=="cloud":
		# A framed envelope identifies the post office at play distance.
		S.box(root,Vector3(0,3.05,.89),Vector3(1.8,.82,.08),cream)
		for side in [-1,1]:
			G.curve(root,Vector3(side*.84,3.38,.945),Vector3(side*.42,3.10,.945),Vector3(0,2.90,.945),.024,trim)
		S.box(root,Vector3(0,3.85,0),Vector3(2.95,.14,2.1),trim)
	elif theme=="clock":
		for i in 12:
			var a:=TAU*i/12
			var mark:=S.box(root,Vector3(sin(a)*1.06,5+cos(a)*1.06,1.83),Vector3(.065,.18,.035),trim)
			mark.rotation.z=-a
		for x in [-1.1,1.1]:
			for y in [1.0,2.8]:
				S.box(root,Vector3(x,y,1.53),Vector3(.48,.82,.08),trim)
				S.box(root,Vector3(x,y,1.59),Vector3(.33,.63,.04),cream)
	elif theme=="bamboo":
		for i in 12:
			var a:=TAU*i/12
			G.curve(root,Vector3(cos(a)*.53,2.53,1.5+sin(a)*.53),Vector3(cos(a)*.76,3,1.5+sin(a)*.76),Vector3(cos(a)*.53,3.47,1.5+sin(a)*.53),.018,cream)
		G.curve(root,Vector3(-.16,3.55,1.5),Vector3(0,3.9,1.5),Vector3(.16,3.55,1.5),.023,trim)
	elif theme in ["windmill","candy","treetop"]:
		var p:=Vector3(0,2,1.1) if theme=="windmill" else (Vector3(0,2,1.34) if theme=="candy" else Vector3(0,3.65,1.93))
		var frame:=S.ring(root,p,.38,.055,trim)
		frame.rotation.x=PI*.5
		S.orb(root,p-Vector3(0,0,.025),Vector3(.34,.34,.025),cream)
		S.box(root,p+Vector3(0,0,.025),Vector3(.045,.64,.04),trim)
		S.box(root,p+Vector3(0,0,.025),Vector3(.64,.045,.04),trim)
	elif theme=="train":
		var boiler:=S.cylinder(root,Vector3(.55,1.8,0),.65,2.2,trim)
		boiler.rotation.z=PI*.5
		for x in [0.0,1.0]:
			var band:=S.ring(root,Vector3(x,1.8,0),.66,.035,cream)
			band.rotation.z=PI*.5
		S.orb(root,Vector3(1.73,1.9,0),Vector3(.06,.19,.19),accent)
