extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	for i in 12: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Campaign").level_index=0
	var w=root.get_node("Wardrobe")
	w.save_enabled=false
	w.balance=360
	w.equipped="classic"
	change_scene_to_file("res://main.tscn")
	for i in 5: await process_frame
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,800)
	root.gui_disable_input=true
	var game=current_scene
	game._show_shop()
	game.shop._select("eternal_dawn")
	game.shop.set_process(false)
	await shot("res://docs/skin-shop.png")
	game.shop._select("royal")
	await shot("/tmp/shop-classic-final.png")
	game.shop._select("eternal_dawn")
	root.size=Vector2i(1600,900)
	await shot("/tmp/shop-wide-final.png")
	if "--all" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("/tmp/couture-shop-fit")
		for dimensions in [Vector2i(1280,720),Vector2i(1600,900)]:
			root.size=dimensions
			for skin in game.shop.STYLES.SKINS:
				game.shop._select(skin.id)
				for angle in [0.0,PI*.5,PI]:
					game.shop.mannequin.rotation.y=angle
					await shot("/tmp/couture-shop-fit/%s_%d_%d.png" % [skin.id,dimensions.x,int(rad_to_deg(angle))])
	game._close_shop()
	game.overlay.hide()
	root.size=Vector2i(1280,800)
	await shot("res://preview.png")
	game.player.apply_skin("eternal_dawn")
	await shot("res://docs/couture-gameplay.png")
	paused=false
	game.queue_free()
	for i in 5: await process_frame
	quit()
