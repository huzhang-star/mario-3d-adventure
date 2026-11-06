extends RefCounted
const S := preload("res://scripts/sculpt.gd")
const ROUND_THEMES := ["orchard","mushroom","ice","cloud","crystal","astral","coral","honey","lotus","biolume","jellyfish","meteor","aurora","solar","crown"]
const PLATFORM := preload("res://scripts/adventure_platform.gd")
const ITEM := preload("res://scripts/adventure_item.gd")
const LANDMARKS := preload("res://scripts/world_landmarks.gd")
const HAZARD := preload("res://scripts/adventure_hazard.gd")
const POLISH := preload("res://scripts/world_polish.gd")

static func point(data: Array) -> Vector3:
	return Vector3(data[0],data[1],data[2])

static func heading(from: Vector3, to: Vector3) -> float:
	return atan2(to.x-from.x,to.z-from.z)

static func build(game: Node3D, config: Dictionary) -> void:
	var route: Array = config.route
	var theme: String = config.theme
	var palette: Array = config.palette
	var top := Color(palette[0])
	var trim := Color(palette[1])
	var rock := Color(palette[2])
	var accent := Color(palette[5])
	game.stage_spawn = point(route[0]) + Vector3(0,.12,1)
	game.stage_spawn_yaw = heading(point(route[0]),point(route[1]))
	game.stage_goal = point(route[-1])
	game.required_keys = config.key_nodes.size()
	var round_shape := theme in ROUND_THEMES
	for i in route.size():
		var pos := point(route[i])
		var kind: String = config.features.get(str(i),"normal")
		var width: float = config.width
		if i == 0 or i == route.size()-1: width += 2.4
		elif i == int(config.checkpoint): width += 1.0
		var platform = PLATFORM.new()
		platform.name = "Route_%02d" % i
		platform.position = pos
		platform.size = Vector3(width,.7,width)
		platform.kind = kind
		platform.game = game
		if kind == "ferry": platform.travel = Vector3(1.4,0,0)
		if kind == "lift": platform.travel = Vector3(0,2.6,0)
		platform.period = float(config.get("moving_period",4.8)) + (.7 if kind=="lift" else 0.0)
		platform.crumble_delay = float(config.get("crumble_delay",.95))
		game.add_child(platform)
		platform.setup(top,trim,rock,round_shape)
		if int(config.difficulty)>6: POLISH.platform_detail(platform,theme,width,accent,round_shape)
		game.route_surfaces.append(platform)
		if i > 0 and i < route.size()-1:
			game._spawn_coin(Vector3(-.6,1.2,0),platform)
			if not i in config.spring_nodes: game._spawn_coin(Vector3(.6,1.2,0),platform)
		if kind in ["fire","wind"]:
			var hazard = HAZARD.new()
			hazard.kind = kind
			hazard.platform_width = width
			hazard.rate = float(config.get("hazard_rate",1.0))
			hazard.position.x = -.8 if kind == "fire" else 0.0
			platform.add_child(hazard)
		if i in config.spring_nodes: item(platform,game,"spring",Vector3.ZERO)
		if i in config.key_nodes: item(platform,game,"key",Vector3(1.0,1.1,0))
		if i == int(config.checkpoint):
			var checkpoint = item(platform,game,"checkpoint",Vector3(0,0,.7))
			checkpoint.checkpoint_yaw = heading(pos,point(route[mini(i+1,route.size()-1)]))
		if i in config.enemy_nodes:
			var enemy := IslandEnemy.new()
			enemy.kind = enemy_kind(theme,i)
			enemy.position = pos + Vector3(0,.15,-.6)
			enemy.speed = float(config.get("enemy_speed",1.0))
			enemy.patrol_distance = width*.23
			enemy.stomped.connect(game._on_enemy_stomped)
			game.add_child(enemy)
		# Edge details leave the centre and jump approach clear.
		if i%2==0 and kind == "normal":
			if int(config.difficulty)>6: POLISH.edge_detail(platform,theme,width,accent,i,round_shape)
			else: edge_details(platform,theme,width,accent,i)
		if i < route.size()-1:
			var direction := point(route[i+1])-pos
			var marker := Node3D.new()
			platform.add_child(marker)
			marker.rotation.y = heading(pos,point(route[i+1]))
			var mat := S.material(trim,.5,0,.08)
			for side in [-1,1]:
				var arrow := S.box(marker,Vector3(side*.16,.028,1.0),Vector3(.07,.025,.46),mat)
				arrow.rotation.y = side*-.7
	# Three optional side excursions, placed on the open side of the route.
	var used_sources: Array[int] = []
	for fraction in [.22,.52,.78]:
		var preferred := clampi(int(route.size()*fraction),1,route.size()-2)
		var index := preferred
		var best := Vector3.ZERO
		var best_score := -INF
		for offset in [0,-1,1,2]:
			var source := clampi(preferred+offset,1,route.size()-2)
			if source in used_sources or source in config.spring_nodes: continue
			if config.features.get(str(source),"normal") in ["lift","ferry"]: continue
			var base := point(route[source])
			var distance: float = config.width*.5+2.6
			for angle_index in 16:
				var angle := angle_index*TAU/16
				var candidate := base+Vector3(cos(angle),0,sin(angle))*distance
				var clearance := INF
				for j in route.size():
					if j == source: continue
					clearance = minf(clearance,Vector2(candidate.x-point(route[j]).x,candidate.z-point(route[j]).z).length())
				var score := minf(clearance,8.0)-absf(offset)*.25
				if score > best_score:
					best_score = score
					best = candidate
					index = source
		used_sources.append(index)
		var bonus = PLATFORM.new()
		bonus.position = best+Vector3.UP*.15
		bonus.size = Vector3(3.6,.7,3.6)
		bonus.game = game
		bonus.set_meta("source_index", index)
		bonus.add_to_group("bonus_surface")
		game.add_child(bonus)
		bonus.setup(top.lightened(.1),accent,rock,true)
		if int(config.difficulty)>6: POLISH.platform_detail(bonus,theme,3.6,accent,true)
		item(bonus,game,"star",Vector3(0,1.65,0))
		game._spawn_coin(Vector3(0,1.0,.8),bonus)
	game._make_goal(game.stage_goal)
	landscape(game,config)

static func item(parent: Node3D, game: Node3D, kind: String, pos: Vector3) -> Area3D:
	var obj = ITEM.new()
	obj.kind = kind
	obj.game = game
	obj.position = pos
	parent.add_child(obj)
	return obj

static func enemy_kind(theme: String, i: int) -> String:
	match theme:
		"orchard","mushroom": return "mushroom"
		"coast","bamboo","storm": return "beetle"
		"desert","ice","crystal": return "golem"
		"forge","clock","cloud": return "clockwork"
	return ["mushroom","beetle","golem","clockwork"][i%4]

static func edge_details(parent: Node3D, theme: String, width: float, accent: Color, seed_value: int) -> void:
	var gold := S.material(accent,.35,.35)
	var dark := S.material(Color("394654"),.65)
	var edge := width*(.29 if theme in ROUND_THEMES else .42)
	if theme in ["coast","forge","clock","storm"]:
		for z in [-edge,edge]:
			S.cylinder(parent,Vector3(edge,.35,z),.085,.7,gold)
			S.orb(parent,Vector3(edge,.72,z),Vector3.ONE*.13,gold)
			if theme == "coast": S.cylinder(parent,Vector3(edge,-1.6,z),.16,2.5,dark)
	elif theme in ["ice","crystal","astral"]:
		for j in 3:
			var crystal := S.cylinder(parent,Vector3(edge-.2*j,.35+j*.15,-edge),.16,.8+j*.3,gold,0,5)
			crystal.rotation.z = -.22+j*.2
	else:
		for j in 4:
			var pos := Vector3(edge-.22*j,.12,-edge+.12*sin(j+seed_value))
			S.orb(parent,pos,Vector3(.1,.18,.1),S.material(Color("58a97d")))
			S.orb(parent,pos+Vector3.UP*.19,Vector3.ONE*.12,gold)

static func landscape(game: Node3D, config: Dictionary) -> void:
	var theme: String = config.theme
	var route: Array = config.route
	var cream := S.material(Color("fff1d0"),.58)
	var accent := S.material(Color(config.palette[5]),.38,.2,.25)
	var base := S.material(Color(config.palette[2]),.8)
	var color := S.material(Color(config.palette[0]),.6)
	var trim := S.material(Color(config.palette[1]),.42,.25)
	var center := Vector3.ZERO
	for pos in route: center += point(pos)
	center /= route.size()
	var decor := Node3D.new()
	decor.name = "Scenery_"+theme
	game.add_child(decor)
	var background: Array[Node3D] = []
	# Build first so placement includes each finished model's full footprint.
	for i in 10:
		var prop := Node3D.new()
		prop.name = "Landmark_%02d" % i
		prop.position.y = center.y - 1.5
		decor.add_child(prop)
		background.append(prop)
		match theme:
			"orchard":
				S.cylinder(prop,Vector3(0,-.6,0),3.1,1.2,base,3.8,16)
				S.cylinder(prop,Vector3.ZERO,3.8,.25,color)
				tree(prop,Vector3.ZERO,1.0+(i%3)*.25,cream,accent)
				for j in 4: flower(prop,Vector3(cos(j*1.7)*2.6,.15,sin(j*1.7)*2.6),accent,cream)
			"mushroom":
				S.cylinder(prop,Vector3(0,-.6,0),2.4,1.2,base,3.2)
				for j in 3:
					mushroom(prop,Vector3((j-1)*2,0,j*.6),2.0+j*.65,accent if j%2==0 else trim,cream)
			"coast":
				S.cylinder(prop,Vector3(0,-1,0),3.2,1.5,base)
				if i%3==0:
					S.cylinder(prop,Vector3(0,3,0),1.05,6,cream,.8)
					for y in [1.8,3.8]: S.cylinder(prop,Vector3(0,y,0),1.02,.5,accent)
					S.cylinder(prop,Vector3(0,6.2,0),1.5,.2,trim)
					S.orb(prop,Vector3(0,6.8,0),Vector3(.6,.65,.6),accent)
					S.cylinder(prop,Vector3(0,7.5,0),1.2,.8,trim,0)
				else:
					S.box(prop,Vector3(0,.2,0),Vector3(3,.6,1.5),accent)
					S.cylinder(prop,Vector3(0,2,0),.06,3.6,cream)
					var sail := S.box(prop,Vector3(.6,2.5,0),Vector3(1.2,1.8,.05),cream)
					sail.rotation.z = -.14
			"desert":
				for tier in 5:
					S.box(prop,Vector3(0,tier*.65,0),Vector3(6-tier,.65,6-tier),trim if tier%2==0 else color)
				S.cylinder(prop,Vector3(0,4,0),.8,2,accent,0,4)
				for x in [-3.8,3.8]: pillar(prop,Vector3(x,0,0),3.4,cream,accent)
			"ice":
				S.cylinder(prop,Vector3(0,-.5,0),2.5,1.0,trim,3.5,7)
				for j in 4:
					S.cylinder(prop,Vector3((j-1.5)*.8,1.0+j*.6,0),.6,2.6+j,cream if j%2==0 else accent,0,5)
				pine(prop,Vector3(2,0,1),3.5,color,cream)
			"forge":
				S.cylinder(prop,Vector3(0,1,0),2.5,3,base)
				S.ring(prop,Vector3(0,2.4,0),2.5,.12,accent)
				for j in 3:
					S.cylinder(prop,Vector3((j-1)*1.4,3.5+j*.5,0),.44,4+j,trim)
					S.ring(prop,Vector3((j-1)*1.4,5.5+j,0),.48,.1,accent)
				gear(prop,Vector3(0,2,2.6),1.5,accent)
			"cloud":
				for j in 4: S.orb(prop,Vector3((j-1.5)*1.7,0,0),Vector3(2,1.0,1.7),cream)
				pillar(prop,Vector3.ZERO,3.0,cream,trim)
				S.box(prop,Vector3(0,3.1,0),Vector3(2.6,1.3,1.7),accent)
				S.box(prop,Vector3(0,3.25,.9),Vector3(1.5,.14,.08),base)
				S.cylinder(prop,Vector3(0,4.4,0),1.9,1.3,trim,0,4)
				var hoop := S.ring(prop,Vector3(0,6.5,0),1.4,.1,accent)
				hoop.rotation.x = PI*.5
			"bamboo":
				S.cylinder(prop,Vector3(0,-.5,0),3,1,base)
				for j in 5:
					var x := (j-2)*.85
					S.cylinder(prop,Vector3(x,3+j*.2,0),.14,6+j*.4,color)
					for k in 5:
						S.ring(prop,Vector3(x,k*1.1+.5,0),.16,.025,trim)
						var leaf := S.orb(prop,Vector3(x+.35,k*1.1+.7,.1),Vector3(.65,.055,.2),color)
						leaf.rotation.z = .45
				S.cylinder(prop,Vector3(0,3,1.5),.65,1.0,accent)
				S.ring(prop,Vector3(0,3.5,1.5),.65,.08,trim)
				S.ring(prop,Vector3(0,2.5,1.5),.65,.08,trim)
			"clock":
				S.box(prop,Vector3(0,3,0),Vector3(3.6,8,3),base)
				for y in [0,2,4,6,7]: S.box(prop,Vector3(0,y,0),Vector3(4,.15,3.4),trim)
				gear(prop,Vector3(0,5,1.7),1.6,accent)
				var face := S.cylinder(prop,Vector3(0,5,1.75),1.24,.12,cream)
				face.rotation.x = PI*.5
				var hand := S.box(prop,Vector3(.3,5.3,1.85),Vector3(.08,1.1,.09),base)
				hand.rotation.z = -.7
				S.box(prop,Vector3(-.32,5,1.87),Vector3(.75,.07,.09),base)
				S.cylinder(prop,Vector3(0,8,0),3,2,trim,0,4)
			"crystal":
				for j in 5:
					var shard := S.cylinder(prop,Vector3((j-2)*1.4,1.3+sin(j)*1.5,0),1.0,5+j*.4,accent if j%2==0 else trim,0,6)
					shard.rotation.z = (j-2)*.16
				S.cylinder(prop,Vector3(0,-1,0),4,2,base,3,7)
			"storm":
				for j in 4: S.orb(prop,Vector3((j-1.5)*1.5,5+sin(j),0),Vector3(2.2,1.4,1.8),base)
				for j in 7:
					var rain := S.box(prop,Vector3((j-3)*.7,2.3+sin(j)*1.5,.2),Vector3(.025,.8,.025),trim)
					rain.rotation.z = -.22
				if i%3==0:
					for j in 3:
						var bolt := S.box(prop,Vector3(.2*(j%2),3-j,.5),Vector3(.12,1.25,.12),accent)
						bolt.rotation.z = .4 if j%2==0 else -.4
			"astral":
				S.orb(prop,Vector3(0,3,0),Vector3.ONE*(1.5+i%3*.4),color if i%2==0 else trim)
				var ring := S.ring(prop,Vector3(0,3,0),3,.12,accent)
				ring.rotation.z = .35+i*.1
				S.orb(prop,Vector3(3,3,0),Vector3.ONE*.3,cream)
			_:
				LANDMARKS.build(prop,theme,i,base,color,trim,accent,cream)
		if int(config.difficulty)>6:
			POLISH.landmark_detail(prop,theme,trim,cream,accent)
			POLISH.refine(prop,theme)
		ground_landmark(prop)
	if theme in ["orchard","mushroom","coast","cloud","ice"]:
		for i in 7:
			var bank := Node3D.new()
			bank.name = "CloudBank_%02d" % i
			bank.position.y = center.y + 9 + (i%3)*3
			decor.add_child(bank)
			background.append(bank)
			for j in 4:
				S.orb(bank,Vector3((j-1.5)*2,absf(sin(j))*.6,0),Vector3(2.4,1.0,1.5),cream)
	place_background(game, background, center)
	# The finish has a theme-coloured arch and a clear beacon.
	var finish := point(route[-1])
	for x in [-2.1,2.1]: pillar(decor,finish+Vector3(x,0,-1.1),3.7,trim,accent)
	S.box(decor,finish+Vector3(0,3.7,-1.1),Vector3(4.8,.24,.5),accent)

static func place_background(game: Node3D, background: Array[Node3D], center: Vector3) -> void:
	var origin := Vector2(center.x, center.z)
	var playable_radius := 0.0
	# Include bonus islands, wider start/finish floors, and moving-platform travel.
	# The circle also contains the straight jump paths between these surfaces.
	for surface in game.get_tree().get_nodes_in_group("course_surface"):
		if not game.is_ancestor_of(surface): continue
		var offset := Vector2(surface.position.x, surface.position.z) - origin
		var half_size := Vector2(surface.size.x, surface.size.z) * 0.5
		var travel := Vector2(surface.travel.x, surface.travel.z)
		playable_radius = maxf(playable_radius, maxf(offset.length(), (offset+travel).length()) + half_size.length())
	var largest_footprint := 0.0
	for prop in background:
		for part: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			var relative := prop.global_transform.affine_inverse() * part.global_transform
			var bounds := part.get_aabb()
			for corner in 8:
				var vertex := relative * bounds.get_endpoint(corner)
				largest_footprint = maxf(largest_footprint, Vector2(vertex.x, vertex.z).length())
	# Reserve the entire camera orbit, not only the floor, so scenery stays
	# behind the camera or beyond the route instead of between camera and player.
	var radius: float = playable_radius + game.CAMERA_MAX_DISTANCE + 4.0 + largest_footprint
	# Equal angles prevent long routes from bunching buildings at either end.
	# Enforce a six-unit gap even for large models or short routes.
	radius = maxf(radius, (2.0*largest_footprint + 6.0)/(2.0*sin(PI/background.size())))
	var spawn_offset: Vector3 = game.stage_spawn - center
	var start_angle := atan2(spawn_offset.z, spawn_offset.x) + PI/background.size()
	for i in background.size():
		var angle := start_angle + i*TAU/background.size()
		background[i].position.x = center.x + cos(angle)*radius
		background[i].position.z = center.z + sin(angle)*radius
		background[i].add_to_group("background_scenery")

static func pillar(parent: Node3D, pos: Vector3, height: float, mat: Material, trim: Material) -> void:
	S.cylinder(parent,pos+Vector3.UP*height*.5,.28,height,mat)
	for y in [0.12,height-.12]: S.cylinder(parent,pos+Vector3.UP*y,.48,.24,trim)

static func ground_landmark(root: Node3D) -> void:
	# Landmark meshes are authored with different local origins. Move only the
	# body (never its shared plinth) until its lowest visible point meets the
	# plinth top at local y = -0.05.
	var lowest := INF
	var anchors: Array[Node3D] = []
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var part := mesh as MeshInstance3D
		if not part or not part.mesh:
			continue
		var anchor := part as Node3D
		var under_plinth := false
		while anchor.get_parent() and anchor.get_parent() != root:
			anchor = anchor.get_parent() as Node3D
			if anchor.name == "LandmarkPlinth":
				under_plinth = true
				break
		if under_plinth or anchor.name == "LandmarkPlinth":
			continue
		if not anchors.has(anchor):
			anchors.append(anchor)
		var local_from_mesh := root.global_transform.affine_inverse() * part.global_transform
		var bounds := part.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					lowest = minf(lowest, (local_from_mesh * Vector3(x,y,z)).y)
	if lowest == INF:
		return
	var lift := maxf(0.0, -0.05 - lowest)
	if lift <= 0.001:
		return
	for anchor in anchors:
		anchor.position.y += lift

static func tree(parent: Node3D, pos: Vector3, factor: float, cream: Material, fruit: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE*factor
	parent.add_child(root)
	S.cylinder(root,Vector3(0,1.2,0),.25,2.4,S.material(Color("805b48")),.15)
	var leaves := S.material(Color("61ad7a"),.85)
	for j in 5:
		var angle := j*TAU/5
		S.orb(root,Vector3(cos(angle)*.8,2.7+sin(j)*.4,sin(angle)*.8),Vector3(1.2,1.1,1.1),leaves)
		S.orb(root,Vector3(cos(angle)*1.5,2.5,sin(angle)*1.5),Vector3.ONE*.22,fruit)

static func mushroom(parent: Node3D, pos: Vector3, height: float, cap: Material, stem: Material) -> void:
	S.cylinder(parent,pos+Vector3.UP*height*.45,.4,height*.9,stem,.25)
	S.lathe(parent,pos,[Vector2(0,height*.8),Vector2(height*.6,height*.8),Vector2(height*.67,height*.87),Vector2(height*.58,height*1.1),Vector2(height*.3,height*1.27),Vector2(0,height*1.32)],cap)
	for j in 6:
		var a := j*TAU/6
		S.orb(parent,pos+Vector3(cos(a)*height*.4,height*1.19,sin(a)*height*.4),Vector3(.2,.05,.2),stem)

static func pine(parent: Node3D,pos: Vector3,height: float, green: Material,snow: Material) -> void:
	for i in 3:
		S.cylinder(parent,pos+Vector3.UP*(height*.35+i*.8),1.5-i*.3,height*.7,green,0,12)
		S.cylinder(parent,pos+Vector3.UP*(height*.45+i*.8),1.2-i*.25,height*.58,snow,0,12)

static func flower(parent: Node3D,pos: Vector3, petal: Material, middle: Material) -> void:
	for i in 5:
		S.orb(parent,pos+Vector3(cos(i*TAU/5)*.17,0,sin(i*TAU/5)*.17),Vector3(.15,.06,.15),petal)
	S.orb(parent,pos+Vector3.UP*.055,Vector3.ONE*.09,middle)

static func gear(parent: Node3D, pos: Vector3,radius: float,mat: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.x = PI*.5
	parent.add_child(root)
	S.ring(root,Vector3.ZERO,radius,.2,mat)
	for j in 12:
		var a := j*TAU/12
		var tooth := S.box(root,Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(.45,.25,.4),mat)
		tooth.rotation.y = -a
