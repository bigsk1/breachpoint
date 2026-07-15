class_name HiddenKeyCache
extends StaticBody3D

signal keys_taken(cache: HiddenKeyCache)

var display_name := "Hidden service lockbox"
var durability := 72.0
var broken := false
var collected := false
var location_hint := ""
var _lid: Node3D
var _label: Label3D
var _notice_cooldown := 0.0

func setup(color := Color("#525d60")) -> void:
	add_to_group("gas_key_cache")
	collision_layer = 1
	collision_mask = 2 | 8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 0.78, 0.64)
	collision.shape = shape
	add_child(collision)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.15, 0.58, 0.64)
	base_mesh.material = _material(color, 0.72, 0.36)
	base.mesh = base_mesh
	base.position.y = -0.10
	add_child(base)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.22, 0.25)
	add_child(_lid)
	var lid_mesh_instance := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.17, 0.18, 0.66)
	lid_mesh.material = _material(color.lightened(0.08), 0.78, 0.30)
	lid_mesh_instance.mesh = lid_mesh
	lid_mesh_instance.position.z = -0.25
	_lid.add_child(lid_mesh_instance)
	var latch := MeshInstance3D.new()
	var latch_mesh := BoxMesh.new()
	latch_mesh.size = Vector3(0.22, 0.26, 0.08)
	latch_mesh.material = _material(Color("#b18a45"), 0.88, 0.24)
	latch.mesh = latch_mesh
	latch.position = Vector3(0, 0.04, -0.35)
	add_child(latch)
	for offset in [-0.18, 0.18]:
		var scratch := MeshInstance3D.new()
		var scratch_mesh := BoxMesh.new()
		scratch_mesh.size = Vector3(0.035, 0.31, 0.018)
		scratch_mesh.material = _material(Color("#aeb8b7"), 0.65, 0.34)
		scratch.mesh = scratch_mesh
		scratch.position = Vector3(offset, 0.03, -0.365)
		scratch.rotation_degrees.z = 28.0 * signf(offset)
		add_child(scratch)
	_label = Label3D.new()
	_label.text = ""
	_label.font_size = 28
	_label.outline_size = 9
	_label.modulate = Color("#f0c65f")
	_label.position = Vector3(0, 0.85, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

func _process(delta: float) -> void:
	_notice_cooldown = maxf(0.0, _notice_cooldown - delta)

func take_damage(amount: float, _headshot := false, source: Object = null) -> void:
	if broken:
		return
	var weapon_id := ""
	if source and source.has_method("get_current_weapon_id"):
		weapon_id = str(source.get_current_weapon_id())
	if weapon_id not in ["fists", "pipe_wrench"]:
		if _notice_cooldown <= 0.0:
			_notice_cooldown = 1.4
			GameManager.notification.emit("Bullets only dent this reinforced lockbox - fists or a pipe wrench can break the latch", "warn")
		return
	var force_multiplier := 1.45 if weapon_id == "pipe_wrench" else 1.0
	durability -= amount * force_multiplier
	if durability <= 0.0:
		_break_open()
	else:
		GameManager.notification.emit("The lockbox latch is bending...", "warn")
		var shake := create_tween()
		shake.tween_property(self, "rotation:z", deg_to_rad(2.5), 0.05)
		shake.tween_property(self, "rotation:z", deg_to_rad(-2.5), 0.06)
		shake.tween_property(self, "rotation:z", 0.0, 0.05)

func _break_open() -> void:
	broken = true
	collision_layer = 4
	collision_mask = 8
	_label.text = "KEYS - SERVICE KEYS"
	GameManager.add_score(450, "Hidden service-key lockbox breached")
	GameManager.notification.emit("LOCKBOX OPEN - take the service keys", "good")
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lid, "rotation:x", deg_to_rad(-118.0), 0.38)

func get_interaction_text(_player: Node) -> String:
	if collected:
		return "EMPTY LOCKBOX"
	if not broken:
		return "REINFORCED LOCKBOX - BREAK THE LATCH"
	return "HOLD TO TAKE  ROUTE 17 SERVICE KEYS"

func interact(player: Node) -> void:
	if collected or not broken:
		return
	var keys := InventorySystem.item("route17_car_keys", "Route 17 Service Keys", "mission", 1, 0.08, false, 1, Color("#d8b252"))
	if not player.add_loot(keys):
		GameManager.notification.emit("Make room for the service keys", "warn")
		return
	collected = true
	collision_layer = 1
	collision_mask = 2 | 8
	_label.text = ""
	GameManager.notification.emit("SERVICE KEYS ACQUIRED - the garage car can now be started", "good")
	keys_taken.emit(self)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
