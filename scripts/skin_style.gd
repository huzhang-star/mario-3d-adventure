extends RefCounted

const BASE = preload("res://scripts/couture_base.gd")
const COUTURE = preload("res://scripts/couture_skins.gd")
const MOTION = preload("res://scripts/couture_motion.gd")
const S = preload("res://scripts/sculpt.gd")
const SKINS := [
	{"id": "daisy", "name": "雏菊奶油", "price": 40, "tier": "清新", "color": "e8b957", "accent": "fff3c6", "detail": "蜂蜜奶油 · 三花弧簪", "cut": 1},
	{"id": "mint", "name": "薄荷邮差", "price": 80, "tier": "清新", "color": "518977", "accent": "f2ddb4", "detail": "森林绿软帽 · 奶油邮包", "cut": 2},
	{"id": "bunny", "name": "草莓软糖", "price": 140, "tier": "精致", "color": "e991af", "accent": "fff1e4", "detail": "草莓粉绒装 · 奶白长兔耳", "cut": 3},
	{"id": "sailor", "name": "海盐水手", "price": 220, "tier": "精致", "color": "425d86", "accent": "f9e1b4", "detail": "海军蓝制服 · 奶白帽顶与金扣", "cut": 1},
	{"id": "fox", "name": "枫糖小狐", "price": 320, "tier": "珍藏", "color": "bf6645", "accent": "f6d1a2", "detail": "枫糖狐狸耳 · 蓬松奶油尾巴", "cut": 0},
	{"id": "witch", "name": "暮色魔法师", "price": 460, "tier": "珍藏", "color": "8872c7", "accent": "f1c870", "detail": "星扣尖顶帽 · 月色魔法披风", "cut": 0},
	{"id": "pearl", "name": "珍珠海精灵", "price": 650, "tier": "华丽", "color": "7fbfd4", "accent": "e7f1e8", "detail": "冰水蓝贝母 · 五瓣贝冠与珍珠", "cut": 1},
	{"id": "angel", "name": "云端小天使", "price": 900, "tier": "华丽", "color": "d8d6cf", "accent": "e3bd74", "detail": "月白香槟 · 奶油羽翼与小光环", "cut": 1},
	{"id": "astral", "name": "银河旅梦者", "price": 1250, "tier": "梦幻", "color": "3e7e92", "accent": "d7ece4", "detail": "黛青星轨 · 细环与星石", "cut": 1},
	{"id": "royal", "name": "极光星冠", "price": 1800, "tier": "传说", "color": "bc9cc4", "accent": "efd8a5", "detail": "紫藤香槟 · 五晶金冠与极光羽翼", "cut": 1},
	{"id": "rose_seraph", "name": "蔷薇圣歌", "price": 2200, "tier": "典藏", "color": "e6a0b2", "accent": "e7c77e", "detail": "七花蔷薇冠 · 花瓣金边裙 · 柔粉花雨", "couture": true, "cut": 1},
	{"id": "moon_empress", "name": "月冕霜华", "price": 2500, "tier": "典藏", "color": "b9d8ef", "accent": "f6fbff", "detail": "弯月银冕 · 冰晶耳坠 · 星月环与霜绸", "couture": true, "cut": 4},
	{"id": "glass_butterfly", "name": "琉璃蝶梦", "price": 2800, "tier": "典藏", "color": "c05d9e", "accent": "76e2d9", "detail": "唯一蝶翼主题 · 紫晶叶脉 · 琉璃蝶光", "couture": true, "cut": 2},
	{"id": "phoenix", "name": "赤霄凤凰", "price": 3200, "tier": "典藏", "color": "ad3b48", "accent": "e5b55a", "detail": "凤翎金冠 · 绛红波褶裙 · 赤金长尾", "couture": true, "cut": 4},
	{"id": "ocean_pearl", "name": "沧海明珠", "price": 3600, "tier": "典藏", "color": "3dbbc1", "accent": "f8dca6", "detail": "九瓣贝冠 · 珍珠珊瑚帘 · 水光宝珠", "couture": true, "cut": 3},
	{"id": "sakura_deity", "name": "樱雪花神", "price": 4100, "tier": "典藏", "color": "d9c07a", "accent": "ef9cae", "detail": "樱枝花簪 · 香槟雪裙 · 樱瓣流光", "couture": true, "cut": 3},
	{"id": "star_weaver", "name": "星穹织梦", "price": 4700, "tier": "典藏", "color": "354aa6", "accent": "72d7ff", "detail": "深钴双层星轨 · 电光星芒 · 夜穹织锦", "couture": true, "cut": 2},
	{"id": "platinum_dragon", "name": "白金龙姬", "price": 5300, "tier": "典藏", "color": "8e9ba9", "accent": "b8ead1", "detail": "高挑龙角 · 冷铂四层鳞甲 · 翡翠龙纹", "couture": true, "cut": 2},
	{"id": "jade_peacock", "name": "翡翠孔雀", "price": 6000, "tier": "典藏", "color": "16a98d", "accent": "f0cb62", "detail": "十一翎羽屏 · 孔雀蓝眼羽 · 翡翠礼裙", "couture": true, "cut": 2},
	{"id": "eternal_dawn", "name": "永恒曙光", "price": 6800, "tier": "典藏", "color": "694876", "accent": "e8c181", "detail": "十一芒日冕 · 青欧泊珠宝 · 绛紫象牙礼裙", "couture": true, "cut": 0, "opal": "a9dcce"},
]

static func get_skin(id: String) -> Dictionary:
	for skin in SKINS:
		if skin.id == id: return skin
	return {"id":"classic","name":"经典小紫","price":0,"tier":"初始","color":"9670cc","accent":"fff2dc","detail":"最初的可爱伙伴 · 永久拥有"}

static func apply(model: Node3D, id: String) -> void:
	var data := get_skin(id)
	apply_data(model,data)

# The same builder renders design candidates and the purchased in-game skin.
static func apply_data(model: Node3D, data: Dictionary) -> void:
	var id: String=data.id
	var cut:=int(data.get("cut",0))
	var breadth: float=[1.0,.88,1.06,1.14,.96][cut]
	var old := model.find_child("SkinAccessories",true,false)
	if old:
		old.get_parent().remove_child(old)
		old.queue_free()
	BASE.apply(model,data)
	var torso := model.find_child("torso",true,false) as Node3D
	if not torso: return
	var accessories := Node3D.new()
	accessories.name="SkinAccessories"
	torso.add_child(accessories)
	var motion:=model.get_node_or_null("CoutureMotion")
	if not motion:
		motion=Node3D.new()
		motion.name="CoutureMotion"
		motion.set_script(MOTION)
		model.add_child(motion)
	if data.get("couture",false):
		COUTURE.build(accessories,data)
		motion.refresh.call_deferred()
		return
	accessories.position.y=.10
	motion.refresh.call_deferred()
	var body := S.material(Color(data.color),.45)
	var cream := S.material(Color(data.accent),.42)
	var gold := S.material(Color("f5cc7e"),.28,.65)
	var white := S.material(Color("fff5eb"),.65)
	var glow := S.material(Color("94e2da") if id=="royal" else Color(data.accent),.3,.2,.35)
	match id:
		"daisy":
			var count: int=[1,3,2,5,1][cut]
			for i in count:
				_flower(accessories,Vector3(-.20+i*.075,.56+sin(i*.8)*.065,.24-i*.012),white,gold)
			if cut==4: _bow(accessories,Vector3(.19,.61,.20),body,gold)
		"mint":
			S.orb(accessories,Vector3(0,.62,0),Vector3(.31*breadth,.105*(1.25 if cut==2 else 1),.26),body).rotation.z=[0.0,-.15,.08,-.22,.12][cut]
			S.orb(accessories,Vector3(.03,.724,0),Vector3(.035,.035,.035),cream)
			S.orb(accessories,Vector3(.23,.10,-.22),Vector3(.14*breadth,.17,.08),cream)
			S.ring(accessories,Vector3(0,.085,0),.198,.015,gold).scale.z=.75
		"bunny":
			for side in [-1,1]:
				var ear := S.orb(accessories,Vector3(side*.16,.78,0),Vector3(.078,.26*[1.0,.80,1.13,.90,1.05][cut],.063),white)
				ear.rotation.z=side*[-.16,-.08,-.22,-.38,-.12][cut]
				S.orb(accessories,Vector3(side*.16,.8,.053),Vector3(.04,.18*[1.0,.80,1.13,.90,1.05][cut],.016),body).rotation.z=side*[-.16,-.08,-.22,-.38,-.12][cut]
			_bow(accessories,Vector3(0,.06,.17),body,gold)
		"sailor":
			S.cylinder(accessories,Vector3(0,.60,0),.29*breadth,.095,body)
			S.orb(accessories,Vector3(0,.67,0),Vector3(.30*breadth,.105*(1.4 if cut==2 else 1),.255),white)
			S.orb(accessories,Vector3(0,.62,.26),Vector3(.05,.047,.02),gold)
			_bow(accessories,Vector3(0,.07,.17),body,gold)
		"fox":
			for side in [-1,1]:
				S.cylinder(accessories,Vector3(side*.22*breadth,.69,0),.10,.28*(1.22 if cut==2 else .9 if cut==1 else 1),body,0,4).rotation.z=side*-.25
				S.orb(accessories,Vector3(side*.22,.67,.05),Vector3(.047,.07,.015),cream)
			S.orb(accessories,Vector3(0,.02,-.40),Vector3(.16*breadth,.13,.30),body).rotation.x=-.35
			S.orb(accessories,Vector3(0,.10,-.63),Vector3(.12,.11,.13),cream)
		"witch":
			S.cylinder(accessories,Vector3(0,.60,0),.38*breadth,.04,body)
			S.cylinder(accessories,Vector3(.025,.80,0),.23,.40*(1.20 if cut==2 else .85 if cut==1 else 1),body,.02).rotation.z=[-.16,-.08,-.22,-.30,.12][cut]
			S.ring(accessories,Vector3(0,.63,0),.215,.022,gold)
			_gem(accessories,Vector3(0,.68,.21),.06,glow)
			_cape(accessories,body,gold)
		"pearl":
			var count: int=[7,5,9,7,5][cut]
			for i in count:
				var a := PI*float(i)/(count-1)
				S.orb(accessories,Vector3(cos(a)*.27*breadth,.58+sin(a)*(.21 if cut==2 else .15),.03),Vector3(.07,.12,.05),cream).rotation.z=a-PI/2
			for i in 12:
				var a := TAU*i/12
				S.orb(accessories,Vector3(cos(a)*.20,.085,sin(a)*.146),Vector3.ONE*.027,white)
			S.ring(accessories,Vector3(0,.085,0),.20,.006,white).scale.z=.73
			_wings(accessories,glow,.75*breadth)
		"angel":
			S.ring(accessories,Vector3(0,.87,0),.25*breadth,.022,gold)
			_wings(accessories,white,breadth)
			_bow(accessories,Vector3(0,.08,.16),cream,gold)
		"astral":
			var ring := S.ring(accessories,Vector3(0,.74,0),.34*breadth,.012,glow)
			ring.rotation.z=[.28,.10,.40,.52,-.20][cut]
			for i in 5:
				var a := TAU*i/5
				_gem(accessories,Vector3(cos(a)*.34,.74+cos(a)*.08,sin(a)*.34),.04,gold)
			_wings(accessories,glow,1.05*breadth)
			_cape(accessories,body,gold)
		"royal":
			S.ring(accessories,Vector3(0,.61,0),.25,.03,gold)
			var count: int=[7,5,9,7,5][cut]
			for i in count:
				var a := TAU*i/count
				S.cylinder(accessories,Vector3(cos(a)*.235,.69,sin(a)*.235),.05,.20,gold,0,5)
				_gem(accessories,Vector3(cos(a)*.235,.81,sin(a)*.235),.049,glow)
			_wings(accessories,glow,1.2*breadth)
			_cape(accessories,body,gold)
			_gem(accessories,Vector3(0,.10,.17),.07,glow)

static func _flower(root: Node3D, pos: Vector3, petals: Material, center: Material) -> void:
	for i in 6:
		var a:=TAU*i/6
		S.orb(root,pos+Vector3(cos(a)*.063,sin(a)*.063,0),Vector3(.045,.045,.022),petals)
	S.orb(root,pos+Vector3(0,0,.025),Vector3(.038,.038,.024),center)

static func _bow(root: Node3D, pos: Vector3, mat: Material, center: Material) -> void:
	for side in [-1,1]:
		S.orb(root,pos+Vector3(side*.067,0,0),Vector3(.068,.044,.03),mat).rotation.z=side*.25
	S.orb(root,pos+Vector3(0,0,.018),Vector3(.028,.03,.027),center)

static func _gem(root: Node3D, pos: Vector3, radius: float, mat: Material) -> void:
	S.cylinder(root,pos+Vector3.UP*radius*.4,radius,radius,mat,0,6)
	S.cylinder(root,pos-Vector3.UP*radius*.4,0,radius,mat,radius,6)

static func _wings(root: Node3D, mat: Material, size: float) -> void:
	for side in [-1,1]:
		for i in 3:
			# Scale the attachment spacing with the feathers, so smaller studies
			# still overlap the upper back instead of leaving floating fins.
			var feather:=S.orb(root,Vector3(side*(.24+i*.065)*size,.22+i*.07*size,-.20),Vector3(.08,.22-i*.025,.055)*size,mat)
			feather.rotation.z=side*(-.55-i*.22)

static func _cape(root: Node3D, mat: Material, trim: Material) -> void:
	S.orb(root,Vector3(0,.12,-.18),Vector3(.30,.25,.055),mat)
	S.orb(root,Vector3(0,-.07,-.19),Vector3(.30,.025,.06),trim)
