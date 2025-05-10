extends SceneTree
## Test runner for Promise tests

func _initialize() -> void:
	print("Starting Promise test runner...")
	run_tests()

func run_tests() -> void:
	# Create test node
	var test_node: Node = load("res://tests/test_promise.gd").new()
	root.add_child(test_node)
	
	# Wait for tests to complete
	await test_node.tree_exited
	
	print("Test runner complete")
	quit()
