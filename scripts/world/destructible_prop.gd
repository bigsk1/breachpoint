class_name DestructibleProp
extends StaticBody3D

var durability := 30.0
var shard_color := Color("#a9d7df")

func setup(size: Vector3, color: Color, transparent := false) -> void:
	collision_layer = 1; collision_mask = 2 | 8
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; add_child(collision)
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.18
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color.a = 0.34; material.metallic = 0.12
	mesh.material = material; visual.mesh = mesh; add_child(visual)

func take_damage(amount: float, _headshot := false, _source: Object = null) -> void:
	durability -= amount
	if durability <= 0.0:
		shatter()

func shatter() -> void:
	for i in 8:
		var shard := RigidBody3D.new(); shard.mass = 0.08; shard.collision_layer = 1; shard.collision_mask = 1
		var mesh_instance := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(0.08, 0.12, 0.025) * randf_range(0.6, 1.5)
		var mat := StandardMaterial3D.new(); mat.albedo_color = shard_color; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color.a = 0.52; mesh.material = mat; mesh_instance.mesh = mesh; shard.add_child(mesh_instance)
		get_parent().add_child(shard); shard.global_position = global_position + Vector3(randf_range(-0.4,0.4), randf_range(-0.3,0.4), randf_range(-0.1,0.1)); shard.linear_velocity = Vector3(randf_range(-2,2), randf_range(1,4), randf_range(-2,2))
		var tween := shard.create_tween(); tween.tween_interval(4.0); tween.tween_callback(shard.queue_free)
	GameManager.notification.emit("Glass shattered", "warn")
	queue_free()
