extends Node3D

const S := preload("res://scripts/sculpt.gd")
var stream_material: ShaderMaterial
var mist_material: ShaderMaterial
var sock_material: ShaderMaterial
var dust: MultiMeshInstance3D
var gust := 0.0
var platform_width := 4.5

func _ready() -> void:
	name = "WindEffect"
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float clock = 0.0;
uniform float travel = 0.0;
uniform float strength = 0.0;
instance uniform float phase_offset = 0.0;
void vertex() {
 VERTEX.y += sin(UV.x*6.5-clock*2.1+phase_offset)*.09;
 VERTEX.z += sin(UV.x*4.0-clock*1.8+phase_offset)*.08;
}
void fragment() {
 float pulse = fract(UV.x-travel+phase_offset);
 float tail = smoothstep(.08,.58,pulse)*(1.0-smoothstep(.60,.69,pulse));
 float width = 1.0-smoothstep(.05,.48,abs(UV.y-.5));
 float ends = smoothstep(0.0,.12,UV.x)*(1.0-smoothstep(.85,1.0,UV.x));
 ALBEDO = vec3(.87,.96,1.0);
 ALPHA = width*tail*ends*(.28+strength*.17);
}"""
	stream_material = ShaderMaterial.new()
	stream_material.shader = shader
	# Every strand runs in +X, matching the actual sideways force.
	for i in 9:
		var ribbon := S.mesh(self, ribbon_mesh(), Vector3(0,.36+(i%3)*.62,-1.25+floori(i/3.0)*1.18), Vector3.ONE, stream_material)
		ribbon.name = "Stream_%02d" % i
		ribbon.rotation.x = -.45 + (i%3)*.45
		ribbon.set_instance_shader_parameter("phase_offset", i*.371)
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.extra_cull_margin = .2
	var mist_shader := Shader.new()
	mist_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float clock = 0.0;
uniform float travel = 0.0;
uniform float strength = 0.0;
instance uniform float phase_offset = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=vec2(UV.x*4.5-travel*4.5,UV.y*3.0+phase_offset);
 float n=noise(p*2.0+vec2(0,sin(clock*.7)*.15));
 n=mix(n,noise(p*5.0),.25);
 float edges=pow(max(0.0,1.0-length((UV-.5)*2.0)),1.5);
 ALBEDO=vec3(.79,.90,.94);
 ALPHA=smoothstep(.35,.78,n)*edges*(.09+strength*.055);
}"""
	mist_material = ShaderMaterial.new()
	mist_material.shader = mist_shader
	for i in 2:
		var quad := QuadMesh.new()
		quad.size = Vector2(4.5,2.2)
		var veil := S.mesh(self,quad,Vector3(0,1.15,-.85+i*1.7),Vector3.ONE,mist_material)
		veil.set_instance_shader_parameter("phase_offset",i*3.14)
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dust_mat := S.material(Color("e6e6c7"),1)
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mote := SphereMesh.new()
	mote.radius = .014
	mote.height = .028
	mote.radial_segments = 6
	mote.rings = 4
	mote.material = dust_mat
	dust = MultiMeshInstance3D.new()
	dust.name = "WindDust"
	dust.multimesh = MultiMesh.new()
	dust.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	dust.multimesh.mesh = mote
	dust.multimesh.instance_count = 22
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	build_windsock()
	update_effect(0.0)

static func ribbon_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for corner in [Vector2(i,0),Vector2(i+1,0),Vector2(i,1),Vector2(i+1,0),Vector2(i+1,1),Vector2(i,1)]:
			var uv := Vector2(corner.x/32.0,corner.y)
			surface.set_uv(uv)
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(Vector3(uv.x*4.5-2.25,(uv.y-.5)*.18,0))
	return surface.commit()

func build_windsock() -> void:
	var base := Vector3(-minf(1.78,platform_width*.5-.2),0,-minf(1.48,platform_width*.5-.2))
	var brass := S.material(Color("cdb68a"),.4,.55)
	var pole := S.material(Color("e8e5d6"),.48,.22)
	S.cylinder(self,base+Vector3.UP*.055,.16,.11,brass)
	S.cylinder(self,base+Vector3.UP*.72,.027,1.4,pole)
	S.orb(self,base+Vector3.UP*1.45,Vector3.ONE*.053,brass)
	var rim := S.ring(self,base+Vector3(.04,1.25,0),.155,.012,brass)
	rim.rotation.z = PI*.5
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
uniform float strength = 0.0;
void vertex(){
 float u=UV.x;
 VERTEX.y += sin(clock*4.2-u*5.5)*.032*u-pow(u,2.0)*(.17-strength*.12);
 VERTEX.z += sin(clock*3.4-u*5.0)*.052*u;
}
void fragment(){
 float stripe=step(.5,fract(UV.x*3.0));
 ALBEDO=mix(vec3(.88,.87,.73),vec3(.19,.55,.48),stripe);
 ROUGHNESS=.86;
}"""
	sock_material = ShaderMaterial.new()
	sock_material.shader = shader
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 20:
		for side in 24:
			for corner in [Vector2(row,side),Vector2(row+1,side),Vector2(row,side+1),Vector2(row+1,side),Vector2(row+1,side+1),Vector2(row,side+1)]:
				var u: float = corner.x/20.0
				var a: float = corner.y/24.0*TAU
				var radius: float = lerpf(.15,.07,u)
				surface.set_uv(Vector2(u,corner.y/24.0))
				surface.set_normal(Vector3(.11,cos(a),sin(a)).normalized())
				surface.add_vertex(Vector3(.72*u,cos(a)*radius,sin(a)*radius))
	var sock := S.mesh(self,surface.commit(),base+Vector3(.04,1.25,0),Vector3.ONE,sock_material)
	sock.name = "ClothWindsock"
	sock.extra_cull_margin = .2

func update_effect(time: float) -> void:
	gust = (sin(time*1.1)+1.0)*.5
	# Integral of the existing gust force: positive velocity even during its lull.
	var distance := 1.65*time + .65/1.1*(1.0-cos(time*1.1))
	for mat in [stream_material,mist_material]:
		mat.set_shader_parameter("clock",time)
		mat.set_shader_parameter("travel",distance/4.5)
		mat.set_shader_parameter("strength",gust)
	sock_material.set_shader_parameter("clock",time)
	sock_material.set_shader_parameter("strength",gust)
	for i in dust.multimesh.instance_count:
		var phase := fposmod(distance/4.5+float(i)*.618,1.0)
		var fade := smoothstep(0.0,.12,phase)*(1.0-smoothstep(.88,1.0,phase))
		var position := Vector3(-2.25+phase*4.5,.22+(i%7)*.28+sin(time*2+i)*.055,-1.55+(i%5)*.73)
		var basis := Basis.IDENTITY.scaled(Vector3.ONE*maxf(.001,fade))
		dust.multimesh.set_instance_transform(i,Transform3D(basis,position))
