class_name CPPAuthDebugAction
extends DebugAction
## Base class for C++ Firebase Auth debug actions.
## Provides NSRunLoop pumping for iOS/macOS callback execution (task-414).

var cpp_auth: Object = null
var cpp_auth_instance_id: int = -1
var firebase_instance: Object = null  # For NSRunLoop pumping on iOS/macOS


func _init() -> void:
	super._init()
	category = "C++ Firebase Auth"
	action_callable = Callable(self, "_execute_action_logic")
	auto_continue = false  # Wait for async completion (Firebase Auth signals may take time)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Clean up Firebase instance used for NSRunLoop pumping
		firebase_instance = null
		cpp_auth = null


func get_cpp_firebase_auth() -> Object:
	if cpp_auth != null and is_instance_valid(cpp_auth):
		return cpp_auth

	Log.debug("Creating direct C++ Firebase Auth instance", {}, ["debug", "cpp_auth"])

	if not ClassDB.class_exists("FirebaseAuth"):
		Log.error("FirebaseAuth C++ class not available", {}, ["debug", "cpp_auth", "error"])
		return null

	cpp_auth = ClassDB.instantiate("FirebaseAuth")
	if not is_instance_valid(cpp_auth):
		Log.error("Failed to instantiate C++ FirebaseAuth", {}, ["debug", "cpp_auth", "error"])
		return null

	cpp_auth_instance_id = cpp_auth.get_instance_id()
	Log.info(
		"C++ Firebase Auth instance created",
		{"cpp_instance_id": cpp_auth_instance_id},
		["debug", "cpp_auth"]
	)
	return cpp_auth


# Initialize Firebase instance for NSRunLoop pumping on iOS/macOS
# Call this before polling for Firebase C++ async operation completion
func _start_nsloop_pumping() -> void:
	# iOS/macOS require NSRunLoop pumping for Firebase callbacks to execute
	# Android JNI callbacks work differently - no action needed
	if not OS.has_feature("ios") and not OS.has_feature("macos"):
		return

	# Create Firebase instance for process_notifications()
	if not is_instance_valid(firebase_instance):
		if ClassDB.class_exists("Firebase"):
			firebase_instance = ClassDB.instantiate("Firebase")
			if is_instance_valid(firebase_instance):
				Log.debug(
					"Firebase instance created for NSRunLoop pumping",
					{},
					["debug", "cpp_auth", "ios"]
				)
			else:
				Log.warning(
					"Failed to create Firebase instance for NSRunLoop",
					{},
					["debug", "cpp_auth", "ios"]
				)
		else:
			Log.warning(
				"Firebase class not available for NSRunLoop pumping",
				{},
				["debug", "cpp_auth", "ios"]
			)


# Stop NSRunLoop pumping after async operation completes
func _stop_nsloop_pumping() -> void:
	# Firebase instance cleanup is handled in _notification(PREDELETE)
	pass


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	push_error("_execute_action_logic() not implemented in " + get_script().get_path())
	_update_status("ERROR: _execute_action_logic() not implemented", true)
	return DebugActionResult.new_failure(
		str("_execute_action_logic() not implemented in " + get_script().get_path()),
		"NOT_IMPLEMENTED",
		DebugActionResult.ErrorCategory.SYSTEM,
		{"error": "missing_implementation"},
		0,
		action_name,
		{}
	)
