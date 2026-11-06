extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var w=root.get_node("Wardrobe")
	var c=root.get_node("Campaign")
	c.save_enabled=false
	c.level_index=0
	# Test persistence in an isolated writable directory, never the player's wallet.
	var temp_dir := OS.get_environment("TMPDIR")
	if temp_dir.is_empty(): temp_dir="/tmp"
	w.save_path=temp_dir.path_join("wardrobe_test_%d.cfg" % OS.get_process_id())
	var missing_path:=temp_dir.path_join("missing_shop_test_%d/wallet.cfg" % OS.get_process_id())
	w.save_enabled=true
	c.collected_by_level.fill(0)
	c.collected_by_level[0]=17
	w.load_wallet()
	check(w.balance==17,"Old coin records credited once")
	w.load_wallet()
	check(w.balance==17,"Loading does not duplicate migration")
	check(w.STYLES.SKINS.size()==20,"Twenty purchasable skins")
	check(w.purchase("royal").begins_with("还差") and w.balance==17 and not w.owned.has("royal"),"Insufficient funds never spend or unlock")
	check(w.purchase("invalid")=="这款皮肤不存在","Invalid ID rejected")
	check(not w.earn(-8),"Negative earnings rejected")
	w.earn(23)
	check(w.balance==40,"Earned coins add to wallet")
	w.purchase("daisy")
	check(w.balance==0 and w.owned.has("daisy") and w.equipped=="daisy","Exact price purchase equips and spends once")
	w.purchase("daisy")
	check(w.balance==0,"Owned skin cannot charge twice")
	w.load_wallet()
	check(w.balance==0 and w.owned.has("daisy") and w.equipped=="daisy","Disk reload preserves balance, ownership and equip")
	w.equip("classic")
	check(w.equipped=="classic","Original skin always available")
	var test_path: String=w.save_path
	w.save_path=missing_path
	w.balance=1000
	w.purchase("bunny")
	check(w.balance==1000 and not w.owned.has("bunny") and w.equipped=="classic","Save failure rolls back purchase")
	w.save_path=test_path
	w.balance=0
	w.save_wallet()
	change_scene_to_file("res://main.tscn")
	await frames(30)
	var game=current_scene
	game.player.sound_enabled=false
	game._show_shop()
	check(paused and game.shop.cards.size()==20,"Shop opens at intro with all twenty options")
	for page in 2:
		game.shop._set_collection(page)
		var visible_cards:=0
		for card in game.shop.cards.values():
			if card.visible: visible_cards+=1
		check(visible_cards==10,"Each collection page shows ten skins")
	var preview_press:=InputEventMouseButton.new()
	preview_press.button_index=MOUSE_BUTTON_LEFT
	preview_press.pressed=true
	game.shop._preview_input(preview_press)
	var preview_motion:=InputEventMouseMotion.new()
	preview_motion.relative=Vector2(80,0)
	var preview_yaw: float=game.shop.mannequin.rotation.y
	game.shop._preview_input(preview_motion)
	check(absf(game.shop.mannequin.rotation.y-preview_yaw)>.8,"Left drag rotates the preview")
	preview_press.pressed=false
	game.shop._input(preview_press)
	check(not game.shop.preview_dragging and not game.shop.auto_rotate,"Releasing outside preview stops drag without undoing chosen angle")
	var before: String=w.equipped
	game.shop._select("royal")
	check(w.equipped==before and game.shop.buy_button.disabled,"Locked skin can be previewed without equipping")
	game._close_shop()
	check(paused,"Closing shop keeps intro paused")
	game._on_overlay_button()
	var initial: int=w.balance
	var coin=StarCoin.new()
	game.add_child(coin)
	coin.position=Vector3(80,80,80)
	w.save_path=missing_path
	coin._on_body_entered(game.player)
	check(not coin.collected and game.player.coins==0 and w.balance==initial,"Failed save leaves the coin collectible")
	w.save_path=test_path
	coin._on_body_entered(game.player)
	coin._on_body_entered(game.player)
	check(w.balance==initial+1 and game.player.coins==1,"Coin collider credits exactly once")
	game._show_shop()
	var time: float=game.time_left
	await frames(5)
	check(game.time_left==time and paused,"Shop freezes gameplay timer")
	game._close_shop()
	check(not paused,"Closing shop resumes gameplay")
	game._end_game(false,"测试")
	check(w.balance==initial+1,"Failure preserves collected coins")
	w.load_wallet()
	check(w.balance==initial+1,"Collected coin saved immediately")
	game._on_overlay_button()
	await frames(5)
	game=current_scene
	check(w.balance==initial+1 and game.player.coins==0,"Retry resets stage count but not wallet")
	w.earn(100000)
	var previous_price := 0
	for skin in w.STYLES.SKINS:
		check(skin.price>previous_price,"Prices increase with detail")
		previous_price=skin.price
		w.purchase(skin.id)
		check(game.player.applied_skin==skin.id,"Purchased skin reaches live character")
		check(game.player._visual.find_child("SkinAccessories",true,false)!=null,"Skin geometry built")
	w.load_wallet()
	check(w.owned.size()==21 and w.equipped=="eternal_dawn","All twenty skins plus default persist")
	game._on_overlay_button()
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_RIGHT
	press.pressed=true
	game._unhandled_input(press)
	check(game.camera_dragging,"Right drag starts camera control")
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(170,900)
	var yaw: float=game.camera_yaw
	game._input(motion)
	check(absf(angle_difference(yaw,game.camera_yaw))>.7,"Horizontal drag rotates camera")
	check(game.camera_pitch==1.05,"Vertical view angle is clamped")
	press.pressed=false
	game._input(press)
	check(not game.camera_dragging and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Release restores cursor")
	motion.relative=Vector2(-600,0)
	yaw=game.camera_yaw
	game._input(motion)
	check(game.camera_yaw==yaw,"Mouse motion without dragging does not rotate")
	press.pressed=true
	game._unhandled_input(press)
	game._show_shop()
	check(not game.camera_dragging and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Shop clears camera capture")
	game._close_shop()
	w.save_enabled=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	paused=false
	game.queue_free()
	await frames(6)
	print("Wallet/shop/camera failures: ",failures)
	quit(1 if failures else 0)
