extends RefCounted
# Sanity test — proves the run_tests pipeline discovers this file,
# instantiates it, and executes its test_* methods. Delete once the
# project has real tests of its own (or keep as a smoke test; it's cheap).

func test_true_is_true() -> bool:
	return true

func test_math_works() -> bool:
	return 2 + 2 == 4

func test_gdscript_string_repeat_is_not_python() -> bool:
	# Reminder: GDScript does NOT support `"=" * 50`. Use `"=".repeat(50)`.
	var line := "=".repeat(50)
	return line.length() == 50
