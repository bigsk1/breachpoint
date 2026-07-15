class_name ZombieIslandLevel
extends Node3D

signal mission_won

var player: Node3D
var wave := 0
var _remaining_to_spawn := 0
var _spawn_cooldown := 0.0
var _intermission := 1.5
var _waiting_for_wave := true
var _active: Array[UndeadAI] = []
var _rng := RandomNumberGenerator.new()
var _materials := {}

func _ready() -> void:
	_rng.randomize()
	_build_materials()
	_build_environment()
	_build_island()
	_build_cover_and_landmarks()
	_build_supplies()

func _process(delta: float) -> void:
	if not GameManager.run_active:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	for enemy in _active.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			_active.erase(enemy)
	if _waiting_for_wave:
		_intermission -= delta
		if _intermission <= 0.0:
			_start_wave()
		return
	if _remaining_to_spawn > 0:
		_spawn_cooldown -= delta
		if _spawn_cooldown <= 0.0 and _active.size() < _max_active():
			_spawn_undead()
			_remaining_to_spawn -= 1
			_spawn_cooldown = GameManager.get_difficulty_value(1.05, 0.72, 0.48)
			_update_objective()
	elif _active.is_empty():
		_waiting_for_wave = true
		_intermission = GameManager.get_difficulty_value(8.0, 6.0, 4.5)
		_spawn_wave_resupply()
		GameManager.add_score(450 + wave * 125, "Wave %d survived" % wave)
		GameManager.set_objective("WAVE %d CLEARED • Resupply and prepare — next wave in %.0f seconds" % [wave, _intermission])

func _spawn_wave_resupply() -> void:
	var contents: Array[Dictionary] = []
	contents.append(InventorySystem.ammo_item("fuel_cell", 60 + mini(wave * 5, 60)))
	contents.append(InventorySystem.ammo_item("ammo", 30 + mini(wave * 3, 30)))
	if wave % 2 == 0:
		contents.append(InventorySystem.ammo_item("shells", 6))
	if wave % 3 == 0:
		contents.append(InventorySystem.ammo_item("rockets", 1))
	var angle := float(wave % 8) / 8.0 * TAU
	var drop_position := Vector3(cos(angle) * 4.0, 0.65, 8.0 + sin(angle) * 4.0)
	_supply_cache("Wave %d resupply" % wave, drop_position, contents)

func _start_wave() -> void:
	wave += 1
	_waiting_for_wave = false
	var base_count := int(GameManager.get_difficulty_value(5.0, 7.0, 9.0))
	_remaining_to_spawn = base_count + wave * 2
	_spawn_cooldown = 0.15
	GameManager.notification.emit("WAVE %d — THE ISLAND IS WAKING UP" % wave, "warn")
	_update_objective()

func _spawn_undead() -> void:
	var skeleton_chance := clampf(0.28 + wave * 0.018, 0.28, 0.58)
	var kind := UndeadAI.Kind.SKELETON if _rng.randf() < skeleton_chance else UndeadAI.Kind.ZOMBIE
	var enemy := UndeadAI.new()
	enemy.configure(kind, _spawn_position(), wave)
	add_child(enemy)
	enemy.defeated.connect(_on_undead_defeated.bind(enemy))
	_active.append(enemy)

func _spawn_position() -> Vector3:
	for _attempt in 12:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(31.0, 40.0)
		var candidate := Vector3(cos(angle) * radius, 0.25, sin(angle) * radius)
		if not is_instance_valid(player) or candidate.distance_to(player.global_position) > 19.0:
			return candidate
	return Vector3(0, 0.25, -36)

func _on_undead_defeated(_kind_name: String, enemy: UndeadAI) -> void:
	_active.erase(enemy)
	_update_objective()

func _max_active() -> int:
	return int(GameManager.get_difficulty_value(8.0, 12.0, 16.0)) + mini(6, wave / 3)

func _update_objective() -> void:
	var total_left := _remaining_to_spawn + _active.size()
	GameManager.set_objective("ENDLESS WAVE %d • %d UNDEAD REMAIN • Zombies are tough; skeletons are fast" % [wave, total_left])

func _build_materials() -> void:
	_materials.sand = _material(Color("#92845d"), 0.0, 0.96)
	_materials.grass = _material(Color("#263c2d"), 0.0, 0.98)
	_materials.rock = _material(Color("#41484a"), 0.05, 0.94)
	_materials.wood = _material(Color("#4a3326"), 0.0, 0.92)
	_materials.rotten_wood = _material(Color("#29251f"), 0.0, 1.0)
	_materials.metal = _material(Color("#5e6462"), 0.68, 0.48)
	_materials.roof = _material(Color("#292f34"), 0.25, 0.82)
	_materials.fire = _emissive_material(Color("#ff6a28"), 5.0)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#07101c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#6383a0")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("#324b5b")
	environment.fog_density = 0.008
	environment.fog_height = 0.5
	environment.fog_height_density = 0.18
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, -28, 0)
	moon.light_color = Color("#91b4d8")
	moon.light_energy = 0.62
	moon.shadow_enabled = true
	add_child(moon)
	var water_material := _material(Color(0.025, 0.12, 0.19, 0.86), 0.18, 0.2)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box("MoonlitOcean", Vector3(150, 0.18, 150), Vector3(0, -1.35, 0), water_material, false)

func _build_island() -> void:
	_cylinder("IslandSand", 47.0, 1.8, Vector3(0, -0.9, 0), _materials.sand, true)
	_cylinder("IslandGrass", 40.5, 0.28, Vector3(0, 0.05, 0), _materials.grass, false)
	for index in 28:
		var angle := float(index) / 28.0 * TAU
		var radius := 43.0 + sin(index * 1.7) * 1.8
		_sphere("ShoreRock", Vector3(1.5, 0.8, 1.2), Vector3(cos(angle) * radius, 0.15, sin(angle) * radius), _materials.rock)
	for pos in [
		Vector3(-28,0,-14), Vector3(-24,0,18), Vector3(-8,0,30), Vector3(13,0,29),
		Vector3(29,0,15), Vector3(30,0,-11), Vector3(12,0,-31), Vector3(-15,0,-29)
	]:
		_palm_tree(pos)

func _build_cover_and_landmarks() -> void:
	# Abandoned lodge: open front and side gaps let the player kite enemies through it.
	_box("LodgeFloor", Vector3(14, 0.25, 11), Vector3(0, 0.18, -9), _materials.wood)
	_box("LodgeBack", Vector3(14, 3.8, 0.35), Vector3(0, 2.0, -14.3), _materials.rotten_wood)
	_box("LodgeLeft", Vector3(0.35, 3.8, 7.0), Vector3(-6.8, 2.0, -10.8), _materials.rotten_wood)
	_box("LodgeRight", Vector3(0.35, 3.8, 7.0), Vector3(6.8, 2.0, -10.8), _materials.rotten_wood)
	_box("LodgeRoof", Vector3(15, 0.35, 12), Vector3(0, 4.05, -9), _materials.roof, false)
	for x in [-4.2, 0.0, 4.2]:
		_box("LodgeBarricade", Vector3(2.2, 1.2, 0.35), Vector3(x, 0.6, -3.6), _materials.wood)
	# Crumbling ruins provide short walls to circle and break line-of-chase.
	for entry in [
		[Vector3(-19,1.2,9), Vector3(0.6,2.4,11)],
		[Vector3(-14,1.2,14), Vector3(10,2.4,0.6)],
		[Vector3(20,1.2,10), Vector3(0.6,2.4,12)],
		[Vector3(15,1.2,5), Vector3(10,2.4,0.6)],
		[Vector3(-6,0.75,20), Vector3(8,1.5,0.55)],
		[Vector3(7,0.75,23), Vector3(0.55,1.5,8)]
	]:
		_box("RuinedWall", entry[1], entry[0], _materials.rock)
	# Watch platform and stairs-like crates.
	_box("WatchPlatform", Vector3(7, 0.4, 7), Vector3(23, 3.6, -19), _materials.wood)
	for x in [19.8, 26.2]:
		for z in [-22.2, -15.8]:
			_box("WatchPost", Vector3(0.35, 3.6, 0.35), Vector3(x, 1.8, z), _materials.wood)
	for index in 4:
		_box("WatchStep", Vector3(2.4, 0.45, 1.1), Vector3(17.0 + index * 0.7, 0.22 + index * 0.42, -18.8), _materials.wood)
	# Central fire makes the safe orientation point visible from anywhere.
	_cylinder("FireRing", 1.2, 0.28, Vector3(0, 0.18, 8), _materials.rock, true)
	for angle in [0.0, 1.57, 3.14, 4.71]:
		_box("FireLog", Vector3(0.28, 0.28, 1.9), Vector3(cos(angle) * 0.25, 0.45, 8 + sin(angle) * 0.25), _materials.wood, false, Vector3(0, angle, 0))
	for height in [0.55, 0.9, 1.2]:
		_sphere("CampFlame", Vector3(0.65 - height * 0.18, 0.65, 0.65 - height * 0.18), Vector3(0, height, 8), _materials.fire, false)
	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color("#ff7935")
	fire_light.light_energy = 7.0
	fire_light.omni_range = 12.0
	fire_light.position = Vector3(0, 1.2, 8)
	add_child(fire_light)
	_sign("BLACKTIDE ISLAND", Vector3(0, 3.1, -14.1), 45, Color("#b8d0d9"))

func _build_supplies() -> void:
	_supply_cache("Lodge emergency case", Vector3(-4.8, 0.65, -12.2), [
		InventorySystem.item("medkit", "Field Medkit", "consumable", 2, 0.8, true, 3, Color("#d45f5f")),
		InventorySystem.item("armor_plate", "Armor Plate", "gear", 2, 1.1, true, 4, Color("#5f84a2")),
	])
	_supply_cache("Watchtower fuel crate", Vector3(23, 4.15, -19), [
		InventorySystem.ammo_item("fuel_cell", 80),
		InventorySystem.item("grenade", "Flash-Frag", "tactical", 2, 0.5, true, 4, Color("#8e9d68")),
	])
	_supply_cache("Ruins medical cache", Vector3(-17, 0.65, 11), [
		InventorySystem.item("medkit", "Field Medkit", "consumable", 2, 0.8, true, 3, Color("#d45f5f")),
	])

func _supply_cache(title: String, pos: Vector3, contents: Array[Dictionary]) -> void:
	var cache := LootContainer.new()
	cache.display_name = title
	cache.items = contents
	cache.setup(Vector3(1.3, 0.7, 0.85), Color("#43524a"))
	cache.position = pos
	add_child(cache)

func _palm_tree(pos: Vector3) -> void:
	_cylinder("PalmTrunk", 0.28, 5.2, pos + Vector3(0, 2.6, 0), _materials.wood, true)
	for index in 7:
		var angle := float(index) / 7.0 * TAU
		_box("PalmLeaf", Vector3(0.45, 0.08, 3.8), pos + Vector3(cos(angle) * 1.3, 5.25, sin(angle) * 1.3), _materials.grass, false, Vector3(0.12, angle, 0))

func _box(node_name: String, size: Vector3, pos: Vector3, material: Material, collision_enabled := true, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var body: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	body.name = node_name
	body.position = pos
	body.rotation = rotation_value
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return visual

func _cylinder(node_name: String, radius: float, height: float, pos: Vector3, material: Material, collision_enabled := true) -> MeshInstance3D:
	var body: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	body.name = node_name
	body.position = pos
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
	return visual

func _sphere(node_name: String, size: Vector3, pos: Vector3, material: Material, collision_enabled := true) -> MeshInstance3D:
	var body: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	body.name = node_name
	body.position = pos
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = material
	visual.mesh = mesh
	visual.scale = size
	body.add_child(visual)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(size.x, maxf(size.y, size.z)) * 0.5
		collision.shape = shape
		body.add_child(collision)
	return visual

func _sign(text_value: String, pos: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = font_size
	label.outline_size = 12
	label.modulate = color
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.0, 0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
