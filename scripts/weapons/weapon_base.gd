class_name WeaponBase
extends Node3D

signal ammo_changed(magazine: int, reserve: int)
signal hit_confirmed(damage_amount: float, headshot: bool)
signal fired

var owner_player: Node
var camera: Camera3D
var weapon_id := "sidearm"
var display_name := "VX-9 SIDEARM"
var damage := 34.0
var fire_rate := 0.24
var magazine_size := 12
var magazine := 12
var reserve := 60
var reload_time := 1.45
var spread := 0.006
var pellets := 1
var automatic := false
var suppressed := false
var range_m := 120.0
var is_melee := false
var is_explosive := false
var melee_knockback := 0.0
var explosive_radius := 0.0

var _cooldown := 0.0
var _reload_remaining := 0.0
var _recoil := 0.0
var _attack_time := 0.0
var _attack_duration := 0.5
var _attack_side := 1
var _rng := RandomNumberGenerator.new()
var _body: Node3D
var _muzzle: OmniLight3D
var _audio: AudioStreamPlayer3D
var _left_hand: Node3D
var _right_hand: Node3D

func configure(id: String) -> void:
	weapon_id = id
	is_melee = false
	is_explosive = false
	automatic = false
	suppressed = false
	pellets = 1
	spread = 0.006
	melee_knockback = 0.0
	explosive_radius = 0.0
	range_m = 120.0
	match id:
		"fists":
			var punch_rank := GameManager.get_upgrade_bonus("punch_power")
			display_name = "BARE FISTS"; damage = 30.0 + punch_rank * 8.0; fire_rate = 0.42; magazine_size = 0; magazine = 0; reserve = 0; range_m = 2.25; is_melee = true; melee_knockback = 2.2 + punch_rank * 1.0
		"sidearm":
			display_name = "VX-9 SIDEARM"; damage = 38.0; fire_rate = 0.22; magazine_size = 12; magazine = 12; reserve = 72; reload_time = 1.35; spread = 0.005; pellets = 1; automatic = false
		"carbine":
			display_name = "K-11 CARBINE"; damage = 27.0; fire_rate = 0.095; magazine_size = 30; magazine = 30; reserve = 120; reload_time = 1.85; spread = 0.009; pellets = 1; automatic = true
		"smg":
			display_name = "RAPTOR SMG"; damage = 21.0; fire_rate = 0.065; magazine_size = 32; magazine = 32; reserve = 160; reload_time = 1.65; spread = 0.014; pellets = 1; automatic = true; range_m = 85.0
		"shotgun":
			display_name = "M90 BREACHER"; damage = 15.0; fire_rate = 0.72; magazine_size = 6; magazine = 6; reserve = 30; reload_time = 2.25; spread = 0.05; pellets = 8; automatic = false; range_m = 55.0
		"marksman":
			display_name = "MESA-7 MARKSMAN"; damage = 76.0; fire_rate = 0.48; magazine_size = 10; magazine = 10; reserve = 50; reload_time = 2.15; spread = 0.002; pellets = 1; automatic = false; range_m = 180.0
		"bazooka":
			display_name = "ATLAS LAUNCHER"; damage = 175.0; fire_rate = 1.3; magazine_size = 1; magazine = 1; reserve = 4; reload_time = 3.25; spread = 0.003; pellets = 1; automatic = false; range_m = 150.0; is_explosive = true; explosive_radius = 6.0
		"pipe_wrench":
			display_name = "HEAVY PIPE WRENCH"; damage = 92.0; fire_rate = 0.72; magazine_size = 0; magazine = 0; reserve = 0; pellets = 1; automatic = false; range_m = 2.8; is_melee = true; melee_knockback = 5.0
		"knife":
			display_name = "TACTICAL KNIFE"; damage = 64.0; fire_rate = 0.36; magazine_size = 0; magazine = 0; reserve = 0; pellets = 1; automatic = false; range_m = 2.45; is_melee = true; melee_knockback = 2.0
		"chain_bat":
			display_name = "GRAVEBREAKER BAT"; damage = 112.0; fire_rate = 0.62; magazine_size = 0; magazine = 0; reserve = 0; range_m = 3.05; is_melee = true; melee_knockback = 6.8
		"flamethrower":
			display_name = "CINDER-9 FLAMETHROWER"; damage = 5.5; fire_rate = 0.075; magazine_size = 80; magazine = 80; reserve = 240; reload_time = 3.1; spread = 0.052; pellets = 3; automatic = true; range_m = 14.0
	build_visual()

func build_visual() -> void:
	for child in get_children():
		child.queue_free()
	_body = Node3D.new()
	add_child(_body)
	var gunmetal := _material(Color("#1b2125"), 0.82, 0.26)
	var accent := _material(Color("#9d7e45"), 0.58, 0.38)
	var steel := _material(Color("#899597"), 0.9, 0.22)
	var polymer := _material(Color("#242a2d"), 0.15, 0.72)
	if weapon_id == "fists":
		_build_fists()
		return
	if weapon_id == "pipe_wrench":
		_build_pipe_wrench(steel, accent)
		return
	if weapon_id == "knife":
		_build_knife(steel, polymer)
		return
	if weapon_id == "chain_bat":
		_build_spiked_chain_bat(steel)
		return
	if weapon_id == "flamethrower":
		_build_flamethrower(gunmetal, steel, accent)
	elif weapon_id == "bazooka":
		var tube := MeshInstance3D.new()
		var tube_mesh := CylinderMesh.new()
		tube_mesh.top_radius = 0.13; tube_mesh.bottom_radius = 0.13; tube_mesh.height = 1.45; tube_mesh.material = polymer
		tube.mesh = tube_mesh; tube.position = Vector3(0.28, -0.18, -0.62); tube.rotation_degrees.x = 90.0; _body.add_child(tube)
		_add_box(_body, Vector3(0.18, 0.22, 0.25), Vector3(0.28, -0.32, -0.25), accent)
	else:
		var length := 0.55 if weapon_id == "sidearm" else (0.68 if weapon_id == "smg" else 0.88)
		_add_box(_body, Vector3(0.12, 0.13, length), Vector3(0.26, -0.21, -0.48), gunmetal)
		_add_box(_body, Vector3(0.10, 0.27, 0.13), Vector3(0.26, -0.36, -0.26), polymer, Vector3(0.2, 0.0, 0.0))
		_add_box(_body, Vector3(0.035, 0.035, 0.30), Vector3(0.26, -0.20, -0.98 if weapon_id != "sidearm" else -0.82), accent)
		if weapon_id != "sidearm":
			_add_box(_body, Vector3(0.16, 0.16, 0.24), Vector3(0.26, -0.20, -0.22), accent)
			if weapon_id != "smg":
				_add_box(_body, Vector3(0.06, 0.08, 0.16), Vector3(0.26, -0.05, -0.50), gunmetal)
	if weapon_id != "flamethrower":
		_build_scope_ring(gunmetal)
	_build_support_hands()
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color("#ffb45e")
	_muzzle.light_energy = 0.0
	_muzzle.omni_range = 4.5
	_muzzle.position = Vector3(0.26, -0.20, -1.18 if weapon_id == "flamethrower" else (-1.3 if weapon_id != "sidearm" else -1.0))
	add_child(_muzzle)
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = &"SFX"
	_audio.max_distance = 90.0
	_audio.stream = load("res://sounds/blaster_repeater.ogg" if weapon_id in ["carbine", "smg", "flamethrower"] else "res://sounds/blaster.ogg")
	_audio.volume_db = -4.0 if weapon_id == "flamethrower" else 0.0
	add_child(_audio)

func _build_fists() -> void:
	var skin := _material(Color("#c88f6a"), 0.0, 0.72)
	var sleeve := _material(Color("#20292f"), 0.05, 0.82)
	_left_hand = Node3D.new(); _right_hand = Node3D.new()
	_body.add_child(_left_hand); _body.add_child(_right_hand)
	_left_hand.position = Vector3(-0.28, -0.30, -0.48)
	_right_hand.position = Vector3(0.28, -0.30, -0.48)
	_add_capsule(_left_hand, 0.10, 0.52, Vector3(0, -0.18, 0.22), sleeve, Vector3(-0.35, 0, -0.12))
	_add_capsule(_right_hand, 0.10, 0.52, Vector3(0, -0.18, 0.22), sleeve, Vector3(-0.35, 0, 0.12))
	_add_sphere(_left_hand, Vector3(0.19, 0.15, 0.18), Vector3.ZERO, skin)
	_add_sphere(_right_hand, Vector3(0.19, 0.15, 0.18), Vector3.ZERO, skin)
	for hand in [_left_hand, _right_hand]:
		for finger_x in [-0.10, -0.035, 0.035, 0.10]:
			_add_capsule(hand, 0.035, 0.18, Vector3(finger_x, 0.02, -0.11), skin, Vector3(PI * 0.5, 0, 0))

func _build_pipe_wrench(steel: Material, grip: Material) -> void:
	# Long cast handle, adjustment collar, fixed jaw and hooked movable jaw.
	_add_box(_body, Vector3(0.13, 0.11, 1.18), Vector3(0.31, -0.20, -0.64), grip, Vector3(0.05, 0, -0.10))
	_add_box(_body, Vector3(0.28, 0.22, 0.22), Vector3(0.25, -0.18, -1.24), steel, Vector3(0, 0, -0.12))
	_add_box(_body, Vector3(0.13, 0.46, 0.16), Vector3(0.08, -0.05, -1.28), steel, Vector3(0, 0, -0.42))
	_add_box(_body, Vector3(0.13, 0.42, 0.16), Vector3(0.43, -0.04, -1.26), steel, Vector3(0, 0, 0.48))
	var wheel := MeshInstance3D.new()
	var wheel_mesh := CylinderMesh.new(); wheel_mesh.top_radius = 0.105; wheel_mesh.bottom_radius = 0.105; wheel_mesh.height = 0.13; wheel_mesh.material = grip
	wheel.mesh = wheel_mesh; wheel.position = Vector3(0.28, -0.18, -1.15); wheel.rotation_degrees.z = 90.0; _body.add_child(wheel)
	_build_support_hands()

func _build_knife(steel: Material, grip: Material) -> void:
	_add_box(_body, Vector3(0.11, 0.13, 0.38), Vector3(0.30, -0.25, -0.35), grip)
	_add_box(_body, Vector3(0.07, 0.025, 0.62), Vector3(0.30, -0.20, -0.82), steel, Vector3(0.05, 0, 0))
	_add_box(_body, Vector3(0.28, 0.05, 0.08), Vector3(0.30, -0.21, -0.53), steel)
	_build_support_hands()

func _build_spiked_chain_bat(steel: Material) -> void:
	var wood := _material(Color("#604329"), 0.0, 0.82)
	var grip := _material(Color("#1b1a18"), 0.18, 0.72)
	var bat := MeshInstance3D.new()
	var bat_mesh := CylinderMesh.new()
	bat_mesh.top_radius = 0.075
	bat_mesh.bottom_radius = 0.13
	bat_mesh.height = 1.38
	bat_mesh.material = wood
	bat.mesh = bat_mesh
	bat.position = Vector3(0.30, -0.16, -0.72)
	bat.rotation_degrees.x = 90.0
	_body.add_child(bat)
	_add_box(_body, Vector3(0.16, 0.15, 0.42), Vector3(0.30, -0.16, -0.10), grip)
	for row in 4:
		var z := -0.96 - row * 0.18
		_add_box(_body, Vector3(0.055, 0.24, 0.055), Vector3(0.30, -0.02, z), steel, Vector3(0.0, 0.0, 0.18))
		_add_box(_body, Vector3(0.24, 0.055, 0.055), Vector3(0.44, -0.16, z - 0.05), steel, Vector3(0.0, 0.18, 0.0))
	for index in 6:
		var link := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.026
		torus.outer_radius = 0.048
		torus.material = steel
		link.mesh = torus
		link.position = Vector3(0.30 + sin(index * 1.4) * 0.045, -0.18 - index * 0.065, -1.42 - index * 0.055)
		link.rotation_degrees = Vector3(90.0 if index % 2 == 0 else 0.0, 0.0, float(index) * 22.0)
		_body.add_child(link)
	_build_support_hands()

func _build_flamethrower(gunmetal: Material, steel: Material, accent: Material) -> void:
	var tank_material := _material(Color("#8b3e27"), 0.62, 0.38)
	for x in [0.16, 0.38]:
		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 0.095
		tank_mesh.bottom_radius = 0.095
		tank_mesh.height = 0.62
		tank_mesh.material = tank_material
		tank.mesh = tank_mesh
		tank.position = Vector3(x, -0.31, -0.18)
		_body.add_child(tank)
	_add_box(_body, Vector3(0.15, 0.14, 0.94), Vector3(0.27, -0.18, -0.60), gunmetal)
	_add_box(_body, Vector3(0.08, 0.08, 0.58), Vector3(0.27, -0.16, -1.18), steel)
	_add_box(_body, Vector3(0.12, 0.24, 0.18), Vector3(0.27, -0.34, -0.34), accent)
	var nozzle := MeshInstance3D.new()
	var nozzle_mesh := TorusMesh.new()
	nozzle_mesh.inner_radius = 0.055
	nozzle_mesh.outer_radius = 0.085
	nozzle_mesh.material = steel
	nozzle.mesh = nozzle_mesh
	nozzle.position = Vector3(0.27, -0.16, -1.48)
	nozzle.rotation_degrees.x = 90.0
	_body.add_child(nozzle)

func _build_support_hands() -> void:
	var skin := _material(Color("#c88f6a"), 0.0, 0.72)
	var sleeve := _material(Color("#20292f"), 0.05, 0.82)
	_add_capsule(_body, 0.09, 0.48, Vector3(0.28, -0.42, -0.05), sleeve, Vector3(-0.4, 0, 0))
	_add_sphere(_body, Vector3(0.15, 0.12, 0.17), Vector3(0.27, -0.30, -0.27), skin)

func _build_scope_ring(material: Material) -> void:
	var red := _material(Color("#d14d3f"), 0.18, 0.38)
	if weapon_id == "smg":
		# The SMG uses a deliberately minimal post so the target stays visible.
		_add_box(_body, Vector3(0.007, 0.068, 0.010), Vector3(0.26, -0.015, -0.73), red)
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	var radius := 0.085 if weapon_id == "sidearm" else (0.15 if weapon_id in ["marksman", "bazooka"] else 0.115)
	torus.inner_radius = radius * 0.72
	torus.outer_radius = radius
	torus.material = material
	ring.mesh = torus
	ring.position = Vector3(0.26, -0.10, -0.55)
	ring.rotation_degrees.x = 90.0
	_body.add_child(ring)
	_add_box(_body, Vector3(0.008, 0.074, 0.012), Vector3(0.26, -0.10, -0.57), red)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size; mesh.material = material
	mesh_instance.mesh = mesh; mesh_instance.position = pos; mesh_instance.rotation = rot
	parent.add_child(mesh_instance)

func _add_sphere(parent: Node, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0; mesh.material = material
	mesh_instance.mesh = mesh; mesh_instance.scale = size; mesh_instance.position = pos
	parent.add_child(mesh_instance)

func _add_capsule(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = radius; mesh.height = height; mesh.material = material
	mesh_instance.mesh = mesh; mesh_instance.position = pos; mesh_instance.rotation = rot
	parent.add_child(mesh_instance)

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_remaining > 0.0:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()
	_recoil = lerpf(_recoil, 0.0, delta * 16.0)
	_attack_time = maxf(0.0, _attack_time - delta)
	var arc := 0.0
	if _attack_time > 0.0:
		var progress := 1.0 - _attack_time / _attack_duration
		arc = sin(progress * PI)
	if weapon_id == "fists" and _left_hand and _right_hand:
		_left_hand.position = Vector3(-0.28, -0.30, -0.48)
		_right_hand.position = Vector3(0.28, -0.30, -0.48)
		var active_hand := _right_hand if _attack_side > 0 else _left_hand
		active_hand.position += Vector3(-0.13 * _attack_side, 0.10 * arc, -0.78 * arc)
		active_hand.rotation.x = -0.65 * arc
	elif _body:
		_body.position = Vector3(0, 0, _recoil)
		if weapon_id in ["pipe_wrench", "chain_bat"]:
			var ready_pose := Vector3(0.64, -0.08, -0.34) if weapon_id == "pipe_wrench" else Vector3(0.48, 0.12, -0.48)
			var swing_scale := 1.82 if weapon_id == "pipe_wrench" else 2.05
			_body.rotation = ready_pose + Vector3(-swing_scale * arc, 0.14 * arc, 0.58 * arc)
			_body.position = Vector3(0.02, 0.04 + 0.18 * arc, -0.04 - 0.14 * arc)
		elif weapon_id == "knife":
			_body.rotation = Vector3(-0.20 * arc, 0.0, -0.35 * arc)
			_body.position.z -= 0.72 * arc
		else:
			_body.rotation = Vector3.ZERO
	if _muzzle:
		_muzzle.light_energy = move_toward(_muzzle.light_energy, 0.0, delta * 80.0)

func try_fire() -> bool:
	if is_melee:
		if _cooldown > 0.0 or not is_instance_valid(camera):
			return false
		_cooldown = fire_rate
		_attack_duration = fire_rate
		_attack_time = fire_rate
		if weapon_id == "fists":
			_attack_side *= -1
		_fire_melee_ray()
		fired.emit()
		return true
	if _cooldown > 0.0 or _reload_remaining > 0.0 or magazine <= 0 or not is_instance_valid(camera):
		if magazine <= 0:
			start_reload()
		return false
	magazine -= 1
	_cooldown = fire_rate
	_recoil = 0.035 if weapon_id == "flamethrower" else (0.18 if weapon_id in ["shotgun", "bazooka"] else (0.09 if weapon_id == "marksman" else (0.07 if weapon_id in ["carbine", "smg"] else 0.06)))
	if _muzzle: _muzzle.light_energy = 8.0
	if _audio:
		_audio.pitch_scale = _rng.randf_range(0.56, 0.66) if weapon_id == "flamethrower" else _rng.randf_range(0.94, 1.06)
		_audio.play()
	if weapon_id == "flamethrower":
		_spawn_flame_burst()
	if is_explosive:
		_fire_explosive_ray()
	else:
		for _pellet in pellets:
			_fire_ray()
	GameManager.register_shot()
	ammo_changed.emit(magazine, reserve)
	fired.emit()
	return true

func _fire_melee_ray() -> void:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(viewport_size * 0.5)
	var direction := camera.project_ray_normal(viewport_size * 0.5)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range_m)
	query.collision_mask = 1 | 2 | 4
	if is_instance_valid(owner_player) and owner_player is CollisionObject3D:
		query.exclude = [owner_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider and collider.has_method("take_damage"):
		collider.take_damage(damage, false, owner_player)
		if collider.has_method("apply_knockback"):
			collider.apply_knockback(direction * melee_knockback)
		hit_confirmed.emit(damage, false)
		_spawn_impact(hit.position, hit.normal, true, false)
	else:
		_spawn_impact(hit.position, hit.normal)

func _fire_explosive_ray() -> void:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(viewport_size * 0.5)
	var direction := camera.project_ray_normal(viewport_size * 0.5)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range_m)
	query.collision_mask = 1 | 2 | 4
	if is_instance_valid(owner_player) and owner_player is CollisionObject3D:
		query.exclude = [owner_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var impact := origin + direction * range_m if hit.is_empty() else Vector3(hit.position)
	_spawn_explosion(impact)
	for actor in get_tree().get_nodes_in_group("actors"):
		if not actor is Node3D:
			continue
		var distance := impact.distance_to(actor.global_position)
		if distance > explosive_radius:
			continue
		var scale := 1.0 - distance / explosive_radius
		if actor.has_method("take_damage"):
			actor.take_damage(damage * maxf(0.25, scale), false, owner_player)
		if actor.has_method("apply_knockback"):
			actor.apply_knockback((actor.global_position - impact).normalized() * (7.0 + 8.0 * scale))

func _spawn_flame_burst() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(get_tree().current_scene):
		return
	var direction := -camera.global_basis.z
	var origin := camera.global_position + direction * 0.75
	for index in 4:
		var flame := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		var color := Color("#ffcf55") if index < 2 else Color("#ff6328")
		var material := _material(color, 0.0, 0.24)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.82
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 5.5
		mesh.material = material
		flame.mesh = mesh
		flame.scale = Vector3.ONE * (0.18 + index * 0.06)
		get_tree().current_scene.add_child(flame)
		var jitter := camera.global_basis.x * _rng.randf_range(-0.16, 0.16) + camera.global_basis.y * _rng.randf_range(-0.12, 0.12)
		flame.global_position = origin + direction * index * 0.35 + jitter
		var destination := flame.global_position + direction * (2.2 + index * 0.75) + jitter * 1.4
		var tween := flame.create_tween().set_parallel(true)
		tween.tween_property(flame, "global_position", destination, 0.24 + index * 0.025).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(flame, "scale", Vector3.ONE * (0.55 + index * 0.12), 0.28)
		tween.tween_property(flame, "transparency", 1.0, 0.27)
		tween.chain().tween_callback(flame.queue_free)

func _fire_ray() -> void:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(viewport_size * 0.5)
	var direction := camera.project_ray_normal(viewport_size * 0.5)
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var stability := 1.0 - minf(0.52, GameManager.get_upgrade_bonus("stability") * 0.052)
	direction = (direction + right * _rng.randf_range(-spread, spread) * stability + up * _rng.randf_range(-spread, spread) * stability).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range_m)
	query.collision_mask = 1 | 2 | 4
	if is_instance_valid(owner_player) and owner_player is CollisionObject3D:
		query.exclude = [owner_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	var headshot := false
	if collider and collider.has_method("is_headshot_point"):
		headshot = collider.is_headshot_point(hit.position)
	if collider and collider.has_method("take_damage"):
		collider.take_damage(damage, headshot, owner_player)
		if weapon_id == "flamethrower" and collider.has_method("ignite"):
			collider.ignite(1.8, damage * 0.7)
		GameManager.register_hit()
		var applied_damage := damage * (1.7 if headshot else 1.0)
		hit_confirmed.emit(applied_damage, headshot)
		_spawn_impact(hit.position, hit.normal, true, headshot)
		if collider.has_method("apply_knockback"):
			var impulse := 0.24
			if weapon_id == "shotgun":
				impulse = 0.52
			elif weapon_id == "marksman":
				impulse = 0.72
			elif weapon_id == "sidearm":
				impulse = 0.38
			collider.apply_knockback(direction * impulse)
	else:
		_spawn_impact(hit.position, hit.normal)

func _spawn_explosion(position_world: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ff8b32"); flash.light_energy = 18.0; flash.omni_range = explosive_radius * 1.5
	get_tree().current_scene.add_child(flash); flash.global_position = position_world
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius = 0.7; mesh.height = 1.4
	var material := _material(Color("#ff8a37"), 0.0, 0.35); material.emission_enabled = true; material.emission = Color("#ff5b20"); material.emission_energy_multiplier = 7.0
	mesh.material = material; sphere.mesh = mesh; flash.add_child(sphere)
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "light_energy", 0.0, 0.35)
	tween.tween_property(sphere, "scale", Vector3.ONE * explosive_radius, 0.38)
	tween.chain().tween_callback(flash.queue_free)

func _spawn_impact(position_world: Vector3, normal: Vector3, damage_hit := false, headshot := false) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var hit_normal := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	var effect := Node3D.new()
	scene.add_child(effect)
	effect.global_position = position_world + hit_normal * 0.025

	var flash := OmniLight3D.new()
	flash.light_color = Color("#ff5a42") if damage_hit else Color("#ffc36c")
	flash.light_energy = 6.5 if headshot else (4.5 if damage_hit else 3.2)
	flash.omni_range = 2.4 if headshot else 1.65
	effect.add_child(flash)

	var marker := MeshInstance3D.new()
	var mark_mesh := CylinderMesh.new()
	mark_mesh.top_radius = 0.13 if headshot else 0.09
	mark_mesh.bottom_radius = mark_mesh.top_radius
	mark_mesh.height = 0.012
	var mark_color := Color("#9b2926") if damage_hit else Color("#211a14")
	var mark_material := _material(mark_color, 0.05, 0.96)
	mark_material.emission_enabled = true
	mark_material.emission = Color("#6f1b18") if damage_hit else Color("#7c5428")
	mark_material.emission_energy_multiplier = 1.4 if damage_hit else 0.45
	mark_mesh.material = mark_material
	marker.mesh = mark_mesh
	marker.quaternion = Quaternion(Vector3.UP, hit_normal)
	scene.add_child(marker)
	marker.global_position = position_world + hit_normal * 0.009
	var mark_tween := marker.create_tween()
	mark_tween.tween_interval(0.62 if damage_hit else 8.0)
	mark_tween.tween_property(marker, "transparency", 1.0, 0.35)
	mark_tween.tween_callback(marker.queue_free)

	var spark_color := Color("#ff5245") if damage_hit else Color("#ffd27a")
	var spark_count := 11 if headshot else (8 if damage_hit else 6)
	for index in spark_count:
		var spark := MeshInstance3D.new()
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.014, 0.014, 0.075 if index % 2 == 0 else 0.045)
		var spark_material := _material(spark_color, 0.0, 0.25)
		spark_material.emission_enabled = true
		spark_material.emission = spark_color
		spark_material.emission_energy_multiplier = 5.0
		spark_mesh.material = spark_material
		spark.mesh = spark_mesh
		effect.add_child(spark)
		var random_vector := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		var travel := hit_normal * _rng.randf_range(0.16, 0.42) + random_vector * _rng.randf_range(0.16, 0.48)
		var spark_tween := spark.create_tween().set_parallel(true)
		spark_tween.tween_property(spark, "position", travel, _rng.randf_range(0.18, 0.32)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "scale", Vector3.ZERO, 0.30).set_delay(0.08)
		spark_tween.tween_property(spark, "transparency", 1.0, 0.22).set_delay(0.10)

	var dust := MeshInstance3D.new()
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.5
	dust_mesh.height = 1.0
	var dust_material := _material(Color("#7e3930") if damage_hit else Color("#8a7966"), 0.0, 1.0)
	dust_mesh.material = dust_material
	dust.mesh = dust_mesh
	dust.scale = Vector3.ONE * 0.05
	effect.add_child(dust)
	var effect_tween := effect.create_tween().set_parallel(true)
	effect_tween.tween_property(flash, "light_energy", 0.0, 0.20)
	effect_tween.tween_property(dust, "scale", Vector3.ONE * (0.38 if headshot else 0.27), 0.32)
	effect_tween.tween_property(dust, "transparency", 1.0, 0.32)
	effect_tween.chain().tween_callback(effect.queue_free)

func start_reload() -> void:
	if is_melee or _reload_remaining > 0.0 or magazine >= magazine_size or reserve <= 0:
		return
	var speed_bonus := 1.0 - minf(0.48, GameManager.get_upgrade_bonus("reload") * 0.048)
	_reload_remaining = reload_time * speed_bonus

func _finish_reload() -> void:
	var needed := magazine_size - magazine
	var loaded := mini(needed, reserve)
	magazine += loaded
	reserve -= loaded
	ammo_changed.emit(magazine, reserve)

func add_ammo(amount: int) -> void:
	reserve += amount
	ammo_changed.emit(magazine, reserve)

func get_ads_offset() -> Vector3:
	if is_melee:
		return Vector3.ZERO
	if weapon_id == "smg":
		return Vector3(-0.26, 0.015, 0.20)
	return Vector3(-0.26, 0.10, 0.20)

func uses_scope() -> bool:
	return not is_melee and weapon_id != "flamethrower"

func is_reloading() -> bool:
	return _reload_remaining > 0.0

func reload_progress() -> float:
	if _reload_remaining <= 0.0:
		return 0.0
	return clampf(1.0 - _reload_remaining / reload_time, 0.0, 1.0)
