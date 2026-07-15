extends SceneTree

const DEFAULT_ASSET_PATH := "res://assets/quaternius/animation_library/AnimationLibrary_Godot_Standard.glb"

func _initialize() -> void:
	var asset_path := DEFAULT_ASSET_PATH
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		asset_path = args[0]
	print("ASSET: ", asset_path)
	var packed := load(asset_path) as PackedScene
	if not packed:
		print("ASSET_LOAD_FAILED")
		quit(1)
		return
	var instance := packed.instantiate()
	print("ASSET_TREE")
	_print_tree(instance)
	for node in instance.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		print("ANIMATION_PLAYER: ", player.name)
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			print("LIBRARY: ", library_name, " ANIMATIONS: ", library.get_animation_list())
	for node in instance.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var bone_names: Array[StringName] = []
		for bone_index in skeleton.get_bone_count():
			bone_names.append(skeleton.get_bone_name(bone_index))
		print("BONES: ", bone_names)
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		print("MESH: ", mesh_instance.name, " AABB: ", mesh_instance.get_aabb(), " SURFACES: ", mesh_instance.mesh.get_surface_count())
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface_index)
			print("  MATERIAL ", surface_index, ": ", material.resource_name if material else "none")
	instance.free()
	quit()

func _print_tree(node: Node, depth := 0) -> void:
	print("  ".repeat(depth), node.name, " [", node.get_class(), "]")
	if node is Node3D:
		var spatial := node as Node3D
		print("  ".repeat(depth), "  POSITION=", spatial.position, " SCALE=", spatial.scale, " ROTATION=", spatial.rotation_degrees)
	for child in node.get_children():
		_print_tree(child, depth + 1)
