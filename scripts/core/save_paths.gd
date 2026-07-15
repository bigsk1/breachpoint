extends RefCounted

const PORTABLE_ENV := "BREACHPOINT_DATA_DIR"
const PORTABLE_FOLDER := "save-data"

static func resolve_file(filename: String) -> String:
	var legacy_path := "user://".path_join(filename)
	var directory := _portable_directory()
	if directory.is_empty():
		return legacy_path
	var make_result := DirAccess.make_dir_recursive_absolute(directory)
	if make_result != OK and make_result != ERR_ALREADY_EXISTS:
		push_warning("Portable save folder is not writable; using the Windows user profile instead.")
		return legacy_path
	var target_path := directory.path_join(filename)
	if not FileAccess.file_exists(target_path) and FileAccess.file_exists(legacy_path):
		var legacy_absolute := ProjectSettings.globalize_path(legacy_path)
		var copy_result := DirAccess.copy_absolute(legacy_absolute, target_path)
		if copy_result != OK:
			push_warning("Existing %s could not be copied into portable storage." % filename)
	return target_path

static func is_portable_path(path: String) -> bool:
	return not path.begins_with("user://")

static func _portable_directory() -> String:
	var directory := OS.get_environment(PORTABLE_ENV).strip_edges()
	if directory.is_empty() and OS.has_feature("standalone"):
		var executable_dir := OS.get_executable_path().get_base_dir()
		var launcher_parent := executable_dir.get_base_dir()
		if FileAccess.file_exists(launcher_parent.path_join("PLAY_GAME.bat")):
			executable_dir = launcher_parent
		directory = executable_dir.path_join(PORTABLE_FOLDER)
	if directory.is_empty():
		return ""
	directory = directory.replace("\\", "/").trim_suffix("/")
	if not directory.is_absolute_path():
		directory = OS.get_executable_path().get_base_dir().path_join(directory)
	return directory.simplify_path()
