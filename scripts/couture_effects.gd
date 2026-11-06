extends RefCounted
const G=preload("res://scripts/couture_geometry.gd")

# Bounded mesh effects: deterministic in the showroom and independent of physics.
# All children are owned by SkinAccessories, so a skin swap clears them atomically.
static func floater(root: Node3D, kind: String, pos: Vector3, phase: float) -> Node3D:
	var node:=Node3D.new()
	node.name="CoutureFX"+kind+str(root.get_child_count())
	node.position=pos
	node.set_meta("fx_kind",kind)
	node.set_meta("origin",pos)
	node.set_meta("phase",phase)
	root.add_child(node)
	return node

static func build(root: Node3D, data: Dictionary) -> void:
	var kind: String={"rose_seraph":"petal","moon_empress":"moon","glass_butterfly":"butterfly","phoenix":"ember","ocean_pearl":"bubble","sakura_deity":"sakura","star_weaver":"star","platinum_dragon":"rune","jade_peacock":"jade","eternal_dawn":"dawn"}.get(data.id,"star")
	var color:=Color(data.accent)
	var mat:=G.satin(color,.2,.48)
	var petal_mat:=G.satin(Color(data.color).lightened(.23))
	for i in 8:
		var a:=TAU*i/8+.31
		var radius:=.39+(i%3)*.052
		# Face clearance: effects stay beside/below the cheeks, never in front of eyes.
		var origin:=Vector3(cos(a)*radius,.06+(i%4)*.13,sin(a)*radius*.62-.03)
		if absf(origin.x)<.29 and origin.y>.32: origin.z=-.31
		var node:=floater(root,kind,origin,i*.79)
		match kind:
			"petal","sakura":
				G.petal(node,Vector3(0,-.016,0),Vector3(0,.020,0),.012,petal_mat,.005)
			"bubble":
				G.orb(node,Vector3.ZERO,Vector3.ONE*(.022+(i%3)*.011),G.bubble(color))
			"butterfly":
				for side in [-1,1]: G.petal(node,Vector3.ZERO,Vector3(side*.030,.024,0),.014,petal_mat,.004)
			"ember":
				G.petal(node,Vector3(0,-.015,0),Vector3(0,.025,0),.010,mat,.002)
			"rune":
				var points:=PackedVector3Array([Vector3(0,.020,0),Vector3(.014,0,0),Vector3(0,-.020,0),Vector3(-.014,0,0),Vector3(0,.020,0)])
				G.tube(node,points,.0025,mat)
			"jade":
				G.petal(node,Vector3(0,-.023,0),Vector3(0,.023,0),.007,petal_mat,.005)
			"dawn":
				G.gem(node,Vector3.ZERO,.012,G.opal(Color(data.get("opal","9ce8df"))))
				if i%3==0: G.star(node,Vector3(0,.022,0),.013,mat)
			_:
				G.star(node,Vector3.ZERO,.015 if i%2 else .021,mat)
