extends Node3D
# A metre-scale articulated explorer. Feet use two-bone IK so the knees bend
# naturally and the boots meet the ground throughout the stance phase.
const S := preload("res://scripts/sculpt.gd")
const THIGH := .405
const SHIN := .385
var torso: Node3D
var head: Node3D
var pack: Node3D
var hips: MeshInstance3D
var legs: Array[Dictionary] = []
var arms: Array[Dictionary] = []
var eyes: Array[Node3D] = []
var phase := 0.0
var elapsed := 0.0
var motion_blend := 0.0
var air_blend := 0.0
var landing_blend := 0.0
var local_motion := Vector3.ZERO
var cloth: Material
var pants: Material
var skin: Material
var leather: Material
var pale: Material
var ink: Material

func _ready() -> void:
	name = "ArticulatedExplorer"
	cloth = S.material(Color("c85b3f"),.88)
	pants = S.material(Color("29394c"),.92)
	skin = S.material(Color("dca17a"),.68)
	leather = S.material(Color("594134"),.65)
	pale = S.material(Color("e8dfc8"),.78)
	ink = S.material(Color("202530"),.52)
	_build_torso()
	_build_head()
	for side in [-1.0,1.0]:
		_build_leg(side)
		_build_arm(side)
	update_pose(.016,Vector3.ZERO,true,0,false)

func capsule(parent: Node3D, center: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height,radius*2.0)
	mesh.radial_segments = 24
	mesh.rings = 10
	return S.mesh(parent,mesh,center,Vector3.ONE,material)

func bone(radius: float,length: float, material: Material) -> Node3D:
	var joint := Node3D.new()
	add_child(joint)
	capsule(joint,Vector3(0,-length*.5,0),radius,length+radius*.4,material)
	return joint

func _build_torso() -> void:
	hips = S.orb(self,Vector3(0,.87,0),Vector3(.205,.14,.125),pants)
	torso = Node3D.new()
	torso.position.y = .98
	add_child(torso)
	# Tailored jacket, inset T-shirt, collar, zip, piping, seams and pockets.
	S.orb(torso,Vector3(0,.235,0),Vector3(.238,.30,.14),cloth)
	S.orb(torso,Vector3(0,.04,0),Vector3(.205,.09,.132),cloth)
	S.orb(torso,Vector3(0,.34,.113),Vector3(.09,.135,.028),pale)
	for side in [-1,1]:
		var lapel := S.orb(torso,Vector3(side*.087,.343,.133),Vector3(.05,.125,.022),cloth)
		lapel.rotation.z = side*.27
		var seam := capsule(torso,Vector3(side*.17,.16,.104),.006,.18,leather)
		seam.rotation.z = side*-.25
		S.orb(torso,Vector3(side*.163,.13,.123),Vector3(.05,.017,.01),leather)
		var strap := capsule(torso,Vector3(side*.145,.27,.123),.018,.34,S.material(Color("405951"),.85))
		strap.rotation.z = side*.1
		S.box(torso,Vector3(side*.15,.22,.15),Vector3(.043,.05,.014),pale)
	capsule(torso,Vector3(0,.13,.14),.005,.25,S.material(Color("c9b191"),.45,.35))
	S.box(torso,Vector3(0,.26,.151),Vector3(.017,.029,.01),pale)
	capsule(torso,Vector3(0,.50,0),.06,.13,skin)
	S.orb(torso,Vector3(0,.40,-.10),Vector3(.18,.115,.12),cloth)
	# Small fabric backpack with a padded back, flap, straps and rolled mat.
	pack = Node3D.new()
	pack.position = Vector3(0,.25,-.19)
	torso.add_child(pack)
	var pack_mat := S.material(Color("426b65"),.9)
	S.orb(pack,Vector3.ZERO,Vector3(.18,.21,.09),pack_mat)
	S.orb(pack,Vector3(0,.12,-.03),Vector3(.185,.10,.085),S.material(Color("558278"),.87))
	for side in [-1,1]:
		capsule(pack,Vector3(side*.095,-.02,-.088),.013,.25,leather)
		S.box(pack,Vector3(side*.095,-.03,-.106),Vector3(.036,.044,.014),pale)
	var roll := capsule(pack,Vector3(0,-.19,-.02),.065,.36,pale)
	roll.rotation.z = PI*.5

func _build_head() -> void:
	head = Node3D.new()
	head.position = Vector3(0,.51,0)
	torso.add_child(head)
	# Human proportions: defined cheeks, jaw, ears, nose, brows and layered hair.
	S.orb(head,Vector3(0,.147,.012),Vector3(.137,.172,.125),skin)
	S.orb(head,Vector3(0,.045,.036),Vector3(.10,.072,.085),skin)
	var lip := S.material(Color("a26553"),.75)
	var hair := S.material(Color("3d2c28"),.82)
	for side in [-1,1]:
		S.orb(head,Vector3(side*.135,.13,0),Vector3(.026,.046,.021),skin)
		S.orb(head,Vector3(side*.144,.13,.012),Vector3(.01,.027,.009),lip)
		S.orb(head,Vector3(side*.065,.106,.112),Vector3(.038,.037,.016),skin)
		var eye := Node3D.new()
		eye.position = Vector3(side*.049,.162,.121)
		head.add_child(eye)
		S.orb(eye,Vector3.ZERO,Vector3(.027,.017,.011),pale)
		S.orb(eye,Vector3(0,0,.010),Vector3(.011,.013,.004),S.material(Color("526255"),.42))
		S.orb(eye,Vector3(0,0,.014),Vector3(.006,.009,.003),ink)
		S.orb(eye,Vector3(-.003,.005,.017),Vector3.ONE*.0025,pale)
		eyes.append(eye)
		var brow := S.orb(head,Vector3(side*.05,.194,.121),Vector3(.033,.007,.008),hair)
		brow.rotation.z = side*-.08
	S.orb(head,Vector3(0,.132,.139),Vector3(.019,.036,.024),skin)
	S.orb(head,Vector3(0,.108,.155),Vector3(.023,.017,.02),skin)
	S.orb(head,Vector3(0,.071,.124),Vector3(.03,.006,.009),lip)
	S.orb(head,Vector3(0,.062,.122),Vector3(.026,.005,.008),skin)
	S.orb(head,Vector3(0,.239,-.012),Vector3(.143,.102,.131),hair)
	for i in 6:
		var tuft := S.orb(head,Vector3((i-2.5)*.042,.24+sin(i*.6)*.034,.084),Vector3(.043,.06,.055),hair)
		tuft.rotation.z = -.42
	for side in [-1,1]:
		S.orb(head,Vector3(side*.121,.19,-.031),Vector3(.028,.086,.078),hair)

func _build_leg(side: float) -> void:
	var upper := bone(.088,THIGH,pants)
	var lower := bone(.067,SHIN,pants)
	var knee := S.orb(self,Vector3.ZERO,Vector3(.079,.085,.074),pants)
	var boot := Node3D.new()
	add_child(boot)
	S.orb(boot,Vector3(0,.006,.046),Vector3(.078,.064,.146),leather)
	S.orb(boot,Vector3(0,-.042,.046),Vector3(.082,.024,.148),ink)
	capsule(boot,Vector3(0,.067,-.026),.066,.15,leather)
	for i in 3:
		S.box(boot,Vector3(0,.062,.025+i*.028),Vector3(.083,.008,.012),pale)
	legs.append({"side":side,"upper":upper,"lower":lower,"knee":knee,"boot":boot})

func _build_arm(side: float) -> void:
	var upper := bone(.066,.245,cloth)
	var lower := bone(.052,.232,cloth)
	var elbow := S.orb(self,Vector3.ZERO,Vector3.ONE*.06,cloth)
	var hand := Node3D.new()
	add_child(hand)
	S.orb(hand,Vector3(0,-.031,0),Vector3(.039,.061,.025),skin)
	for finger in 4:
		capsule(hand,Vector3((finger-1.5)*.017,-.073,.004),.010,.060-absf(finger-1.4)*.008,skin)
	var thumb := capsule(hand,Vector3(-side*.043,-.028,.016),.013,.051,skin)
	thumb.rotation.z = side*-.42
	capsule(lower,Vector3(0,-.217,0),.055,.036,pale)
	arms.append({"side":side,"upper":upper,"lower":lower,"elbow":elbow,"hand":hand})

func place_bone(node: Node3D, from: Vector3, to: Vector3) -> void:
	node.position = from
	node.quaternion = Quaternion(Vector3.DOWN,(to-from).normalized())

func solve_leg(leg: Dictionary, hip: Vector3, foot: Vector3) -> void:
	var direction := foot-hip
	var distance := clampf(direction.length(),.15,THIGH+SHIN-.005)
	var axis := direction.normalized()
	var forward := Vector3.FORWARD*-1.0
	var bend := (forward-axis*forward.dot(axis)).normalized()
	var along := (THIGH*THIGH-SHIN*SHIN+distance*distance)/(2*distance)
	foot = hip+axis*distance
	var knee := hip+axis*along+bend*sqrt(maxf(0,THIGH*THIGH-along*along))
	place_bone(leg.upper,hip,knee)
	place_bone(leg.lower,knee,foot)
	leg.knee.position = knee
	leg.boot.position = foot

func update_pose(delta: float, velocity_local: Vector3, grounded: bool, vertical_speed: float, just_landed: bool) -> void:
	elapsed += delta
	var speed := Vector2(velocity_local.x,velocity_local.z).length()
	var smoothing := 1.0-exp(-delta*12.0)
	motion_blend = lerpf(motion_blend,clampf(speed/5.0,0,1),smoothing)
	local_motion = local_motion.lerp(velocity_local/7.0,smoothing)
	air_blend = lerpf(air_blend,0.0 if grounded else 1.0,1-exp(-delta*15))
	if just_landed: landing_blend = 1.0
	landing_blend = move_toward(landing_blend,0.0,delta*4.2)
	phase += delta * (5.0+speed*1.55) * motion_blend
	var bob := absf(sin(phase))*.024*motion_blend*(1-air_blend)
	var pelvis_y := .85+bob-motion_blend*.08-landing_blend*.09
	hips.position.y = pelvis_y
	torso.position.y = pelvis_y+.10
	torso.rotation = Vector3(local_motion.z*.08,-sin(phase)*.035*motion_blend,-local_motion.x*.08)
	torso.position.z = local_motion.z*.025
	torso.scale.y = 1.0+sin(elapsed*2.0)*.003*(1-motion_blend)
	head.rotation = Vector3(-air_blend*.06,local_motion.x*.24,sin(phase)*.012*motion_blend)
	pack.rotation.x = sin(phase*2)*.02*motion_blend
	for eye in eyes: eye.scale.y = .12 if fmod(elapsed,4.7)>4.57 else 1.0
	var movement := Vector3(local_motion.x,0,local_motion.z)
	if movement.length()>.01: movement=movement.normalized()
	for leg in legs:
		var side: float = leg.side
		var t := phase+(PI if side>0 else 0.0)
		var swing := -cos(t)*.30*motion_blend
		var lift := maxf(0,sin(t))*.16*motion_blend
		var foot := Vector3(side*.123,.067,0.02)+movement*swing
		foot.y += lift*(1-air_blend)
		foot.y += air_blend*(.15+(.11 if side>0 else 0))
		foot.z += air_blend*(.16 if side>0 else -.10)
		solve_leg(leg,Vector3(side*.12,pelvis_y,0),foot)
		leg.boot.rotation.x = -maxf(0,sin(t))*.20*motion_blend*(1-air_blend)+air_blend*.15
	for arm in arms:
		var side: float = arm.side
		var shoulder := Vector3(side*.235,pelvis_y+.465,0)
		var swing := -cos(phase+(PI if side<0 else 0.0))*.55*motion_blend
		var angle := swing*local_motion.z-.10-air_blend*.25
		var elbow := shoulder+Vector3(side*(.028+air_blend*.07),-.237*cos(angle),.237*sin(angle))
		var wrist := elbow+Vector3(side*.017,-.215*cos(angle+.35+motion_blend*.4),.215*sin(angle+.35+motion_blend*.4))
		place_bone(arm.upper,shoulder,elbow)
		place_bone(arm.lower,elbow,wrist)
		arm.elbow.position = elbow
		arm.hand.position = wrist
		arm.hand.rotation.x = -angle*.4
