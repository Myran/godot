class_name FirebaseServiceDiagnosticAction
extends DebugAction


func _init() -> void:
	super._init()
	action_name = "firebase.service.diagnostic"
	category = "Firebase Debug"
	action_callable = Callable(self, "execute_firebase_diagnostic")


func execute_firebase_diagnostic() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	var diagnostic_info: Dictionary = {}

	Log.info("🔍 FIREBASE SERVICE DIAGNOSTIC START", {}, ["debug", "firebase", "diagnostic"])

	# Test 1: Check if FirebaseService autoload exists
	var firebase_service_exists: bool = false
	var firebase_service_instance: Node = null

	if Engine.has_singleton("FirebaseService"):
		firebase_service_exists = true
		firebase_service_instance = Engine.get_singleton("FirebaseService")
		diagnostic_info["firebase_service_singleton"] = true
	else:
		# Try to access via autoload tree
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			firebase_service_instance = tree.root.get_node_or_null("FirebaseService")
			if firebase_service_instance:
				firebase_service_exists = true
				diagnostic_info["firebase_service_autoload"] = true
			else:
				diagnostic_info["firebase_service_missing"] = true

	Log.info(
		"📊 Firebase Service Autoload Status",
		{
			"exists": firebase_service_exists,
			"singleton": Engine.has_singleton("FirebaseService"),
			"autoload_found": firebase_service_instance != null
		},
		["debug", "firebase", "diagnostic"]
	)

	# Test 2: Check C++ Firebase class availability
	var firebase_db_available: bool = ClassDB.class_exists("FirebaseDatabase")
	var firebase_auth_available: bool = ClassDB.class_exists("FirebaseAuth")

	diagnostic_info["cpp_firebase_database"] = firebase_db_available
	diagnostic_info["cpp_firebase_auth"] = firebase_auth_available

	Log.info(
		"📊 C++ Firebase Classes",
		{"FirebaseDatabase": firebase_db_available, "FirebaseAuth": firebase_auth_available},
		["debug", "firebase", "diagnostic"]
	)

	# Test 3: Check FirebaseService initialization status (if exists)
	var service_initialized: bool = false
	var service_available: bool = false
	var service_has_db: bool = false

	if firebase_service_instance:
		if firebase_service_instance.has_method("is_available"):
			service_available = firebase_service_instance.is_available()

		# Use reflection to check private fields safely
		if firebase_service_instance.has_method("get"):
			var is_initialized_value: Variant = firebase_service_instance.get("_is_initialized")
			if is_initialized_value != null:
				service_initialized = is_initialized_value

		var db_instance: Variant = (
			firebase_service_instance.get("db")
			if firebase_service_instance.has_method("get")
			else null
		)
		service_has_db = db_instance != null

		diagnostic_info["service_initialized"] = service_initialized
		diagnostic_info["service_available"] = service_available
		diagnostic_info["service_has_db"] = service_has_db

		Log.info(
			"📊 FirebaseService Status",
			{
				"initialized": service_initialized,
				"available": service_available,
				"has_db": service_has_db,
				"service_class": Utils.get_type(firebase_service_instance)
			},
			["debug", "firebase", "diagnostic"]
		)

	# Test 4: Try to instantiate FirebaseDatabase C++ class directly
	var cpp_instantiation_success: bool = false
	var cpp_instantiation_error: String = ""

	if firebase_db_available:
		var cpp_db_instance: Object = ClassDB.instantiate("FirebaseDatabase")
		if is_instance_valid(cpp_db_instance):
			cpp_instantiation_success = true
			diagnostic_info["cpp_instantiation_success"] = true
			# Clean up
			if cpp_db_instance.has_method("queue_free"):
				cpp_db_instance.queue_free()
		else:
			cpp_instantiation_error = "ClassDB.instantiate returned invalid instance"

	diagnostic_info["cpp_instantiation_success"] = cpp_instantiation_success
	if not cpp_instantiation_error.is_empty():
		diagnostic_info["cpp_instantiation_error"] = cpp_instantiation_error

	Log.info(
		"📊 C++ Firebase Instantiation Test",
		{"success": cpp_instantiation_success, "error": cpp_instantiation_error},
		["debug", "firebase", "diagnostic"]
	)

	# Test 5: Check if DataSource has FirebaseServiceBackend
	var data_source_backend_type: String = "unknown"
	var data_source_initialized: bool = false

	if data_source:
		data_source_initialized = data_source.is_initialized()
		if data_source_initialized and data_source._backend:
			data_source_backend_type = Utils.get_type(data_source._backend)

		diagnostic_info["data_source_initialized"] = data_source_initialized
		diagnostic_info["data_source_backend_type"] = data_source_backend_type

		Log.info(
			"📊 DataSource Status",
			{"initialized": data_source_initialized, "backend_type": data_source_backend_type},
			["debug", "firebase", "diagnostic"]
		)

	var total_duration: int = Time.get_ticks_msec() - start_time

	# Determine overall success
	var diagnostic_success: bool = (
		firebase_service_exists
		and firebase_db_available
		and service_initialized
		and service_available
		and cpp_instantiation_success
	)

	var summary: Dictionary = {
		"firebase_service_exists": firebase_service_exists,
		"cpp_firebase_available": firebase_db_available,
		"service_initialized": service_initialized,
		"service_available": service_available,
		"cpp_instantiation_works": cpp_instantiation_success,
		"data_source_backend": data_source_backend_type,
		"overall_status": "WORKING" if diagnostic_success else "FAILED"
	}

	Log.info("🎯 FIREBASE SERVICE DIAGNOSTIC COMPLETE", summary, ["debug", "firebase", "diagnostic"])

	if diagnostic_success:
		return DebugActionResult.new_success(
			"Firebase service diagnostic completed - all systems working",
			total_duration,
			action_name,
			diagnostic_info
		)

	return DebugActionResult.new_failure(
		"Firebase service diagnostic found issues",
		"DIAGNOSTIC_FAILED",
		DebugActionResult.ErrorCategory.FIREBASE,
		diagnostic_info,
		total_duration,
		action_name
	)
