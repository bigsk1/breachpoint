class_name UndeadAI
extends CharacterBody3D

signal defeated(kind_name: String)

enum Kind { ZOMBIE, SKELETON }

var undead_kind := Kind.ZOMBIE
var wave_number := 1
var max_health := 120.0
var health := 120.0
var move_speed := 2.8
var attack_damage := 13.0
var attack_interval := 1.0
var dead := false

var _player: Node3D
var _attack_cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _visual: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _jaw: Node3D
var _label: Label3D
var _burn_light: OmniLight3D
var _burn_time := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _stuck_time := 0.0
var _escape_direction := Vector3.ZERO
var _escape_time := 0.0

func configure(kind: Kind, spawn_position: Vector3, wave := 1) -> void:
	undead_kind = kind
	position = spawn_position
	wave_number = maxi(1, wave)
	var wave_scale := 1.0 + minf(1.8, float(wave_number - 1) * 0.055)
	if undead_kind == Kind.SKELETON:
		max_health = 96.0 * wave_scale
		move_speed = 3.8 + minf(1.25, wave_number * 0.038)
		attack_damage = 12.0
		attack_interval = 0.72
	else:
		max_health = 138.0 * wave_scale
		move_speed = 2.55 + minf(0.9, wave_number * 0.025)
		attack_damage = 16.0
		attack_interval = 1.02
	max_health *= GameManager.get_difficulty_value(0.78, 1.0, 1.28)
	attack_damage *= GameManager.get_difficulty_value(0.62, 1.0, 1.32)
	move_speed *= GameManager.get_difficulty_value(0.88, 1.0, 1.12)
	health = max_health

func _ready() -> void:
	_rng.randomize()
	add_to_group("actors")
	add_to_group("hostiles")
	add_to_group("damageable")
	add_to_group("undead")
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.76
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	_build_visual()
	_player = get_tree().get_first_node_in_group("player")
	_label = Label3D.new()
	_label.text = get_actor_name().to_upper()
	_label.font_size = 21
	_label.outline_size = 7
	_label.modulate = Color("#b9d89a") if undead_kind == Kind.ZOMBIE else Color("#b97b70")
	_label.position.y = 2.15
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

func _physics_process(delta: float) -> void:
	if dead or not GameManager.run_active:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_escape_time = maxf(0.0, _escape_time - delta)
	_process_burning(delta)
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var offset := _player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 1.48:
		_chase(offset.normalized(), delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 16.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 16.0)
		look_at(Vector3(_player.global_position.x, global_position.y, _player.global_position.z), Vector3.UP)
		if _attack_cooldown <= 0.0 and _can_reach_player():
			_attack_player()
	_animate(delta)
	var previous := global_position
	var intended_speed := Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	_recover_from_collision(delta, previous, intended_speed)

func _chase(direction: Vector3, delta: float) -> void:
	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("undead"):
		if other == self or not other is Node3D:
			continue
		var away := global_position - (other as Node3D).global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.03 and distance < 1.15:
			separation += away.normalized() * (1.15 - distance)
	if separation.length_squared() > 0.01:
		direction = (direction + separation * 1.5).normalized()
	if _escape_time > 0.0:
		direction = _escape_direction
	var probe := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.UP + direction * 1.05)
	probe.collision_mask = 1 | 4
	probe.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(probe).is_empty():
		var side := -1.0 if get_instance_id() % 2 == 0 else 1.0
		var lateral := Vector3(-direction.z, 0.0, direction.x) * side
		_escape_direction = (direction * -0.25 + lateral).normalized()
		_escape_time = 0.8
		direction = _escape_direction
	velocity.x = move_toward(velocity.x, direction.x * move_speed, delta * 9.0)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, delta * 9.0)
	look_at(global_position + direction, Vector3.UP)

func _recover_from_collision(delta: float, previous: Vector3, intended_speed: float) -> void:
	var moved := Vector2(global_position.x - previous.x, global_position.z - previous.z).length()
	if intended_speed > 0.5 and moved < 0.01:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
	if _stuck_time > 0.32:
		var angle := 1.8 if get_instance_id() % 2 == 0 else -1.8
		_escape_direction = (-global_basis.z).rotated(Vector3.UP, angle).normalized()
		_escape_time = 1.0
		_stuck_time = 0.0

func _can_reach_player() -> bool:
	var from := global_position + Vector3.UP * 1.2
	var to := _player.global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4 | 8
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == _player

func _attack_player() -> void:
	_attack_cooldown = attack_interval * _rng.randf_range(0.9, 1.12)
	if _left_arm:
		var tween := create_tween()
		tween.tween_property(_left_arm, "rotation:x", -1.2, 0.10)
		tween.tween_property(_left_arm, "rotation:x", 0.0, 0.22)
	if _right_arm:
		var tween := create_tween()
		tween.tween_property(_right_arm, "rotation:x", -1.1, 0.12)
		tween.tween_property(_right_arm, "rotation:x", 0.0, 0.20)
	_player.take_damage(attack_damage * _rng.randf_range(0.88, 1.12), false, self)

func _animate(_delta: float) -> void:
	if not _visual:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var phase := Time.get_ticks_msec() * 0.009 + float(get_instance_id() % 17)
	var stride := sin(phase) * clampf(speed / maxf(move_speed, 0.1), 0.0, 1.0)
	if _left_leg:
		_left_leg.rotation.x = stride * 0.55
	if _right_leg:
		_right_leg.rotation.x = -stride * 0.55
	if _left_arm and _attack_cooldown <= attack_interval * 0.55:
		_left_arm.rotation.x = -0.72 + stride * 0.18
	if _right_arm and _attack_cooldown <= attack_interval * 0.55:
		_right_arm.rotation.x = -0.72 - stride * 0.18
	_visual.position.y = sin(phase * 2.0) * 0.025
	if _jaw and undead_kind == Kind.SKELETON:
		_jaw.rotation.x = 0.08 + maxf(0.0, sin(phase * 0.63)) * 0.24

func take_damage(amount: float, headshot := false, _source: Object = null) -> void:
	if dead:
		return
	health -= amount * (1.7 if headshot else 1.0)
	if health <= 0.0:
		_die(headshot)
	elif _visual:
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
		tween.tween_property(_visual, "scale", Vector3.ONE, 0.12)

func ignite(duration: float, damage_per_second: float) -> void:
	if dead:
		return
	_burn_time = maxf(_burn_time, duration)
	_burn_dps = maxf(_burn_dps, damage_per_second)
	if not _burn_light:
		_burn_light = OmniLight3D.new()
		_burn_light.light_color = Color("#ff6a25")
		_burn_light.light_energy = 3.5
		_burn_light.omni_range = 2.6
		_burn_light.position.y = 1.0
		add_child(_burn_light)

func _process_burning(delta: float) -> void:
	if _burn_time <= 0.0:
		if _burn_light:
			_burn_light.queue_free()
			_burn_light = null
		return
	_burn_time -= delta
	_burn_tick -= delta
	if _burn_light:
		_burn_light.light_energy = 2.7 + sin(Time.get_ticks_msec() * 0.03) * 0.8
	if _burn_tick <= 0.0:
		_burn_tick = 0.25
		take_damage(_burn_dps * 0.25, false)

func apply_knockback(force: Vector3) -> void:
	if dead:
		return
	velocity.x += force.x
	velocity.z += force.z
	velocity.y = maxf(velocity.y, minf(4.0, force.length() * 0.2))

func is_headshot_point(point: Vector3) -> bool:
	return point.y - global_position.y > 1.40

func get_actor_name() -> String:
	return "Skeleton" if undead_kind == Kind.SKELETON else "Zombie"

func _die(headshot: bool) -> void:
	dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	if _label:
		_label.text = ""
	GameManager.hostile_neutralized(get_actor_name(), headshot)
	defeated.emit(get_actor_name())
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "rotation:x", -1.45, 0.38).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_visual, "position:y", 0.10, 0.38)
	tween.chain().tween_interval(2.2)
	tween.chain().tween_callback(queue_free)

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if undead_kind == Kind.SKELETON:
		_build_skeleton()
	else:
		_build_zombie()

func _build_zombie() -> void:
	var skin := _material(Color("#6f8752"), 0.0, 0.92)
	var rot := _material(Color("#39432d"), 0.0, 0.98)
	var cloth := _material(Color("#4d3a32"), 0.0, 0.96)
	var eye := _emissive_material(Color("#e0bb4e"), 2.6)
	_add_box(_visual, Vector3(0.48, 0.68, 0.28), Vector3(0, 1.18, 0), cloth)
	_add_sphere(_visual, Vector3(0.34, 0.38, 0.32), Vector3(0, 1.72, -0.02), skin)
	_add_box(_visual, Vector3(0.24, 0.07, 0.035), Vector3(0, 1.60, -0.31), rot)
	_add_sphere(_visual, Vector3(0.065, 0.045, 0.035), Vector3(-0.105, 1.79, -0.30), eye)
	_add_sphere(_visual, Vector3(0.065, 0.045, 0.035), Vector3(0.105, 1.79, -0.30), eye)
	_left_arm = Node3D.new(); _right_arm = Node3D.new(); _left_leg = Node3D.new(); _right_leg = Node3D.new()
	_visual.add_child(_left_arm); _visual.add_child(_right_arm); _visual.add_child(_left_leg); _visual.add_child(_right_leg)
	_left_arm.position = Vector3(-0.34, 1.38, -0.05); _right_arm.position = Vector3(0.34, 1.38, -0.05)
	_add_capsule(_left_arm, 0.09, 0.70, Vector3(0, -0.04, -0.30), skin, Vector3(PI * 0.5, 0, 0))
	_add_capsule(_right_arm, 0.09, 0.70, Vector3(0, -0.04, -0.30), skin, Vector3(PI * 0.5, 0, 0))
	_left_leg.position = Vector3(-0.16, 0.83, 0); _right_leg.position = Vector3(0.16, 0.83, 0)
	_add_capsule(_left_leg, 0.11, 0.88, Vector3(0, -0.40, 0), cloth)
	_add_capsule(_right_leg, 0.11, 0.88, Vector3(0, -0.40, 0), cloth)

func _build_skeleton() -> void:
	_visual.scale = Vector3(1.08, 1.08, 1.08)
	_visual.rotation_degrees.x = -4.0
	var bone := _material(Color("#c9c0a7"), 0.0, 0.74)
	var old_bone := _material(Color("#9b927c"), 0.0, 0.88)
	var grime := _material(Color("#50463a"), 0.0, 0.96)
	var void_material := _material(Color("#130d0d"), 0.0, 1.0)
	var cloth := _material(Color("#352d2b"), 0.05, 0.94)
	var rust := _material(Color("#633a2b"), 0.22, 0.82)
	var eye := _emissive_material(Color("#ff3b28"), 5.4)
	# Layered cranium, facial cavities, hinged jaw, and individually readable teeth.
	_add_sphere(_visual, Vector3(0.35, 0.40, 0.32), Vector3(0, 1.75, 0), bone)
	_add_sphere(_visual, Vector3(0.29, 0.22, 0.27), Vector3(0, 1.58, -0.015), old_bone)
	_add_box(_visual, Vector3(0.17, 0.075, 0.07), Vector3(-0.16, 1.66, -0.285), bone, Vector3(0, 0, deg_to_rad(-14.0)))
	_add_box(_visual, Vector3(0.17, 0.075, 0.07), Vector3(0.16, 1.66, -0.285), bone, Vector3(0, 0, deg_to_rad(14.0)))
	_add_sphere(_visual, Vector3(0.115, 0.095, 0.052), Vector3(-0.115, 1.77, -0.294), void_material)
	_add_sphere(_visual, Vector3(0.115, 0.095, 0.052), Vector3(0.115, 1.77, -0.294), void_material)
	_add_sphere(_visual, Vector3(0.050, 0.041, 0.026), Vector3(-0.115, 1.77, -0.342), eye)
	_add_sphere(_visual, Vector3(0.050, 0.041, 0.026), Vector3(0.115, 1.77, -0.342), eye)
	_add_box(_visual, Vector3(0.065, 0.10, 0.055), Vector3(0, 1.66, -0.31), void_material, Vector3(deg_to_rad(18.0), 0, 0))
	_add_box(_visual, Vector3(0.10, 0.035, 0.045), Vector3(-0.23, 1.91, -0.22), grime, Vector3(0, 0, deg_to_rad(-38.0)))
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, 1.56, -0.03)
	_visual.add_child(_jaw)
	_add_box(_jaw, Vector3(0.30, 0.095, 0.22), Vector3(0, -0.06, -0.08), old_bone)
	_add_box(_jaw, Vector3(0.21, 0.075, 0.13), Vector3(0, -0.03, -0.18), void_material)
	for tooth_x in [-0.105, -0.063, -0.021, 0.021, 0.063, 0.105]:
		_add_box(_jaw, Vector3(0.029, 0.085, 0.035), Vector3(tooth_x, 0.015, -0.255), bone)
	# Vertebrae and oval torus ribs create an actual cage around the torso.
	for y in [0.96, 1.05, 1.14, 1.23, 1.32, 1.41, 1.50]:
		_add_sphere(_visual, Vector3(0.09, 0.065, 0.08), Vector3(0, y, 0.055), old_bone)
	for rib_data in [[1.07, 0.90], [1.16, 1.0], [1.25, 1.08], [1.34, 1.02], [1.43, 0.88]]:
		_add_torus(_visual, 0.30, 0.36, Vector3(0, rib_data[0], 0), bone, Vector3(rib_data[1], 0.78, 0.56))
	_add_capsule(_visual, 0.048, 0.55, Vector3(0, 1.25, -0.29), old_bone)
	_add_capsule(_visual, 0.055, 0.42, Vector3(-0.19, 1.47, -0.02), bone, Vector3(0, 0, deg_to_rad(68.0)))
	_add_capsule(_visual, 0.055, 0.42, Vector3(0.19, 1.47, -0.02), bone, Vector3(0, 0, deg_to_rad(-68.0)))
	# Pelvic bowl, hip sockets, and torn burial cloth.
	_add_box(_visual, Vector3(0.42, 0.18, 0.24), Vector3(0, 0.85, 0), old_bone)
	_add_sphere(_visual, Vector3(0.14, 0.13, 0.13), Vector3(-0.17, 0.83, 0), grime)
	_add_sphere(_visual, Vector3(0.14, 0.13, 0.13), Vector3(0.17, 0.83, 0), grime)
	_add_box(_visual, Vector3(0.52, 0.23, 0.30), Vector3(0.08, 0.76, 0.01), cloth, Vector3(0, 0, deg_to_rad(-8.0)))
	_add_box(_visual, Vector3(0.18, 0.48, 0.07), Vector3(-0.24, 1.26, -0.34), cloth, Vector3(0, 0, deg_to_rad(-22.0)))
	_add_box(_visual, Vector3(0.25, 0.16, 0.28), Vector3(0.31, 1.47, 0), rust, Vector3(0, 0, deg_to_rad(-10.0)))
	# Jointed arms reach forward with distinct elbows, hands, and finger bones.
	_left_arm = Node3D.new(); _right_arm = Node3D.new(); _left_leg = Node3D.new(); _right_leg = Node3D.new()
	_visual.add_child(_left_arm); _visual.add_child(_right_arm); _visual.add_child(_left_leg); _visual.add_child(_right_leg)
	_left_arm.position = Vector3(-0.36, 1.43, 0); _right_arm.position = Vector3(0.36, 1.43, 0)
	for arm in [_left_arm, _right_arm]:
		_add_sphere(arm, Vector3(0.10, 0.10, 0.10), Vector3.ZERO, grime)
		_add_capsule(arm, 0.058, 0.43, Vector3(0, -0.15, -0.14), bone, Vector3(deg_to_rad(43.0), 0, 0))
		_add_sphere(arm, Vector3(0.082, 0.082, 0.082), Vector3(0, -0.31, -0.28), grime)
		_add_capsule(arm, 0.052, 0.47, Vector3(0, -0.34, -0.49), old_bone, Vector3(deg_to_rad(76.0), 0, 0))
		_add_box(arm, Vector3(0.16, 0.09, 0.20), Vector3(0, -0.36, -0.72), old_bone)
		for finger_x in [-0.055, 0.0, 0.055]:
			_add_capsule(arm, 0.014, 0.18, Vector3(finger_x, -0.37, -0.84), bone, Vector3(deg_to_rad(82.0), 0, 0))
	# Split femurs and shins give the runner a heavier, articulated silhouette.
	_left_leg.position = Vector3(-0.17, 0.82, 0); _right_leg.position = Vector3(0.17, 0.82, 0)
	for leg in [_left_leg, _right_leg]:
		_add_sphere(leg, Vector3(0.105, 0.105, 0.105), Vector3.ZERO, grime)
		_add_capsule(leg, 0.067, 0.44, Vector3(0, -0.20, 0.015), bone)
		_add_sphere(leg, Vector3(0.09, 0.075, 0.085), Vector3(0, -0.42, 0), grime)
		_add_capsule(leg, 0.058, 0.46, Vector3(0, -0.63, -0.015), old_bone)
		_add_box(leg, Vector3(0.18, 0.11, 0.34), Vector3(0, -0.86, -0.11), bone, Vector3(deg_to_rad(-8.0), 0, 0))

func _add_torus(parent: Node, inner_radius: float, outer_radius: float, pos: Vector3, material: Material, scale_value := Vector3.ONE) -> void:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	parent.add_child(instance)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.0, 0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _add_box(parent: Node, size: Vector3, pos: Vector3, material: Material, rotation_value := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rotation_value
	parent.add_child(instance)

func _add_sphere(parent: Node, size: Vector3, pos: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = material
	instance.mesh = mesh
	instance.scale = size
	instance.position = pos
	parent.add_child(instance)

func _add_capsule(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rotation_value := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rotation_value
	parent.add_child(instance)
