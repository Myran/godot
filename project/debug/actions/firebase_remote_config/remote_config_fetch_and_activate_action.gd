class_name RemoteConfigFetchAndActivateAction
extends CPPRemoteConfigDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.fetch_and_activate"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting Remote Config fetch and activate test...")

	var rc: Object = get_cpp_remote_config()
	if not is_instance_valid(rc):
		return DebugActionResult.new_failure(
			"FirebaseRemoteConfig C++ instance not available",
			"REMOTE_CONFIG_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Note: Defaults are set in availability action (runs first in suite)
	# Windows SDK requires defaults before fetch_and_activate returns activated=true

	# Execute fetch_and_activate operation
	var request_id: int = Time.get_ticks_msec()
	var start_time: int = Time.get_ticks_msec()

	# Connect to completion signal
	if not rc.has_signal("fetch_and_activate_completed"):
		return DebugActionResult.new_failure(
			"FirebaseRemoteConfig missing fetch_and_activate_completed signal",
			"SIGNAL_NOT_FOUND",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Call the async method
	rc.fetch_and_activate_async(request_id)

	# Wait for completion
	var signal_result: Array = await rc.fetch_and_activate_completed
	var duration: int = Time.get_ticks_msec() - start_time

	# Parse result: [request_id, success, activated, error_message]
	# Handle type conversions from signal
	var recv_request_id: int = int(signal_result[0])
	var success: bool = bool(signal_result[1])
	var activated: bool = bool(signal_result[2])
	var error_message: String = str(signal_result[3])

	var result: Variant = activated if success else null

	if result == null:
		return DebugActionResult.new_failure(
			"Remote Config fetch and activate operation failed",
			"FETCH_AND_ACTIVATE_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var metadata: Dictionary = {
		"operation": "fetch_and_activate",
		"activated": result,
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"✅ Remote Config fetch and activate completed",
		metadata,
		["debug", "cpp_firebase", "remote_config", "fetch"]
	)

	return DebugActionResult.new_success(true, 0, action_name, metadata)
