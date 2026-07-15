extends Node

const SAVE_PATHS := preload("res://scripts/core/save_paths.gd")

var ui: GameUI
var level: Node3D
var player: PlayerController
var music: AmbientMusic

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = GameUI.new()
	add_child(ui)
	ui.deploy_requested.connect(start_operation)
	ui.quit_to_menu_requested.connect(return_to_menu)
	GameManager.mission_finished.connect(_on_mission_finished)
	if "--progression-smoke" in OS.get_cmdline_user_args():
		_smoke_progression.call_deferred()
	if "--portable-storage-smoke" in OS.get_cmdline_user_args():
		_smoke_portable_storage.call_deferred()
	if "--controller-ui-smoke" in OS.get_cmdline_user_args():
		_smoke_controller_ui.call_deferred()
	if "--smoke-test" in OS.get_cmdline_user_args():
		var smoke_map := "bank"
		var smoke_difficulty := "easy"
		var smoke_loadout: Array[String] = []
		var smoke_fire := "--fire-smoke" in OS.get_cmdline_user_args()
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--map="):
				smoke_map = argument.trim_prefix("--map=")
			elif argument.begins_with("--difficulty="):
				smoke_difficulty = argument.trim_prefix("--difficulty=")
			elif argument.begins_with("--loadout="):
				for id in argument.trim_prefix("--loadout=").split(","):
					smoke_loadout.append(id)
		if not smoke_loadout.is_empty():
			GameManager.selected_loadout.clear()
			for id in smoke_loadout:
				if id == "fists":
					continue
				GameManager.owned_weapons[id] = true
				if GameManager.selected_loadout.size() < GameManager.MAX_LOADOUT_WEAPONS:
					GameManager.selected_loadout.append(id)
		start_operation.call_deferred(smoke_map, smoke_difficulty)
		if smoke_fire:
			_smoke_fire_selected.call_deferred()
		if "--boot-smoke" in OS.get_cmdline_user_args():
			_smoke_map_boot.call_deferred()
		if "--zombie-smoke" in OS.get_cmdline_user_args():
			_smoke_zombie_mode.call_deferred()
		if "--gas-smoke" in OS.get_cmdline_user_args():
			_smoke_gas_getaway.call_deferred()
		if "--door-smoke" in OS.get_cmdline_user_args():
			_smoke_vault_collision.call_deferred()

func _smoke_portable_storage() -> void:
	await get_tree().process_frame
	var profile_path := GameManager.get_profile_path()
	var settings_path := SettingsManager.get_settings_path()
	assert(SAVE_PATHS.is_portable_path(profile_path))
	assert(SAVE_PATHS.is_portable_path(settings_path))
	GameManager.reset_profile()
	GameManager.lifetime_credits = 4321
	GameManager._save_profile()
	SettingsManager.set_value("mouse_sensitivity", 0.17)
	var profile := ConfigFile.new()
	var settings := ConfigFile.new()
	assert(profile.load(profile_path) == OK)
	assert(settings.load(settings_path) == OK)
	assert(int(profile.get_value("profile", "credits", 0)) == 4321)
	assert(is_equal_approx(float(settings.get_value("settings", "mouse_sensitivity", 0.0)), 0.17))
	print("PORTABLE_STORAGE_SMOKE_OK profile and settings saved beside the game")
	get_tree().quit()

func _smoke_map_boot() -> void:
	await get_tree().create_timer(1.8).timeout
	assert(is_instance_valid(level))
	assert(is_instance_valid(player))
	assert(GameManager.run_active)
	print("MAP_BOOT_SMOKE_OK %s" % player.mission_id)
	return_to_menu()
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()

func _smoke_fire_selected() -> void:
	await get_tree().create_timer(0.8).timeout
	Input.action_press("fire")
	await get_tree().create_timer(0.18).timeout
	Input.action_release("fire")

func _smoke_vault_collision() -> void:
	await get_tree().create_timer(1.0).timeout
	assert(level is BankLevel)
	var vault: InteractableDoor
	for candidate in level.find_children("*", "InteractableDoor", true, false):
		var door := candidate as InteractableDoor
		if door and door.is_vault:
			vault = door
			break
	assert(vault)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.55, -40.0), Vector3(0, 1.55, -46.0))
	query.collision_mask = 1 | 4
	query.exclude = [player.get_rid()]
	var closed_hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not closed_hit.is_empty() and closed_hit.collider == vault)
	var guard := ActorAI.new()
	guard.configure(ActorAI.Kind.SECURITY, Vector3(0, 0, -45.2))
	level.add_child(guard)
	await get_tree().physics_frame
	guard.set_physics_process(false)
	for other_actor in get_tree().get_nodes_in_group("actors"):
		if other_actor == guard:
			continue
		other_actor.set_physics_process(false)
		if other_actor is CollisionObject3D:
			(other_actor as CollisionObject3D).collision_layer = 0
	player.global_position = Vector3(0, 0, -40.0)
	guard.global_position = Vector3(0, 0, -45.2)
	assert((guard.collision_mask & 4) != 0)
	assert(not guard._has_line_of_sight())
	var hostile_start := Vector3(0, 1.55, -45.2)
	var hostile_aim := Vector3(0, 1.55, -40.0)
	var protection_before := player.health + player.armor
	var impacts_before := get_tree().get_nodes_in_group("hostile_bullet_impacts").size()
	var blocked_round := guard._resolve_hostile_round(hostile_start, hostile_aim, 20.0)
	assert(not blocked_round.is_empty() and blocked_round.collider == vault)
	assert(is_equal_approx(player.health + player.armor, protection_before))
	assert(get_tree().get_nodes_in_group("hostile_bullet_impacts").size() > impacts_before)
	assert(not guard._request_door_open(vault))
	vault.locked_item_id = ""
	assert(not guard._request_door_open(vault))
	var regular_door := InteractableDoor.new()
	regular_door.display_name = "Test office door"
	regular_door.setup(Vector3(2.4, 2.5, 0.18), Color("#6f5948"))
	regular_door.position = Vector3(12.0, 1.25, -40.0)
	level.add_child(regular_door)
	assert(guard._request_door_open(regular_door))
	assert(regular_door.is_open)
	regular_door.queue_free()
	vault.interact(player)
	await get_tree().create_timer(0.7).timeout
	player.global_position = Vector3(0, 0, -40.0)
	guard.global_position = Vector3(0, 0, -45.2)
	await get_tree().physics_frame
	var open_hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	assert(open_hit.is_empty() or open_hit.collider != vault)
	var exposed_before := player.health + player.armor
	var exposed_aim := player.global_position + Vector3.UP * 1.55
	var exposed_round := guard._resolve_hostile_round(hostile_start, exposed_aim, 20.0)
	assert(not exposed_round.is_empty() and exposed_round.collider == player)
	assert(player.health + player.armor < exposed_before)
	print("VAULT_DOOR_SMOKE_OK vault blocks player and hostile rounds; wall impacts spawn; breached doorway clears")
	return_to_menu()
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()

func _smoke_gas_getaway() -> void:
	await get_tree().create_timer(1.2).timeout
	assert(level is GasStationLevel)
	var gas := level as GasStationLevel
	assert(gas._key_spawn_index >= 0 and gas._key_spawn_index < 5)
	assert(is_instance_valid(gas._key_cache) and is_instance_valid(gas._car))
	assert(player.inventory.count_item("route17_car_keys") == 0)
	gas._car.interact(player)
	assert(not gas._escaped)
	player._equip_weapon("fists")
	gas._key_cache.take_damage(200.0, false, player)
	assert(gas._key_cache.broken)
	gas._key_cache.interact(player)
	assert(gas._keys_found)
	assert(player.inventory.count_item("route17_car_keys") == 1)
	var register: ObjectiveStation
	for candidate in gas.find_children("*", "ObjectiveStation", true, false):
		var station := candidate as ObjectiveStation
		if station and station.display_name == "Cash register":
			register = station
			break
	assert(register)
	register.interact(player)
	assert(gas._register_robbed)
	gas._car.interact(player)
	assert(gas._escaped and gas._car.driving)
	await get_tree().create_timer(2.9).timeout
	assert(not GameManager.run_active)
	print("GAS_GETAWAY_SMOKE_OK randomized breakable keys, locked car, register gate, and drive-away extraction")
	get_tree().quit()

func _smoke_zombie_mode() -> void:
	await get_tree().create_timer(3.2).timeout
	assert(level is ZombieIslandLevel)
	assert((level as ZombieIslandLevel).wave >= 1)
	assert(get_tree().get_nodes_in_group("undead").size() > 0)
	var skeleton := UndeadAI.new()
	skeleton.configure(UndeadAI.Kind.SKELETON, Vector3(10.0, 0.25, 10.0), 1)
	level.add_child(skeleton)
	await get_tree().process_frame
	skeleton.set_physics_process(false)
	assert(is_instance_valid(skeleton._jaw))
	var rib_count := 0
	for mesh_node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh is TorusMesh:
			rib_count += 1
	assert(rib_count >= 5)
	assert(skeleton.max_health > 70.0)
	assert(player.inventory.count_item("chain_bat") == 1)
	assert(player.inventory.count_item("flamethrower") == 1)
	player._equip_weapon("flamethrower")
	var ammo_before := player._weapon.magazine
	assert(player._weapon.try_fire())
	await get_tree().create_timer(0.3).timeout
	assert(player._weapon.magazine < ammo_before)
	print("ZOMBIE_MODE_SMOKE_OK wave spawning, scary articulated skeleton, island kit, bat, and flamethrower")
	return_to_menu()
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()

func _smoke_controller_ui() -> void:
	await get_tree().process_frame
	start_operation("bank", "easy")
	await get_tree().process_frame
	await get_tree().process_frame
	var headless_input_test := DisplayServer.get_name() == "headless"
	if not headless_input_test:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	var yaw_before_mouse := player.rotation.y
	var pitch_before_mouse := player._look_pitch
	var physical_mouse := InputEventMouseMotion.new()
	physical_mouse.relative = Vector2(32.0, -18.0)
	if headless_input_test:
		player._apply_mouse_look(physical_mouse.relative)
	else:
		Input.parse_input_event(physical_mouse)
	await get_tree().process_frame
	assert(not is_equal_approx(player.rotation.y, yaw_before_mouse))
	assert(not is_equal_approx(player._look_pitch, pitch_before_mouse))
	assert(is_instance_valid(music) and music.playing and music.bus == &"Music")
	var music_bus := AudioServer.get_bus_index("Music")
	assert(music_bus >= 0)
	SettingsManager.set_value("music_enabled", false)
	assert(AudioServer.is_bus_mute(music_bus))
	SettingsManager.set_value("music_enabled", true)
	assert(not AudioServer.is_bus_mute(music_bus))
	player.health = 35.0
	var medkit_index := -1
	for index in player.inventory.slots.size():
		if str(player.inventory.slots[index].get("id", "")) == "medkit":
			medkit_index = index
			break
	assert(medkit_index >= 0)
	var medkits_before := player.inventory.count_item("medkit")
	ui.set_inventory_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var focused_slot := get_viewport().gui_get_focus_owner() as InventorySlotUI
	assert(focused_slot and focused_slot.slot_index == 0)
	var focused_style := focused_slot.get_theme_stylebox("panel") as StyleBoxFlat
	assert(focused_style and focused_style.border_width_left == 5)
	assert(focused_slot._number.text.begins_with("▶"))
	var physical_stick := InputEventJoypadMotion.new()
	physical_stick.device = 0
	physical_stick.axis = JOY_AXIS_LEFT_X
	for _step in medkit_index:
		physical_stick.axis_value = 1.0
		Input.parse_input_event(physical_stick)
		await get_tree().process_frame
		physical_stick.axis_value = 0.0
		Input.parse_input_event(physical_stick)
		await get_tree().process_frame
	var medkit_slot := ui._inventory_grid.get_child(medkit_index) as InventorySlotUI
	assert(get_viewport().gui_get_focus_owner() == medkit_slot)
	var physical_accept := InputEventJoypadButton.new()
	physical_accept.device = 0
	physical_accept.button_index = JOY_BUTTON_A
	physical_accept.pressed = true
	Input.parse_input_event(physical_accept)
	await get_tree().process_frame
	physical_accept.pressed = false
	Input.parse_input_event(physical_accept)
	await get_tree().process_frame
	assert(player.inventory.count_item("medkit") == medkits_before - 1)
	assert(player.health > 35.0)
	player._equip_weapon("sidearm")
	player._weapon.reserve = 0
	player.inventory.add_item(InventorySystem.ammo_item("ammo", 20))
	assert(player.inventory.count_item("ammo") == 20)
	var ammo_index := -1
	for index in player.inventory.slots.size():
		if str(player.inventory.slots[index].get("id", "")) == "ammo":
			ammo_index = index
			break
	assert(ammo_index > medkit_index)
	for _step in ammo_index - medkit_index:
		ui._move_inventory_focus(Vector2i.RIGHT)
	assert((get_viewport().gui_get_focus_owner() as InventorySlotUI).slot_index == ammo_index)
	assert(ui._activate_focused_inventory_slot())
	await get_tree().process_frame
	assert(player._weapon.reserve == 20)
	assert(player.inventory.count_item("ammo") == 0)
	ui.set_inventory_open(false)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	GameManager.finish_mission(true, "Controller regression extraction")
	await get_tree().process_frame
	await get_tree().process_frame
	var report_focus := get_viewport().gui_get_focus_owner() as Button
	assert(report_focus and report_focus.text == "RUN IT AGAIN")
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	down.pressed = false
	Input.parse_input_event(down)
	report_focus = get_viewport().gui_get_focus_owner() as Button
	assert(report_focus and report_focus.text == "RETURN TO MAIN MENU")
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	Input.parse_input_event(up)
	await get_tree().process_frame
	up.pressed = false
	Input.parse_input_event(up)
	accept.pressed = true
	Input.parse_input_event(accept)
	await get_tree().process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	await get_tree().process_frame
	assert(GameManager.run_active)
	print("INPUT_UI_SMOKE_OK mouse look, left-stick inventory navigation, consumable and ammo use, music toggle, report navigation, and replay selection")
	return_to_menu()
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()

func _smoke_progression() -> void:
	await get_tree().process_frame
	assert(_has_joy_button("ui_accept", JOY_BUTTON_A))
	assert(_has_joy_button("ui_cancel", JOY_BUTTON_B))
	assert(_has_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0))
	assert(_has_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0))
	assert(ui._cash.text.begins_with("CASH  $"))
	GameManager.reset_profile()
	assert(GameManager.lifetime_credits == 0)
	assert(GameManager.artifact_stash.is_empty())
	GameManager.lifetime_credits = 2000000000
	ui._buy_supply("ammo")
	assert(int(GameManager.pending_supplies.ammo) == int(GameManager.SUPPLY_CATALOG.ammo.quantity))
	assert(GameManager.lifetime_credits < 2000000000)
	for _rank in GameManager.MAX_UPGRADE_RANK:
		ui._buy_upgrade("armor")
	for key in GameManager.UPGRADE_BASE_COSTS:
		if str(key) == "armor":
			continue
		for _rank in 8:
			ui._buy_upgrade(str(key))
	for id in GameManager.WEAPON_ORDER:
		ui._buy_weapon(str(id))
	var extraction_inventory := InventorySystem.new()
	extraction_inventory.add_item(InventorySystem.artifact("smoke_artifact", "QA Artifact", 1234, 0.2, Color.WHITE))
	assert(GameManager.store_extracted_artifacts(extraction_inventory) == 1)
	assert(int(GameManager.get_artifact_totals().value) == 1234)
	assert(GameManager.sell_all_artifacts() == 1234)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(int(GameManager.upgrades.armor) == GameManager.MAX_UPGRADE_RANK)
	GameManager.reset_profile()
	assert(GameManager.lifetime_credits == 0)
	assert(GameManager.artifact_stash.is_empty())
	assert(int(GameManager.upgrades.armor) == 0)
	print("PROGRESSION_SMOKE_OK ammo purchase, controller UI, cash HUD, rank100, artifact sale, and fresh reset")
	get_tree().quit()

func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _has_joy_axis(action: StringName, axis: JoyAxis, value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, value):
			return true
	return false

func start_operation(map_id := "", difficulty_id := "") -> void:
	if map_id.is_empty():
		map_id = str(SettingsManager.get_value("selected_map", "bank"))
	if difficulty_id.is_empty():
		difficulty_id = str(SettingsManager.get_value("difficulty", "easy"))
	SettingsManager.set_value("selected_map", map_id, false)
	SettingsManager.set_value("difficulty", difficulty_id)
	_cleanup_operation()
	get_tree().paused = false
	GameManager.configure_run(map_id, difficulty_id)
	GameManager.reset_run()
	match map_id:
		"zombie_island":
			level = ZombieIslandLevel.new()
			level.name = "BlacktideIsland"
		"museum":
			level = MuseumLevel.new()
			level.name = "MesaGrandMuseum"
		"gas_station":
			level = GasStationLevel.new()
			level.name = "Route17FuelService"
		"pawn_shop":
			level = PawnShopLevel.new()
			level.name = "MesaExchangePawnAndLoan"
		_:
			level = BankLevel.new()
			level.name = "MesaBankAndTrust"
	add_child(level)
	music = AmbientMusic.new()
	music.configure(map_id)
	add_child(music)
	player = PlayerController.new()
	player.name = "Operator"
	player.configure_mission(map_id)
	add_child(player)
	var spawn_z := 0.0 if map_id == "zombie_island" else (56.0 if map_id == "museum" else (30.0 if map_id == "pawn_shop" else 32.0))
	player.global_position = Vector3(0, 0.35, spawn_z)
	level.set("player", player)
	player.died.connect(func(): GameManager.finish_mission(false, "Operator down"))
	var success_reason := "Vault secured and operator extracted"
	if map_id == "gas_station":
		success_reason = "Register emptied and getaway car escaped"
	elif map_id == "museum":
		success_reason = "Golden Sun Disk secured and operator extracted"
	elif map_id == "pawn_shop":
		success_reason = "Pawn shop business concluded and operator departed"
	elif map_id == "zombie_island":
		success_reason = "Blacktide Island survived"
	level.connect("mission_won", func():
		if is_instance_valid(player):
			GameManager.store_extracted_artifacts(player.inventory)
		GameManager.finish_mission(true, success_reason)
	)
	ui.bind_player(player)
	ui.show_game()
	match map_id:
		"zombie_island":
			GameManager.notification.emit("%s difficulty. Endless waves are active. The Gravebreaker Bat and Cinder-9 Flamethrower are included in the island kit — cycle weapons with the D-pad." % GameManager.get_difficulty_label(), "voice")
		"museum":
			GameManager.notification.emit("%s difficulty. Find the archive access card, secure the Golden Sun Disk, and explore — the museum rewards curiosity." % GameManager.get_difficulty_label(), "voice")
		"gas_station":
			GameManager.notification.emit("%s difficulty. Find and break the hidden service-key lockbox with fists or a pipe wrench, empty the register, then escape in the garage car." % GameManager.get_difficulty_label(), "voice")
		"pawn_shop":
			GameManager.notification.emit("%s difficulty. Pawnkeepers remain neutral unless attacked. Sell extracted artifacts at the appraisal counter, browse, or risk the register." % GameManager.get_difficulty_label(), "voice")
		_:
			GameManager.notification.emit("%s difficulty. No mission timer — enter Mesa Bank, follow the vault marker and extract through the lobby." % GameManager.get_difficulty_label(), "voice")

func return_to_menu() -> void:
	get_tree().paused = false
	GameManager.run_active = false
	_cleanup_operation()
	ui.show_main_menu()

func _cleanup_operation() -> void:
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(level):
		level.free()
	if is_instance_valid(music):
		music.free()
	player = null
	level = null
	music = null

func _on_mission_finished(won: bool, report: Dictionary) -> void:
	if is_instance_valid(player):
		player.set_controls_enabled(false)
	ui.show_report(won, report)
