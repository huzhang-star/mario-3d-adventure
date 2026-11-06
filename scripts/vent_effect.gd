extends Node3D
const S=preload("res://scripts/sculpt.gd")
var flame_material: ShaderMaterial
var glow: OmniLight3D
var embers: MultiMeshInstance3D
var smoke: Array[MeshInstance3D]=[]

func _ready() -> void:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float clock = 0.0;
uniform float strength = 0.0;
instance uniform float phase_offset = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
 float h=1.0-UV.y;
 float t=clock+phase_offset;
 float turbulence=noise(vec2(UV.x*6.0+phase_offset,h*6.0-t*3.0))*.65;
 turbulence+=noise(vec2(UV.x*14.0+3.0,h*12.0-t*5.5))*.35;
 float sway=sin(h*9.0-t*4.3)*.07*h;
 float x=abs((UV.x-.5+sway+(turbulence-.5)*.21*h)*2.0);
 float field=(1.0-h)*.86-pow(x,1.35)*1.12+(turbulence-.5)*.70;
 float mask=smoothstep(.015,.19,field)*(1.0-smoothstep(.90,1.0,h));
 mask*=smoothstep(0.0,.035,h);
 float core=smoothstep(.25,.77,field)*(1.0-h*.8);
 vec3 color=mix(vec3(.95,.065,.005),vec3(1.0,.44,.025),smoothstep(.06,.38,field));
 color=mix(color,vec3(1.0,.88,.43),core);
 ALBEDO=color; EMISSION=color*.42;
 ALPHA=mask*strength*.9;
}"""
	flame_material=ShaderMaterial.new()
	flame_material.shader=shader
	for i in 3:
		var quad:=QuadMesh.new()
		quad.size=Vector2(1.45,2.55)
		var tongue:=S.mesh(self,quad,Vector3(0,1.38,0),Vector3.ONE,flame_material)
		tongue.rotation.y=PI*i/3
		tongue.set_instance_shader_parameter("phase_offset",i*1.73)
		tongue.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spark_mat:=S.material(Color("ffb549"),.4,0,2.0)
	spark_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var spark:=SphereMesh.new()
	spark.radius=.021
	spark.height=.065
	spark.radial_segments=6
	spark.rings=4
	spark.material=spark_mat
	embers=MultiMeshInstance3D.new()
	embers.multimesh=MultiMesh.new()
	embers.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	embers.multimesh.mesh=spark
	embers.multimesh.instance_count=18
	embers.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(embers)
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(1,1,1,.48),Color(1,1,1,.20),Color(1,1,1,0)])
	gradient.offsets=PackedFloat32Array([0,.45,1])
	var texture:=GradientTexture2D.new()
	texture.gradient=gradient
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(.5,0)
	texture.width=64
	texture.height=64
	for i in 5:
		var mat:=S.material(Color("857b78"),1)
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture=texture
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var quad:=QuadMesh.new()
		quad.size=Vector2.ONE
		var puff:=S.mesh(self,quad,Vector3.ZERO,Vector3.ONE,mat)
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.append(puff)
	glow=OmniLight3D.new()
	glow.position.y=.65
	glow.light_color=Color("ff9d45")
	glow.omni_range=3.6
	glow.shadow_enabled=false
	add_child(glow)
	update_effect(0.0,false)

func update_effect(time: float, burning: bool) -> void:
	var phase:=fmod(time,4.6)
	var power:=0.0
	if burning:
		power=.72+.28*smoothstep(3.0,3.18,phase)
		power*=1.0-.25*smoothstep(4.4,4.6,phase)
	flame_material.set_shader_parameter("clock",time)
	flame_material.set_shader_parameter("strength",power)
	glow.light_energy=power*(1.0+sin(time*27)*.12)
	embers.visible=burning
	for i in 18:
		var age:=fmod(time*1.6+float(i)/18.0,1.0)
		var a:=i*2.39996
		var radius:=.12+age*.45
		var position:=Vector3(cos(a)*radius,.18+age*2.3,sin(a)*radius)
		var basis:=Basis.IDENTITY.scaled(Vector3.ONE*(1.0-age*.75))
		embers.multimesh.set_instance_transform(i,Transform3D(basis,position))
	# A brief residue dissipates after shutdown, never resembles active fire.
	var smoke_power:=power if burning else maxf(0.0,1.0-phase/.7)*.35
	for i in smoke.size():
		var age:=fmod(time*.55+i*.2,1.0)
		smoke[i].position=Vector3(sin(i*2.4+age)*.25,1.85+age*1.4,cos(i*2.4)*.17)
		smoke[i].scale=Vector3.ONE*(.35+age*.8)
		smoke[i].material_override.albedo_color.a=sin(age*PI)*smoke_power*.48
