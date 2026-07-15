class_name PlayerController
extends CharacterBody3D

signal health_changed(health: float, armor: float)
signal weapon_changed(name: String, magazine: int, reserve: int)
signal interaction_changed(text: String, progress: float)
signal inventory_changed(inventory: InventorySystem)
signal hit_marker(damage_amount: float, headshot: bool)
signal died
signal ads_changed(active: bool)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.4
const CROUCH_SPEED := 2.8
const JUMP_VELOCITY := 4.7

var health := 100.0
var armor := 50.0
var inventory := InventorySystem.new()
var active_slot := 0
var grenades := 2
var controls_enabled := true
var mission_id := "bank"

var _head: Node3D
var _camera: Camera3D
var _weapon: WeaponBase
var _weapon_mount: Node3D
var _flashlight: SpotLight3D
var _collision: CollisionShape3D
var _is_crouched := false
var _crouch_latched := false
var _look_pitch := 0.0
var _mouse_delta := Vector2.ZERO
var _bob_time := 0.0
var _base_camera_y := 0.72
var _current_weapon_id := "fists"
var _was_ads := false
var _weapon_states := {
	"fists": {"magazine": 0, "reserve": 0},
	"sidearm": {"magazine": 12, "reserve": 72},
	"pipe_wrench": {"magazine": 0, "reserve": 0},
	"knife": {"magazine": 0, "reserve": 0},
	"chain_bat": {"magazine": 0, "reserve": 0},
	"carbine": {"magazine": 30, "reserve": 120},
	"smg": {"magazine": 32, "reserve": 160},
	"shotgun": {"magazine": 6, "reserve": 30},
	"marksman": {"magazine": 10, "reserve": 50},
	"bazooka": {"magazine": 1, "reserve": 4},
	"flamethrower": {"magazine": 80, "reserve": 240},
}
var _interaction_hold := 0.0
var _last_target: Object

func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	_build_rig()
	_seed_inventory()
	_apply_upgrades()
	var starting_weapon := "chain_bat" if mission_id == "zombie_island" else (GameManager.selected_loadout[0] if not GameManager.selected_loadout.is_empty() else "fists")
	_equip_weapon(starting_weapon)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, armor)

func configure_mission(id: String) -> void:
	mission_id = id

func _build_rig() -> void:
	_collision = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.38; capsule.height = 1.8
	_collision.shape = capsule; _collision.position.y = 0.9; add_child(_collision)
	_head = Node3D.new(); _head.name = "Head"; _head.position.y = 1.62; add_child(_head)
	_camera = Camera3D.new(); _camera.name = "Camera"; _camera.fov = float(SettingsManager.get_value("fov", 82.0)); _camera.current = true; _head.add_child(_camera)
	_weapon_mount = Node3D.new(); _weapon_mount.name = "WeaponMount"; _camera.add_child(_weapon_mount)
	_flashlight = SpotLight3D.new(); _flashlight.name = "TacticalLight"; _flashlight.light_energy = 4.2; _flashlight.spot_range = 18.0; _flashlight.spot_angle = 32.0; _flashlight.shadow_enabled = true; _flashlight.visible = false; _camera.add_child(_flashlight)
	_flashlight.position = Vector3(0.18, -0.12, -0.2)

func _seed_inventory() -> void:
	inventory.max_weight = 24.0 + GameManager.get_upgrade_bonus("capacity") * 3.5
	if mission_id == "zombie_island":
		inventory.max_weight += 12.0
	inventory.add_item(InventorySystem.item("fists", "Bare Fists", "weapon", 1, 0.0, false, 1, Color("#c88f6a")))
	for id in GameManager.selected_loadout:
		if not GameManager.is_weapon_owned(id):
			continue
		var data := GameManager.get_weapon_data(id)
		inventory.add_item(InventorySystem.item(id, str(data.get("title", id.capitalize())), "weapon", 1, float(data.get("weight", 2.0)), false, 1, _weapon_color(id)))
	if mission_id == "zombie_island":
		for island_weapon in ["chain_bat", "flamethrower"]:
			if inventory.count_item(island_weapon) > 0:
				continue
			var island_data := GameManager.get_weapon_data(island_weapon)
			inventory.add_item(InventorySystem.item(island_weapon, str(island_data.get("title", island_weapon.capitalize())), "weapon", 1, float(island_data.get("weight", 2.0)), false, 1, _weapon_color(island_weapon)))
	if mission_id == "gas_station":
		grenades = 1
		inventory.add_item(InventorySystem.item("medkit", "Field Medkit", "consumable", 1, 0.8, true, 3, Color("#d45f5f")))
	else:
		inventory.add_item(InventorySystem.item("medkit", "Field Medkit", "consumable", 2, 0.8, true, 3, Color("#d45f5f")))
		inventory.add_item(InventorySystem.item("armor_plate", "Armor Plate", "gear", 2, 1.1, true, 4, Color("#5f84a2")))
	if grenades > 0:
		inventory.add_item(InventorySystem.item("grenade", "Flash-Frag", "tactical", grenades, 0.5, true, 4, Color("#8e9d68")))
	var purchased_supplies := GameManager.take_pending_supplies()
	for ammo_id in purchased_supplies:
		var quantity := int(purchased_supplies[ammo_id])
		if quantity > 0:
			inventory.add_item(InventorySystem.ammo_item(str(ammo_id), quantity))
	inventory.changed.connect(func(): inventory_changed.emit(inventory))
	inventory.capacity_reached.connect(func(): GameManager.notification.emit("Inventory capacity reached", "warn"))

func _weapon_color(id: String) -> Color:
	return {
		"fists": Color("#c88f6a"),
		"sidearm": Color("#c2b280"),
		"pipe_wrench": Color("#a7b0b0"),
		"knife": Color("#b7c3c7"),
		"chain_bat": Color("#8f6b43"),
		"carbine": Color("#8fa4ad"),
		"smg": Color("#758f99"),
		"shotgun": Color("#a18b61"),
		"marksman": Color("#8f8b74"),
		"bazooka": Color("#68784f"),
		"flamethrower": Color("#d06a32"),
	}.get(id, Color.WHITE)

func _apply_upgrades() -> void:
	armor = GameManager.get_difficulty_value(90.0, 55.0, 35.0) + GameManager.get_upgrade_bonus("armor") * 10.0

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := float(SettingsManager.get_value("mouse_sensitivity", 0.11))
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		_look_pitch = clampf(_look_pitch - deg_to_rad(event.relative.y * sensitivity), deg_to_rad(-86.0), deg_to_rad(86.0))
		_mouse_delta = event.relative
	if event.is_action_pressed("flashlight"):
		_flashlight.visible = not _flashlight.visible
	if event.is_action_pressed("reload"):
		_weapon.start_reload()
	if event.is_action_pressed("grenade"):
		_throw_grenade()
	if event.is_action_pressed("melee"):
		_melee()
	if event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	if event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)
	for i in range(9):
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select_hotbar(i)

func _physics_process(delta: float) -> void:
	if not controls_enabled or not GameManager.run_active:
		velocity = Vector3.ZERO
		return
	_process_controller_look(delta)
	_process_crouch()
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouched:
		velocity.y = JUMP_VELOCITY
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and input.y < -0.2 and not _is_crouched
	var speed := CROUCH_SPEED if _is_crouched else (SPRINT_SPEED if sprinting else WALK_SPEED)
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * speed, delta * 24.0)
		velocity.z = move_toward(velocity.z, direction.z * speed, delta * 24.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 18.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 18.0)
	move_and_slide()
	_update_camera_feel(delta, input, sprinting)
	_process_weapon(delta, sprinting)
	_process_interaction(delta)

func _process_controller_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() < 0.05:
		return
	var sensitivity := float(SettingsManager.get_value("controller_sensitivity", 2.4))
	rotate_y(-look.x * sensitivity * delta)
	_look_pitch = clampf(_look_pitch - look.y * sensitivity * delta, deg_to_rad(-86.0), deg_to_rad(86.0))

func _process_crouch() -> void:
	var toggle := bool(SettingsManager.get_value("toggle_crouch", true))
	if toggle:
		if Input.is_action_just_pressed("crouch"):
			_crouch_latched = not _crouch_latched
		_is_crouched = _crouch_latched
	else:
		_is_crouched = Input.is_action_pressed("crouch")
	var target_height := 1.15 if _is_crouched else 1.8
	var capsule := _collision.shape as CapsuleShape3D
	capsule.height = move_toward(capsule.height, target_height, 0.08)
	_head.position.y = move_toward(_head.position.y, 1.05 if _is_crouched else 1.62, 0.08)

func _update_camera_feel(delta: float, input: Vector2, sprinting: bool) -> void:
	_head.rotation.x = _look_pitch
	var moving := input.length() > 0.1 and is_on_floor()
	if moving:
		_bob_time += delta * (12.5 if sprinting else 9.0)
	var motion_scale := 0.25 if bool(SettingsManager.get_value("reduced_motion", false)) else 1.0
	var bob := Vector3(cos(_bob_time * 0.5) * 0.025, sin(_bob_time) * 0.035, 0.0) * motion_scale if moving else Vector3.ZERO
	_camera.position = _camera.position.lerp(bob, delta * 10.0)
	var ads_active := Input.is_action_pressed("ads") and _weapon and _weapon.uses_scope()
	var target_fov := float(SettingsManager.get_value("fov", 82.0)) + (5.0 if sprinting else 0.0)
	if ads_active:
		target_fov -= 26.0 if _weapon.weapon_id == "marksman" else 15.0
	if ads_active != _was_ads:
		_was_ads = ads_active
		ads_changed.emit(ads_active)
	_camera.fov = lerpf(_camera.fov, target_fov, delta * 10.0)
	var sway_scale := 0.00035 * motion_scale
	_weapon_mount.rotation.y = lerpf(_weapon_mount.rotation.y, -_mouse_delta.x * sway_scale, delta * 14.0)
	_weapon_mount.rotation.x = lerpf(_weapon_mount.rotation.x, -_mouse_delta.y * sway_scale, delta * 14.0)
	var ads_pos := _weapon.get_ads_offset() if ads_active else Vector3.ZERO
	_weapon_mount.position = _weapon_mount.position.lerp(ads_pos, delta * 12.0)
	_mouse_delta = _mouse_delta.lerp(Vector2.ZERO, delta * 14.0)

func _process_weapon(_delta: float, sprinting: bool) -> void:
	if sprinting or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var wants_fire := Input.is_action_pressed("fire") if _weapon.automatic else Input.is_action_just_pressed("fire")
	if wants_fire and _weapon.try_fire():
		var kick := 0.0 if _weapon.is_melee else (0.018 if _weapon.weapon_id == "flamethrower" else (0.095 if _weapon.weapon_id == "bazooka" else (0.075 if _weapon.weapon_id == "shotgun" else (0.052 if _weapon.weapon_id == "marksman" else (0.033 if _weapon.weapon_id in ["carbine", "smg"] else 0.038)))))
		_look_pitch = clampf(_look_pitch + kick, deg_to_rad(-86.0), deg_to_rad(86.0))
		if mission_id == "zombie_island":
			return
		var quiet_bonus := GameManager.get_upgrade_bonus("quiet_steps") * 0.9
		if _weapon.is_melee:
			GameManager.raise_alert(4.0 if _weapon.weapon_id in ["fists", "knife"] else 6.0, "Close-quarters struggle")
		elif _weapon.is_explosive:
			GameManager.raise_alert(48.0, "Explosion reported")
		else:
			GameManager.raise_alert(maxf(2.0, (4.0 if _weapon.suppressed else 10.0) - quiet_bonus), "Gunfire detected")

func _process_interaction(delta: float) -> void:
	var target: Object = _find_interactable()
	if target != _last_target:
		_interaction_hold = 0.0
		_last_target = target
	if target == null:
		interaction_changed.emit("", 0.0)
		return
	var label: String = str(target.get_interaction_text(self)) if target.has_method("get_interaction_text") else "INTERACT"
	if Input.is_action_pressed("interact"):
		_interaction_hold += delta
		interaction_changed.emit(label, clampf(_interaction_hold / 0.45, 0.0, 1.0))
		if _interaction_hold >= 0.45:
			target.interact(self)
			_interaction_hold = 0.0
	else:
		_interaction_hold = 0.0
		interaction_changed.emit(label, 0.0)

func _find_interactable() -> Object:
	var origin := _camera.global_position
	var direction := -_camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 3.2)
	query.collision_mask = 4
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return null
	var collider: Object = result.collider
	if collider.has_method("interact"): return collider
	if collider is Node and collider.get_parent().has_method("interact"): return collider.get_parent()
	return null

func _equip_weapon(id: String) -> void:
	if _weapon:
		_weapon_states[_current_weapon_id] = {"magazine": _weapon.magazine, "reserve": _weapon.reserve}
		_weapon.queue_free()
	_current_weapon_id = id
	_weapon = WeaponBase.new()
	_weapon.owner_player = self; _weapon.camera = _camera
	_weapon.configure(id)
	var state: Dictionary = _weapon_states.get(id, {})
	_weapon.magazine = int(state.get("magazine", _weapon.magazine))
	_weapon.reserve = int(state.get("reserve", _weapon.reserve))
	_weapon_mount.add_child(_weapon)
	_weapon.ammo_changed.connect(func(mag: int, res: int): weapon_changed.emit(_weapon.display_name, mag, res))
	_weapon.hit_confirmed.connect(func(damage_amount: float, headshot: bool): hit_marker.emit(damage_amount, headshot))
	weapon_changed.emit(_weapon.display_name, _weapon.magazine, _weapon.reserve)

func _cycle_weapon(direction: int) -> void:
	var available: Array[String] = []
	for id in GameManager.WEAPON_ORDER:
		if inventory.count_item(id) > 0:
			available.append(id)
	if available.is_empty():
		return
	var index := available.find(_current_weapon_id)
	if index < 0:
		index = 0
	_equip_weapon(available[posmod(index + direction, available.size())])

func select_hotbar(index: int) -> void:
	active_slot = index
	if index >= inventory.slots.size() or inventory.slots[index].is_empty():
		return
	var item: Dictionary = inventory.slots[index]
	if item.get("kind", "") == "weapon":
		_equip_weapon(item.id)
	elif item.get("kind", "") == "ammo":
		_use_ammo_slot(index)
	else:
		if inventory.use_slot(index, self):
			GameManager.notification.emit("%s used" % str(item.get("title", "Item")), "good")
		elif str(item.get("kind", "")) in ["consumable", "gear"]:
			GameManager.notification.emit("%s not needed — health or armor is already full" % str(item.get("title", "Item")), "warn")

func _use_ammo_slot(index: int) -> void:
	var item: Dictionary = inventory.slots[index]
	var compatible_weapons: Array = item.get("compatible_weapons", [])
	if not _weapon or _weapon.is_melee or _current_weapon_id not in compatible_weapons:
		GameManager.notification.emit("%s is not compatible with the equipped weapon" % str(item.get("title", "Ammo")), "warn")
		return
	var amount := int(item.get("quantity", 0))
	if amount <= 0:
		return
	_weapon.add_ammo(amount)
	inventory.remove_item(str(item.get("id", "")), amount)
	GameManager.notification.emit("%d %s added to %s reserves" % [amount, str(item.get("title", "rounds")), _weapon.display_name], "good")

func _throw_grenade() -> void:
	if inventory.remove_item("grenade", 1) <= 0:
		GameManager.notification.emit("No tactical grenades", "warn")
		return
	var grenade := TacticalGrenade.new()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = _camera.global_position + -_camera.global_basis.z * 0.7
	grenade.linear_velocity = -_camera.global_basis.z * 13.0 + Vector3.UP * 3.0

func _melee() -> void:
	var origin := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -_camera.global_basis.z * 2.15)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("take_damage"):
		var rank := GameManager.get_upgrade_bonus("punch_power")
		hit.collider.take_damage(34.0 + rank * 7.0, false, self)
		if hit.collider.has_method("apply_knockback"):
			hit.collider.apply_knockback(-_camera.global_basis.z * (2.0 + rank))
		GameManager.raise_alert(5.0, "Close-quarters struggle")

func add_loot(item: Dictionary) -> bool:
	var original := int(item.get("quantity", 1))
	var remaining := inventory.add_item(item)
	if remaining < original:
		var secured := original - remaining
		GameManager.add_score(25 * secured, "Loot secured")
		return true
	return false

func heal(amount: float) -> bool:
	if health >= 100.0: return false
	health = minf(100.0, health + amount); health_changed.emit(health, armor); return true

func restore_armor(amount: float) -> bool:
	var max_armor := GameManager.get_difficulty_value(90.0, 55.0, 35.0) + GameManager.get_upgrade_bonus("armor") * 10.0
	if armor >= max_armor: return false
	armor = minf(max_armor, armor + amount); health_changed.emit(health, armor); return true

func take_damage(amount: float, _headshot := false, _source: Object = null) -> void:
	if not GameManager.run_active: return
	amount *= GameManager.get_difficulty_value(0.58, 1.0, 1.25)
	var absorbed := minf(armor, amount * 0.62)
	armor -= absorbed
	health -= amount - absorbed
	health_changed.emit(maxf(health, 0.0), armor)
	if health <= 0.0:
		controls_enabled = false
		died.emit()

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE

func get_current_weapon_id() -> String:
	return _current_weapon_id

func get_camera() -> Camera3D:
	return _camera

func get_inventory() -> InventorySystem:
	return inventory

func emit_status() -> void:
	health_changed.emit(health, armor)
	if _weapon:
		weapon_changed.emit(_weapon.display_name, _weapon.magazine, _weapon.reserve)
