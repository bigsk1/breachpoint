extends SceneTree

const CharacterVisualScript := preload("res://scripts/ai/character_visual.gd")

func _initialize() -> void:
	_build_preview.call_deferred()

func _build_preview() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("#18202b")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("#dce8ff")
	world.ambient_light_energy = 0.7
	environment.environment = world
	stage.add_child(environment)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12.0, 7.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#48505b")
	floor_material.roughness = 0.92
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	stage.add_child(floor)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_energy = 1.4
	key_light.shadow_enabled = true
	stage.add_child(key_light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.45, 7.2)
	camera.fov = 42.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	for kind in 4:
		var visual := CharacterVisualScript.new()
		visual.configure(kind, 7349 + kind * 103)
		visual.position = Vector3(-2.55 + kind * 1.7, 0.0, 0.0)
		stage.add_child(visual)
		match kind:
			0:
				visual.trigger_shoot()
			1:
				visual.trigger_hit(false)
			2:
				visual.trigger_death()
			3:
				visual.update_motion(3.5, 3.8, true)
		visual.look_at(Vector3(visual.position.x, 1.0, camera.position.z), Vector3.UP)
	for frame in 24:
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/breachpoint-character-preview.png")
	print("PREVIEW_SAVED: ", error)
	quit()
