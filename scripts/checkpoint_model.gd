extends Node3D

const S := preload("res://scripts/sculpt.gd")
const G := preload("res://scripts/couture_geometry.gd")
var flag_material: ShaderMaterial
var lens_material: StandardMaterial3D
var rim_material: StandardMaterial3D
var ripple_material: ShaderMaterial
var lamp: OmniLight3D
var activation_time := -1.0
var light_amount := 0.0

func _ready() -> void:
	name = "CheckpointModel"
	var brass := S.material(Color("c7a468"),.37,.65)
	var ivory := S.material(Color("e9e3cf"),.58,.12)
	var stone := S.material(Color("738c86"),.8)
	var dark := S.material(Color("445b58"),.6,.3)
	# Rounded stone plinth, inset metal footing and a socket around the mast.
	S.lathe(self,Vector3.ZERO,[Vector2(0,.015),Vector2(.56,.015),Vector2(.65,.045),Vector2(.66,.10),Vector2(.61,.16),Vector2(.48,.18),Vector2(0,.18)],stone)
	S.ring(self,Vector3(0,.151,0),.57,.018,brass)
	S.lathe(self,Vector3.ZERO,[Vector2(0,.17),Vector2(.24,.17),Vector2(.24,.22),Vector2(.17,.25),Vector2(.12,.39),Vector2(.07,.41),Vector2(0,.41)],dark)
	for i in 6:
		var a := TAU*i/6.0
		S.cylinder(self,Vector3(cos(a)*.39,.188,sin(a)*.39),.034,.025,brass,-1,8)
	rim_material = S.material(Color("679789"),.32,.3,.02)
	S.ring(self,Vector3(0,.18,0),.48,.022,rim_material)
	S.cylinder(self,Vector3(0,1.1,0),.043,1.55,ivory)
	for y in [.40,1.26,1.82]:
		S.cylinder(self,Vector3(0,y,0),.065,.063,brass)
	# A small caged jade lens is physically supported by the mast cap.
	S.lathe(self,Vector3(0,1.86,0),[Vector2(0,0),Vector2(.16,0),Vector2(.20,.05),Vector2(.17,.10),Vector2(0,.10)],brass)
	lens_material = S.material(Color("82b7a3"),.20,.14,.05)
	S.orb(self,Vector3(0,2.09,0),Vector3(.145,.20,.145),lens_material).name = "SignalLens"
	for i in 4:
		var a := TAU*i/4.0+PI*.25
		G.curve(self,Vector3(cos(a)*.17,1.92,sin(a)*.17),Vector3(cos(a)*.205,2.10,sin(a)*.205),Vector3(cos(a)*.09,2.29,sin(a)*.09),.013,brass)
	S.lathe(self,Vector3(0,2.27,0),[Vector2(0,0),Vector2(.12,0),Vector2(.14,.025),Vector2(.10,.06),Vector2(0,.08)],brass)
	S.orb(self,Vector3(0,2.36,0),Vector3.ONE*.04,brass)
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0,2.08,0)
	lamp.light_color = Color("bcf9cc")
	lamp.omni_range = 2.4
	lamp.shadow_enabled = false
	add_child(lamp)
	build_flag()
	build_ripple()
	update_effect(0,false)

func build_flag() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
uniform float activation = 0.0;
void vertex(){
 float u=UV.x, v=UV.y;
 float a=u*7.8-clock*3.0+v*1.5;
 float b=u*14.0-clock*4.3-v*2.0;
 float wave=sin(a)*.073+sin(b)*.020;
 VERTEX.z += u*u*wave;
 VERTEX.y -= .055*u*u;
 float dx=(2.0*u*wave+u*u*(cos(a)*.5694+cos(b)*.28))/.84;
 float dy=u*u*(cos(a)*.1095-cos(b)*.04)/(-.54);
 NORMAL=normalize(vec3(-dx,-dy,1.0));
}
void fragment(){
 float weave=(sin(UV.x*480.0)*sin(UV.y*340.0))*.013;
 vec3 cloth=mix(vec3(.14,.37,.29),vec3(.17,.54,.37),activation);
 float border=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float hem=1.0-smoothstep(.023,.035,border);
 float diamond=abs((UV.x-.51)*1.15)+abs(UV.y-.49);
 float emblem=1.0-smoothstep(.155,.17,diamond);
 float inset=1.0-smoothstep(.075,.085,diamond);
 vec3 color=mix(cloth,vec3(.87,.78,.52),hem);
 color=mix(color,vec3(.94,.88,.66),emblem*(1.0-inset*.8));
 ALBEDO=color+weave;
 ROUGHNESS=.83;
}"""
	flag_material = ShaderMaterial.new()
	flag_material.shader = shader
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 32:
		for y in 16:
			for corner in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
				var uv := Vector2(corner.x/32.0,corner.y/16.0)
				var notch := .07*pow(uv.x,8)*(1.0-absf(uv.y*2.0-1.0))
				surface.set_normal(Vector3.BACK)
				surface.set_uv(uv)
				surface.add_vertex(Vector3(uv.x*.84-notch,-uv.y*.54,0))
	var flag := S.mesh(self,surface.commit(),Vector3(.055,1.81,0),Vector3.ONE,flag_material)
	flag.name = "WovenFlag"
	flag.extra_cull_margin = .14
	# Cloth's pinned edge meets both metal collars, including from behind.
	var tie := S.material(Color("d8c995"),.74)
	for y in [1.30,1.78]:
		var knot := S.ring(self,Vector3(0,y,0),.047,.009,tie)
		knot.scale.x = 1.35

func build_ripple() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age = 2.0;
void fragment(){
 float r=length(UV-.5)*2.0;
 float front=.35+age*.56;
 float ring=1.0-smoothstep(.014,.053,abs(r-front));
 float fade=(1.0-smoothstep(.5,1.25,age))*smoothstep(.0,.12,age);
 ALBEDO=vec3(.66,.94,.76);
 EMISSION=vec3(.10,.16,.10);
 ALPHA=ring*fade*.5;
}"""
	ripple_material = ShaderMaterial.new()
	ripple_material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.8,2.8)
	var ripple := S.mesh(self,plane,Vector3(0,.025,0),Vector3.ONE,ripple_material)
	ripple.name = "ActivationRipple"
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_effect(time: float, active: bool) -> void:
	if active and activation_time < 0: activation_time = time
	if not active: activation_time = -1.0
	var age := time-activation_time if active else 2.0
	light_amount = smoothstep(0.0,.6,age) if active else 0.0
	flag_material.set_shader_parameter("clock",time)
	flag_material.set_shader_parameter("activation",light_amount)
	ripple_material.set_shader_parameter("age",age)
	lens_material.emission_energy_multiplier = .05+light_amount*.85
	rim_material.emission_energy_multiplier = .02+light_amount*.6
	lamp.light_energy = light_amount*.55
