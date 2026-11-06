extends Node

const STYLES = preload("res://scripts/skin_style.gd")
const SAVE_PATH := "user://island_wardrobe.cfg"
signal changed
var balance := 0
var owned: Array[String] = ["classic"]
var equipped := "classic"
var save_enabled := true
var save_path := SAVE_PATH
var infinite_coins := true
const INFINITE_BALANCE := 999999999

func _ready() -> void:
	# Automated runs never write the real wallet, including old physics tests.
	save_enabled = not ("--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args())
	infinite_coins = save_enabled
	load_wallet()

func load_wallet() -> void:
	var file := ConfigFile.new()
	balance=INFINITE_BALANCE if infinite_coins else 0
	owned=["classic"]
	equipped="classic"
	if file.load(save_path) == OK:
		if not infinite_coins:
			balance=maxi(0,int(file.get_value("wallet","balance",0)))
		var saved_owned = file.get_value("wallet","owned",[])
		if saved_owned is Array or saved_owned is PackedStringArray:
			for id in saved_owned:
				if id is String and STYLES.get_skin(id).id==id and not owned.has(id): owned.append(id)
		var chosen: String = str(file.get_value("wallet","equipped","classic"))
		if owned.has(chosen): equipped=chosen
	elif not infinite_coins:
		# One-time welcome credit for coins already in the old stage records.
		balance=Campaign.total_collected()
		save_wallet()
	if infinite_coins:
		balance=INFINITE_BALANCE
	changed.emit()

func save_wallet() -> bool:
	if not save_enabled: return true
	if infinite_coins: balance=INFINITE_BALANCE
	var file := ConfigFile.new()
	file.set_value("wallet","balance",balance)
	file.set_value("wallet","owned",owned)
	file.set_value("wallet","equipped",equipped)
	var temporary := save_path+".tmp"
	if file.save(temporary)!=OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_path))==OK

func earn(amount: int) -> bool:
	if amount<=0: return false
	if infinite_coins:
		balance=INFINITE_BALANCE
		save_wallet()
		changed.emit()
		return true
	balance+=amount
	if not save_wallet():
		balance-=amount
		return false
	changed.emit()
	return true

func purchase(id: String) -> String:
	var skin := STYLES.get_skin(id)
	if skin.id!=id: return "这款皮肤不存在"
	if owned.has(id): return equip(id)
	if infinite_coins:
		var previous := equipped
		owned.append(id)
		equipped=id
		if not save_wallet():
			owned.erase(id)
			equipped=previous
			return "保存失败，请重试"
		changed.emit()
		return "兑换成功，已穿上「%s」" % skin.name
	if balance<int(skin.price): return "还差 %d 枚金币" % (int(skin.price)-balance)
	var previous := equipped
	balance-=int(skin.price)
	owned.append(id)
	equipped=id
	if not save_wallet():
		balance+=int(skin.price)
		owned.erase(id)
		equipped=previous
		return "保存失败，未扣除金币，请重试"
	changed.emit()
	return "兑换成功，已穿上「%s」" % skin.name

func equip(id: String) -> String:
	if not owned.has(id): return "请先兑换这款皮肤"
	var previous := equipped
	equipped=id
	if not save_wallet():
		equipped=previous
		return "保存失败，请重试"
	changed.emit()
	return "已穿上「%s」" % STYLES.get_skin(id).name
