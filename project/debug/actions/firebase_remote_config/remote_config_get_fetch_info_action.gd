class_name RemoteConfigGetFetchInfoAction
extends CPPRemoteConfigDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.get_fetch_info"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Retrieving Remote Config fetch info...")

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

	# Get fetch info
	var fetch_info: Dictionary = rc.get_fetch_info()

	# Add human-readable status description
	var status_description: String = ""
	match fetch_info.get("status", ""):
		"Success":
			status_description = "Last fetch completed successfully"
		"Failure":
			status_description = "Last fetch failed"
		"Pending":
			status_description = "Fetch operation in progress"
		"NoFetchYet":
			status_description = "No fetch has been performed yet"
		_:
			status_description = "Unknown status"

	var metadata: Dictionary = {
		"operation": "get_fetch_info",
		"fetch_info": fetch_info,
		"status_description": status_description,
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"✅ Remote Config fetch info retrieved",
		metadata,
		["debug", "cpp_firebase", "remote_config", "fetch_info"]
	)

	return DebugActionResult.new_success(true, 0, action_name, metadata)
