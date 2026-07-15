class_name CharacterVisual
extends Node3D

const MEN_SCENE: PackedScene = preload("res://assets/quaternius/modular_characters/Men_Master.fbx")
const WOMEN_SCENE: PackedScene = preload("res://assets/quaternius/modular_characters/Women_Master.fbx")

const SECURITY := 0
const POLICE := 1
const SWAT := 2
const CIVILIAN := 3
const EMPLOYEE := 4
const PAWNKEEPER := 5

const ANIMATIONS := {
	"Idle": &"CharacterArmature|Idle_Neutral",
	"ArmedIdle": &"CharacterArmature|Idle_Gun_Pointing",
	"Walk": &"CharacterArmature|Walk",
	"Run": &"CharacterArmature|Run",
	"Shoot": &"CharacterArmature|Idle_Gun_Shoot",
	"HitBody": &"CharacterArmature|HitRecieve",
	"HitHead": &"CharacterArmature|HitRecieve_2",
	"Death": &"CharacterArmature|Death",
	"Punch": &"CharacterArmature|Punch_Right",
}

var _actor_kind := SECURITY
var _variant_seed := 1
var _armed := true
var _model: Node3D
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _rng := RandomNumberGenerator.new()
var _desired_state := &"Idle"
var _current_state := &""
var _action_lock := 0.0
var _alive := true
var _base_height := 0.0

func configure(kind: int, variant_seed: int) -> void:
	_actor_kind = kind
	_variant_seed = maxi(1, variant_seed)
	_armed = kind not in [CIVILIAN, EMPLOYEE]

func _ready() -> void:
	_rng.seed = _variant_seed
	var use_woman := _actor_kind != SWAT and _rng.randi_range(0, 1) == 1
	var scene := WOMEN_SCENE if use_woman else MEN_SCENE
	_model = scene.instantiate() as Node3D
	if not _model:
		push_error("Character model could not be instantiated.")
		return
	add_child(_model)
	_model.rotation_degrees.y = 180.0
	var height_scale := _rng.randf_range(0.97, 1.04)
	scale = Vector3.ONE * height_scale
	_base_height = _model.position.y
	var appearance := _choose_appearance(use_woman)
	_show_appearance(appearance)
	_apply_material_variation()
	_animation_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player:
		_build_animation_tree()
	else:
		push_error("Character model is missing its AnimationPlayer.")

func _choose_appearance(use_woman: bool) -> String:
	if use_woman:
		match _actor_kind:
			SECURITY:
				return "Suit"
			POLICE:
				return "Soldier"
			SWAT:
				return "Soldier"
			CIVILIAN:
				var options := ["Casual", "Suit", "Worker", "Punk", "Formal"]
				return options[_rng.randi_range(0, options.size() - 1)]
			EMPLOYEE:
				return "Worker"
			PAWNKEEPER:
				return "Suit" if _rng.randi_range(0, 1) == 0 else "Worker"
	else:
		match _actor_kind:
			SECURITY:
				return "Suit"
			POLICE:
				return "Swat"
			SWAT:
				return "Swat"
			CIVILIAN:
				var options := ["Casual", "Casual2", "Worker", "Punk", "Suit"]
				return options[_rng.randi_range(0, options.size() - 1)]
			EMPLOYEE:
				return "Worker"
	return "Casual"

func _show_appearance(prefix: String) -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var part_name := String(mesh_instance.name)
		var belongs_to_outfit := part_name.begins_with(prefix + "_")
		if prefix == "Formal" and part_name == "Formad_Head":
			belongs_to_outfit = true
		mesh_instance.visible = belongs_to_outfit or (_armed and part_name == "Pistol")
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _apply_material_variation() -> void:
	var skin_tones := [
		Color("#f0c5a5"),
		Color("#d6a27f"),
		Color("#b77a59"),
		Color("#8d5b43"),
		Color("#684033"),
	]
	var hair_tones := [
		Color("#241b18"),
		Color("#513323"),
		Color("#8b5a2f"),
		Color("#d2ad69"),
		Color("#3a302a"),
	]
	var eye_tones := [Color("#443329"), Color("#315b67"), Color("#4d6840"), Color("#241d18")]
	var skin_color: Color = skin_tones[_rng.randi_range(0, skin_tones.size() - 1)]
	var hair_color: Color = hair_tones[_rng.randi_range(0, hair_tones.size() - 1)]
	var eye_color: Color = eye_tones[_rng.randi_range(0, eye_tones.size() - 1)]
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.visible or not mesh_instance.mesh:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if not source:
				continue
			var material := source.duplicate() as StandardMaterial3D
			var material_name := String(source.resource_name)
			if material_name.contains("Skin"):
				material.albedo_color = skin_color
			elif material_name.contains("Hair") or material_name in ["Eyebrows", "Moustache"]:
				material.albedo_color = hair_color
			elif material_name == "Eye":
				material.albedo_color = eye_color
			elif _actor_kind == SECURITY and material_name in ["Suit", "Black"]:
				material.albedo_color = Color("#17273b") if material_name == "Suit" else Color("#101820")
			elif _actor_kind == POLICE and material_name in ["Swat", "Black"]:
				material.albedo_color = Color("#24466b") if material_name == "Swat" else Color("#111a24")
			elif _actor_kind == SWAT and material_name in ["Swat", "Swat_Black", "Black"]:
				material.albedo_color = Color("#171d22") if material_name == "Swat" else Color("#090c0f")
				material.metallic = maxf(material.metallic, 0.22)
			material.roughness = maxf(material.roughness, 0.62)
			mesh_instance.set_surface_override_material(surface_index, material)

func _build_animation_tree() -> void:
	var looping_animations := [
		ANIMATIONS["Idle"],
		ANIMATIONS["ArmedIdle"],
		ANIMATIONS["Walk"],
		ANIMATIONS["Run"],
	]
	for animation_name in looping_animations:
		if _animation_player.has_animation(animation_name):
			_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	var state_machine := AnimationNodeStateMachine.new()
	var states := ANIMATIONS.keys()
	for state_name in states:
		var animation_node := AnimationNodeAnimation.new()
		animation_node.animation = ANIMATIONS[state_name]
		state_machine.add_node(StringName(state_name), animation_node, Vector2.ZERO)
	for from_state in states:
		for to_state in states:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.16 if to_state not in ["Shoot", "HitBody", "HitHead"] else 0.06
			state_machine.add_transition(StringName(from_state), StringName(to_state), transition)
	_animation_tree = AnimationTree.new()
	_animation_tree.name = "CharacterAnimationTree"
	add_child(_animation_tree)
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)
	_animation_tree.tree_root = state_machine
	_animation_tree.active = true
	_playback = _animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_set_state(&"ArmedIdle" if _armed else &"Idle", true)

func update_motion(horizontal_speed: float, top_speed: float, panic: bool) -> void:
	if not _alive:
		return
	if horizontal_speed < 0.18:
		_desired_state = &"ArmedIdle" if _armed else &"Idle"
	elif panic or horizontal_speed > top_speed * 0.72:
		_desired_state = &"Run"
	else:
		_desired_state = &"Walk"
	if _action_lock <= 0.0:
		_set_state(_desired_state)

func trigger_shoot() -> void:
	if not _alive:
		return
	_action_lock = 0.24
	_set_state(&"Shoot", true)

func trigger_hit(headshot: bool) -> void:
	if not _alive:
		return
	_action_lock = 0.46
	_set_state(&"HitHead" if headshot else &"HitBody", true)

func trigger_melee() -> void:
	if not _alive:
		return
	_action_lock = 0.42
	_set_state(&"Punch", true)

func trigger_death() -> void:
	if not _alive:
		return
	_alive = false
	_action_lock = 999.0
	_set_state(&"Death", true)

func _process(delta: float) -> void:
	if not _alive:
		return
	if _action_lock > 0.0:
		_action_lock = maxf(0.0, _action_lock - delta)
		if _action_lock <= 0.0:
			_set_state(_desired_state)
	if _model and _current_state in [&"Idle", &"ArmedIdle"]:
		var breathing := sin(Time.get_ticks_msec() * 0.0021 + float(_variant_seed % 17)) * 0.0025
		_model.position.y = _base_height + breathing
	elif _model:
		_model.position.y = move_toward(_model.position.y, _base_height, delta * 0.04)

func _set_state(state_name: StringName, force_restart := false) -> void:
	if not _playback or (state_name == _current_state and not force_restart):
		return
	_current_state = state_name
	if force_restart:
		_playback.start(state_name, true)
	else:
		_playback.travel(state_name)
