extends ColorRect

const STYLES = preload("res://scripts/skin_style.gd")
const MODEL = preload("res://assets/kenney/models/character.glb")
const S = preload("res://scripts/sculpt.gd")
signal closed
var selected := "daisy"
var mannequin: Node3D
var wallet_label: Label
var name_label: Label
var detail_label: Label
var status_label: Label
var buy_button: Button
var cards: Dictionary = {}
var collection := 1
var collection_buttons: Array[Button] = []
var preview_camera: Camera3D
var preview_dragging := false
var auto_rotate := true

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color=Color("151e32")
	mouse_filter=Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,40)
	for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,26)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := label("星光衣橱",32,Color("fff0d3"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	wallet_label=label("",23,Color("ffd784"))
	heading.add_child(wallet_label)
	var back := button("返回游戏  Esc")
	back.pressed.connect(func(): closed.emit())
	heading.add_child(back)
	column.add_child(label("20 款新装 · 点选免费试穿 · 左键拖动模特，查看立体细节",18,Color("bbc6dd")))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",28)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var showroom := VBoxContainer.new()
	showroom.custom_minimum_size.x=350
	showroom.add_theme_constant_override("separation",10)
	body.add_child(showroom)
	var preview := SubViewportContainer.new()
	preview.custom_minimum_size=Vector2(350,270)
	preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview.stretch=true
	preview.mouse_filter=Control.MOUSE_FILTER_STOP
	preview.gui_input.connect(_preview_input)
	showroom.add_child(preview)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(350,320)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.scaling_3d_scale=1.5
	preview.add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("202b45")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d8dcf5")
	env.ambient_light_energy=.42
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.glow_enabled=true
	env.glow_intensity=.28
	env.tonemap_exposure=.9
	world.environment=env
	studio.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-35,0)
	light.light_energy=1.05
	studio.add_child(light)
	var fill := OmniLight3D.new()
	fill.position=Vector3(-2,2,-1)
	fill.light_color=Color("b9b7ff")
	fill.omni_range=8
	fill.light_energy=.7
	studio.add_child(fill)
	S.cylinder(studio,Vector3(0,-.07,0),.66,.14,S.material(Color("404e70"),.45,.3))
	S.ring(studio,Vector3(0,.005,0),.60,.012,S.material(Color("d5b9ff"),.35,.3,.5))
	mannequin=MODEL.instantiate()
	mannequin.scale=Vector3.ONE*1.5
	mannequin.rotation.y=-.2
	studio.add_child(mannequin)
	var animation: AnimationPlayer=mannequin.find_child("AnimationPlayer",true,false)
	animation.get_animation("idle").loop_mode=Animation.LOOP_LINEAR
	animation.play("idle")
	var camera := Camera3D.new()
	camera.position=Vector3(0,1.42,3.9)
	studio.add_child(camera)
	camera.look_at(Vector3(0,.85,0))
	camera.fov=38
	preview_camera=camera
	name_label=label("",25,Color("fff0d3"))
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	showroom.add_child(name_label)
	detail_label=label("",16,Color("bdcbe1"))
	detail_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.y=42
	showroom.add_child(detail_label)
	buy_button=button("")
	buy_button.custom_minimum_size.y=48
	buy_button.add_theme_stylebox_override("normal",style(Color("dbb876"),Color("ffe7b0")))
	buy_button.add_theme_color_override("font_color",Color("20283b"))
	buy_button.pressed.connect(_buy)
	showroom.add_child(buy_button)
	var classic := button("穿回经典小紫 · 免费")
	classic.pressed.connect(func(): status_label.text=Wardrobe.equip("classic"); _select("classic"))
	showroom.add_child(classic)
	var catalog := VBoxContainer.new()
	catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	catalog.add_theme_constant_override("separation",12)
	body.add_child(catalog)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",12)
	catalog.add_child(tabs)
	for i in 2:
		var tab:=button("经典衣橱 · 10 款" if i==0 else "全新典藏 · 10 款")
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_set_collection.bind(i))
		tabs.add_child(tab)
		collection_buttons.append(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	catalog.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns=2
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	for skin in STYLES.SKINS:
		var card := button("")
		card.name="Skin_"+skin.id
		card.custom_minimum_size=Vector2(260,86)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.alignment=HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size",19)
		card.pressed.connect(_select.bind(skin.id))
		grid.add_child(card)
		cards[skin.id]=card
	status_label=label("星晶收藏奖励：9 颗薄荷邮差 · 30 颗暮色魔法师 · 75 颗银河旅梦者",17,Color("b5c6d9"))
	column.add_child(status_label)
	Wardrobe.changed.connect(_refresh)
	_select(Wardrobe.equipped if Wardrobe.equipped!="classic" else "rose_seraph")

func _process(delta: float) -> void:
	if mannequin and auto_rotate and not preview_dragging: mannequin.rotation.y+=delta*.16

func _select(id: String) -> void:
	selected=id
	STYLES.apply(mannequin,id)
	mannequin.rotation.y=-.2
	auto_rotate=true
	var premium: bool=STYLES.get_skin(id).get("couture",false)
	# Keep room for wide silhouettes without making the close-fitting jewels tiny.
	var wide_silhouette: bool=id in ["glass_butterfly","jade_peacock","star_weaver"]
	preview_camera.position=Vector3(0,1.6,5.5 if wide_silhouette else (4.35 if premium else 4.2))
	preview_camera.look_at(Vector3(0,.94,0))
	_set_collection(1 if premium else 0)
	_refresh()

func _refresh() -> void:
	wallet_label.text="金币余额  ∞    " if Wardrobe.infinite_coins else "金币余额  %d    " % Wardrobe.balance
	var data := STYLES.get_skin(selected)
	name_label.text=data.name
	detail_label.text=data.detail
	for skin in STYLES.SKINS:
		var card: Button=cards[skin.id]
		var state: String="已穿戴" if Wardrobe.equipped==skin.id else ("已拥有" if Wardrobe.owned.has(skin.id) else "%d 金币" % skin.price)
		card.text="  %s  ·  %s\n  %s" % [skin.name,skin.tier,state]
		card.add_theme_stylebox_override("normal",style(Color(skin.color).darkened(.58 if selected!=skin.id else .38),Color(skin.color).lightened(.35) if selected==skin.id else Color("46516a")))
	if Wardrobe.equipped==selected:
		buy_button.text="正在穿戴"
		buy_button.disabled=true
	elif Wardrobe.owned.has(selected):
		buy_button.text="穿上这款皮肤"
		buy_button.disabled=false
	else:
		var enough := Wardrobe.balance>=int(data.price)
		buy_button.text="免费兑换并穿戴" if Wardrobe.infinite_coins else ("%d 金币 · 兑换并穿戴" % data.price if enough else "还差 %d 金币" % (int(data.price)-Wardrobe.balance))
		buy_button.disabled=not enough

func _buy() -> void:
	status_label.text=Wardrobe.purchase(selected)
	_refresh()

func label(content: String, font_size: int, tint: Color) -> Label:
	var result := Label.new()
	result.text=content
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",tint)
	return result

func button(content: String) -> Button:
	var result := Button.new()
	result.text=content
	result.custom_minimum_size.y=38
	result.add_theme_font_size_override("font_size",18)
	result.add_theme_stylebox_override("normal",style(Color("303e58"),Color("536382")))
	result.add_theme_stylebox_override("hover",style(Color("53617e"),Color("f6d8a2")))
	result.add_theme_stylebox_override("focus",style(Color(0,0,0,0),Color("e8d6ff")))
	result.add_theme_stylebox_override("disabled",style(Color("2a3247"),Color("46516a")))
	return result

func style(background: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=background
	result.border_color=border
	result.set_border_width_all(2)
	result.set_corner_radius_all(12)
	result.content_margin_left=12
	result.content_margin_right=12
	return result

func _set_collection(index: int) -> void:
	collection=index
	for skin in STYLES.SKINS:
		cards[skin.id].visible=bool(skin.get("couture",false))==(index==1)
	for i in collection_buttons.size():
		collection_buttons[i].add_theme_stylebox_override("normal",style(Color("6c557c") if i==index else Color("303e58"),Color("e8cc9c") if i==index else Color("536382")))

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		preview_dragging=event.pressed
		auto_rotate=false
	if event is InputEventMouseMotion and preview_dragging:
		mannequin.rotation.y+=event.relative.x*.012

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		preview_dragging=false
