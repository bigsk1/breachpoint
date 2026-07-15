extends Node

const SAVE_PATHS := preload("res://scripts/core/save_paths.gd")

signal score_changed(score: int)
signal alert_changed(level: float, tier: int)
signal objective_changed(text: String)
signal civilian_count_changed(casualties: int)
signal notification(text: String, tone: String)
signal reinforcement_requested(tier: int)
signal mission_finished(won: bool, report: Dictionary)
signal profile_changed

const SAVE_FILE := "breachpoint_profile.cfg"
const MISSIONS := {
	"bank": "Mesa Bank & Trust",
	"gas_station": "Route 17 Fuel & Service",
	"museum": "Mesa Grand Museum",
	"pawn_shop": "Mesa Exchange Pawn & Loan",
	"zombie_island": "Blacktide Island — Endless Undead",
}
const DIFFICULTIES := ["easy", "medium", "hard"]
const MAX_UPGRADE_RANK := 100
const MAX_LOADOUT_WEAPONS := 3
const WEAPON_ORDER := ["fists", "sidearm", "pipe_wrench", "knife", "chain_bat", "carbine", "smg", "shotgun", "marksman", "bazooka", "flamethrower"]
const WEAPON_CATALOG := {
	"fists": {"title": "Bare Fists", "cost": 0, "weight": 0.0, "description": "Always equipped. Alternate left and right punches."},
	"sidearm": {"title": "VX-9 Sidearm", "cost": 0, "weight": 2.0, "description": "Reliable semi-automatic handgun."},
	"pipe_wrench": {"title": "Heavy Pipe Wrench", "cost": 0, "weight": 2.7, "description": "Weighty overhead melee weapon."},
	"knife": {"title": "Tactical Knife", "cost": 850, "weight": 0.8, "description": "Fast, quiet close-quarters weapon."},
	"chain_bat": {"title": "Gravebreaker Bat", "cost": 0, "weight": 3.8, "description": "Spiked hardwood bat wrapped with a loose striking chain."},
	"carbine": {"title": "K-11 Carbine", "cost": 0, "weight": 3.8, "description": "Balanced automatic rifle."},
	"smg": {"title": "Raptor SMG", "cost": 1800, "weight": 2.9, "description": "High fire rate for close interiors."},
	"shotgun": {"title": "M90 Breacher", "cost": 1300, "weight": 4.6, "description": "Powerful short-range spread."},
	"marksman": {"title": "MESA-7 Marksman", "cost": 2800, "weight": 4.4, "description": "Precision rifle with a strong optic."},
	"bazooka": {"title": "Atlas Launcher", "cost": 7000, "weight": 8.5, "description": "Single-shot explosive launcher. Extremely loud."},
	"flamethrower": {"title": "Cinder-9 Flamethrower", "cost": 8500, "weight": 7.2, "description": "Short-range fuel projector that ignites undead over time."},
}
const SUPPLY_ORDER := ["ammo", "shells", "rockets", "fuel_cell"]
const SUPPLY_CATALOG := {
	"ammo": {"title": "Standard Ammunition", "cost": 250, "quantity": 60, "description": "Sidearm, carbine, SMG, and marksman rounds."},
	"shells": {"title": "12-Gauge Shells", "cost": 300, "quantity": 18, "description": "A field pack for the M90 Breacher."},
	"rockets": {"title": "Launcher Rockets", "cost": 750, "quantity": 3, "description": "Three Atlas Launcher rockets."},
	"fuel_cell": {"title": "Flamethrower Fuel", "cost": 400, "quantity": 120, "description": "Cinder-9 pressurized fuel reserve."},
}

const UPGRADE_BASE_COSTS := {
	"armor": 600,
	"reload": 500,
	"stability": 500,
	"quiet_steps": 450,
	"capacity": 550,
	"punch_power": 400,
}

var score := 0
var alert_level := 0.0
var civilian_casualties := 0
var hostiles_neutralized := 0
var headshots := 0
var shots_fired := 0
var shots_hit := 0
var current_objective := ""
var current_mission := "bank"
var difficulty := "easy"
var run_active := false
var upgrades := {
	"armor": 0,
	"reload": 0,
	"stability": 0,
	"quiet_steps": 0,
	"capacity": 0,
	"punch_power": 0,
}
var owned_weapons := {
	"sidearm": true,
	"pipe_wrench": true,
	"carbine": true,
	"chain_bat": true,
}
var selected_loadout: Array[String] = ["sidearm", "carbine", "pipe_wrench"]
var lifetime_credits := 0
var artifact_stash: Dictionary = {}
var pending_supplies := {"ammo": 0, "shells": 0, "rockets": 0, "fuel_cell": 0}
var _last_tier := 0
var _profile_path := ""

func _ready() -> void:
	_profile_path = SAVE_PATHS.resolve_file(SAVE_FILE)
	_load_profile()

func _process(delta: float) -> void:
	if run_active and alert_level > 0.0:
		var decay := get_difficulty_value(0.72, 0.36, 0.18)
		alert_level = maxf(0.0, alert_level - delta * decay)
		alert_changed.emit(alert_level, get_alert_tier())

func configure_run(mission_id: String, difficulty_id: String) -> void:
	current_mission = mission_id if MISSIONS.has(mission_id) else "bank"
	difficulty = difficulty_id if difficulty_id in DIFFICULTIES else "medium"

func reset_run() -> void:
	score = 0
	alert_level = 0.0
	civilian_casualties = 0
	hostiles_neutralized = 0
	headshots = 0
	shots_fired = 0
	shots_hit = 0
	_last_tier = 0
	run_active = true
	if current_mission == "gas_station":
		set_objective("Enter the gas station and locate the cash register")
	elif current_mission == "museum":
		set_objective("Enter Mesa Grand Museum and locate the antiquities archive")
	elif current_mission == "pawn_shop":
		set_objective("Enter Mesa Exchange and visit the artifact appraisal counter")
	elif current_mission == "zombie_island":
		set_objective("Hold Blacktide Island against endless waves of zombies and skeletons")
	else:
		set_objective("Enter Mesa Bank & Trust and locate the vault")
	score_changed.emit(score)
	alert_changed.emit(alert_level, 0)
	civilian_count_changed.emit(0)

func set_objective(text: String) -> void:
	current_objective = text
	objective_changed.emit(text)

func add_score(amount: int, reason := "") -> void:
	if amount > 0:
		amount = roundi(amount * get_difficulty_value(1.35, 1.0, 1.25))
	score += amount
	score_changed.emit(score)
	if not reason.is_empty():
		notification.emit(("+%d  " % amount if amount >= 0 else "%d  " % amount) + reason, "good" if amount >= 0 else "bad")

func register_shot(_hit := false) -> void:
	shots_fired += 1

func register_hit() -> void:
	shots_hit += 1

func hostile_neutralized(enemy_type: String, headshot: bool) -> void:
	hostiles_neutralized += 1
	var reward: int = int({"Employee": 110, "Security": 150, "Police": 225, "SWAT": 350, "Zombie": 135, "Skeleton": 165}.get(enemy_type, 125))
	if headshot:
		headshots += 1
		reward += 100
	add_score(reward, enemy_type + (" headshot" if headshot else " neutralized"))

func civilian_harmed(killed := true) -> void:
	if killed:
		civilian_casualties += 1
		civilian_count_changed.emit(civilian_casualties)
	add_score(-1500 if killed else -500, "CIVILIAN CASUALTY" if killed else "Civilian wounded")
	raise_alert(35.0, "Collateral damage reported")
	if civilian_casualties >= get_civilian_limit():
		finish_mission(false, "Mission terminated: unacceptable civilian casualties")

func raise_alert(amount: float, reason := "") -> void:
	if not run_active or current_mission == "zombie_island":
		return
	amount *= get_difficulty_value(0.68, 1.0, 1.22)
	alert_level = clampf(alert_level + amount, 0.0, 100.0)
	var tier := get_alert_tier()
	alert_changed.emit(alert_level, tier)
	if not reason.is_empty():
		notification.emit(reason, "warn")
	if tier > _last_tier:
		for crossed_tier in range(_last_tier + 1, tier + 1):
			reinforcement_requested.emit(crossed_tier)
		_last_tier = tier

func get_alert_tier() -> int:
	if alert_level >= 75.0: return 3
	if alert_level >= 45.0: return 2
	if alert_level >= 15.0: return 1
	return 0

func get_difficulty_value(easy_value: float, medium_value: float, hard_value: float) -> float:
	match difficulty:
		"easy": return easy_value
		"hard": return hard_value
		_: return medium_value

func is_easy_mode() -> bool:
	return difficulty == "easy"

func is_hard_mode() -> bool:
	return difficulty == "hard"

func get_difficulty_label() -> String:
	return difficulty.to_upper()

func get_mission_label() -> String:
	return str(MISSIONS.get(current_mission, "Unknown Operation"))

func get_civilian_limit() -> int:
	return int(get_difficulty_value(5.0, 3.0, 2.0))

func get_upgrade_bonus(key: String) -> float:
	# Ranks above ten keep improving the player, with diminishing gameplay returns
	# so rank 100 remains powerful without breaking health, recoil, or reload math.
	var rank := float(upgrades.get(key, 0))
	return rank if rank <= 10.0 else 10.0 + (rank - 10.0) * 0.15

func get_upgrade_cost(key: String) -> int:
	var rank := int(upgrades.get(key, 0))
	var base := int(UPGRADE_BASE_COSTS.get(key, 500))
	return roundi(base * pow(1.065, rank) * (1.0 + rank * 0.055))

func buy_upgrade(key: String, _legacy_cost := 0) -> bool:
	if not upgrades.has(key) or int(upgrades[key]) >= MAX_UPGRADE_RANK:
		return false
	var cost := get_upgrade_cost(key)
	if lifetime_credits < cost:
		return false
	lifetime_credits -= cost
	upgrades[key] = mini(int(upgrades[key]) + 1, MAX_UPGRADE_RANK)
	notification.emit("%s upgraded to rank %d" % [key.replace("_", " ").capitalize(), upgrades[key]], "good")
	_save_profile()
	profile_changed.emit()
	return true

func get_weapon_data(id: String) -> Dictionary:
	return WEAPON_CATALOG.get(id, {}).duplicate(true)

func is_weapon_owned(id: String) -> bool:
	return id == "fists" or bool(owned_weapons.get(id, false))

func buy_weapon(id: String) -> bool:
	if not WEAPON_CATALOG.has(id) or is_weapon_owned(id) or id == "fists":
		return false
	var cost := int(WEAPON_CATALOG[id].cost)
	if lifetime_credits < cost:
		return false
	lifetime_credits -= cost
	owned_weapons[id] = true
	notification.emit("%s purchased" % WEAPON_CATALOG[id].title, "good")
	_save_profile()
	profile_changed.emit()
	return true

func get_supply_data(id: String) -> Dictionary:
	return SUPPLY_CATALOG.get(id, {}).duplicate(true)

func buy_supply(id: String) -> bool:
	if not SUPPLY_CATALOG.has(id):
		return false
	var data: Dictionary = SUPPLY_CATALOG[id]
	var cost := int(data.get("cost", 0))
	if lifetime_credits < cost:
		return false
	lifetime_credits -= cost
	var quantity := int(data.get("quantity", 0))
	pending_supplies[id] = int(pending_supplies.get(id, 0)) + quantity
	notification.emit("%s purchased for the next deployment" % str(data.get("title", "Ammunition")), "good")
	_save_profile()
	profile_changed.emit()
	return true

func take_pending_supplies() -> Dictionary:
	var result := pending_supplies.duplicate(true)
	for id in pending_supplies:
		pending_supplies[id] = 0
	_save_profile()
	return result

func set_weapon_selected(id: String, selected: bool) -> bool:
	if id == "fists" or not is_weapon_owned(id):
		return false
	if selected:
		if id in selected_loadout:
			return true
		if selected_loadout.size() >= MAX_LOADOUT_WEAPONS:
			notification.emit("Loadout full — choose up to %d weapons plus fists" % MAX_LOADOUT_WEAPONS, "warn")
			return false
		selected_loadout.append(id)
	else:
		selected_loadout.erase(id)
	_save_profile()
	profile_changed.emit()
	return true

func store_extracted_artifacts(inventory: InventorySystem) -> int:
	var stored_count := 0
	for slot in inventory.slots:
		if slot.is_empty() or str(slot.get("kind", "")) != "artifact":
			continue
		var id := str(slot.get("id", ""))
		if id.is_empty():
			continue
		var quantity := int(slot.get("quantity", 1))
		var entry: Dictionary = artifact_stash.get(id, {}).duplicate(true)
		entry["title"] = str(slot.get("title", id.replace("_", " ").capitalize()))
		entry["quantity"] = int(entry.get("quantity", 0)) + quantity
		entry["sell_value"] = int(slot.get("sell_value", 500))
		entry["color"] = slot.get("color", Color("#d8b85a"))
		artifact_stash[id] = entry
		stored_count += quantity
	if stored_count > 0:
		_save_profile()
		profile_changed.emit()
		notification.emit("%d extracted artifact%s added to your collection" % [stored_count, "" if stored_count == 1 else "s"], "good")
	return stored_count
	for id in pending_supplies:
		pending_supplies[id] = 0

func get_artifact_totals() -> Dictionary:
	var count := 0
	var value := 0
	for entry_value in artifact_stash.values():
		var entry := entry_value as Dictionary
		var quantity := int(entry.get("quantity", 0))
		count += quantity
		value += quantity * int(entry.get("sell_value", 0))
	return {"count": count, "value": value}

func sell_all_artifacts() -> int:
	var totals := get_artifact_totals()
	var payout := int(totals.value)
	if payout <= 0:
		return 0
	artifact_stash.clear()
	lifetime_credits += payout
	_save_profile()
	profile_changed.emit()
	notification.emit("Artifact sale complete: +$%d cash" % payout, "good")
	return payout

func reset_profile() -> void:
	lifetime_credits = 0
	for key in upgrades:
		upgrades[key] = 0
	owned_weapons.clear()
	for id in ["sidearm", "pipe_wrench", "carbine", "chain_bat"]:
		owned_weapons[id] = true
	selected_loadout.clear()
	for id in ["sidearm", "carbine", "pipe_wrench"]:
		selected_loadout.append(id)
	artifact_stash.clear()
	for id in pending_supplies:
		pending_supplies[id] = 0
	_save_profile()
	profile_changed.emit()
	notification.emit("Progression reset — fresh profile created", "good")

func finish_mission(won: bool, reason := "") -> void:
	if not run_active:
		return
	run_active = false
	var accuracy := 0.0 if shots_fired == 0 else float(shots_hit) / float(shots_fired) * 100.0
	var clean_bonus := int(get_difficulty_value(2000.0, 1500.0, 2200.0)) if civilian_casualties == 0 else 0
	if won:
		score += int(get_difficulty_value(4000.0, 3000.0, 4500.0)) + clean_bonus
		lifetime_credits += maxi(score, 0)
		_save_profile()
		profile_changed.emit()
	var report := {
		"reason": reason,
		"score": score,
		"hostiles": hostiles_neutralized,
		"headshots": headshots,
		"civilians": civilian_casualties,
		"accuracy": accuracy,
		"clean_bonus": clean_bonus,
		"mission": get_mission_label(),
		"difficulty": get_difficulty_label(),
	}
	mission_finished.emit(won, report)

func get_profile_path() -> String:
	return _profile_path

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "credits", lifetime_credits)
	config.set_value("profile", "upgrades", upgrades)
	config.set_value("profile", "owned_weapons", owned_weapons)
	config.set_value("profile", "selected_loadout", selected_loadout)
	config.set_value("profile", "artifact_stash", artifact_stash)
	config.set_value("profile", "pending_supplies", pending_supplies)
	var result := config.save(_profile_path)
	if result != OK:
		push_warning("Could not save progression profile: %s" % error_string(result))

func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(_profile_path) != OK:
		return
	lifetime_credits = int(config.get_value("profile", "credits", 0))
	var stored_upgrades: Dictionary = config.get_value("profile", "upgrades", upgrades)
	for key in upgrades:
		upgrades[key] = clampi(int(stored_upgrades.get(key, upgrades[key])), 0, MAX_UPGRADE_RANK)
	var stored_owned: Dictionary = config.get_value("profile", "owned_weapons", owned_weapons)
	for id in WEAPON_CATALOG:
		if id != "fists" and bool(stored_owned.get(id, owned_weapons.get(id, false))):
			owned_weapons[id] = true
	var stored_loadout: Array = config.get_value("profile", "selected_loadout", selected_loadout)
	selected_loadout.clear()
	for id_value in stored_loadout:
		var id := str(id_value)
		if is_weapon_owned(id) and id != "fists" and selected_loadout.size() < MAX_LOADOUT_WEAPONS:
			selected_loadout.append(id)
	var stored_artifacts: Variant = config.get_value("profile", "artifact_stash", {})
	artifact_stash = stored_artifacts.duplicate(true) if stored_artifacts is Dictionary else {}
	var stored_supplies: Dictionary = config.get_value("profile", "pending_supplies", pending_supplies)
	for id in pending_supplies:
		pending_supplies[id] = maxi(0, int(stored_supplies.get(id, 0)))
