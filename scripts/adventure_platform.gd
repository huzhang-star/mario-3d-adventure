extends AnimatableBody3D
const S := preload("res://scripts/sculpt.gd")
var kind := "normal"
var origin := Vector3.ZERO
var travel := Vector3.ZERO
var period := 4.5
var elapsed := 0.0
var size := Vector3(5, .7, 5)
var visual: Node3D
var collider: CollisionShape3D
var crumble_delay := .95
var collapse_clock := -1.0
var game: Node3D

func _ready() -> void:
	origin = position
	sync_to_physics = true
	add_to_group("course_surface")
	if kind == "ice": add_to_group("ice")

func setup(top_color: Color, edge_color: Color, base_color: Color, round_shape := false) -> void:
	visual = Node3D.new()
	add_child(visual)
	var top_mat := S.material(top_color, 0.22 if kind == "ice" else 0.72)
	var trim := S.material(edge_color, 0.45, 0.15)
	var rock := S.material(base_color, .88)
	# Top surface is exactly local y = 0 for geometry and collision.
	if round_shape:
		S.cylinder(visual, Vector3(0,-.22,0),size.x*.49,.34,trim,size.x*.47,48)
		S.cylinder(visual, Vector3(0,-.025,0),size.x*.455,.05,top_mat,-1,48)
		S.cylinder(visual, Vector3(0,-1.02,0),size.x*.29,1.4,rock,size.x*.44,12)
	else:
		S.box(visual,Vector3(0,-.36,0),Vector3(size.x,.6,size.z),trim)
		S.box(visual,Vector3(0,-.025,0),Vector3(size.x-.22,.05,size.z-.22),top_mat)
		S.box(visual,Vector3(0,-.8,0),Vector3(size.x*.9,.45,size.z*.9),rock)
		for x in [-1,1]:
			for z in [-1,1]:
				S.orb(visual,Vector3(x*(size.x*.5-.15),-.18,z*(size.z*.5-.15)),Vector3.ONE*.16,trim)
	collider = CollisionShape3D.new()
	if round_shape:
		var shape := CylinderShape3D.new()
		shape.radius = size.x*.47
		shape.height = .6
		collider.shape = shape
	else:
		var shape := BoxShape3D.new()
		shape.size = Vector3(size.x-.12,.6,size.z-.12)
		collider.shape = shape
	collider.position.y = -.3
	add_child(collider)
	if kind == "crumble":
		for i in 3:
			var crack := S.box(visual,Vector3((i-1)*.65,.015,0),Vector3(.055,.02,size.z*.7),rock)
			crack.rotation.y = .3 if i%2==0 else -.4
	if kind in ["ferry", "lift"]:
		S.ring(visual,Vector3(0,-.55,0),size.x*.37,.08,S.material(edge_color,.25,.3,.45))
	if kind == "belt":
		for i in 5:
			S.box(visual,Vector3(0,.014,(i-2)*size.z/6.0),Vector3(size.x*.8,.03,.065),rock)
		var label := Label3D.new()
		label.text = "→ → →"
		label.font_size = 80
		label.pixel_size = .013
		label.rotation_degrees.x = -90
		label.position.y = .05
		add_child(label)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if travel.length_squared() > 0:
		position = origin + travel * (sin(elapsed * TAU / period - PI*.5)+1)*.5
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	var p = game.player
	var standing: bool = p.is_on_floor() and absf(p.position.x-position.x)<size.x*.5 and absf(p.position.z-position.z)<size.z*.5 and absf(p.position.y-position.y)<.25
	if kind == "crumble":
		if standing and collapse_clock < 0: collapse_clock = 0
		if collapse_clock >= 0:
			collapse_clock += delta
			if collapse_clock < crumble_delay:
				visual.position.x = sin(collapse_clock*65)*.045
			elif collapse_clock < 3.8:
				collider.set_deferred("disabled", true)
				visual.position.y = -minf((collapse_clock-crumble_delay)*7,12)
				visual.visible = collapse_clock < 2.4
			else:
				visual.position = Vector3.ZERO
				visual.visible = true
				collider.set_deferred("disabled", false)
				collapse_clock = -1
	if kind == "belt" and standing and p.active:
		p.external_drift += Vector3(1.6,0,0)
