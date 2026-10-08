extends SceneTree
## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all passed. Script errors raised during a test count as failures.

const TEST_DIR := "res://tests/unit"


class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if not rationale.is_empty() else code
		errors.append("%s (%s:%d in %s)" % [text, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var passed := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	for file_name: String in files:
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR.path_join(file_name))
		if script == null:
			printerr("  FAIL  could not load %s" % file_name)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			counter.errors.clear()
			var test: TestCase = script.new()
			test.current_test = test_name
			test.before_each()
			test.call(test_name)
			test.after_each()
			var problems: Array[String] = test.failures.duplicate()
			for err in counter.errors:
				problems.append("script error: " + err)
			if problems.is_empty():
				passed += 1
				print("  PASS  %s :: %s" % [file_name, test_name])
			else:
				failed += 1
				for problem in problems:
					printerr("  FAIL  %s :: %s -> %s" % [file_name, test_name, problem])
	OS.remove_logger(counter)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
