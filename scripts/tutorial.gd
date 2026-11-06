extends RefCounted

# Per-attempt guidance. Completing actions early is allowed; falls retain progress.
var game: Node3D
var panel: PanelContainer
var heading: Label
var instruction: Label
var tip: Label
var step := 0
var furthest_landing := 0
var moved := false

func setup(owner_game: Node3D) -> void:
	game = owner_game
	panel = PanelContainer.new()
	panel.name = "TutorialCard"
	panel.position = Vector2(24,190)
	panel.custom_minimum_size = Vector2(368,0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = game._button_style(Color("183e3b"),Color("8acbb2"),14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",style)
	game.hud.add_child(panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",10)
	panel.add_child(stack)
	heading = game._hud_label("",20,Color("ffe7a2"))
	instruction = game._hud_label("",18,Color("f4faf1"))
	tip = game._hud_label("",15,Color("b3d8cb"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	for label in [heading,instruction,tip]:
		label.add_theme_font_override("font",font)
		label.language = "zh_CN"
		label.custom_minimum_size.x = 332
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(label)
	update()

func update() -> void:
	panel.visible = game.game_started and not game.game_finished and not game.get_tree().paused
	if not panel.visible: return
	var player: IslandPlayer = game.player
	if player.active and player.is_on_floor():
		if player.global_position.distance_to(game.stage_spawn)>2.0: moved = true
		for i in player.get_slide_collision_count():
			var collision := player.get_slide_collision(i)
			if collision.get_normal().y < .5: continue
			var index: int = game.route_surfaces.find(collision.get_collider())
			furthest_landing = maxi(furthest_landing,index)
	# Re-evaluate actions already done so early pickups never leave a stale task.
	if step==0 and moved: step=1
	if step==1 and player.coins>0: step=2
	if step==2 and furthest_landing>=2: step=3
	if step==3 and player.checkpoint_index>=3: step=4
	if step==4 and (game.stars>0 or furthest_landing>=6): step=5
	var move := "WASD / 方向键"
	var jump := "空格"
	var look := "触控板单指滑动或移动鼠标看四周，无需按下；Q 回正，Esc 显示鼠标。"
	if game.device_kind=="gamepad":
		move="左摇杆"
		jump="A 键"
		look="右摇杆转动视角；按下右摇杆回正。"
	elif game.device_kind=="touch":
		move="左侧屏幕摇杆"
		jump="右侧跳跃按钮"
		look="单指滑动画面空白处，可以转动视角。"
	var titles := ["学习移动","拾取金币","试试跳跃","点亮检查点","发现星晶","前往终点"]
	var instructions := [
		"用%s移动，沿地面箭头向前走。" % move,
		"靠近前方的金色硬币，碰到就会自动拾取。",
		"向前移动时按住%s，跨过前方的小缺口，落在下一座岛上。" % jump,
		"走近前方的绿色旗帜，点亮你的复活位置。",
		"碰一碰前方悬浮的星晶。三颗都在主路上，也可以直接前往终点。",
		"继续沿箭头前进，走进旗塔下的光圈，就能解锁第二关。"
	]
	var tips := [look,"金币可以在右上角的衣橱兑换外观。","短按跳得低，长按跳得高。掉落不扣生命，可以再试。","之后掉落会从这里继续；整关重试才会重置。","星晶是可选收集，收齐三颗可获得探索奖章。",look]
	heading.text = "新手教程  %d / 6 · %s" % [step+1,titles[step]]
	instruction.text = instructions[step]
	tip.text = tips[step]
