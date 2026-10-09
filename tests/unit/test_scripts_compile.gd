extends TestCase
## Every game script must compile. Catches parse/type errors in code the logic tests don't load
## (rendering, UI) before they reach a build.


func test_all_game_scripts_compile() -> void:
	var paths: Array[String] = []
	_collect("res://src", paths)
	assert_gt(paths.size(), 20, "found the game scripts")
	for path in paths:
		var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
		assert_true(script != null and script.can_instantiate(), "compiles: " + path)


func _collect(dir_path: String, into: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			into.append(dir_path.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), into)
