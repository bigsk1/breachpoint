class_name BankLevel
extends Node3D

signal mission_won

var player: Node3D
var _vault_opened := false
var _zone_stage := 0
var _reinforcement_waves := {}
var _materials := {}
var _reverb: AudioEffectReverb
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build_materials()
	_setup_audio()
	_build_environment()
	_build_architecture()
	_build_furnishings()
	_spawn_initial_cast()
	GameManager.reinforcement_requested.connect(_on_reinforcement_requested)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	if not GameManager.run_active: return
	var z := player.global_position.z
	_update_audio_zone(z)
	if _zone_stage == 0 and z < 20.0:
		_zone_stage = 1; GameManager.add_score(150, "Bank infiltrated"); GameManager.set_objective("Cross the lobby and find the security corridor")
	elif _zone_stage == 1 and z < -5.0:
		_zone_stage = 2; GameManager.set_objective("Locate the vault keycard in the management offices")
	elif _zone_stage == 2 and player.get_inventory().count_item("keycard") > 0:
		_zone_stage = 3; GameManager.add_score(400, "Security keycard acquired"); GameManager.set_objective("Reach the vault and breach its access door")
	if _vault_opened and z > 23.0:
		mission_won.emit()

func _build_materials() -> void:
	_materials.floor = _material(Color("#c9c6bf"), 0.12, 0.82)
	_materials.wall = _material(Color("#d8d4ca"), 0.02, 0.88)
	_materials.trim = _material(Color("#2b3a40"), 0.48, 0.36)
	_materials.wood = _material(Color("#5f4936"), 0.05, 0.62)
	_materials.marble = _material(Color("#bbb7ac"), 0.1, 0.25)
	_materials.carpet = _material(Color("#263b47"), 0.0, 0.95)
	_materials.metal = _material(Color("#59636a"), 0.75, 0.28)
	_materials.red = _material(Color("#7f2d2d"), 0.1, 0.6)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.metallic = metallic; mat.roughness = roughness; return mat

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("#0c141b"); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("#8ba0aa"); env.ambient_light_energy = 0.32; env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.glow_enabled = true; env.fog_enabled = true; env.fog_light_color = Color("#596873"); env.fog_density = 0.006
	world_environment.environment = env; add_child(world_environment)
	var moon := DirectionalLight3D.new(); moon.rotation_degrees = Vector3(-52, -28, 0); moon.light_color = Color("#91a9c4"); moon.light_energy = 0.42; moon.shadow_enabled = true; add_child(moon)
	for z in range(20, -51, -8):
		for x in [-9.0, 0.0, 9.0]:
			_ceiling_light(Vector3(x, 4.15, float(z)))

func _ceiling_light(pos: Vector3) -> void:
	var light := OmniLight3D.new(); light.position = pos; light.light_color = Color("#fff1cf"); light.light_energy = 2.0; light.omni_range = 8.5; light.shadow_enabled = false; add_child(light)
	var panel := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(1.2, 0.06, 0.35); var mat := _material(Color("#fff4d8"), 0.0, 0.2); mat.emission_enabled = true; mat.emission = Color("#fff0c8"); mat.emission_energy_multiplier = 2.0; mesh.material = mat; panel.mesh = mesh; panel.position = pos + Vector3(0, 0.2, 0); add_child(panel)

func _build_architecture() -> void:
	_box("Ground", Vector3(31, 0.35, 82), Vector3(0, -0.18, -15), _materials.floor)
	_box("Ceiling", Vector3(31, 0.22, 82), Vector3(0, 4.55, -15), _materials.trim, false)
	_box("WestWall", Vector3(0.35, 4.7, 82), Vector3(-15.35, 2.25, -15), _materials.wall)
	_box("EastWall", Vector3(0.35, 4.7, 82), Vector3(15.35, 2.25, -15), _materials.wall)
	_box("RearWall", Vector3(31, 4.7, 0.35), Vector3(0, 2.25, -56), _materials.wall)
	# Front facade with a double-door opening and dark exterior apron.
	_box("FrontLeft", Vector3(13, 4.7, 0.45), Vector3(-9, 2.25, 26), _materials.trim)
	_box("FrontRight", Vector3(13, 4.7, 0.45), Vector3(9, 2.25, 26), _materials.trim)
	_box("FrontHeader", Vector3(5, 1.4, 0.45), Vector3(0, 4.0, 26), _materials.trim)
	_box("Apron", Vector3(15, 0.25, 8), Vector3(0, -0.12, 29.8), _materials.trim)
	_door(Vector3(-2.35, 1.25, 25.75), Vector3(2.2, 2.5, 0.16), "Front door", "", false, Color("#405662"))
	_door(Vector3(0.15, 1.25, 25.75), Vector3(2.2, 2.5, 0.16), "Front door", "", false, Color("#405662"))
	# Teller line and secure corridor.
	_box("TellerBarrier", Vector3(23, 1.15, 0.85), Vector3(0, 0.58, 1.0), _materials.wood)
	for x in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		_glass(Vector3(x, 1.95, 0.95), Vector3(0.09, 1.55, 2.8))
	_box("SecureWallL", Vector3(12.2, 4.5, 0.3), Vector3(-9.4, 2.25, -7.0), _materials.wall)
	_box("SecureWallR", Vector3(12.2, 4.5, 0.3), Vector3(9.4, 2.25, -7.0), _materials.wall)
	_door(Vector3(-3.3, 1.25, -6.8), Vector3(2.8, 2.5, 0.16), "Security corridor", "", false, Color("#39454a"))
	# Management offices on the west, records and staff room east. Every door now has a real wall opening.
	_box("OfficeDividerWFront", Vector3(0.25, 4.5, 3.8), Vector3(-6.5, 2.25, -8.9), _materials.wall)
	_box("OfficeDividerWRear", Vector3(0.25, 4.5, 29.8), Vector3(-6.5, 2.25, -28.1), _materials.wall)
	_door(Vector3(-6.4, 1.25, -13.2), Vector3(0.16, 2.5, 2.4), "Manager office", "", false, Color("#6f5948"))
	_box("OfficeDividerEFront", Vector3(0.25, 4.5, 13.8), Vector3(6.5, 2.25, -13.9), _materials.wall)
	_box("OfficeDividerERear", Vector3(0.25, 4.5, 19.8), Vector3(6.5, 2.25, -33.1), _materials.wall)
	_door(Vector3(6.4, 1.25, -23.2), Vector3(0.16, 2.5, 2.4), "Records", "", false, Color("#6f5948"))
	_build_office_crosswall(-17.0, true, "Manager inner office")
	_build_office_crosswall(-29.0, true, "Executive office")
	_build_office_crosswall(-17.0, false, "Staff room")
	_build_office_crosswall(-29.0, false, "Security storage")
	# Vault antechamber.
	_box("VaultWallL", Vector3(12.25, 4.7, 0.55), Vector3(-9.275, 2.25, -43), _materials.metal)
	_box("VaultWallR", Vector3(12.25, 4.7, 0.55), Vector3(9.275, 2.25, -43), _materials.metal)
	_box("VaultHeader", Vector3(6.3, 1.55, 0.55), Vector3(0, 3.875, -43), _materials.metal)
	var vault := _door(Vector3(-3.1, 1.55, -42.7), Vector3(6.2, 3.1, 0.42), "Vault blast door", "keycard", true, Color("#59646a"))
	vault.opened.connect(_on_vault_opened)
	var vault_light := OmniLight3D.new(); vault_light.position = Vector3(0, 3.65, -41.7); vault_light.light_color = Color("#e6bb5f"); vault_light.light_energy = 5.2; vault_light.omni_range = 9.0; add_child(vault_light)
	_box("VaultInnerFloor", Vector3(22, 0.12, 11), Vector3(0, 0.04, -49), _materials.metal, false)
	_sign("MESA BANK & TRUST", Vector3(0, 3.1, 25.6), 58, Color("#d9c58c"))
	_sign("SECURE ACCESS", Vector3(0, 3.45, -6.65), 30, Color("#b44444"))
	_sign("← MANAGEMENT     VAULT ↓     RECORDS →", Vector3(0, 3.5, -10.5), 27, Color("#d9c58c"))
	_sign("BANK VAULT", Vector3(0, 3.62, -42.35), 46, Color("#f0c65f"))
	_waypoint("◆  VAULT", Vector3(0, 4.05, -42.0), Color("#f0c65f"))

func _build_office_crosswall(z: float, west: bool, title: String) -> void:
	if west:
		_box("OfficeCross", Vector3(3.4, 4.5, 0.25), Vector3(-13.3, 2.25, z), _materials.wall)
		_box("OfficeCross", Vector3(2.9, 4.5, 0.25), Vector3(-7.95, 2.25, z), _materials.wall)
		_door(Vector3(-11.6, 1.25, z + 0.15), Vector3(2.2, 2.5, 0.16), title, "", false, Color("#6f5948"))
	else:
		_box("OfficeCross", Vector3(2.9, 4.5, 0.25), Vector3(7.95, 2.25, z), _materials.wall)
		_box("OfficeCross", Vector3(3.4, 4.5, 0.25), Vector3(13.3, 2.25, z), _materials.wall)
		_door(Vector3(9.4, 1.25, z + 0.15), Vector3(2.2, 2.5, 0.16), title, "", false, Color("#6f5948"))

func _build_furnishings() -> void:
	# Lobby benches, planters, tables, and queue rails.
	for x in [-10.5, -5.5, 5.5, 10.5]:
		_box("LobbyBench", Vector3(3.2, 0.46, 0.78), Vector3(x, 0.42, 12.0 + absf(x) * 0.25), _materials.wood)
	for x in [-8.0, -2.7, 2.7, 8.0]:
		_box("TellerDesk", Vector3(2.2, 0.95, 1.4), Vector3(x, 0.48, -1.8), _materials.wood)
		_monitor(Vector3(x, 1.25, -1.85))
	for z in [-12.0, -23.0, -34.0]:
		_box("HallTable", Vector3(2.5, 0.78, 1.1), Vector3(0, 0.39, z), _materials.marble)
	for pos in [Vector3(-10,0.48,-12), Vector3(-10,0.48,-23), Vector3(10,0.48,-12), Vector3(10,0.48,-23), Vector3(-10,0.48,-34), Vector3(10,0.48,-34)]:
		_box("OfficeDesk", Vector3(3.6, 0.95, 1.45), pos, _materials.wood)
		_monitor(pos + Vector3(0, 0.82, 0))
	# Framed regional and historic artwork gives the lobby and offices visual identity.
	_portrait(Vector3(-15.12, 2.45, 14.0), 0, 90.0)
	_portrait(Vector3(-15.12, 2.45, 6.0), 1, 90.0)
	_portrait(Vector3(15.12, 2.45, 14.0), 2, -90.0)
	_portrait(Vector3(15.12, 2.45, 6.0), 3, -90.0)
	_portrait(Vector3(-7.85, 2.5, -16.82), 0, 0.0)
	_portrait(Vector3(13.0, 2.5, -28.82), 2, 0.0)
	# Pipe-wrench Easter egg: a false wall hides the founder's emergency cache.
	_box("SecretClosetL", Vector3(0.22, 3.2, 3.2), Vector3(-12.1, 1.6, -40.6), _materials.wall)
	_box("SecretClosetR", Vector3(0.22, 3.2, 3.2), Vector3(-7.9, 1.6, -40.6), _materials.wall)
	_box("SecretClosetBack", Vector3(4.4, 3.2, 0.22), Vector3(-10.0, 1.6, -42.15), _materials.wall)
	var founder_panel := SecretPanel.new(); founder_panel.display_name = "Founder's emergency cache"; founder_panel.setup(Vector3(4.0, 3.0, 0.24), Color("#d4d0c7")); founder_panel.position = Vector3(-10.0, 1.5, -39.0); add_child(founder_panel)
	var founder_cache := _loot(Vector3(-10.0, 0.55, -41.0), "Founder's hidden lockbox", Color("#66502f"))
	founder_cache.items = [InventorySystem.item("cash", "Unregistered Bonds", "loot", 10, 0.15, true, 20, Color("#7aa35a")), InventorySystem.item("armor_plate", "Antique Ballistic Plate", "gear", 1, 1.1, true, 4, Color("#5f84a2")), InventorySystem.artifact("founder_medallion", "Mesa Bank Founder Medallion", 1550, 0.4, Color("#d6aa42"))]
	# Keycard and supplies deliberately placed in explorable side rooms.
	var keycase := _loot(Vector3(-10.2, 1.1, -22.7), "Manager lockbox", Color("#8c6d3e"))
	keycase.items = [InventorySystem.item("keycard", "Vault Security Keycard", "mission", 1, 0.05, false, 1, Color("#e7c46d"))]
	var ammo := _loot(Vector3(10.2, 0.55, -33.8), "Security weapons case", Color("#3f4f46"))
	ammo.items = [InventorySystem.ammo_item("ammo", 48), InventorySystem.ammo_item("shells", 12), InventorySystem.item("shotgun", "M90 Breacher", "weapon", 1, 4.6, false, 1, Color("#a18b61"))]
	var aid := _loot(Vector3(10.2, 0.55, -12.8), "Emergency station", Color("#6e3434"))
	aid.items = [InventorySystem.item("medkit", "Field Medkit", "consumable", 1, 0.8, true, 3, Color("#d45f5f")), InventorySystem.item("armor_plate", "Armor Plate", "gear", 1, 1.1, true, 4, Color("#5f84a2"))]
	# Dense physical coin mounds and gold bars make the vault read as actual wealth.
	_build_vault_coin_piles()
	for x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		var cash := _loot(Vector3(x, 0.45, -50.0), "Insured cash bundle", Color("#546b49"))
		cash.items = [InventorySystem.item("cash", "Secured Cash", "loot", 5, 0.25, true, 20, Color("#7aa35a"))]
		if is_zero_approx(x):
			cash.items.append(InventorySystem.artifact("mesa_mint_coin_set", "Mesa Mint Proof Coin Set", 1800, 0.7, Color("#e2b84d")))

func _build_vault_coin_piles() -> void:
	var gold := _material(Color("#d6a934"), 0.92, 0.20)
	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = 0.105
	coin_mesh.bottom_radius = 0.105
	coin_mesh.height = 0.026
	coin_mesh.radial_segments = 12
	coin_mesh.material = gold
	var mound_count := 5
	var coins_per_mound := 58
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = coin_mesh
	multimesh.instance_count = mound_count * coins_per_mound
	var index := 0
	var mound_centers := [-7.0, -3.5, 0.0, 3.5, 7.0]
	for center_x in mound_centers:
		for coin_index in coins_per_mound:
			var layer := coin_index / 16
			var radius := maxf(0.18, 0.78 - float(layer) * 0.13)
			var angle := _rng.randf_range(0.0, TAU)
			var offset := Vector3(cos(angle) * _rng.randf_range(0.04, radius), float(layer) * 0.029, sin(angle) * _rng.randf_range(0.04, radius * 0.62))
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
			basis = basis.rotated(Vector3.RIGHT, _rng.randf_range(-0.08, 0.08))
			multimesh.set_instance_transform(index, Transform3D(basis, Vector3(float(center_x), 0.80, -50.0) + offset))
			index += 1
	var coin_field := MultiMeshInstance3D.new()
	coin_field.name = "VaultCoinMounds"
	coin_field.multimesh = multimesh
	add_child(coin_field)
	# Staggered bullion stacks sit between the coin mounds.
	for x in [-5.25, -1.75, 1.75, 5.25]:
		for row in 3:
			for column in 4:
				var bar := MeshInstance3D.new()
				var mesh := BoxMesh.new(); mesh.size = Vector3(0.42, 0.085, 0.18); mesh.material = gold
				bar.mesh = mesh
				bar.position = Vector3(x + (column - 1.5) * 0.34, 0.80 + row * 0.088, -51.2 + (row % 2) * 0.07)
				bar.rotation_degrees.y = 5.0 if row % 2 == 0 else -5.0
				add_child(bar)

func _setup_audio() -> void:
	var bus := AudioServer.get_bus_index("InteriorReverb")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		_reverb = AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb

func _update_audio_zone(z: float) -> void:
	if not _reverb: return
	var target_wet := 0.14
	var target_room := 0.62
	if z > -7.0:
		target_wet = 0.24; target_room = 0.88 # Marble lobby.
	elif z < -42.0:
		target_wet = 0.34; target_room = 0.96 # Metal vault.
	_reverb.wet = lerpf(_reverb.wet, target_wet, 0.04)
	_reverb.room_size = lerpf(_reverb.room_size, target_room, 0.04)

func _spawn_initial_cast() -> void:
	# A vault guard is guaranteed; every other room assignment is shuffled each attempt.
	_spawn_actor(ActorAI.Kind.SECURITY, Vector3(4.5, 0, -49.0), [Vector3(-5,0,-49), Vector3(5,0,-49)])
	var security_positions: Array[Vector3] = [
		Vector3(-7,0,10), Vector3(7,0,7), Vector3(-10,0,-12), Vector3(10,0,-14),
		Vector3(-10,0,-24), Vector3(10,0,-34), Vector3(-3,0,-39), Vector3(-4,0,-49),
	]
	security_positions.shuffle()
	var security_count := int(GameManager.get_difficulty_value(3.0, 5.0, 7.0))
	for i in security_count - 1:
		_spawn_actor(ActorAI.Kind.SECURITY, security_positions[i])
	var civilian_positions: Array[Vector3] = [
		Vector3(-9,0,17), Vector3(8,0,15), Vector3(-3,0,6), Vector3(9,0,-10),
		Vector3(-10,0,-12), Vector3(10,0,-15), Vector3(-10,0,-23), Vector3(10,0,-25),
		Vector3(-10,0,-34), Vector3(9,0,-35), Vector3(-2,0,-20),
	]
	civilian_positions.shuffle()
	var civilian_count := int(GameManager.get_difficulty_value(5.0, 7.0, 8.0))
	for i in civilian_count:
		_spawn_actor(ActorAI.Kind.CIVILIAN, civilian_positions[i])

func _spawn_actor(kind: ActorAI.Kind, pos: Vector3, patrol: Array[Vector3] = []) -> ActorAI:
	var actor := ActorAI.new(); actor.configure(kind, pos, patrol); add_child(actor); return actor

func _on_reinforcement_requested(tier: int) -> void:
	if _reinforcement_waves.has(tier):
		return
	_reinforcement_waves[tier] = true
	match tier:
		1:
			GameManager.notification.emit("LOCAL SECURITY: Alarm verification in progress", "voice")
			_spawn_actor(ActorAI.Kind.SECURITY, Vector3(11,0,22))
		2:
			GameManager.notification.emit("DISPATCH: Patrol units entering the bank", "voice")
			var police_count := int(GameManager.get_difficulty_value(2.0, 3.0, 4.0))
			for i in police_count:
				_spawn_actor(ActorAI.Kind.POLICE, Vector3(-6.0 + i * 4.0, 0, 29.0 + absf(i - 1)))
		3:
			GameManager.notification.emit("SWAT: Entry team, breach and clear", "voice")
			var swat_count := int(GameManager.get_difficulty_value(2.0, 3.0, 4.0))
			for i in swat_count:
				_spawn_actor(ActorAI.Kind.SWAT, Vector3(-7.0 + i * 4.5, 0, 30.0 + absf(i - 1)))

func _on_vault_opened(_door: InteractableDoor) -> void:
	if _vault_opened: return
	_vault_opened = true
	GameManager.add_score(1200, "Vault breached")
	GameManager.set_objective("Secure cash if desired, then return to the front extraction zone")
	GameManager.raise_alert(30.0, "VAULT BREACH — tactical response authorized")

func _box(name_value: String, size: Vector3, pos: Vector3, material: Material, collision := true) -> Node3D:
	var root: Node3D
	if collision:
		var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 2 | 8; root = body
		var shape_node := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; shape_node.shape = shape; body.add_child(shape_node)
	else:
		root = Node3D.new()
	root.name = name_value; root.position = pos; add_child(root)
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; mesh.material = material; visual.mesh = mesh; root.add_child(visual)
	return root

func _glass(pos: Vector3, size: Vector3) -> void:
	var glass := DestructibleProp.new(); glass.setup(size, Color("#a6d9df"), true); glass.position = pos; add_child(glass)

func _monitor(pos: Vector3) -> void:
	var monitor := DestructibleProp.new(); monitor.durability = 20.0; monitor.shard_color = Color("#24292e"); monitor.setup(Vector3(0.8, 0.52, 0.12), Color("#17242b")); monitor.position = pos; add_child(monitor)

func _door(pos: Vector3, size: Vector3, title: String, lock_id: String, vault: bool, color: Color, rotation_value := Vector3.ZERO) -> InteractableDoor:
	var door := InteractableDoor.new(); door.display_name = title; door.locked_item_id = lock_id; door.is_vault = vault; door.setup(size, color); door.position = pos; door.rotation_degrees = rotation_value; add_child(door); return door

func _loot(pos: Vector3, title: String, color: Color) -> LootContainer:
	var loot := LootContainer.new(); loot.display_name = title; loot.setup(Vector3(1.2, 0.65, 0.72), color); loot.position = pos; add_child(loot); return loot

func _portrait(pos: Vector3, _quadrant: int, rotation_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rotation_y
	add_child(root)
	var backing := MeshInstance3D.new()
	var backing_mesh := BoxMesh.new(); backing_mesh.size = Vector3(2.35, 1.72, 0.10); backing_mesh.material = _material(Color("#181b1d"), 0.25, 0.5)
	backing.mesh = backing_mesh; root.add_child(backing)
	var picture := MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(2.15, 1.52)
	var selected := _rng.randi_range(0, 3)
	var source_texture := load("res://assets/art/wall_art_collection.png") as Texture2D
	var source_image := source_texture.get_image()
	var tile := source_image.get_region(Rect2i((selected % 2) * 627, floori(selected / 2.0) * 627, 627, 627))
	var picture_texture := ImageTexture.create_from_image(tile)
	var material := StandardMaterial3D.new(); material.albedo_texture = picture_texture; material.roughness = 0.82; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material; picture.mesh = quad; picture.position.z = 0.061; root.add_child(picture)

func _sign(text_value: String, pos: Vector3, size: int, color: Color) -> void:
	var label := Label3D.new(); label.text = text_value; label.font_size = size; label.modulate = color; label.outline_size = 10; label.position = pos; label.billboard = BaseMaterial3D.BILLBOARD_DISABLED; add_child(label)

func _waypoint(text_value: String, pos: Vector3, color: Color) -> void:
	var marker := Label3D.new(); marker.text = text_value; marker.font_size = 34; marker.modulate = color; marker.outline_size = 12; marker.position = pos; marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; marker.no_depth_test = true; add_child(marker)
