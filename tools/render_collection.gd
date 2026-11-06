extends SceneTree
const STYLES=preload("res://scripts/skin_style.gd")
var viewport: SubViewport
func _initialize() -> void: call_deferred("run")
func text_at(parent: Node, content: String, pos: Vector2, width: float, font_size: int, tint: Color, centered := false) -> void:
	var label:=Label.new()
	label.text=content
	label.position=pos
	label.size.x=width
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	if centered: label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(850,540)
	root.gui_disable_input=true
	viewport=SubViewport.new()
	viewport.size=Vector2i(1700,1080)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for page in 2:
		var canvas:=ColorRect.new()
		canvas.color=Color("101a2b")
		canvas.size=Vector2(1700,1080)
		viewport.add_child(canvas)
		text_at(canvas,"星跃岛  /  STARLIGHT ATELIER",Vector2(50,26),1600,19,Color("c9b48c"))
		text_at(canvas,"典藏华服 · 十款新作" if page==1 else "经典衣橱 · 全新可爱建模",Vector2(48,62),1600,38,Color("fff0d8"))
		text_at(canvas,"游戏内 3D 实际渲染  ·  金币兑换  ·  独立立体配饰",Vector2(50,119),1600,21,Color("b6c6dc"))
		for index in 10:
			var skin: Dictionary=STYLES.SKINS[page*10+index]
			var x:=50+(index%5)*324
			var y:=174+(index/5)*426
			var panel:=Panel.new()
			panel.position=Vector2(x,y)
			panel.size=Vector2(304,408)
			var style:=StyleBoxFlat.new()
			style.bg_color=Color("18263b")
			style.set_corner_radius_all(16)
			style.border_color=Color(skin.accent).darkened(.45)
			style.set_border_width_all(1)
			panel.add_theme_stylebox_override("panel",style)
			canvas.add_child(panel)
			var source:=Image.load_from_file("res://docs/couture/"+skin.id+".png")
			var cropped:=source.get_region(Rect2i(0,80,600,560))
			cropped.resize(296,276,Image.INTERPOLATE_LANCZOS)
			var art:=TextureRect.new()
			art.texture=ImageTexture.create_from_image(cropped)
			art.position=Vector2(4,4)
			art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.size=Vector2(296,302)
			panel.add_child(art)
			text_at(panel,skin.name,Vector2(0,311),304,26,Color("fff0d8"),true)
			text_at(panel,"%d 金币" % skin.price,Vector2(0,352),304,19,Color(skin.accent),true)
		for i in 4: await process_frame
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("res://docs/couture-collection.png" if page==1 else "res://docs/skins.png")
		canvas.queue_free()
		await process_frame
	quit()
