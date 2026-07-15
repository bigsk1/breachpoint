class_name MuseumLevel
extends Node3D

signal mission_won

var player: Node3D
var _entered := false
var _artifact_secured := false
var _escaped := false
var _reinforcement_waves := {}
var _materials := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build_materials()
	_build_environment()
	_build_architecture()
	_build_galleries()
	_build_secrets()
	_spawn_initial_cast()
	GameManager.reinforcement_requested.connect(_on_reinforcement_requested)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	if not GameManager.run_active:
		return
	var z := player.global_position.z
	if not _entered and z < 46.0:
		_entered = true
		GameManager.add_score(200, "Museum infiltrated")
		GameManager.set_objective("Search the west archives for the antiquities access card")
	if not _artifact_secured and player.get_inventory().count_item("museum_keycard") > 0:
		GameManager.set_objective("Unlock the Antiquities Vault and secure the Sun Disk")
	if _artifact_secured and not _escaped and z > 47.0:
		_escaped = true
		mission_won.emit()

func _build_materials() -> void:
	_materials.floor = _material(Color("#c8c1b2"), 0.08, 0.38)
	_materials.wall = _material(Color("#dfd8ca"), 0.02, 0.86)
	_materials.dark = _material(Color("#20282d"), 0.42, 0.38)
	_materials.wood = _material(Color("#59402c"), 0.04, 0.66)
	_materials.gold = _material(Color("#b58a36"), 0.78, 0.24)
	_materials.stone = _material(Color("#8d8981"), 0.05, 0.78)
	_materials.red = _material(Color("#71312f"), 0.05, 0.72)
	_materials.blue = _material(Color("#28475b"), 0.06, 0.74)
	_materials.green = _material(Color("#3b584a"), 0.03, 0.8)
	_materials.glass = _material(Color("#9fd0d3"), 0.15, 0.18)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d4c9b5")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("#7b817f")
	environment.fog_density = 0.0025
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -25, 0)
	moon.light_color = Color("#9fb4c8")
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)
	for z in range(42, -47, -11):
		for x in [-24.0, -12.0, 0.0, 12.0, 24.0]:
			_ceiling_light(Vector3(x, 4.75, float(z)))

func _build_architecture() -> void:
	_box("MuseumGround", Vector3(64, 0.35, 108), Vector3(0, -0.18, 1), _materials.floor)
	_box("MuseumCeiling", Vector3(60, 0.22, 100), Vector3(0, 5.15, 0), _materials.dark, false)
	_box("WestExterior", Vector3(0.4, 5.3, 100), Vector3(-30.2, 2.5, 0), _materials.stone)
	_box("EastExterior", Vector3(0.4, 5.3, 100), Vector3(30.2, 2.5, 0), _materials.stone)
	_box("RearExterior", Vector3(60.4, 5.3, 0.4), Vector3(0, 2.5, -50.2), _materials.stone)
	# Grand entrance with a broad stair/apron and four-door opening.
	_box("FrontLeft", Vector3(26, 5.3, 0.4), Vector3(-17, 2.5, 50.2), _materials.stone)
	_box("FrontRight", Vector3(26, 5.3, 0.4), Vector3(17, 2.5, 50.2), _materials.stone)
	_box("FrontHeader", Vector3(8, 1.5, 0.4), Vector3(0, 4.35, 50.2), _materials.gold)
	_box("EntranceApron", Vector3(28, 0.3, 9), Vector3(0, -0.12, 53.5), _materials.stone)
	for x in [-3.9, -1.9, 0.1, 2.1]:
		_door(Vector3(x, 1.35, 50.0), Vector3(1.8, 2.7, 0.16), "Museum entrance", Color("#3d5964"))
	# Central hall dividers: three connections per side create loops and alternate routes.
	_build_divider(-8.0, true)
	_build_divider(8.0, false)
	_build_cross_gallery(18.0, true, "West Classical Gallery")
	_build_cross_gallery(-12.0, true, "West Archives")
	_build_cross_gallery(12.0, false, "Natural History")
	_build_cross_gallery(-18.0, false, "Armor & Technology")
	# Secure antiquities threshold at the far end of the main axis.
	_box("AntiquitiesGateL", Vector3(6.0, 5.0, 0.35), Vector3(-5.0, 2.5, -34.0), _materials.red)
	_box("AntiquitiesGateR", Vector3(6.0, 5.0, 0.35), Vector3(5.0, 2.5, -34.0), _materials.red)
	_box("AntiquitiesHeader", Vector3(4.0, 1.45, 0.35), Vector3(0, 4.28, -34.0), _materials.gold)
	_door(Vector3(-2.0, 1.35, -33.82), Vector3(4.0, 2.7, 0.18), "Antiquities security door", Color("#6d5635"))
	# Archive dead-end room in the southwest corner.
	_box("ArchiveWallL", Vector3(5.0, 5.0, 0.3), Vector3(-27.5, 2.5, -36.0), _materials.wall)
	_box("ArchiveWallR", Vector3(6.0, 5.0, 0.3), Vector3(-11.0, 2.5, -36.0), _materials.wall)
	_door(Vector3(-22.5, 1.3, -35.82), Vector3(5.5, 2.6, 0.16), "Collections archive", Color("#594635"))
	_sign("MESA GRAND MUSEUM", Vector3(0, 3.3, 49.95), 58, Color("#e6c66d"))
	_sign("WEST WING  ←     GRAND ATRIUM     →  EAST WING", Vector3(0, 4.15, 35.0), 28, Color("#d2ad61"))
	_sign("ANTIQUITIES VAULT", Vector3(0, 4.12, -33.7), 36, Color("#e1bd62"))
	_waypoint("◆  SUN DISK", Vector3(0, 4.45, -43.0), Color("#f1ca62"))

func _build_divider(x: float, west: bool) -> void:
	for segment in [
		[-43.0, 14.0],
		[-19.0, 26.0],
		[14.0, 32.0],
		[42.0, 16.0],
	]:
		_box("WingDivider", Vector3(0.3, 5.0, segment[1]), Vector3(x, 2.5, segment[0]), _materials.wall)
	for data in [[-34.0, "Rear gallery connection"], [-4.0, "Central gallery connection"], [32.0, "Front gallery connection"]]:
		var door_x := x + 0.16 if west else x - 0.16
		_door(Vector3(door_x, 1.35, data[0] - 1.8), Vector3(0.16, 2.7, 3.6), data[1], Color("#66513b"), Vector3(0, 90, 0))

func _build_cross_gallery(z: float, west: bool, title: String) -> void:
	if west:
		_box("GalleryCrossL", Vector3(10.5, 5.0, 0.3), Vector3(-24.75, 2.5, z), _materials.wall)
		_box("GalleryCrossR", Vector3(8.5, 5.0, 0.3), Vector3(-12.25, 2.5, z), _materials.wall)
		_door(Vector3(-19.5, 1.35, z + 0.16), Vector3(3.0, 2.7, 0.16), title, Color("#604b37"))
	else:
		_box("GalleryCrossL", Vector3(8.5, 5.0, 0.3), Vector3(12.25, 2.5, z), _materials.wall)
		_box("GalleryCrossR", Vector3(10.5, 5.0, 0.3), Vector3(24.75, 2.5, z), _materials.wall)
		_door(Vector3(16.5, 1.35, z + 0.16), Vector3(3.0, 2.7, 0.16), title, Color("#604b37"))

func _build_galleries() -> void:
	# Grand atrium desk, benches, banners, and central sculpture.
	_box("InformationDesk", Vector3(7.5, 1.05, 2.0), Vector3(0, 0.52, 33.0), _materials.wood)
	for z in [26.0, 10.0, -8.0, -25.0]:
		_box("AtriumBenchL", Vector3(3.2, 0.5, 0.8), Vector3(-4.0, 0.42, z), _materials.wood)
		_box("AtriumBenchR", Vector3(3.2, 0.5, 0.8), Vector3(4.0, 0.42, z), _materials.wood)
	_artifact(Vector3(0, 0, 17), "The Navigator", "statue", Color("#7c8587"))
	# West wing: maritime, classical, regional art, then archive dead end.
	_artifact(Vector3(-19,0,35), "Ceremonial Amphora", "vase", Color("#8b4d31"))
	_artifact(Vector3(-24,0,25), "Mariner's Astrolabe", "clock", Color("#b38b3f"))
	_artifact(Vector3(-13,0,8), "Basalt Guardian", "statue", Color("#56585a"))
	_artifact(Vector3(-23,0,2), "Mesa Sun Vessel", "vase", Color("#a96f3e"))
	_artifact(Vector3(-14,0,-25), "Royal Signet", "gem", Color("#7cc1c8"))
	# East wing: fossils, armor, science and technology.
	_artifact(Vector3(19,0,35), "Thunder Lizard Fossil", "fossil", Color("#c5b48f"))
	_artifact(Vector3(24,0,22), "Desert Botanical Study", "botanical", Color("#6c8a5c"))
	_artifact(Vector3(14,0,4), "Knight of the Meridian", "armor", Color("#68757b"))
	_artifact(Vector3(23,0,-5), "Early Flight Engine", "engine", Color("#81654b"))
	_artifact(Vector3(16,0,-28), "Lunar Survey Instrument", "clock", Color("#a58a52"))
	# Archive access card and supplies reward exploration of a true dead end.
	var archive_case := _loot(Vector3(-25.5, 0.62, -44.0), "Curator access case", Color("#6b5138"))
	archive_case.items = [InventorySystem.item("museum_keycard", "Antiquities Access Card", "mission", 1, 0.05, false, 1, Color("#e8c969")), InventorySystem.item("medkit", "Museum First Aid", "consumable", 1, 0.8, true, 3, Color("#d45f5f")), InventorySystem.ammo_item("ammo", 45)]
	# Main artifact objective.
	_box("SunDiskPedestal", Vector3(2.4, 1.2, 2.4), Vector3(0, 0.6, -43.0), _materials.stone)
	var sun_disk := ObjectiveStation.new()
	sun_disk.display_name = "Golden Sun Disk"
	sun_disk.action_text = "HOLD TO SECURE"
	sun_disk.required_item_id = "museum_keycard"
	sun_disk.required_quantity = 1
	sun_disk.requirement_text = "Antiquities access card required"
	sun_disk.items = [InventorySystem.artifact("sun_disk", "Golden Sun Disk", 4200, 3.0, Color("#efc64f"))]
	sun_disk.score_reward = 2500
	sun_disk.alert_amount = 82.0
	sun_disk.notification_text = "Artifact alarm triggered — tactical response inbound"
	sun_disk.setup(Vector3(1.1, 1.5, 0.32), Color("#d1a332"))
	sun_disk.position = Vector3(0, 1.8, -43.0)
	sun_disk.activated.connect(_on_artifact_secured)
	add_child(sun_disk)
	# Individually cropped, randomized museum paintings.
	for data in [
		[Vector3(-29.94,2.6,39),90.0], [Vector3(-29.94,2.6,29),90.0],
		[Vector3(-29.94,2.6,9),90.0], [Vector3(-29.94,2.6,-7),90.0],
		[Vector3(29.94,2.6,39),-90.0], [Vector3(29.94,2.6,27),-90.0],
		[Vector3(29.94,2.6,4),-90.0], [Vector3(29.94,2.6,-10),-90.0],
		[Vector3(-4.5,2.65,-49.94),0.0], [Vector3(5.0,2.65,-49.94),0.0],
	]:
		_portrait(data[0], data[1])

func _build_secrets() -> void:
	# Hidden restoration room: heavy wrench lifts the false wall.
	_box("RestorationSecretL", Vector3(0.22, 3.2, 3.4), Vector3(19.0, 1.6, -42.0), _materials.wall)
	_box("RestorationSecretR", Vector3(0.22, 3.2, 3.4), Vector3(24.0, 1.6, -42.0), _materials.wall)
	_box("RestorationSecretBack", Vector3(5.2, 3.2, 0.22), Vector3(21.5, 1.6, -43.65), _materials.wall)
	var restoration_wall := SecretPanel.new(); restoration_wall.display_name = "Abandoned restoration lab"; restoration_wall.setup(Vector3(4.7, 3.0, 0.24), Color("#dbd4c8")); restoration_wall.position = Vector3(21.5, 1.5, -40.3); add_child(restoration_wall)
	var restoration_cache := _loot(Vector3(21.5, 0.55, -42.6), "Restorer's concealed case", Color("#536264"))
	restoration_cache.items = [InventorySystem.item("cash", "Misfiled Antiquities", "loot", 12, 0.12, true, 20, Color("#7aa35a")), InventorySystem.item("armor_plate", "Restoration Laminate", "gear", 2, 1.1, true, 4, Color("#5f84a2")), InventorySystem.ammo_item("shells", 12)]
	# Smashable false portrait in the west regional gallery.
	_box("PortraitNicheL", Vector3(0.22, 2.8, 2.8), Vector3(-27.0, 1.4, -22.0), _materials.wall)
	_box("PortraitNicheR", Vector3(0.22, 2.8, 2.8), Vector3(-23.6, 1.4, -22.0), _materials.wall)
	_box("PortraitNicheBack", Vector3(3.6, 2.8, 0.22), Vector3(-25.3, 1.4, -23.3), _materials.wall)
	var false_portrait := SecretPanel.new(); false_portrait.display_name = "Portrait of the missing curator"; false_portrait.required_weapon = ""; false_portrait.open_offset = Vector3(3.5, 0, 0); false_portrait.setup(Vector3(3.2, 2.5, 0.18), Color("#35261c")); false_portrait.position = Vector3(-25.3, 1.5, -20.6); add_child(false_portrait)
	_add_portrait_face(false_portrait)
	var portrait_cache := _loot(Vector3(-25.3, 0.55, -22.2), "Curator's hidden evidence", Color("#684a39"))
	portrait_cache.items = [InventorySystem.item("cash", "Anonymous Donation", "loot", 8, 0.12, true, 20, Color("#7aa35a")), InventorySystem.item("knife", "Ceremonial Dagger", "weapon", 1, 0.8, false, 1, Color("#b7c3c7"))]

func _artifact(pos: Vector3, title: String, kind: String, color: Color) -> void:
	_box("ArtifactPedestal", Vector3(2.4, 0.8, 2.4), pos + Vector3(0, 0.4, 0), _materials.stone)
	var root := Node3D.new(); root.position = pos + Vector3(0, 1.2, 0); add_child(root)
	var material := _material(color, 0.3 if kind in ["armor", "clock", "engine"] else 0.05, 0.55)
	match kind:
		"vase":
			_mesh_cylinder(root, 0.42, 0.62, Vector3(0,0.25,0), material)
			_mesh_sphere(root, Vector3(0.52,0.42,0.52), Vector3(0,0.58,0), material)
		"statue":
			_mesh_capsule(root, 0.22, 1.3, Vector3(0,0.55,0), material)
			_mesh_sphere(root, Vector3(0.3,0.3,0.3), Vector3(0,1.28,0), material)
			_mesh_box(root, Vector3(0.9,0.13,0.13), Vector3(0,0.78,0), material, Vector3(0,0,0.2))
		"fossil":
			for i in 7:
				_mesh_box(root, Vector3(1.5 - i * 0.12,0.08,0.08), Vector3(0,0.2 + i * 0.16,-0.45 + i * 0.14), material, Vector3(0,0,float(i)*0.08))
			_mesh_sphere(root, Vector3(0.46,0.32,0.6), Vector3(0,1.3,0.55), material)
		"armor":
			_mesh_box(root, Vector3(0.7,0.9,0.38), Vector3(0,0.65,0), material)
			_mesh_sphere(root, Vector3(0.42,0.38,0.42), Vector3(0,1.35,0), material)
			_mesh_box(root, Vector3(1.25,0.16,0.16), Vector3(0,0.82,0), material)
		"engine":
			_mesh_box(root, Vector3(1.2,0.65,0.85), Vector3(0,0.48,0), material)
			for x in [-0.42,0.42]:
				_mesh_cylinder(root, 0.18, 0.8, Vector3(x,0.95,0), material)
		"clock":
			_mesh_torus(root, 0.42, 0.52, Vector3(0,0.7,0), material)
			_mesh_box(root, Vector3(0.04,0.58,0.04), Vector3(0,0.7,0), _materials.gold, Vector3(0,0,0.55))
		"botanical":
			for i in 5:
				_mesh_capsule(root, 0.055, 1.0, Vector3((i-2)*0.2,0.55,0), material, Vector3(0,0,(i-2)*0.15))
				_mesh_sphere(root, Vector3(0.18,0.11,0.25), Vector3((i-2)*0.2,1.05,0), material)
		"gem":
			_mesh_sphere(root, Vector3(0.55,0.7,0.55), Vector3(0,0.62,0), material)
	var label := Label3D.new(); label.text = title.to_upper(); label.font_size = 20; label.outline_size = 8; label.position = Vector3(0,1.0,0); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; root.add_child(label)
	var value := int({"gem": 2600, "fossil": 2100, "armor": 1950, "clock": 1750, "engine": 1650, "statue": 1500, "vase": 1250, "botanical": 1100}.get(kind, 1200))
	var pickup := ArtifactPickup.new()
	pickup.setup(title.to_snake_case(), title, value, 1.4 if kind not in ["fossil", "engine"] else 2.2, color)
	pickup.visual_target = root
	pickup.position = pos + Vector3(0,1.2,0)
	add_child(pickup)
	var glass := DestructibleProp.new(); glass.durability = 28.0; glass.setup(Vector3(2.0, 2.0, 2.0), Color("#9fd0d3"), true); glass.position = pos + Vector3(0,1.45,0); add_child(glass)

func _spawn_initial_cast() -> void:
	_spawn_actor(ActorAI.Kind.SECURITY, Vector3(-3,0,-41))
	_spawn_actor(ActorAI.Kind.SECURITY, Vector3(3,0,-44))
	var security_positions: Array[Vector3] = [
		Vector3(-5,0,32), Vector3(5,0,20), Vector3(-18,0,32), Vector3(18,0,30),
		Vector3(-22,0,8), Vector3(22,0,5), Vector3(-14,0,-20), Vector3(16,0,-24),
		Vector3(-25,0,-42), Vector3(25,0,-35), Vector3(0,0,-20),
	]
	security_positions.shuffle()
	var security_count := int(GameManager.get_difficulty_value(6.0, 8.0, 10.0))
	for i in security_count - 2:
		_spawn_actor(ActorAI.Kind.SECURITY, security_positions[i])
	var civilian_positions: Array[Vector3] = [
		Vector3(-4,0,39), Vector3(4,0,35), Vector3(-18,0,40), Vector3(18,0,39),
		Vector3(-25,0,26), Vector3(-14,0,24), Vector3(14,0,24), Vector3(25,0,18),
		Vector3(-20,0,7), Vector3(-12,0,2), Vector3(12,0,2), Vector3(23,0,-2),
		Vector3(-24,0,-18), Vector3(-13,0,-26), Vector3(14,0,-27), Vector3(24,0,-30),
		Vector3(-4,0,-15), Vector3(4,0,-8), Vector3(-20,0,-42), Vector3(20,0,-42),
	]
	civilian_positions.shuffle()
	var civilian_count := int(GameManager.get_difficulty_value(10.0, 14.0, 18.0))
	for i in civilian_count:
		_spawn_actor(ActorAI.Kind.CIVILIAN, civilian_positions[i])

func _spawn_actor(kind: ActorAI.Kind, pos: Vector3, patrol: Array[Vector3] = []) -> ActorAI:
	var actor := ActorAI.new(); actor.configure(kind, pos, patrol); add_child(actor); return actor

func _on_artifact_secured(_station: ObjectiveStation) -> void:
	_artifact_secured = true
	GameManager.set_objective("Optional: explore hidden galleries, then extract through the grand entrance")

func _on_reinforcement_requested(tier: int) -> void:
	if _reinforcement_waves.has(tier):
		return
	_reinforcement_waves[tier] = true
	match tier:
		1:
			GameManager.notification.emit("MUSEUM SECURITY: Gallery lockdown initiated", "voice")
			_spawn_actor(ActorAI.Kind.SECURITY, Vector3(0,0,38))
		2:
			GameManager.notification.emit("DISPATCH: Police entering the museum plaza", "voice")
			var count := int(GameManager.get_difficulty_value(3.0, 4.0, 5.0))
			for i in count:
				_spawn_actor(ActorAI.Kind.POLICE, Vector3(-10.0 + i * 5.0,0,53.0))
		3:
			GameManager.notification.emit("SWAT: Museum containment and recovery underway", "voice")
			var count := int(GameManager.get_difficulty_value(3.0, 4.0, 6.0))
			for i in count:
				_spawn_actor(ActorAI.Kind.SWAT, Vector3(-12.0 + i * 4.5,0,55.0))

func _portrait(pos: Vector3, rotation_y: float) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rotation_y; add_child(root)
	var backing := MeshInstance3D.new(); var backing_mesh := BoxMesh.new(); backing_mesh.size = Vector3(2.5, 1.9, 0.10); backing_mesh.material = _materials.wood; backing.mesh = backing_mesh; root.add_child(backing)
	var selected := _rng.randi_range(0, 3)
	var source_texture := load("res://assets/art/museum_art_collection.png") as Texture2D
	var source_image := source_texture.get_image()
	var tile := source_image.get_region(Rect2i((selected % 2) * 627, floori(selected / 2.0) * 627, 627, 627))
	var picture_texture := ImageTexture.create_from_image(tile)
	var picture := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2(2.28,1.68)
	var material := StandardMaterial3D.new(); material.albedo_texture = picture_texture; material.roughness = 0.84; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material; picture.mesh = quad; picture.position.z = 0.061; root.add_child(picture)

func _add_portrait_face(parent: Node3D) -> void:
	var source_texture := load("res://assets/art/museum_art_collection.png") as Texture2D
	var source_image := source_texture.get_image()
	var selected := _rng.randi_range(0, 3)
	var tile := source_image.get_region(Rect2i((selected % 2) * 627, floori(selected / 2.0) * 627, 627, 627))
	var picture := MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(2.92, 2.22)
	var material := StandardMaterial3D.new(); material.albedo_texture = ImageTexture.create_from_image(tile); material.roughness = 0.84; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material; picture.mesh = quad; picture.position.z = 0.101; parent.add_child(picture)

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

func _door(pos: Vector3, size: Vector3, title: String, color: Color, rotation_value := Vector3.ZERO) -> InteractableDoor:
	var door := InteractableDoor.new(); door.display_name = title; door.setup(size, color); door.position = pos; door.rotation_degrees = rotation_value; add_child(door); return door

func _loot(pos: Vector3, title: String, color: Color) -> LootContainer:
	var loot := LootContainer.new(); loot.display_name = title; loot.setup(Vector3(1.2,0.7,0.8), color); loot.position = pos; add_child(loot); return loot

func _ceiling_light(pos: Vector3) -> void:
	var light := OmniLight3D.new(); light.position = pos; light.light_color = Color("#fff0d2"); light.light_energy = 2.3; light.omni_range = 9.0; add_child(light)
	var panel := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(1.4,0.06,0.42)
	var glow := _material(Color("#fff4df"),0.0,0.2); glow.emission_enabled = true; glow.emission = Color("#ffeac1"); glow.emission_energy_multiplier = 2.1
	mesh.material = glow; panel.mesh = mesh; panel.position = pos + Vector3(0,0.2,0); add_child(panel)

func _mesh_box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; mesh.material = material; node.mesh = mesh; node.position = pos; node.rotation = rot; parent.add_child(node)

func _mesh_sphere(parent: Node, scale_value: Vector3, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0; mesh.material = material; node.mesh = mesh; node.scale = scale_value; node.position = pos; parent.add_child(node)

func _mesh_cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.material = material; node.mesh = mesh; node.position = pos; parent.add_child(node)

func _mesh_capsule(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new(); var mesh := CapsuleMesh.new(); mesh.radius = radius; mesh.height = height; mesh.material = material; node.mesh = mesh; node.position = pos; node.rotation = rot; parent.add_child(node)

func _mesh_torus(parent: Node, inner: float, outer: float, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new(); var mesh := TorusMesh.new(); mesh.inner_radius = inner; mesh.outer_radius = outer; mesh.material = material; node.mesh = mesh; node.position = pos; node.rotation_degrees.x = 90.0; parent.add_child(node)

func _sign(text_value: String, pos: Vector3, size: int, color: Color) -> void:
	var label := Label3D.new(); label.text = text_value; label.font_size = size; label.modulate = color; label.outline_size = 10; label.position = pos; add_child(label)

func _waypoint(text_value: String, pos: Vector3, color: Color) -> void:
	var marker := Label3D.new(); marker.text = text_value; marker.font_size = 34; marker.modulate = color; marker.outline_size = 12; marker.position = pos; marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; marker.no_depth_test = true; add_child(marker)
