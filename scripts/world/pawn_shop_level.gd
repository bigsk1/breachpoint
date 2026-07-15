class_name PawnShopLevel
extends Node3D

signal mission_won

var player: Node3D
var _entered := false
var _business_done := false
var _escaped := false
var _reinforcement_waves := {}
var _materials := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build_materials()
	_build_environment()
	_build_architecture()
	_build_inventory_displays()
	_build_transactions()
	_build_secret()
	_spawn_initial_cast()
	GameManager.reinforcement_requested.connect(_on_reinforcement_requested)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	if not GameManager.run_active:
		return
	var z := player.global_position.z
	if not _entered and z < 22.0:
		_entered = true
		GameManager.add_score(100, "Mesa Exchange entered")
		var totals := GameManager.get_artifact_totals()
		if int(totals.count) > 0:
			GameManager.set_objective("Sell your stored artifacts at the appraisal counter")
		else:
			GameManager.set_objective("Browse the pawn shop, or search for valuables")
	if GameManager.get_alert_tier() > 0:
		_business_done = true
	if _business_done and not _escaped and z > 25.5:
		_escaped = true
		mission_won.emit()

func _build_materials() -> void:
	_materials.floor = _material(Color("#776b58"), 0.03, 0.88)
	_materials.wall = _material(Color("#c9bfa9"), 0.02, 0.9)
	_materials.dark = _material(Color("#25292b"), 0.48, 0.42)
	_materials.wood = _material(Color("#5b402b"), 0.05, 0.72)
	_materials.red = _material(Color("#713635"), 0.05, 0.74)
	_materials.gold = _material(Color("#c59b3b"), 0.72, 0.28)
	_materials.glass = _material(Color("#94c8cc"), 0.08, 0.18)

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
	environment.background_color = Color("#101417")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7c9ae")
	environment.ambient_light_energy = 0.40
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new(); moon.rotation_degrees = Vector3(-55,-28,0); moon.light_color = Color("#96abc2"); moon.light_energy = 0.32; moon.shadow_enabled = true; add_child(moon)
	for z in range(18, -21, -8):
		for x in [-14.0, -7.0, 0.0, 7.0, 14.0]:
			_ceiling_light(Vector3(x,4.1,float(z)))

func _build_architecture() -> void:
	_box("PawnGround", Vector3(44,0.35,62), Vector3(0,-0.18,2), _materials.floor)
	_box("PawnCeiling", Vector3(40,0.22,48), Vector3(0,4.45,0), _materials.dark, false)
	_box("WestWall", Vector3(0.35,4.7,48), Vector3(-20.2,2.25,0), _materials.wall)
	_box("EastWall", Vector3(0.35,4.7,48), Vector3(20.2,2.25,0), _materials.wall)
	_box("RearWall", Vector3(40,4.7,0.35), Vector3(0,2.25,-24.2), _materials.wall)
	_box("FrontLeft", Vector3(17,4.7,0.4), Vector3(-11.5,2.25,24.2), _materials.red)
	_box("FrontRight", Vector3(17,4.7,0.4), Vector3(11.5,2.25,24.2), _materials.red)
	_box("FrontHeader", Vector3(6,1.45,0.4), Vector3(0,3.95,24.2), _materials.gold)
	_box("EntranceApron", Vector3(16,0.28,9), Vector3(0,-0.12,28), _materials.dark)
	_door(Vector3(-1.7,1.25,24.0), Vector3(2.8,2.5,0.16), "Pawn shop entrance", Color("#3e565d"))
	_door(Vector3(1.3,1.25,24.0), Vector3(2.8,2.5,0.16), "Pawn shop entrance", Color("#3e565d"))
	# Back-room wall with a real central doorway.
	_box("BackWallL", Vector3(17.0,4.5,0.3), Vector3(-11.5,2.25,-10.0), _materials.wall)
	_box("BackWallR", Vector3(17.0,4.5,0.3), Vector3(11.5,2.25,-10.0), _materials.wall)
	_door(Vector3(-1.7,1.25,-9.82), Vector3(3.0,2.5,0.16), "Employees only", Color("#5e4937"))
	_box("BackOfficeDivider", Vector3(0.3,4.5,14), Vector3(0,2.25,-17), _materials.wall)
	_sign("MESA EXCHANGE  •  PAWN & LOAN", Vector3(0,3.25,23.95), 46, Color("#efc75d"))
	_sign("BUY  •  SELL  •  TRADE", Vector3(0,3.45,8.0), 28, Color("#e3bc5d"))
	_waypoint("◆  ARTIFACT APPRAISAL", Vector3(0,3.3,-1.0), Color("#f1ca62"))

func _build_inventory_displays() -> void:
	# Long side-wall shelving.
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 16.8
		for z in [16.0,10.0,4.0,-3.0]:
			_box("DisplayShelf", Vector3(2.6,2.1,4.2), Vector3(x,1.05,z), _materials.wood)
			for row in 2:
				for item_index in 3:
					var color := Color("#728b91") if (row + item_index) % 2 == 0 else Color("#a48650")
					_prop_box(Vector3(x - side * 1.38,0.72 + row * 0.72,z - 1.15 + item_index * 1.12), Vector3(0.48,0.34,0.62), color)
	# Center glass cases for watches, cameras, jewelry, and electronics.
	for x in [-10.0,-5.0,5.0,10.0]:
		_box("GlassCaseBase", Vector3(3.5,0.75,1.6), Vector3(x,0.38,6.0), _materials.dark)
		var glass := DestructibleProp.new(); glass.durability = 24.0; glass.setup(Vector3(3.35,1.0,1.45), Color("#9fd0d3"), true); glass.position = Vector3(x,1.22,6.0); add_child(glass)
		for item_index in 4:
			_prop_box(Vector3(x - 1.05 + item_index * 0.7,0.92,6.0), Vector3(0.25,0.12,0.3), Color("#d1a940"))
	# Pawn-shop silhouettes: guitars, televisions, tool cases, and speakers.
	for x in [-12.0,-8.0,8.0,12.0]:
		_prop_box(Vector3(x,1.0,14.0), Vector3(2.0,1.4,0.34), Color("#28343a"))
	for x in [-13.0,-6.5,6.5,13.0]:
		_prop_guitar(Vector3(x,1.2,-5.5), Color("#874f31") if x < 0 else Color("#395d70"))
	# Show a sample of the player's persistent collection behind the counter.
	var display_index := 0
	for id in GameManager.artifact_stash:
		if display_index >= 8:
			break
		var entry: Dictionary = GameManager.artifact_stash[id]
		var x := -7.0 + float(display_index % 4) * 4.6
		var z := -6.6 - float(display_index / 4) * 1.5
		_prop_box(Vector3(x,1.25,z), Vector3(0.8,0.8,0.8), entry.get("color", Color("#d8b85a")))
		var label := Label3D.new(); label.text = "%s ×%d" % [str(entry.get("title", id)), int(entry.get("quantity",1))]; label.font_size = 15; label.outline_size = 7; label.position = Vector3(x,2.0,z); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(label)
		display_index += 1

func _build_transactions() -> void:
	var broker := PawnBroker.new(); broker.setup(); broker.position = Vector3(0,0,-1.0); broker.transaction_completed.connect(_on_transaction_completed); add_child(broker)
	var register := ObjectiveStation.new()
	register.display_name = "Pawn shop cash register"
	register.action_text = "EMPTY"
	register.items = [InventorySystem.item("cash", "Pawn Register Cash", "loot", 18,0.12,true,30,Color("#78a45e"))]
	register.score_reward = 350
	register.alert_amount = 24.0
	register.notification_text = "Silent alarm from the pawn register"
	register.setup(Vector3(1.1,0.55,0.65), Color("#2c3335"))
	register.position = Vector3(4.7,1.05,-0.5)
	register.activated.connect(_on_register_emptied)
	add_child(register)
	var safe_loot := _loot(Vector3(9.5,0.55,-18.0), "Layaway safe", Color("#4e5559"))
	safe_loot.items = [InventorySystem.item("cash","Layaway Cash","loot",10,0.12,true,20,Color("#78a45e")), InventorySystem.artifact("vintage_mesa_watch","Vintage Mesa Railroad Watch",1450,0.35,Color("#d4ae4d")), InventorySystem.ammo_item("ammo", 36)]

func _build_secret() -> void:
	_box("SecretRoomL", Vector3(0.22,3.1,3.4), Vector3(-12.3,1.55,-20.2), _materials.wall)
	_box("SecretRoomR", Vector3(0.22,3.1,3.4), Vector3(-7.7,1.55,-20.2), _materials.wall)
	_box("SecretRoomBack", Vector3(4.8,3.1,0.22), Vector3(-10.0,1.55,-21.8), _materials.wall)
	var panel := SecretPanel.new(); panel.display_name = "Unclaimed property room"; panel.setup(Vector3(4.3,2.9,0.24),Color("#c4b9a2")); panel.position = Vector3(-10.0,1.45,-18.45); add_child(panel)
	var cache := _loot(Vector3(-10.0,0.55,-20.8), "Unclaimed property crate", Color("#66513f"))
	cache.items = [InventorySystem.artifact("turquoise_bolo","Turquoise Collector Bolo",1200,0.25,Color("#52a6a0")), InventorySystem.item("armor_plate","Old Ballistic Insert","gear",1,1.1,true,4,Color("#5f84a2")), InventorySystem.ammo_item("shells", 10)]

func _spawn_initial_cast() -> void:
	_spawn_actor(ActorAI.Kind.PAWNKEEPER, Vector3(-4.5,0,-3.0), [Vector3(-5,0,-3),Vector3(-5,0,-7)])
	_spawn_actor(ActorAI.Kind.PAWNKEEPER, Vector3(4.5,0,-3.0), [Vector3(5,0,-3),Vector3(5,0,-7)])
	var civilian_positions: Array[Vector3] = [Vector3(-9,0,15),Vector3(9,0,13),Vector3(-7,0,4),Vector3(8,0,1),Vector3(13,0,-4),Vector3(-13,0,-2)]
	civilian_positions.shuffle()
	var count := int(GameManager.get_difficulty_value(3.0,4.0,5.0))
	for index in count:
		_spawn_actor(ActorAI.Kind.CIVILIAN, civilian_positions[index])

func _spawn_actor(kind: ActorAI.Kind, pos: Vector3, patrol: Array[Vector3] = []) -> ActorAI:
	var actor := ActorAI.new(); actor.configure(kind,pos,patrol); add_child(actor); return actor

func _on_transaction_completed(payout: int) -> void:
	_business_done = true
	GameManager.add_score(300 if payout > 0 else 75, "Appraisal counter visited")
	GameManager.set_objective("Transaction complete — exit through the front doors")

func _on_register_emptied(_station: ObjectiveStation) -> void:
	_business_done = true
	GameManager.set_objective("Cash secured — leave through the front doors")

func _on_reinforcement_requested(tier: int) -> void:
	if _reinforcement_waves.has(tier):
		return
	_reinforcement_waves[tier] = true
	if tier == 2:
		GameManager.notification.emit("DISPATCH: Units responding to Mesa Exchange", "voice")
		for index in int(GameManager.get_difficulty_value(2.0,3.0,4.0)):
			_spawn_actor(ActorAI.Kind.POLICE,Vector3(-6.0 + index * 4.0,0,28.0))
	elif tier == 3:
		GameManager.notification.emit("SWAT: Pawn shop containment underway", "voice")
		for index in int(GameManager.get_difficulty_value(2.0,3.0,5.0)):
			_spawn_actor(ActorAI.Kind.SWAT,Vector3(-8.0 + index * 4.0,0,29.0))

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

func _prop_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; mesh.material = _material(color,0.18,0.58); visual.mesh = mesh; visual.position = pos; add_child(visual)

func _prop_guitar(pos: Vector3, color: Color) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var body := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.5; sphere.height = 1.0; sphere.material = _material(color,0.03,0.52); body.mesh = sphere; body.scale = Vector3(0.48,0.62,0.16); root.add_child(body)
	var neck := MeshInstance3D.new(); var neck_mesh := BoxMesh.new(); neck_mesh.size = Vector3(0.14,1.35,0.10); neck_mesh.material = _materials.wood; neck.mesh = neck_mesh; neck.position.y = 0.9; root.add_child(neck)

func _door(pos: Vector3, size: Vector3, title: String, color: Color) -> InteractableDoor:
	var door := InteractableDoor.new(); door.display_name = title; door.setup(size,color); door.position = pos; add_child(door); return door

func _loot(pos: Vector3, title: String, color: Color) -> LootContainer:
	var loot := LootContainer.new(); loot.display_name = title; loot.setup(Vector3(1.2,0.65,0.72),color); loot.position = pos; add_child(loot); return loot

func _ceiling_light(pos: Vector3) -> void:
	var light := OmniLight3D.new(); light.position = pos; light.light_color = Color("#ffe9bd"); light.light_energy = 1.7; light.omni_range = 8.0; add_child(light)
	var panel := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(1.0,0.06,0.32); var glow := _material(Color("#fff2d5"),0.0,0.2); glow.emission_enabled = true; glow.emission = Color("#ffe8b8"); glow.emission_energy_multiplier = 1.7; mesh.material = glow; panel.mesh = mesh; panel.position = pos + Vector3(0,0.15,0); add_child(panel)

func _sign(text_value: String, pos: Vector3, size: int, color: Color) -> void:
	var label := Label3D.new(); label.text = text_value; label.font_size = size; label.modulate = color; label.outline_size = 10; label.position = pos; add_child(label)

func _waypoint(text_value: String, pos: Vector3, color: Color) -> void:
	var marker := Label3D.new(); marker.text = text_value; marker.font_size = 30; marker.modulate = color; marker.outline_size = 12; marker.position = pos; marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; marker.no_depth_test = true; add_child(marker)
