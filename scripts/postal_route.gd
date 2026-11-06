extends Node3D
# A two-stop delivery trip; all progress lasts through falls but resets on retry.
const S = preload("res://scripts/sculpt.gd")
const PLATFORM = preload("res://scripts/adventure_platform.gd")
var game: Node3D
var carrying := false
var delivered: Array[bool] = [false,false]
var pickup: Area3D
var mailboxes: Array[Area3D] = []
var shortcut: Array[Node3D] = []
var labels: Array[Label3D] = []
var notice_cooldown := 0.0
var branch_signs: Array[Label3D] = []
var gate_label: Label3D

func _ready() -> void:
	name="SkyPostalRoute"
	pickup=_zone(game.route_surfaces[0],Vector3(0,.7,1.0),1.5)
	var ivory := S.material(Color("fff4d4"),.48)
	var gold := S.material(Color("e6b361"),.35,.4)
	_envelope(pickup,Vector3(0,.6,0),ivory,gold)
	_label(pickup,"领取两封星光信",Vector3(0,1.9,0),Color("ffe8ac"))
	pickup.body_entered.connect(_collect)
	var branches := get_tree().get_nodes_in_group("bonus_surface")
	branches.sort_custom(func(a: Node3D,b: Node3D): return a.get_meta("source_index")<b.get_meta("source_index"))
	for i in 2:
		var island: Node3D=branches[i]
		var box := _zone(island,Vector3(.65,.6,-.65),1.15)
		mailboxes.append(box)
		var tint := S.material(Color("71b6a8") if i==0 else Color("b99bd5"),.5)
		S.cylinder(box,Vector3(0,-.25,0),.065,.6,gold)
		S.box(box,Vector3(0,.18,0),Vector3(.7,.58,.42),tint)
		S.cylinder(box,Vector3(0,.61,0),.55,.35,gold,0,4)
		S.box(box,Vector3(0,.27,.22),Vector3(.43,.05,.02),ivory)
		_envelope(box,Vector3(0,1.05,0),ivory,gold)
		labels.append(_label(box,"晨光邮亭" if i==0 else "暮云邮亭",Vector3(0,1.65,0),Color("fff0c5")))
		box.body_entered.connect(_deliver.bind(i))
		# Sign at the branch entry is visible before the player commits to a jump.
		var source: Node3D=game.route_surfaces[int(island.get_meta("source_index"))]
		branch_signs.append(_label(source,"支线邮亭 ↗",Vector3(0,2.2,0),Color("c4f3df")))
	_build_shortcut()

func _physics_process(delta: float) -> void:
	notice_cooldown=maxf(0,notice_cooldown-delta)
	# Overlap recheck covers starting inside the pickup and collecting before returning to a box.
	if not carrying:
		for body in pickup.get_overlapping_bodies(): _collect(body)

func _zone(parent: Node3D, pos: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.position=pos
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius=radius
	collider.shape=sphere
	area.add_child(collider)
	parent.add_child(area)
	return area

func _label(parent: Node3D, text: String, pos: Vector3, tint: Color) -> Label3D:
	var label := Label3D.new()
	label.text=text
	label.position=pos
	label.font_size=36
	label.pixel_size=.008
	label.modulate=tint
	label.outline_size=8
	label.outline_modulate=Color("243447")
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _envelope(parent: Node3D, pos: Vector3, ivory: Material, gold: Material) -> void:
	S.box(parent,pos,Vector3(.72,.46,.09),ivory)
	for side in [-1,1]:
		var seam := S.box(parent,pos+Vector3(side*.16,.04,.055),Vector3(.4,.025,.025),gold)
		seam.rotation.z=side*.6
	S.orb(parent,pos+Vector3(0,-.07,.075),Vector3(.07,.07,.025),gold)

func _collect(body: Node3D) -> void:
	if not body is IslandPlayer or not body.active or carrying: return
	carrying=true
	pickup.hide()
	game.play_sfx(game.SOUND_KEY,-3,1.0)
	game._flash_banner("收到两封信 · 跳上支线小岛，靠近邮亭即可投递")
	game._update_special_label()

func _deliver(body: Node3D, index: int) -> void:
	if not body is IslandPlayer or not body.active or delivered[index]: return
	if not carrying:
		if notice_cooldown<=0:
			game._flash_banner("先回起点领取信件，再来投递")
			notice_cooldown=3
		return
	delivered[index]=true
	labels[index].text="投递完成 ✓"
	labels[index].modulate=Color("a5f4ce")
	game.play_sfx(game.SOUND_KEY,-2,1.2)
	if is_complete():
		for sign in branch_signs: sign.hide()
		gate_label.text="云桥已开启 →"
		gate_label.show()
		for platform in shortcut:
			platform.show()
			platform.collider.set_deferred("disabled",false)
		game._flash_banner("两封信已送达！回到绿色旗帜，走薄荷色云桥直达终点")
	else:
		game._flash_banner("投递 1 / 2 · 继续前往下一座邮亭")
	game._update_special_label()

func delivered_count() -> int:
	return delivered.count(true)

func is_complete() -> bool:
	return delivered_count()==2

func _build_shortcut() -> void:
	var start: Vector3=game.route_surfaces[7].position
	var finish: Vector3=game.stage_goal
	# The direct diagonal bypasses the final lift. Three broad intermediate landings.
	for i in range(1,4):
		var platform=PLATFORM.new()
		platform.name="PostalBridge_%d" % i
		platform.position=[Vector3(13,7.55,-40),Vector3(8,8.4,-46),Vector3(1.5,9.25,-49)][i-1]
		platform.size=Vector3(3.7,.7,3.7)
		platform.game=game
		game.add_child(platform)
		platform.setup(Color("a7dacb"),Color("fff0c5"),Color("71899d"),true)
		platform.add_to_group("postal_bridge")
		platform.hide()
		platform.collider.disabled=true
		shortcut.append(platform)
	gate_label=_label(game.route_surfaces[7],"",Vector3(1.2,2.2,-1),Color("b1ebd3"))
	gate_label.hide()
