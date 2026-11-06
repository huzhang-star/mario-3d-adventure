class_name IslandEnemy
extends CharacterBody3D
const S := preload("res://scripts/sculpt.gd")
signal stomped(world_position: Vector3)
var kind := "mushroom"
var start_position := Vector3.ZERO
var patrol_axis := Vector3.RIGHT
var patrol_distance := 1.2
var speed := 1.0
var direction := 1.0
var defeated := false
var visual: Node3D
var feet: Array[Node3D] = []
var arms: Array[Node3D] = []
var eyes: Array[Node3D] = []
var elapsed := 0.0
var gait_phase := 0.0
var glow: MeshInstance3D

func _ready() -> void:
	add_to_group("enemy")
	start_position = global_position
	floor_snap_length = .3
	_build_body()

func _physics_process(delta: float) -> void:
	if defeated: return
	elapsed += delta
	var offset := (global_position-start_position).dot(patrol_axis)
	if absf(offset) >= patrol_distance: direction = -signf(offset)
	var stride := speed
	var phase := fmod(elapsed,4.5)
	if kind == "golem": stride *= .62
	if kind == "clockwork" and fmod(elapsed,3.8) > 2.9: stride *= .08
	# Beetles signal their short rush by glowing antennae, then recover.
	if kind == "beetle":
		stride *= .12 if phase > 2.4 and phase < 3.2 else (2.1 if phase >= 3.2 and phase < 4.0 else 1.0)
		glow.visible = phase > 2.4 and phase < 4.0
	velocity.x = patrol_axis.x * stride * direction
	velocity.z = patrol_axis.z * stride * direction
	if not is_on_floor(): velocity.y -= 24*delta
	move_and_slide()
	if Vector2(velocity.x,velocity.z).length() > .05:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-velocity.x,-velocity.z),delta*7)
	gait_phase += Vector2(velocity.x,velocity.z).length()*delta*7
	visual.position.y = absf(sin(gait_phase))*.025
	for i in feet.size():
		feet[i].rotation.x = sin(gait_phase + i*PI)*.20
	for i in arms.size():
		arms[i].rotation.z = sin(gait_phase+i*PI)*.15
	var blink := .12 if fmod(elapsed+start_position.z*.1,3.8) > 3.64 else 1.0
	for eye in eyes: eye.scale.y = blink
	for i in get_slide_collision_count():
		var other = get_slide_collision(i).get_collider()
		if other is IslandPlayer and other.active and not defeated:
			if other.global_position.y > global_position.y + .95:
				squash()
				other.launch(8.5)
			else:
				other.take_damage(global_position)
	if global_position.y < -10: queue_free()

func squash() -> void:
	if defeated: return
	defeated = true
	remove_from_group("enemy")
	set_deferred("collision_layer",0)
	set_deferred("collision_mask",0)
	stomped.emit(global_position)
	var tween := create_tween()
	tween.tween_property(visual,"scale",Vector3(1.22,.25,1.22),.12)
	tween.tween_property(visual,"scale",Vector3.ONE*.01,.22)
	tween.tween_callback(queue_free)

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .55
	shape.height = 1.55
	collision.shape = shape
	collision.position.y = .78
	add_child(collision)
	visual = Node3D.new()
	visual.name = "SculptedCharacter"
	add_child(visual)
	var cream := S.material(Color("f4e8ce"),.7)
	var gold := S.material(Color("cfa969"),.32,.55)
	var ink := S.material(Color("203340"),.5)
	var earth := S.material(Color("694b42"),.8)
	match kind:
		"mushroom":
			# Bell-shaped cap, a pear-shaped stem, leaf collar and root boots.
			var stem := S.material(Color("e6c9a2"),.8)
			S.lathe(visual,Vector3.ZERO,[Vector2(0,.18),Vector2(.27,.18),Vector2(.43,.38),Vector2(.39,.80),Vector2(.29,1.13),Vector2(0,1.18)],stem)
			var cap := S.material(Color("bc5363"),.47)
			S.lathe(visual,Vector3.ZERO,[Vector2(0,1.09),Vector2(.54,1.09),Vector2(.80,1.16),Vector2(.88,1.29),Vector2(.75,1.51),Vector2(.45,1.76),Vector2(.13,1.83),Vector2(0,1.82)],cap)
			S.ring(visual,Vector3(0,1.18,0),.80,.045,cream)
			for i in 8:
				var angle := i*TAU/8
				S.orb(visual,Vector3(cos(angle)*.57,1.62,sin(angle)*.57),Vector3(.105,.025,.075),cream)
			S.orb(visual,Vector3(.08,1.815,-.06),Vector3(.15,.025,.11),cream)
			for side in [-1,1]:
				var leaf := S.orb(visual,Vector3(side*.32,.44,.05),Vector3(.28,.07,.15),S.material(Color("6d937b"),.8));leaf.rotation.z=side*.28
				add_foot(Vector3(side*.24,.12,0),Vector3(.18,.13,.25),earth)
			face(Vector3(0,.78,-.395),.96,ink,cream,false)
			S.orb(visual,Vector3(0,.53,-.36),Vector3(.06,.028,.025),earth)
		"beetle":
			# Low, six-legged beetle with split iridescent wing cases and a crest.
			var shell := S.material(Color("267f7b"),.23,.42)
			S.orb(visual,Vector3(0,.62,.12),Vector3(.62,.33,.74),ink)
			for side in [-1,1]:
				var wing := S.orb(visual,Vector3(side*.27,.90,.17),Vector3(.36,.44,.68),shell);wing.rotation.z=side*-.10
				for row in 3:
					var foot := add_foot(Vector3(side*.53,.19,(row-1)*.43),Vector3(.16,.09,.24),ink)
					S.orb(foot,Vector3(side*.07,.15,.04),Vector3(.095,.21,.10),gold)
					foot.rotation.y=side*(row-1)*.28
				for j in 3: S.orb(visual,Vector3(side*.43,1.02,(j-1)*.3+.15),Vector3(.035,.06,.06),gold)
			S.orb(visual,Vector3(0,.69,-.57),Vector3(.37,.31,.27),shell)
			face(Vector3(0,.81,-.855),.90,ink,cream,false)
			for side in [-1,1]:
				var antenna := S.cylinder(visual,Vector3(side*.22,1.19,-.57),.026,.42,gold);antenna.rotation.z=side*-.32
				S.orb(visual,Vector3(side*.29,1.41,-.57),Vector3(.075,.075,.075),cream)
			glow=S.orb(visual,Vector3(0,1.30,-.57),Vector3(.07,.09,.07),S.material(Color("ff8b66"),.3,0,1.5))
			S.box(visual,Vector3(0,1.315,.2),Vector3(.025,.025,.72),gold)
		"golem":
			# Chunky mineral guardian: faceted torso, broad stone arms, crystal core.
			var stone := S.material(Color("65758b"),.87)
			var crystal := S.material(Color("8bd3d4"),.25,.2,.18)
			S.cylinder(visual,Vector3(0,.81,0),.51,1.08,stone,.43,6)
			S.cylinder(visual,Vector3(0,1.32,-.02),.42,.46,stone,.34,7)
			for side in [-1,1]:
				add_foot(Vector3(side*.28,.14,0),Vector3(.25,.16,.30),stone)
				var arm := Node3D.new();arm.position=Vector3(side*.49,1.10,0);visual.add_child(arm);arms.append(arm)
				S.cylinder(arm,Vector3(side*.08,-.18,0),.23,.56,stone,.29,6)
				S.orb(arm,Vector3(side*.08,-.48,-.06),Vector3(.24,.20,.23),stone)
				S.cylinder(arm,Vector3(side*.07,.17,.02),.18,.43,crystal,0,5)
				S.box(visual,Vector3(side*.18,.65,-.455),Vector3(.018,.18,.026),gold)
			var core:=S.cylinder(visual,Vector3(0,.84,-.46),.22,.10,crystal,-1,6);core.rotation.x=PI*.5
			S.orb(visual,Vector3(0,.84,-.52),Vector3(.12,.14,.035),cream)
			for j in 3:
				var shard:=S.cylinder(visual,Vector3((j-1)*.22,1.68+(.12 if j==1 else 0),.08),.14,.51,crystal,0,5);shard.rotation.z=(j-1)*-.22
			face(Vector3(0,1.35,-.415),.93,ink,cream,true)
		"clockwork":
			# Round enamel automaton, riveted bezel, piston arms and winding key.
			var enamel := S.material(Color("4e858f"),.35,.22)
			S.cylinder(visual,Vector3(0,.80,0),.50,1.10,enamel,.48,48)
			for y in [.29,1.30]: S.ring(visual,Vector3(0,y,0),.49,.055,gold)
			var bezel:=S.ring(visual,Vector3(0,1.02,-.445),.36,.045,gold);bezel.rotation.x=PI*.5
			S.orb(visual,Vector3(0,1.02,-.46),Vector3(.33,.32,.035),ink)
			face(Vector3(0,1.06,-.53),.96,ink,cream,false)
			for i in 10:
				var a:=i*TAU/10
				S.orb(visual,Vector3(cos(a)*.42,1.02+sin(a)*.42,-.44),Vector3.ONE*.023,gold)
			for side in [-1,1]:
				add_foot(Vector3(side*.28,.13,-.04),Vector3(.20,.14,.29),ink)
				var arm := Node3D.new();arm.position=Vector3(side*.50,.98,0);visual.add_child(arm);arms.append(arm)
				S.orb(arm,Vector3.ZERO,Vector3.ONE*.13,gold)
				S.cylinder(arm,Vector3(side*.05,-.22,0),.075,.38,ink)
				for j in 4: S.ring(arm,Vector3(side*.05,-.12-j*.06,0),.09,.018,gold)
				S.orb(arm,Vector3(side*.05,-.47,-.02),Vector3(.15,.14,.15),enamel)
				var key:=S.ring(visual,Vector3(side*.16,1.23,.63),.17,.045,gold);key.rotation.x=PI*.5
			S.cylinder(visual,Vector3(0,1.49,0),.055,.29,gold)
			S.orb(visual,Vector3(0,1.66,0),Vector3.ONE*.10,S.material(Color("e6b573"),.3,0,.35))
			for i in 3: S.orb(visual,Vector3((i-1)*.12,.50,-.46),Vector3(.033,.033,.015),gold)

func add_foot(pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	var foot:=Node3D.new()
	foot.position=pos
	visual.add_child(foot)
	S.orb(foot,Vector3(0,0,-.03),size,mat)
	feet.append(foot)
	return foot

func face(pos: Vector3, factor: float, dark: Material, white: Material, mineral: bool) -> void:
	for side in [-1,1]:
		var eye:=Node3D.new();eye.position=pos+Vector3(side*.20*factor,0,0);visual.add_child(eye);eyes.append(eye)
		S.orb(eye,Vector3.ZERO,Vector3(.14,.17,.06)*factor,dark)
		S.orb(eye,Vector3(0,0,-.045)*factor,Vector3(.10,.135,.024)*factor,S.material(Color("bde8dd"),.35,0,.15) if mineral else white)
		S.orb(eye,Vector3(side*-.012,-.006,-.068)*factor,Vector3(.048,.084,.016)*factor,dark)
		S.orb(eye,Vector3(-.024,.037,-.083)*factor,Vector3.ONE*.017*factor,white)
		var brow:=S.orb(visual,pos+Vector3(side*.20,.195,-.01)*factor,Vector3(.12,.026,.025)*factor,dark)
		brow.rotation.z=side*.12
