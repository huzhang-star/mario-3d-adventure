extends Node

const STYLES = preload("res://scripts/skin_style.gd")
const SAVE_PATH := "user://adventure_wardrobe_v2.cfg"
var legacy_path := "user://island_wardrobe.cfg"
var award_claims: Dictionary = {}
signal changed
var balance := 0
var owned: Array[String] = ["classic"]
var equipped := "classic"
var save_enabled := true
var save_path := SAVE_PATH
var infinite_coins := false
const INFINITE_BALANCE := 999999999

func _ready() -> void:
	# Automated runs never write the real wallet, including old physics tests.
	save_enabled = not ("--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args())
	load_wallet()
	set_free_mode(Campaign.unlock_all_levels)

func load_wallet() -> void:
	var file := ConfigFile.new()
	award_claims = {}
	balance=INFINITE_BALANCE if infinite_coins else 0
	owned=["classic"]
	equipped="classic"
	var loaded := file.load(save_path)
	var migrating := false
	if loaded != OK and save_path == SAVE_PATH and save_enabled:
		loaded = file.load(legacy_path)
		migrating = loaded == OK
	if loaded == OK:
		if not infinite_coins:
			balance=maxi(0,int(file.get_value("wallet","balance",0)))
			if migrating and balance >= INFINITE_BALANCE: balance=Campaign.total_collected()
		var claims = file.get_value("wallet","claims",{})
		if claims is Dictionary: award_claims = claims
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
	if migrating: save_wallet()
	if infinite_coins:
		balance=INFINITE_BALANCE
	changed.emit()

func save_wallet() -> bool:
	if not save_enabled or infinite_coins: return true
	var file := ConfigFile.new()
	file.set_value("wallet","balance",balance)
	file.set_value("wallet","owned",owned)
	file.set_value("wallet","equipped",equipped)
	file.set_value("wallet","claims",award_claims)
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

func set_free_mode(_enabled: bool) -> void:
	infinite_coins = false
	load_wallet()
	changed.emit()

func completion_reward(stars: int, fast: bool) -> Dictionary:
	var index: int = Campaign.level_index
	var claims: Dictionary = {}
	if not Campaign.completed[index]: claims["first_%d" % index] = 75
	for i in range(Campaign.stars_by_level[index], stars): claims["star_%d_%d" % [index,i]] = 25
	if fast and not Campaign.speed_medals[index]: claims["speed_%d" % index] = 35
	var amount := 30 + int(index/10)*5
	var actual: Dictionary = {}
	for key in claims:
		if not award_claims.has(key):
			amount += int(claims[key])
			actual[key] = claims[key]
	return {"coins": amount, "claims": actual}

func grant_completion(reward: Dictionary, total_stars: int) -> bool:
	if infinite_coins: return true
	var old_balance := balance
	var old_owned := owned.duplicate()
	var old_claims := award_claims.duplicate()
	balance += int(reward.coins)
	for key in reward.claims: award_claims[key] = true
	for milestone in [[9,"mint"],[30,"witch"],[75,"astral"]]:
		if total_stars >= int(milestone[0]) and not owned.has(milestone[1]): owned.append(milestone[1])
	if not save_wallet():
		balance = old_balance
		owned = old_owned
		award_claims = old_claims
		return false
	changed.emit()
	return true
