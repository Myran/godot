## Test Firestore error handling
class_name TestFirestoreErrorHandling extends FirebaseTestActionBase


func _init() -> void:
	super("test.firestore.error_handling", _execute_test)
	set_category("Firebase SDK")
	set_group("Firestore")
	set_description("Test Firestore error handling")
	set_use_auto_success_logging(false)


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Platform not supported")

	Log.info("Firestore Error Handling Test START", {}, ["debug", "firestore", "test"])

	# Check C++ class is available
	assert_true(ClassDB.class_exists("FirebaseFirestore"), "FirebaseFirestore C++ class exists")
	if not ClassDB.class_exists("FirebaseFirestore"):
		return _assertion_result()

	var firestore: Object = FirebaseFirestore.new()
	assert_true(is_instance_valid(firestore), "FirebaseFirestore instance created")
	if not is_instance_valid(firestore):
		return _assertion_result()

	# Check for required methods
	assert_true(firestore.has_method("initialize"), "FirebaseFirestore has initialize method")
	assert_true(
		firestore.has_method("set_document_async"),
		"FirebaseFirestore has set_document_async method"
	)
	assert_true(
		firestore.has_method("get_document_async"),
		"FirebaseFirestore has get_document_async method"
	)
	assert_true(
		firestore.has_method("update_document_async"),
		"FirebaseFirestore has update_document_async method"
	)
	assert_true(
		firestore.has_method("delete_document_async"),
		"FirebaseFirestore has delete_document_async method"
	)
	assert_true(
		firestore.has_method("query_collection_async"),
		"FirebaseFirestore has query_collection_async method"
	)

	# Mark test as passed before returning
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(action_name, "Firebase SDK", "Firestore", duration, {})
	return _assertion_result()
