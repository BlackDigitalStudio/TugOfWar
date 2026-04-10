extends SceneTree
# Tug of War test runner.
#
# Scans res:// for files matching *.test.gd, instantiates each as a
# RefCounted, and runs every method whose name starts with "test_".
# A test passes if it returns true (or returns nothing / null).
# A test fails if it returns false or throws.
#
# Launched by the ./run_tests bash script via:
#   godot --headless --path <project> --script res://tests/test_runner.gd

func _init() -> void:
	print("== Tug of War test runner ==")

	var files: Array[String] = []
	_find_tests("res://", files)

	if files.is_empty():
		print("No *.test.gd files found under res://.")
		quit(0)
		return

	print("Discovered %d test file(s):" % files.size())
	for f in files:
		print("  - %s" % f)
	print("")

	var total := 0
	var failures := 0

	for path in files:
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_error("run_tests: failed to load script %s" % path)
			failures += 1
			continue

		var instance = script.new()
		if instance == null:
			push_error("run_tests: failed to instantiate %s" % path)
			failures += 1
			continue

		var relative: String = path.trim_prefix("res://")
		for m in instance.get_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			total += 1
			var result = instance.call(mname)
			if result == false:
				print("  [FAIL] %s :: %s" % [relative, mname])
				failures += 1
			else:
				print("  [PASS] %s :: %s" % [relative, mname])

	print("")
	print("%d tests, %d failures" % [total, failures])
	quit(1 if failures > 0 else 0)


func _find_tests(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_find_tests(full, out)
		elif entry.ends_with(".test.gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
