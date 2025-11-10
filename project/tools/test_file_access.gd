extends SceneTree


func _ready():
	print("=== Testing file access ===")

	# Test file creation with different paths
	var test_file1 = FileAccess.open("test_output.txt", FileAccess.WRITE)
	if test_file1:
		test_file1.store_string("Test from project directory")
		test_file1.close()
		print("✅ Created test_output.txt in current dir")
	else:
		print("❌ Failed to create test_output.txt")

	var test_file2 = FileAccess.open("../inject/test_output.txt", FileAccess.WRITE)
	if test_file2:
		test_file2.store_string("Test from project to inject")
		test_file2.close()
		print("✅ Created ../inject/test_output.txt")
	else:
		print("❌ Failed to create ../inject/test_output.txt")

	var test_file3 = FileAccess.open("res://../inject/test_output2.txt", FileAccess.WRITE)
	if test_file3:
		test_file3.store_string("Test using res:// path")
		test_file3.close()
		print("✅ Created res://../inject/test_output2.txt")
	else:
		print("❌ Failed to create res://../inject/test_output2.txt")

	quit()
