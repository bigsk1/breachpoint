class_name GasStationLevel
extends Node3D

const HIDDEN_KEY_CACHE_SCRIPT := preload("res://scripts/world/hidden_key_cache.gd")
const GETAWAY_CAR_SCRIPT := preload("res://scripts/world/getaway_car.gd")

signal mission_won

var player: Node3D
var _entered := false
var _register_robbed := false
var _escaped := false
var _reinforcement_waves := {}
var _materials := {}
var _rng := RandomNumberGenerator.new()
var _keys_found := false
var _key_spawn_index := -1
var _key_cache: Node3D
var _car: Node3D

func _ready() -> void:
	_rng.randomize()
	_build_materials()
	_build_environment()
	_build_architecture()
	_build_furnishings()
	_build_getaway_route()
	_spawn_initial_cast()
	GameManager.reinforcement_requested.connect(_on_reinforcement_requested)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	if not GameManager.run_active:
		return
	var z := player.global_position.z
	if not _entered and z < 19.0:
		_entered = true
		GameManager.add_score(125, "Gas station entered")
		GameManager.set_objective("Empty the register, then find the hidden service keys and escape in the garage car")

func _build_materials() -> void:
	_materials.asphalt = _material(Color("#252a2d"), 0.02, 0.96)
	_materials.floor = _material(Color("#9b9588"), 0.04, 0.76)
	_materials.wall = _material(Color("#d2c9b7"), 0.02, 0.9)
	_materials.red = _material(Color("#a8322c"), 0.12, 0.48)
	_materials.blue = _material(Color("#1f4d67"), 0.18, 0.42)
	_materials.metal = _material(Color("#626c70"), 0.76, 0.3)
	_materials.dark = _material(Color("#20272a"), 0.38, 0.45)
	_materials.wood = _material(Color("#684c32"), 0.03, 0.72)
	_materials.tile = _material(Color("#d5d8d5"), 0.04, 0.32)
	_materials.yellow = _material(Color("#d2a733"), 0.2, 0.46)

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
	environment.background_color = Color("#101923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#91a5b5")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("#485b67")
	environment.fog_density = 0.004
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -34, 0)
	moon.light_color = Color("#9ab2cc")
	moon.light_energy = 0.48
	moon.shadow_enabled = true
	add_child(moon)
	for z in [-13.0, -4.0, 5.0, 14.0]:
		for x in [-10.0, -2.0, 12.0, 21.0]:
			_ceiling_light(Vector3(x, 4.2, z))

func _build_architecture() -> void:
	_box("ParkingLot", Vector3(76, 0.32, 76), Vector3(7, -0.18, 8), _materials.asphalt)
	_box("StoreFloor", Vector3(22, 0.16, 36), Vector3(-4, 0.02, 0), _materials.floor, false)
	_box("ShopFloor", Vector3(22, 0.16, 30), Vector3(18, 0.02, -3), _materials.dark, false)
	_box("StoreCeiling", Vector3(22, 0.2, 36), Vector3(-4, 4.65, 0), _materials.dark, false)
	_box("ShopCeiling", Vector3(22, 0.2, 30), Vector3(18, 4.65, -3), _materials.dark, false)
	_box("WestWall", Vector3(0.35, 4.8, 36), Vector3(-15.2, 2.3, 0), _materials.wall)
	_box("RearWall", Vector3(44.4, 4.8, 0.35), Vector3(7, 2.3, -18.2), _materials.wall)
	_box("EastWall", Vector3(0.35, 4.8, 30), Vector3(29.2, 2.3, -3), _materials.metal)
	# Store facade and a usable double entrance.
	_box("StoreFrontLeft", Vector3(8.8, 4.8, 0.35), Vector3(-10.6, 2.3, 18.2), _materials.red)
	_box("StoreFrontRight", Vector3(8.8, 4.8, 0.35), Vector3(2.6, 2.3, 18.2), _materials.red)
	_box("StoreFrontHeader", Vector3(4.4, 1.3, 0.35), Vector3(-4, 4.05, 18.2), _materials.red)
	_door(Vector3(-6.1, 1.3, 18.0), Vector3(2.0, 2.6, 0.16), "Convenience store door", Color("#335967"))
	_door(Vector3(-3.9, 1.3, 18.0), Vector3(2.0, 2.6, 0.16), "Convenience store door", Color("#335967"))
	# Divider has a genuine doorway into the attached auto shop.
	_box("DividerRear", Vector3(0.3, 4.8, 11.0), Vector3(7.0, 2.3, -12.5), _materials.wall)
	_box("DividerFront", Vector3(0.3, 4.8, 21.0), Vector3(7.0, 2.3, 7.5), _materials.wall)
	_door(Vector3(7.15, 1.3, -5.2), Vector3(0.16, 2.6, 2.6), "Auto shop access", Color("#5f503d"), Vector3(0, 90, 0))
	# Wide garage bay makes the service area readable and explorable.
	_box("GarageFrontLeft", Vector3(8.4, 4.8, 0.35), Vector3(11.2, 2.3, 12.2), _materials.metal)
	_box("GarageFrontRight", Vector3(4.4, 4.8, 0.35), Vector3(27.0, 2.3, 12.2), _materials.metal)
	_box("GarageHeader", Vector3(9.2, 1.1, 0.35), Vector3(20.0, 4.15, 12.2), _materials.red)
	# Restroom at the rear-left with a real interior.
	_box("RestroomFrontL", Vector3(4.4, 4.4, 0.25), Vector3(-12.8, 2.2, -9.0), _materials.tile)
	_box("RestroomFrontR", Vector3(3.2, 4.4, 0.25), Vector3(-6.6, 2.2, -9.0), _materials.tile)
	_box("RestroomSide", Vector3(0.25, 4.4, 9.0), Vector3(-5.0, 2.2, -13.5), _materials.tile)
	_door(Vector3(-9.35, 1.25, -8.85), Vector3(2.5, 2.5, 0.16), "Restroom", Color("#445866"))
	_sign("ROUTE 17 FUEL & SERVICE", Vector3(-4, 3.28, 18.0), 48, Color("#f6e4b1"))
	_sign("RESTROOM", Vector3(-9.4, 3.15, -8.72), 25, Color("#315d71"))
	_sign("AUTO SHOP", Vector3(20, 3.3, 12.0), 44, Color("#f0d37a"))
	_waypoint("◆  CASH REGISTER", Vector3(3.3, 3.1, 1.8), Color("#f1c45b"))
	_build_canopy_and_pumps()

func _build_canopy_and_pumps() -> void:
	_box("FuelCanopy", Vector3(34, 0.5, 14), Vector3(-1, 5.2, 29), _materials.red, false)
	for x in [-13.0, 11.0]:
		for z in [24.0, 34.0]:
			_box("CanopyPost", Vector3(0.45, 5.2, 0.45), Vector3(x, 2.55, z), _materials.metal)
	for x in [-9.0, -1.0, 7.0]:
		_box("FuelPump", Vector3(1.0, 1.8, 0.75), Vector3(x, 0.9, 29), _materials.blue)
		_box("PumpScreen", Vector3(0.72, 0.45, 0.08), Vector3(x, 1.15, 28.58), _materials.dark, false)
	for x in range(-24, 31, 6):
		_box("ParkingStripe", Vector3(0.15, 0.02, 5.5), Vector3(float(x), 0.02, 20.5), _materials.yellow, false)

func _build_furnishings() -> void:
	# Framed Southwestern artwork breaks up the store's blank divider wall.
	_portrait(Vector3(6.84, 2.45, 9.0), 3, -90.0)
	_portrait(Vector3(6.84, 2.45, 4.5), 0, -90.0)
	# Pipe-wrench Easter egg: a false service panel conceals a retired mechanic's stash.
	_box("SecretBayL", Vector3(0.22, 3.1, 3.0), Vector3(9.0, 1.55, -15.5), _materials.wall)
	_box("SecretBayR", Vector3(0.22, 3.1, 3.0), Vector3(13.0, 1.55, -15.5), _materials.wall)
	_box("SecretBayBack", Vector3(4.2, 3.1, 0.22), Vector3(11.0, 1.55, -17.0), _materials.wall)
	var mechanic_panel := SecretPanel.new(); mechanic_panel.display_name = "Retired mechanic's stash"; mechanic_panel.setup(Vector3(3.8, 2.9, 0.24), Color("#d0c7b5")); mechanic_panel.position = Vector3(11.0, 1.45, -14.0); add_child(mechanic_panel)
	var mechanic_cache := _loot(Vector3(11.0, 0.55, -16.0), "Mechanic's hidden crate", Color("#59665d"))
	mechanic_cache.items = [InventorySystem.item("knife", "Workshop Knife", "weapon", 1, 0.8, false, 1, Color("#b7c3c7")), InventorySystem.item("scrap", "Rare Alloy Scrap", "crafting", 3, 0.25, true, 8, Color("#8fa5a5")), InventorySystem.artifact("route17_service_badge", "Route 17 Enamel Service Badge", 900, 0.2, Color("#d45f47"))]
	# Checkout counter and interactive cash register.
	_box("CheckoutCounter", Vector3(7.0, 1.05, 1.45), Vector3(2.8, 0.52, 2.0), _materials.wood)
	var register := ObjectiveStation.new()
	register.display_name = "Cash register"
	register.action_text = "HOLD TO EMPTY"
	register.items = [InventorySystem.item("cash", "Register Cash", "loot", 12, 0.12, true, 30, Color("#78a45e"))]
	register.score_reward = 900
	register.alert_amount = 68.0
	register.notification_text = "Silent alarm tripped — police dispatched"
	register.setup(Vector3(0.8, 0.45, 0.65), Color("#343b3d"))
	register.position = Vector3(3.4, 1.28, 1.7)
	register.activated.connect(_on_register_robbed)
	add_child(register)
	# Convenience-store aisles contain usable food.
	for z in [6.0, 10.0]:
		_box("SnackAisle", Vector3(6.2, 1.35, 1.15), Vector3(-7.0, 0.68, z), _materials.blue)
	var snacks := _loot(Vector3(-10.5, 1.5, 6.0), "Snack display", Color("#b44732"))
	snacks.items = [InventorySystem.item("snack", "Energy Snack", "consumable", 3, 0.15, true, 6, Color("#e9a649")), InventorySystem.item("soda", "Cold Soda", "consumable", 2, 0.3, true, 4, Color("#4aa1be"))]
	var counter_snacks := _loot(Vector3(-3.5, 1.45, 10.0), "Counter snacks", Color("#b86f33"))
	counter_snacks.items = [InventorySystem.item("snack", "Energy Snack", "consumable", 2, 0.15, true, 6, Color("#e9a649"))]
	# Restroom is worth searching.
	_box("Sink", Vector3(1.4, 0.7, 0.65), Vector3(-13.0, 0.75, -16.0), _materials.tile)
	_box("RestroomStall", Vector3(3.2, 2.0, 0.15), Vector3(-8.0, 1.0, -14.2), _materials.blue)
	var restroom_aid := _loot(Vector3(-12.7, 1.45, -12.0), "Restroom first aid", Color("#753c3c"))
	restroom_aid.items = [InventorySystem.item("medkit", "Field Medkit", "consumable", 1, 0.8, true, 3, Color("#d45f5f"))]
	var ammo_locker := _loot(Vector3(25.0, 0.55, -9.0), "Garage ammunition locker", Color("#4a5557"))
	ammo_locker.items = [InventorySystem.ammo_item("ammo", 48), InventorySystem.ammo_item("shells", 10)]
	# Auto-shop lift, tires, scrap, and armor crafting bench.
	_box("VehicleLiftL", Vector3(0.5, 0.28, 8.0), Vector3(15.0, 0.22, -2.5), _materials.yellow)
	_box("VehicleLiftR", Vector3(0.5, 0.28, 8.0), Vector3(20.0, 0.22, -2.5), _materials.yellow)
	for pos in [Vector3(27,0.6,-14), Vector3(27,1.4,-14), Vector3(27,0.6,-11), Vector3(27,1.4,-11)]:
		_tire(pos)
	for data in [
		[Vector3(12.0, 0.55, -13.0), "Parts crate", 1],
		[Vector3(22.0, 0.55, -4.0), "Engine scrap", 2],
		[Vector3(25.0, 0.55, 6.0), "Tool cabinet", 2],
	]:
		var scrap := _loot(data[0], data[1], Color("#5d6663"))
		scrap.items = [InventorySystem.item("scrap", "Auto-Shop Scrap", "crafting", data[2], 0.35, true, 8, Color("#8fa5a5"))]
	_box("ArmorBench", Vector3(4.2, 1.0, 1.4), Vector3(23.5, 0.5, -13.0), _materials.metal)
	var armor_bench := ObjectiveStation.new()
	armor_bench.display_name = "Improvised armor bench"
	armor_bench.action_text = "HOLD TO BUILD ARMOR — 3 SCRAP"
	armor_bench.required_item_id = "scrap"
	armor_bench.required_quantity = 3
	armor_bench.items = [InventorySystem.item("armor_plate", "Improvised Armor Plate", "gear", 2, 1.1, true, 4, Color("#5f84a2"))]
	armor_bench.score_reward = 500
	armor_bench.notification_text = "Improvised armor built — use it from the hotbar"
	armor_bench.setup(Vector3(1.15, 0.55, 0.8), Color("#44616a"))
	armor_bench.position = Vector3(23.5, 1.35, -13.0)
	add_child(armor_bench)

func _build_getaway_route() -> void:
	var hiding_spots: Array[Dictionary] = [
		{"position": Vector3(-13.1, 0.78, -15.3), "rotation": Vector3(0, 0, 0), "hint": "restroom plumbing recess"},
		{"position": Vector3(5.7, 0.76, 3.1), "rotation": Vector3(0, 28, 0), "hint": "behind the checkout counter"},
		{"position": Vector3(27.7, 0.82, -7.2), "rotation": Vector3(0, -90, 0), "hint": "garage tool wall"},
		{"position": Vector3(25.9, 0.72, -12.8), "rotation": Vector3(0, 12, 0), "hint": "behind the tire stacks"},
		{"position": Vector3(10.0, 0.78, -13.4), "rotation": Vector3(0, 0, 0), "hint": "retired mechanic bay"},
	]
	_key_spawn_index = _rng.randi_range(0, hiding_spots.size() - 1)
	var chosen := hiding_spots[_key_spawn_index]
	_key_cache = HIDDEN_KEY_CACHE_SCRIPT.new()
	_key_cache.setup(Color("#4f5d60"))
	_key_cache.location_hint = str(chosen.hint)
	_key_cache.position = chosen.position
	_key_cache.rotation_degrees = chosen.rotation
	_key_cache.keys_taken.connect(_on_keys_taken)
	add_child(_key_cache)
	_car = GETAWAY_CAR_SCRIPT.new()
	_car.setup()
	_car.position = Vector3(20.0, 0.0, -1.2)
	_car.drive_requested.connect(_on_drive_requested)
	_car.escaped.connect(_on_car_escaped)
	add_child(_car)
	_sign("GETAWAY VEHICLE", Vector3(20.0, 3.15, -4.4), 25, Color("#e0bd62"))

func _on_keys_taken(_cache: Node) -> void:
	_keys_found = true
	if _register_robbed:
		GameManager.set_objective("Return to the auto shop and start the getaway car")
	else:
		GameManager.set_objective("Service keys found — empty the cash register, then use the garage car")

func _on_drive_requested(car: Node, rider: Node) -> void:
	if _escaped:
		return
	if not _register_robbed:
		GameManager.notification.emit("The getaway is ready, but the cash register is still untouched", "warn")
		GameManager.set_objective("Empty the cash register before leaving in the garage car")
		return
	if not _keys_found or rider.get_inventory().count_item("route17_car_keys") <= 0:
		GameManager.notification.emit("Find the hidden Route 17 service keys first", "warn")
		return
	_escaped = true
	GameManager.add_score(1800, "Getaway vehicle unlocked")
	GameManager.set_objective("Drive away from Route 17")
	car.begin_escape(rider)

func _on_car_escaped() -> void:
	mission_won.emit()

func _spawn_initial_cast() -> void:
	var employee_positions: Array[Vector3] = [
		Vector3(1.5,0,0), Vector3(4,0,6), Vector3(-8,0,-3),
		Vector3(14,0,-8), Vector3(20,0,-5), Vector3(25,0,5),
	]
	employee_positions.shuffle()
	var employee_count := int(GameManager.get_difficulty_value(2.0, 2.0, 3.0))
	for i in employee_count:
		_spawn_actor(ActorAI.Kind.EMPLOYEE, employee_positions[i])
	var civilian_positions: Array[Vector3] = [
		Vector3(-9,0,13), Vector3(-5,0,5), Vector3(-10,0,-4),
		Vector3(2,0,10), Vector3(12,0,5), Vector3(22,0,2),
	]
	civilian_positions.shuffle()
	var civilian_count := int(GameManager.get_difficulty_value(3.0, 4.0, 5.0))
	for i in civilian_count:
		_spawn_actor(ActorAI.Kind.CIVILIAN, civilian_positions[i])

func _spawn_actor(kind: ActorAI.Kind, pos: Vector3, patrol: Array[Vector3] = []) -> ActorAI:
	var actor := ActorAI.new()
	actor.configure(kind, pos, patrol)
	add_child(actor)
	return actor

func _on_register_robbed(_station: ObjectiveStation) -> void:
	if _register_robbed:
		return
	_register_robbed = true
	if _keys_found:
		GameManager.set_objective("Return to the auto shop and start the getaway car")
	else:
		GameManager.set_objective("Find the hidden service keys — smash the reinforced lockbox with fists or a pipe wrench")

func _on_reinforcement_requested(tier: int) -> void:
	if _reinforcement_waves.has(tier):
		return
	_reinforcement_waves[tier] = true
	match tier:
		1:
			GameManager.notification.emit("EMPLOYEE: Police are on the way!", "voice")
		2:
			GameManager.notification.emit("DISPATCH: Units arriving at Route 17 Fuel", "voice")
			var police_count := int(GameManager.get_difficulty_value(2.0, 3.0, 4.0))
			for i in police_count:
				_spawn_actor(ActorAI.Kind.POLICE, Vector3(-8.0 + i * 5.0, 0, 25.0 + absf(i - 1) * 2.0))
		3:
			GameManager.notification.emit("SWAT: Service station containment in progress", "voice")
			var swat_count := int(GameManager.get_difficulty_value(2.0, 3.0, 4.0))
			for i in swat_count:
				_spawn_actor(ActorAI.Kind.SWAT, Vector3(10.0 + i * 4.0, 0, 18.0 + i))

func _box(name_value: String, size: Vector3, pos: Vector3, material: Material, collision := true) -> Node3D:
	var root: Node3D
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2 | 8
		root = body
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
	else:
		root = Node3D.new()
	root.name = name_value
	root.position = pos
	add_child(root)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	root.add_child(visual)
	return root

func _door(pos: Vector3, size: Vector3, title: String, color: Color, rotation_value := Vector3.ZERO) -> InteractableDoor:
	var door := InteractableDoor.new()
	door.display_name = title
	door.setup(size, color)
	door.position = pos
	door.rotation_degrees = rotation_value
	add_child(door)
	return door

func _loot(pos: Vector3, title: String, color: Color) -> LootContainer:
	var loot := LootContainer.new()
	loot.display_name = title
	loot.setup(Vector3(1.2, 0.7, 0.8), color)
	loot.position = pos
	add_child(loot)
	return loot

func _ceiling_light(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color("#fff0cc")
	light.light_energy = 2.2
	light.omni_range = 8.0
	add_child(light)
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.3, 0.06, 0.4)
	var glow := _material(Color("#fff4d8"), 0.0, 0.18)
	glow.emission_enabled = true
	glow.emission = Color("#fff0c8")
	glow.emission_energy_multiplier = 2.0
	mesh.material = glow
	panel.mesh = mesh
	panel.position = pos + Vector3(0, 0.2, 0)
	add_child(panel)

func _tire(pos: Vector3) -> void:
	var tire := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.24
	mesh.outer_radius = 0.52
	mesh.material = _materials.dark
	tire.mesh = mesh
	tire.position = pos
	tire.rotation_degrees.x = 90.0
	add_child(tire)

func _portrait(pos: Vector3, _quadrant: int, rotation_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rotation_y
	add_child(root)
	var backing := MeshInstance3D.new()
	var backing_mesh := BoxMesh.new(); backing_mesh.size = Vector3(2.35, 1.72, 0.10); backing_mesh.material = _materials.dark
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
	var label := Label3D.new()
	label.text = text_value
	label.font_size = size
	label.modulate = color
	label.outline_size = 10
	label.position = pos
	add_child(label)

func _waypoint(text_value: String, pos: Vector3, color: Color) -> void:
	var marker := Label3D.new()
	marker.text = text_value
	marker.font_size = 32
	marker.modulate = color
	marker.outline_size = 12
	marker.position = pos
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	add_child(marker)
