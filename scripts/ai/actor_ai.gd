class_name ActorAI
extends CharacterBody3D

enum Kind { SECURITY, POLICE, SWAT, CIVILIAN, EMPLOYEE, PAWNKEEPER }
enum State { IDLE, PATROL, INVESTIGATE, COMBAT, FLEE, DEAD }

var actor_kind := Kind.SECURITY
var state := State.PATROL
var max_health := 100.0
var health := 100.0
var move_speed := 2.8
var damage := 13.0
var accuracy := 0.48
var fire_interval := 0.85
var detection_range := 18.0
var patrol_points: Array[Vector3] = []
var reactive_only := false

var _player: Node3D
var _patrol_index := 0
var _fire_cooldown := 0.0
var _think_cooldown := 0.0
var _voice_cooldown := 0.0
var _call_timer := 4.0
var _called_help := false
var _rng := RandomNumberGenerator.new()
var _label: Label3D
var _muzzle_light: OmniLight3D
var _shot_audio: AudioStreamPlayer3D
var _character_visual: CharacterVisual
var _was_attacked := false
var _escape_direction := Vector3.ZERO
var _escape_time := 0.0
var _stuck_time := 0.0

func configure(kind: Kind, spawn_position: Vector3, points: Array[Vector3] = []) -> void:
	actor_kind = kind
	position = spawn_position
	patrol_points = points
	match actor_kind:
		Kind.SECURITY:
			max_health = 85.0; move_speed = 2.6; damage = 12.0; accuracy = 0.40; fire_interval = 0.9; detection_range = 17.0
		Kind.POLICE:
			max_health = 115.0; move_speed = 3.2; damage = 18.0; accuracy = 0.56; fire_interval = 0.72; detection_range = 24.0
		Kind.SWAT:
			max_health = 190.0; move_speed = 3.6; damage = 22.0; accuracy = 0.68; fire_interval = 0.34; detection_range = 30.0
		Kind.CIVILIAN:
			max_health = 55.0; move_speed = 3.8; damage = 0.0; accuracy = 0.0; state = State.IDLE; detection_range = 12.0
		Kind.EMPLOYEE:
			max_health = 72.0; move_speed = 3.5; damage = 14.0; accuracy = 1.0; fire_interval = 1.0; detection_range = 14.0
		Kind.PAWNKEEPER:
			max_health = 105.0; move_speed = 3.0; damage = 16.0; accuracy = 0.52; fire_interval = 0.68; detection_range = 22.0; reactive_only = true
	if actor_kind != Kind.CIVILIAN:
		damage *= GameManager.get_difficulty_value(0.72, 1.0, 1.22)
		accuracy = clampf(accuracy + GameManager.get_difficulty_value(-0.16, 0.0, 0.10), 0.0, 0.88)
		fire_interval *= GameManager.get_difficulty_value(1.2, 1.0, 0.86)
	health = max_health

func _ready() -> void:
	_rng.randomize()
	add_to_group("actors")
	add_to_group("damageable")
	if actor_kind == Kind.CIVILIAN:
		add_to_group("civilians")
	elif actor_kind == Kind.PAWNKEEPER:
		add_to_group("neutral_staff")
	else:
		add_to_group("hostiles")
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	_build_character()
	_player = get_tree().get_first_node_in_group("player")

func _build_character() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.34; capsule.height = 1.72
	collision.shape = capsule; collision.position.y = 0.86; add_child(collision)
	_character_visual = CharacterVisual.new()
	_character_visual.configure(actor_kind, _rng.randi())
	add_child(_character_visual)
	if actor_kind not in [Kind.CIVILIAN, Kind.EMPLOYEE]:
		_muzzle_light = OmniLight3D.new()
		_muzzle_light.light_color = Color("#ff9f46")
		_muzzle_light.light_energy = 0.0
		_muzzle_light.omni_range = 4.5
		_muzzle_light.position = Vector3(0.30, 1.12, -0.54)
		add_child(_muzzle_light)
		_shot_audio = AudioStreamPlayer3D.new()
		_shot_audio.bus = &"SFX"
		_shot_audio.max_distance = 55.0
		_shot_audio.stream = load("res://sounds/enemy_attack.ogg")
		add_child(_shot_audio)
	_label = Label3D.new(); _label.text = get_actor_name(); _label.font_size = 24; _label.outline_size = 8; _label.modulate = Color(1, 1, 1, 0.72); _label.position.y = 2.15; _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _label.no_depth_test = true; add_child(_label)

func _physics_process(delta: float) -> void:
	if state == State.DEAD or not GameManager.run_active:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_think_cooldown = maxf(0.0, _think_cooldown - delta)
	_voice_cooldown = maxf(0.0, _voice_cooldown - delta)
	_escape_time = maxf(0.0, _escape_time - delta)
	if _muzzle_light:
		_muzzle_light.light_energy = move_toward(_muzzle_light.light_energy, 0.0, delta * 90.0)
	if not is_on_floor(): velocity.y -= 9.8 * delta
	if actor_kind == Kind.CIVILIAN:
		_update_civilian(delta)
	else:
		_update_hostile(delta)
	_animate_body(delta)
	var previous_position := global_position
	var intended_speed := Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	_update_collision_recovery(delta, previous_position, intended_speed)

func _animate_body(_delta: float) -> void:
	if _character_visual:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		_character_visual.update_motion(horizontal_speed, move_speed, state == State.FLEE)

func _update_hostile(_delta: float) -> void:
	if reactive_only and not _was_attacked:
		state = State.PATROL
		if patrol_points.is_empty():
			velocity.x = move_toward(velocity.x, 0.0, 0.22)
			velocity.z = move_toward(velocity.z, 0.0, 0.22)
		else:
			_move_toward_point(patrol_points[_patrol_index], move_speed * 0.48)
			if global_position.distance_to(patrol_points[_patrol_index]) < 1.0:
				_patrol_index = (_patrol_index + 1) % patrol_points.size()
		return
	var distance := global_position.distance_to(_player.global_position)
	var sees_player := distance <= detection_range + GameManager.get_alert_tier() * 5.0 and _has_line_of_sight()
	if sees_player or GameManager.get_alert_tier() >= 2:
		state = State.COMBAT
	elif GameManager.get_alert_tier() >= 1 and state != State.COMBAT:
		state = State.INVESTIGATE
	match state:
		State.PATROL:
			if patrol_points.is_empty(): velocity.x = move_toward(velocity.x, 0.0, 0.2); velocity.z = move_toward(velocity.z, 0.0, 0.2)
			else: _move_toward_point(patrol_points[_patrol_index], move_speed * 0.65)
			if not patrol_points.is_empty() and global_position.distance_to(patrol_points[_patrol_index]) < 1.0: _patrol_index = (_patrol_index + 1) % patrol_points.size()
		State.INVESTIGATE:
			_move_toward_point(_player.global_position, move_speed * 0.75)
		State.COMBAT:
			look_at(Vector3(_player.global_position.x, global_position.y, _player.global_position.z), Vector3.UP)
			if actor_kind == Kind.EMPLOYEE:
				if distance > 1.75:
					_move_toward_point(_player.global_position, move_speed)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 0.25)
					velocity.z = move_toward(velocity.z, 0.0, 0.25)
					if _fire_cooldown <= 0.0 and _has_line_of_sight():
						_employee_attack()
				return
			if distance > 9.0:
				var flank := Vector3(sin(Time.get_ticks_msec() * 0.001 + get_instance_id()), 0, 0) * (1.5 if actor_kind == Kind.SWAT else 0.4)
				_move_toward_point(_player.global_position + flank, move_speed)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 0.25); velocity.z = move_toward(velocity.z, 0.0, 0.25)
			if _fire_cooldown <= 0.0 and distance < detection_range and _has_line_of_sight(): _shoot_player(distance)

func _update_civilian(delta: float) -> void:
	if GameManager.get_alert_tier() > 0 or health < max_health:
		state = State.FLEE
	if state == State.FLEE:
		var away := (global_position - _player.global_position); away.y = 0.0
		var hide_bias := Vector3(signf(global_position.x) * 11.0, 0.0, -8.0)
		_move_toward_point(global_position + away.normalized() * 5.0 + hide_bias, move_speed)
		_call_timer -= delta
		if _call_timer <= 0.0 and not _called_help:
			_called_help = true; GameManager.raise_alert(14.0, "Civilian called emergency services"); _speak("They're armed! Call the police!")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 0.15); velocity.z = move_toward(velocity.z, 0.0, 0.15)

func _move_toward_point(point: Vector3, speed: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length() < 0.15:
		return
	direction = direction.normalized()
	if _escape_time > 0.0 and _escape_direction.length_squared() > 0.01:
		direction = _escape_direction
	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("actors"):
		if other == self or not other is Node3D:
			continue
		var offset: Vector3 = global_position - (other as Node3D).global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > 0.02 and distance < 1.35:
			separation += offset.normalized() * (1.35 - distance)
	if separation.length() > 0.01:
		direction = (direction + separation * 1.4).normalized()
	var probe := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.UP + direction * 0.9)
	probe.collision_mask = 1 | 4
	probe.exclude = [get_rid()]
	var obstacle := get_world_3d().direct_space_state.intersect_ray(probe)
	if not obstacle.is_empty() and not _request_door_open(obstacle.get("collider")):
		var side := -1.0 if get_instance_id() % 2 == 0 else 1.0
		var lateral := Vector3(-direction.z, 0.0, direction.x) * side
		_escape_direction = (direction * -0.35 + lateral).normalized()
		_escape_time = maxf(_escape_time, 0.72)
		direction = _escape_direction
	velocity.x = move_toward(velocity.x, direction.x * speed, 0.28)
	velocity.z = move_toward(velocity.z, direction.z * speed, 0.28)
	look_at(global_position + direction, Vector3.UP)

func _request_door_open(collider: Object) -> bool:
	if not is_instance_valid(collider) or not collider.has_method("request_open_for_actor"):
		return false
	var accepted := bool(collider.call("request_open_for_actor", self))
	if accepted:
		_stuck_time = 0.0
		_escape_time = 0.0
	return accepted

func _update_collision_recovery(delta: float, previous_position: Vector3, intended_speed: float) -> void:
	var moved := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z).length()
	if intended_speed > 0.45 and moved < 0.012:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.5)
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if _request_door_open(collision.get_collider()):
			continue
		var normal := collision.get_normal()
		if absf(normal.y) > 0.65:
			continue
		normal.y = 0.0
		if normal.length_squared() < 0.01:
			continue
		var side := -1.0 if (get_instance_id() + index) % 2 == 0 else 1.0
		var tangent := Vector3(-normal.z, 0.0, normal.x) * side
		_escape_direction = (normal.normalized() * 0.72 + tangent * 0.88).normalized()
		_escape_time = maxf(_escape_time, 0.85)
	if _stuck_time >= 0.32:
		var forward := -global_basis.z
		forward.y = 0.0
		var turn := -1.0 if get_instance_id() % 2 == 0 else 1.0
		_escape_direction = forward.normalized().rotated(Vector3.UP, turn * 2.15)
		_escape_time = 1.15
		_stuck_time = 0.0

func _has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP * 1.5
	var to := _player.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4 | 8
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == _player

func _shoot_player(distance: float) -> void:
	if _character_visual:
		_character_visual.trigger_shoot()
	_fire_cooldown = fire_interval * _rng.randf_range(0.9, 1.15)
	var distance_penalty := clampf((distance - 8.0) / 32.0, 0.0, 0.35)
	var did_hit := _rng.randf() <= accuracy - distance_penalty
	var target := _player.global_position + Vector3.UP * 1.2
	if not did_hit:
		target += Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-0.8, 1.4), _rng.randf_range(-1.0, 1.0))
	var start := global_position + Vector3.UP * 1.35
	if _muzzle_light:
		_muzzle_light.light_energy = 8.0
		start = _muzzle_light.global_position
	_resolve_hostile_round(start, target, maxf(detection_range * 1.5, distance + 10.0))
	if _shot_audio:
		_shot_audio.pitch_scale = _rng.randf_range(0.91, 1.08); _shot_audio.play()
	GameManager.raise_alert(2.0)
	if _voice_cooldown <= 0.0:
		_speak(["Drop the weapon!", "Contact front!", "Moving to cover!", "Hold that angle!"][_rng.randi_range(0, 3)])

func _resolve_hostile_round(start: Vector3, aim_point: Vector3, maximum_distance: float) -> Dictionary:
	var direction := aim_point - start
	if direction.length_squared() < 0.001:
		return {}
	direction = direction.normalized()
	var ray_end := start + direction * maximum_distance
	var query := PhysicsRayQueryParameters3D.create(start, ray_end)
	query.collision_mask = 1 | 2 | 4 | 8
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var finish := ray_end if hit.is_empty() else Vector3(hit.position)
	_spawn_tracer(start, finish)
	if hit.is_empty():
		return hit
	var collider: Object = hit.collider
	if collider == _player:
		_player.take_damage(damage * _rng.randf_range(0.82, 1.12), false, self)
	else:
		_spawn_round_impact(hit.position, hit.normal, collider is ActorAI)
	return hit

func _employee_attack() -> void:
	_fire_cooldown = fire_interval * _rng.randf_range(0.9, 1.15)
	if _character_visual:
		_character_visual.trigger_melee()
	_player.take_damage(damage * _rng.randf_range(0.85, 1.12), false, self)
	GameManager.raise_alert(4.0, "Fight at service counter")
	if _voice_cooldown <= 0.0:
		_speak(["Put that back!", "Get out of my store!", "I'm calling the cops!"][_rng.randi_range(0, 2)])

func _spawn_tracer(start: Vector3, finish: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var length := start.distance_to(finish)
	mesh.size = Vector3(0.025, 0.025, length)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ffd17a")
	material.emission_enabled = true
	material.emission = Color("#ff9a3c")
	material.emission_energy_multiplier = 5.0
	mesh.material = material
	tracer.mesh = mesh
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = start.lerp(finish, 0.5)
	tracer.look_at(finish, Vector3.UP)
	var tween := tracer.create_tween()
	tween.tween_interval(0.065)
	tween.tween_callback(tracer.queue_free)

func _spawn_round_impact(position_world: Vector3, normal: Vector3, damage_hit := false) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var hit_normal := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	var marker := MeshInstance3D.new()
	var mark_mesh := CylinderMesh.new()
	mark_mesh.top_radius = 0.085
	mark_mesh.bottom_radius = 0.085
	mark_mesh.height = 0.01
	var mark_material := StandardMaterial3D.new()
	mark_material.albedo_color = Color("#6f2424") if damage_hit else Color("#1c1815")
	mark_material.roughness = 0.96
	mark_mesh.material = mark_material
	marker.mesh = mark_mesh
	marker.quaternion = Quaternion(Vector3.UP, hit_normal)
	marker.add_to_group("hostile_bullet_impacts")
	scene.add_child(marker)
	marker.global_position = position_world + hit_normal * 0.008
	var marker_tween := marker.create_tween()
	marker_tween.tween_interval(6.0)
	marker_tween.tween_property(marker, "transparency", 1.0, 0.35)
	marker_tween.tween_callback(marker.queue_free)
	var effect := Node3D.new()
	effect.add_to_group("hostile_bullet_impacts")
	scene.add_child(effect)
	effect.global_position = position_world + hit_normal * 0.025
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ff6c4d") if damage_hit else Color("#ffc16c")
	flash.light_energy = 4.2
	flash.omni_range = 1.7
	effect.add_child(flash)
	for index in 6:
		var spark := MeshInstance3D.new()
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.012, 0.012, 0.065 if index % 2 == 0 else 0.04)
		var spark_material := StandardMaterial3D.new()
		spark_material.albedo_color = Color("#ff7255") if damage_hit else Color("#ffd27a")
		spark_material.emission_enabled = true
		spark_material.emission = spark_material.albedo_color
		spark_material.emission_energy_multiplier = 4.5
		spark_mesh.material = spark_material
		spark.mesh = spark_mesh
		effect.add_child(spark)
		var scatter := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		var travel := hit_normal * _rng.randf_range(0.15, 0.34) + scatter * _rng.randf_range(0.12, 0.38)
		var spark_tween := spark.create_tween().set_parallel(true)
		spark_tween.tween_property(spark, "position", travel, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "scale", Vector3.ZERO, 0.24).set_delay(0.08)
	var effect_tween := effect.create_tween()
	effect_tween.tween_property(flash, "light_energy", 0.0, 0.20)
	effect_tween.tween_callback(effect.queue_free)

func take_damage(amount: float, headshot := false, source: Object = null) -> void:
	if state == State.DEAD: return
	health -= amount * (1.7 if headshot else 1.0)
	if actor_kind == Kind.CIVILIAN and health > 0.0:
		GameManager.civilian_harmed(false)
	if health <= 0.0:
		_die(headshot)
	else:
		if _character_visual:
			_character_visual.trigger_hit(headshot)
		state = State.FLEE if actor_kind == Kind.CIVILIAN else State.COMBAT
		if actor_kind != Kind.CIVILIAN:
			if source is Node3D:
				_player = source as Node3D
			_fire_cooldown = minf(_fire_cooldown, 0.12)
			if not _was_attacked:
				_was_attacked = true; GameManager.raise_alert(12.0, "%s returning fire" % get_actor_name())

func _die(headshot: bool) -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0; collision_mask = 1
	if _character_visual:
		_character_visual.trigger_death()
	_label.text = ""
	if actor_kind == Kind.CIVILIAN:
		GameManager.civilian_harmed(true)
	elif actor_kind == Kind.PAWNKEEPER:
		GameManager.add_score(-750, "Pawn shop staff harmed")
	else:
		GameManager.hostile_neutralized(get_actor_name(), headshot)
	var tween := create_tween(); tween.tween_interval(14.0); tween.tween_callback(queue_free)

func apply_knockback(force: Vector3) -> void:
	if state == State.DEAD:
		return
	velocity.x += force.x
	velocity.z += force.z
	velocity.y = maxf(velocity.y, minf(4.5, force.length() * 0.22))
	state = State.COMBAT if actor_kind != Kind.CIVILIAN else State.FLEE

func is_headshot_point(point: Vector3) -> bool:
	return point.y - global_position.y > 1.42

func get_actor_name() -> String:
	return ["Security", "Police", "SWAT", "Civilian", "Employee", "Pawnkeeper"][actor_kind]

func _speak(line: String) -> void:
	_voice_cooldown = 5.0
	if bool(SettingsManager.get_value("subtitles", true)):
		GameManager.notification.emit("%s: %s" % [get_actor_name().to_upper(), line], "voice")
